import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/gemini_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/animated_pulse.dart';
import '../../../study/domain/models/study_models.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final List<ChatMessage> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  final _uuid = const Uuid();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String _apiKey = '';

  final List<String> _quickPrompts = [
    '📷 Giải chi tiết đề thi trong ảnh',
    '📐 Phân tích dạng bài Hàm số Toán 12',
    '⚡ Tổng hợp công thức Dao động cơ Lý',
    '🗺️ Lộ trình luyện thi TSA 90 ngày',
    '🧠 Phương pháp Active Recall & Spaced Repetition',
    '🔥 Cho tôi động lực bứt phá hôm nay',
  ];

  @override
  void initState() {
    super.initState();
    _apiKey = StorageService.getGeminiApiKey();
    _messages.add(ChatMessage(
      id: _uuid.v4(),
      text: '👋 Chào bạn! Tôi là **AI Coach EduPulse** — trợ lý giải đề & luyện thi THPTQG, TSA & HSA.\n\n✨ **Tính năng hỗ trợ:**\n- 📷 **OCR Quét ảnh bài tập:** Chụp hoặc tải ảnh đề bài (Toán, Lý, Hóa, Văn, Anh...) để nhận lời giải chi tiết từng bước!\n- 🧠 **Chỉ ra bẫy trắc nghiệm:** Phân tích lỗi sai hay gặp & mẹo bấm máy Casio.\n- 🗺️ **Lộ trình cá nhân hóa:** Tư vấn kế hoạch bứt phá điểm số theo mục tiêu trường.\n\nBạn có thể bấm các câu hỏi gợi ý bên dưới hoặc bấm nút 📷 để tải ảnh bài tập nhé!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedImageBytes = file.bytes;
            _selectedImageName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _selectedImageBytes == null) return;
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
      imageName: attachedName,
    );
    final loadingMsg = ChatMessage(
      id: _uuid.v4(),
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(loadingMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    final apiKey = StorageService.getGeminiApiKey();
    final response = await GeminiService.chat(
      apiKey: apiKey,
      history: _messages.where((m) => !m.isLoading).toList(),
      userMessage: messageText,
      imageBytes: attachedImage,
    );

    setState(() {
      _messages.remove(loadingMsg);
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showApiKeyDialog(bool isDark) {
    final keyCtrl = TextEditingController(text: _apiKey);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cấu Hình Gemini API Key'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                'Nhập khóa Gemini API (miễn phí tại aistudio.google.com) để kích hoạt AI Coach giải đề & phân tích OCR.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: keyCtrl,
                placeholder: 'AIzaSy...',
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final newKey = keyCtrl.text.trim();
              StorageService.setGeminiApiKey(newKey);
              setState(() {
                _apiKey = newKey;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // AI Coach Header with Connection Status
        _buildAiHeader(isDark),

        // Quick prompts pills
        if (_messages.length <= 1) _buildQuickPrompts(isDark),

        // Chat messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) => _buildAnimatedBubble(_messages[i], isDark, i),
          ),
        ),

        // Floating Input Bar with Image Attachment Preview
        _buildFloatingInputBar(isDark),
      ],
    );
  }

  Widget _buildAiHeader(bool isDark) {
    final hasKey = _apiKey.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF161524).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          PulsingGlow(
            glowColor: AppColors.appleIndigo,
            maxBlur: 14,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.appleIndigo, AppColors.neonCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI Coach Sĩ Tử',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showApiKeyDialog(isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (hasKey ? AppColors.appleGreen : AppColors.appleOrange).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (hasKey ? AppColors.appleGreen : AppColors.appleOrange).withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          hasKey ? '🟢 SẴN SÀNG' : '⚙️ CÀI API KEY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: hasKey ? AppColors.appleGreen : AppColors.appleOrange,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isLoading ? 'Đang phân tích & giải bài...' : 'Giải bài tập & OCR qua ảnh 24/7',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(CupertinoIcons.clear_circled, size: 20, color: Colors.grey),
              tooltip: 'Xóa hội thoại',
              onPressed: () {
                setState(() {
                  _messages.removeRange(1, _messages.length);
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(bool isDark) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: _quickPrompts.map((p) {
          return GestureDetector(
            onTap: () => _sendMessage(p),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF24223E).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.appleIndigo.withValues(alpha: 0.4) : AppColors.appleIndigo.withValues(alpha: 0.2),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.appleIndigo.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFD6D1F7) : AppColors.appleIndigo,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnimatedBubble(ChatMessage msg, bool isDark, int index) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
              ),
            ],
          ),
          child: const TypingDotsIndicator(),
        ),
      );
    }

    final isUser = msg.isUser;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 280),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuad,
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, 12 * (1 - val)),
          child: Opacity(
            opacity: val,
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.86,
          ),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    colors: [AppColors.appleIndigo, AppColors.neonCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isUser
                ? null
                : (isDark
                    ? const Color(0xFF1D1D2C).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.92)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
            border: isUser
                ? null
                : Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
            boxShadow: [
              BoxShadow(
                color: isUser
                    ? AppColors.appleIndigo.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: double.infinity,
                    ),
                    child: Image.memory(
                      msg.imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (msg.text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (msg.text.isNotEmpty)
                _renderFormattedText(msg.text, isUser, isDark),
              if (!isUser) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: msg.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép lời giải!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          CupertinoIcons.doc_on_clipboard,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderFormattedText(String text, bool isUser, bool isDark) {
    final clean = text.replaceAll('**', '');
    return Text(
      clean,
      style: TextStyle(
        fontSize: 14,
        color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
        height: 1.45,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildFloatingInputBar(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image preview chip if selected
        if (_selectedImageBytes != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2B2844).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    _selectedImageBytes!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedImageName ?? 'Ảnh bài tập',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearImage,
                  child: const Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: Colors.grey),
                ),
              ],
            ),
          ),

        // Main Input Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 88),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF222034).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Camera / Photo pick button
                    IconButton(
                      icon: const Icon(CupertinoIcons.camera_fill, size: 22, color: AppColors.neonCyan),
                      tooltip: 'Tải ảnh bài tập OCR',
                      onPressed: _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        enabled: !_isLoading,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: _selectedImageBytes != null
                              ? 'Ghi chú cho ảnh (tùy chọn)...'
                              : 'Hỏi AI bài tập hoặc gửi ảnh đề...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _isLoading ? null : () => _sendMessage(_ctrl.text),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: _isLoading
                              ? null
                              : const LinearGradient(
                                  colors: [AppColors.appleIndigo, AppColors.neonCyan],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _isLoading
                              ? (isDark ? const Color(0xFF2E2C44) : const Color(0xFFE2E4EB))
                              : null,
                          shape: BoxShape.circle,
                          boxShadow: _isLoading
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.appleIndigo.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Icon(
                          CupertinoIcons.arrow_up,
                          color: _isLoading ? Colors.grey : Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
