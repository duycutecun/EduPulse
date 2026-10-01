import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/ai/ai_chat_actions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../study/domain/models/study_models.dart';
import '../../domain/quiz_models.dart';
import '../widgets/ai_coach_header.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/model_picker_sheet.dart';
import 'quiz_play_screen.dart';

class AiCoachScreen extends StatefulWidget {
  final String? initialPrompt;
  final VoidCallback? onClose;

  const AiCoachScreen({super.key, this.initialPrompt, this.onClose});

  @override
  AiCoachScreenState createState() => AiCoachScreenState();
}

/// State công khai để màn hình khác (ví dụ card gợi ý AI ở Home) có thể
/// nhồi một câu hỏi vào hội thoại đang mở mà không phải tạo lại screen.
class AiCoachScreenState extends State<AiCoachScreen> {
  final List<ChatMessage> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  final _uuid = const Uuid();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  AIModel _model = AIModel.defaultModel;
  bool _autoReadImage = false;

  /// Gửi câu hỏi có sẵn vào hội thoại (dùng khi học sinh bấm vào một gợi ý
  /// AI ở Home — gợi ý đó trở thành một cuộc trò chuyện thật thay vì chỉ là
  /// dòng chữ tĩnh).
  void sendPrompt(String text) {
    if (text.trim().isEmpty) return;
    _sendMessage(text);
  }

  bool get _isIntroOnly => _messages.length == 1;

  @override
  void initState() {
    super.initState();
    // Luôn chạy ở chế độ Auto: AI chọn model hợp lý theo câu hỏi và tự chuyển
    // sang model khác khi model đang dùng bị lỗi.
    _model = AIModel.defaultModel;
    _autoReadImage = true;
    _loadChatHistory();

    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sendPrompt(widget.initialPrompt!);
      });
    }
  }

  void _loadChatHistory() {
    final saved = StorageService.getAiChatHistory();
    if (saved != null && saved.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(saved);
        final loaded = list
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
        if (loaded.isNotEmpty) {
          _messages.addAll(loaded);
          return;
        }
      } catch (_) {}
    }

    _messages.add(ChatMessage(
      id: _uuid.v4(),
      text:
          'Chào bạn! Tôi là AI Coach EduPulse — trợ lý giải đề & luyện thi.\n\n- 📷 OCR quét ảnh bài tập\n- 🧠 Chỉ ra bẫy trắc nghiệm\n- 🗺️ Lộ trình cá nhân hóa\n- 🔍 Tra cứu web để biết thêm thông tin\n\nHãy đặt câu hỏi hoặc tải ảnh bài tập!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _saveChatHistory() {
    try {
      final validMsgs = _messages.where((m) => !m.isLoading).toList();
      final capped = validMsgs.length > 40
          ? validMsgs.sublist(validMsgs.length - 40)
          : validMsgs;
      final encoded = jsonEncode(capped.map((m) => m.toJson()).toList());
      StorageService.setAiChatHistory(encoded);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final file = files.first;
      var bytes = await file.readAsBytes();
      // Nén ảnh lớn ngay tại chỗ để AI đọc được (proxy serverless giới hạn ~4MB).
      final compressed = await ImageCompressor.compress(bytes);
      if (compressed != null) bytes = compressed;
      if (mounted && bytes.isNotEmpty) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
        if (_autoReadImage) {
          _sendMessage(
              'Hãy đọc nội dung trong ảnh này và giải thích giúp tôi.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  /// Phân tích lịch sử chat để tìm chủ đề yếu lặp lại.
  Future<void> _analyzeWeakTopics() async {
    if (!(StorageService.getBool('ai_permission_analyze') ?? true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bạn đã tắt quyền AI phân tích tiến độ trong mục Tôi.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    if (!PwaService.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('AI cần kết nối mạng — hãy thử lại khi online!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    // Gom 15 tin nhắn user gần nhất (bỏ tin intro/loading).
    final userMsgs =
        _messages.where((m) => m.isUser && m.text.trim().isNotEmpty).toList();
    final recent = userMsgs.length > 15
        ? userMsgs.sublist(userMsgs.length - 15)
        : userMsgs;
    final userMessages = recent.map((m) => m.text.trim()).toList();

    if (userMessages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Chưa có hội thoại để phân tích — hãy hỏi AI vài bài tập trước!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    final prompt = '''
Dưới đây là các câu hỏi gần đây của một sĩ tử trong lịch sử chat với AI Coach:
${userMessages.map((m) => '• $m').join('\n')}

Hãy phân tích và trả lời:
1. Các CHỦ ĐỀ/CHUYÊN ĐỀ yếu lặp lại nhiều lần (nếu có) — vd: hàm số, điện xoay chiều, câu điều kiện...
2. Dạng bài khiến học sinh hay vướng mắc.
3. Gợi ý 3 việc cụ thể nên làm trong tuần này để cải thiện.

Trả lời ngắn gọn, súc tích, dùng bullet.
''';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      color: AppColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Điểm yếu từ lịch sử chat',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: FutureBuilder<String>(
                  future: AiRouter.chat(
                    model: _model,
                    history: const [],
                    userMessage: prompt,
                    searchWeb: false,
                  ),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: AppColors.purple),
                            const SizedBox(height: 12),
                            Text('AI đang phân tích...',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text('Lỗi: ${snap.error}',
                            style: const TextStyle(color: AppColors.red)),
                      );
                    }
                    return SingleChildScrollView(
                      child: Text(
                        snap.data ?? '',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Đã hiểu',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Suy đoán tên môn từ tên file/nội dung người dùng chọn để quiz từ ảnh
  /// được ghi điểm đúng môn (MockScore), giúp AI tư vấn môn yếu chính xác.
  String _inferSubjectFromNote(String hint) {
    final lower = hint.toLowerCase();
    if (lower.contains('toán') || lower.contains('toan')) return 'Toán';
    if (lower.contains('lý') || lower.contains('vat li')) return 'Vật lý';
    if (lower.contains('hóa') || lower.contains('hoa hoc')) return 'Hóa học';
    if (lower.contains('anh') || lower.contains('english')) return 'Tiếng Anh';
    if (lower.contains('văn')) return 'Ngữ văn';
    if (lower.contains('sinh')) return 'Sinh học';
    if (lower.contains('sử')) return 'Lịch sử';
    if (lower.contains('địa')) return 'Địa lý';
    return 'Tổng hợp';
  }

  /// Tạo quiz từ ảnh (đã chọn hoặc mở picker).
  Future<void> _createQuiz() async {
    Uint8List? image = _selectedImageBytes;
    String? name = _selectedImageName;

    if (image == null) {
      try {
        final files = await FilePicker.pickFiles(type: FileType.image);
        if (files.isEmpty) return;
        final file = files.first;
        var bytes = await file.readAsBytes();
        if (bytes.isEmpty) return;
        final compressed = await ImageCompressor.compress(bytes);
        if (compressed != null) bytes = compressed;
        image = bytes;
        name = file.name;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
        return;
      }
    }
    _clearImage();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.quiz_rounded,
                      color: AppColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Tạo quiz từ ảnh',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'AI sẽ đọc nội dung "$name" và tạo 5 câu hỏi trắc nghiệm để bạn luyện ngay.',
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: FutureBuilder<String>(
                  future: AiRouter.chat(
                    model: _model,
                    history: const [],
                    userMessage: buildQuizPrompt(),
                    imageBytes: image,
                    searchWeb: false,
                  ),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: AppColors.purple),
                            const SizedBox(height: 12),
                            Text('AI đang đọc ảnh & soạn câu hỏi...',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text('Lỗi: ${snap.error}',
                            style: const TextStyle(color: AppColors.red)),
                      );
                    }
                    final questions = parseQuiz(snap.data ?? '');
                    if (questions.isEmpty) {
                      return Center(
                        child: Text(
                          'AI không tạo được câu hỏi từ ảnh này. Thử ảnh khác rõ nét hơn!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text('Đã tạo ${questions.length} câu hỏi!',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => QuizPlayScreen(
                                    questions: questions,
                                    subject: _inferSubjectFromNote(name ?? 'quiz'),
                                    topic: 'Quiz từ ảnh: $name',
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.purple,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                      color: AppColors.purple,
                                      blurRadius: 0,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              child: const Text('LUYỆN NGAY',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _selectedImageBytes == null) return;

    if (!PwaService.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bạn đang ngoại tuyến. AI Coach cần kết nối mạng để giải đề.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE65100),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final messageText = text.trim();
    _ctrl.clear();
    final attachedImage = _selectedImageBytes;
    final attachedName = _selectedImageName;
    _clearImage();

    final userMsg = ChatMessage(
        id: _uuid.v4(),
        text: messageText,
        isUser: true,
        timestamp: DateTime.now(),
        imageBytes: attachedImage,
        imageName: attachedName);
    final loadingMsg = ChatMessage(
        id: _uuid.v4(),
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true);

    setState(() {
      _messages.add(userMsg);
      _messages.add(loadingMsg);
      _isLoading = true;
    });
    _saveChatHistory();
    _scrollToBottom();

    final response = await AiRouter.chat(
      model: _model,
      history: _messages.where((m) => !m.isLoading).toList(),
      userMessage: messageText,
      imageBytes: attachedImage,
    );

    // AI biết HÀNH ĐỘNG: tách khối <<<ACTIONS>>> khỏi câu trả lời — phần
    // text sạch hiển thị, phần hành động thành nút bấm thật trong bubble.
    final parsed = AiChatActionParser.parse(response);

    setState(() {
      _messages.remove(loadingMsg);
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        text: parsed.text,
        isUser: false,
        timestamp: DateTime.now(),
        // Source card (mục 10.9): nguồn web đã dùng cho câu trả lời này.
        sourceTitle: AiRouter.lastWebSource?.title,
        sourceUrl: AiRouter.lastWebSource?.pageUrl,
        actions: parsed.actions,
      ));
      _isLoading = false;
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  /// Regenerate câu trả lời AI (đặc tả mục 10.10): gửi lại câu hỏi
  /// cuối của người dùng, thay thế câu trả lời cũ.
  Future<void> _regenerate(ChatMessage aiMessage) async {
    if (_isLoading) return;
    final index = _messages.indexOf(aiMessage);
    if (index <= 0) return; // không tìm thấy / không có câu hỏi phía trước.
    final userMessage = _messages[index - 1];
    if (!userMessage.isUser) return;

    final loadingMsg = ChatMessage(
      id: _uuid.v4(),
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    setState(() {
      _messages[index] = loadingMsg;
      _isLoading = true;
    });
    _scrollToBottom();

    String response;
    try {
      response = await AiRouter.chat(
        model: _model,
        history:
            _messages.where((m) => !m.isLoading && m != loadingMsg).toList(),
        userMessage: userMessage.text,
        imageBytes: userMessage.imageBytes,
      );
    } catch (_) {
      setState(() {
        _messages[index] = aiMessage; // giữ câu cũ — không mất nội dung.
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa tạo lại được — giữ nguyên câu trả lời cũ.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    final parsed = AiChatActionParser.parse(response);
    setState(() {
      _messages[index] = ChatMessage(
        id: _uuid.v4(),
        text: parsed.text,
        isUser: false,
        timestamp: DateTime.now(),
        imageBytes: userMessage.imageBytes,
        sourceTitle: AiRouter.lastWebSource?.title,
        sourceUrl: AiRouter.lastWebSource?.pageUrl,
        actions: parsed.actions,
      );
      _isLoading = false;
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent + 80);
      }
    });
  }

  void _showModelPicker() {
    showModelPickerSheet(
      context: context,
      currentModel: _model,
      onSelect: (m) {
        setState(() => _model = m);
        StorageService.setAiModel(m.slug);
      },
    );
  }

  void _refreshChat() {
    StorageService.clearAiChatHistory();
    setState(() {
      if (_messages.length > 1) {
        _messages.removeRange(1, _messages.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AICoachHeader(
          model: _model,
          onModelTap: _showModelPicker,
          onRefresh: _refreshChat,
          onAnalyze: _analyzeWeakTopics,
          showRefresh: _messages.length > 1,
          showAnalyze: _messages.length > 1,
          onClose: widget.onClose,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: _messages.length + (_isIntroOnly ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (_isIntroOnly && i == 0) {
                // Empty AI (đặc tả mục 33): mascot + gợi ý prompt — chạm
                // để điền vào ô nhập, người dùng tự quyết định gửi (mục
                // 10.4). Gợi ý mang tính cá nhân hóa theo môn đang học.
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Center(
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/mascot.png',
                            width: 116,
                            height: 116,
                            fit: BoxFit.contain,
                            cacheWidth: 348,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Hôm nay ôn gì together? 🦁',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final prompt in const [
                            'Giải thích dạng bài đạo hàm lớp 12',
                            'Lập kế hoạch 3 ngày trước thi',
                            'Kiểm tra lần này sai ở đâu?',
                          ])
                            ActionChip(
                              label: Text(prompt,
                                  style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                _ctrl.text = prompt;
                                _ctrl.selection = TextSelection.collapsed(
                                    offset: prompt.length);
                                _focusNode.requestFocus();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return ChatBubble(
                msg: _messages[i - (_isIntroOnly ? 1 : 0)],
                onRegenerate: _isIntroOnly
                    ? null
                    : () => _regenerate(_messages[i - (_isIntroOnly ? 1 : 0)]),
              );
            },
          ),
        ),
        ChatInputBar(
          controller: _ctrl,
          focusNode: _focusNode,
          isLoading: _isLoading,
          selectedImageBytes: _selectedImageBytes,
          selectedImageName: _selectedImageName,
          onPickImage: _pickImage,
          onClearImage: _clearImage,
          onCreateQuiz: _createQuiz,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}
