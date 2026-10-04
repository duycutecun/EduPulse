import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/ai/ai_chat_actions.dart';
import '../../../../core/ai/ai_context.dart';
import '../../../../core/ai/ai_copilot_service.dart';
import '../../../../core/ai/ai_sprint4_planner.dart';
import '../../../../core/ai/ai_weakness_analyzer.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../home/domain/services/today_service.dart';
import '../../../study/domain/distribute_day.dart';
import '../../../study/domain/optimize_week.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/presentation/widgets/day_balance_sheet.dart';
import '../../../tasks/domain/repositories/task_repository.dart';
import '../../domain/quiz_models.dart';
import '../widgets/ai_coach_header.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../../../../shared/widgets/state_views.dart';

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
    // Đọc model đã ghim ở Tôi → Cài đặt → AI nâng cao (UX 5.11); rỗng = Auto.
    // AI vẫn tự chuyển model khi model đang dùng bị lỗi (Model Routing, AI-23).
    _model = AIModel.fromSlug(StorageService.getAiModel());
    _autoReadImage = StorageService.getAiAutoReadImage();
    _loadChatHistory();

    if (widget.initialPrompt != null &&
        widget.initialPrompt!.trim().isNotEmpty) {
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
                      // Gate 2 (AI): không đẩy lỗi kỹ thuật vào mặt người
                      // dùng — nói rõ chuyện gì xảy ra và làm sao đi tiếp.
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Chưa phân tích được lịch sử chat lúc này. '
                            'Kiểm tra kết nối rồi thử lại nhé.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
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

  // ─── Sprint 4 — Quick Actions (FE-4.1) ────────────────────────────────

  /// Đẩy một câu trả lời AI cục bộ (không cần mạng) vào hội thoại, kèm nút
  /// hành động. Dùng cho gợi ý tức thời như "Tôi nên học gì?" (AI-4.2).
  void _pushAiMessage(String text, {List<dynamic> actions = const []}) {
    setState(() {
      _messages.add(ChatMessage(
        id: _uuid.v4(),
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        actions: actions,
      ));
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  /// AI-4.2 — "Tôi nên học gì bây giờ?": một khuyến nghị rõ ràng kèm nút bắt
  /// đầu. Phân tích cục bộ theo giờ hiện tại, deadline và độ ưu tiên nên luôn
  /// chạy được cả khi ngoại tuyến.
  void _quickRecommend() {
    final report = AiCopilotService.buildSituationReport();
    final text =
        '${report.statusTitle}\n\n${report.headline}\n\n${report.details}';
    _pushAiMessage(text, actions: report.actions);
  }

  /// AI-4.3 — Giải thích bài học theo ngữ cảnh: chọn bài chưa xong đầu tiên
  /// và gửi kèm đúng ngữ cảnh cấp 1 (bài hiện tại) thay vì cả kho dữ liệu.
  void _quickExplain() {
    final tasks = TodayService.getTodayTasksSorted()
        .where((t) => !t.isDone && t.status != 'skipped')
        .toList();
    if (tasks.isEmpty) {
      const hint = 'Giải thích giúp tôi bài học...';
      _ctrl.text = hint;
      _ctrl.selection = TextSelection.collapsed(offset: hint.length);
      _focusNode.requestFocus();
      return;
    }
    final task = tasks.first;
    final topic = task.topic;
    _sendMessage(
      'Hãy giải thích trọng tâm kiến thức của bài "${task.title}" môn '
      '${task.subject}${topic == null || topic.isEmpty ? '' : ', chủ đề $topic'}. '
      'Nêu ý chính, lỗi/bẫy thường gặp và 2-3 câu hỏi để tôi tự kiểm tra.',
      contextLevel: AiContextLevel.task,
      contextTask: task,
    );
  }

  /// AI-4.4 — Lập kế hoạch ôn tập: sinh kế hoạch rồi mở Preview để học sinh
  /// duyệt (AI-4.6: không ghi gì khi chưa xác nhận).
  Future<void> _quickPlan() async {
    if (_isLoading) return;
    if (!PwaService.isOnline) {
      _showAiToast('AI tạm thời không khả dụng khi ngoại tuyến — '
          'bạn vẫn có thể tự học bình thường.');
      return;
    }

    _showLoadingDialog('AI đang lập kế hoạch ôn tập...');
    AiStudyPlan? plan;
    Object? error;
    try {
      plan = await AiStudyPlannerService.generatePlan();
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // đóng loading

    if (plan == null || plan.isEmpty) {
      _showAiToast(error == null
          ? 'AI chưa tạo được kế hoạch phù hợp. Hãy thử lại sau một lát.'
          : 'AI tạm thời không khả dụng, bạn vẫn có thể tự học bình thường.');
      return;
    }
    await AiPlanPreviewSheet.show(context, plan: plan);
  }

  /// AI-4.5 — Phân tích điểm yếu từ dữ liệu thật (điểm thi thử, thời gian học,
  /// số lần dời lịch). Cục bộ nên không cần mạng; thiếu dữ liệu thì nói thật.
  void _quickWeakness() {
    final report = WeaknessAnalyzer.analyze();
    showModalBottomSheet<void>(
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
              const Row(
                children: [
                  Icon(Icons.insights_rounded,
                      color: AppColors.purple, size: 22),
                  SizedBox(width: 8),
                  Text('Phân tích điểm yếu',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                report.summary.replaceAll('**', ''),
                style: const TextStyle(
                    fontSize: 13.5, height: 1.5, color: AppColors.textPrimary),
              ),
              if (report.suggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Nên làm gì tiếp:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...report.suggestions.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

  /// AI-4.7 — Quick Action "Điều chỉnh lịch" (AI mục 22).
  ///
  /// Cố tình **KHÔNG gọi LLM**: việc này chỉ là sort task + cộng tổng thời
  /// gian theo quỹ ngày, đúng danh sách "Không gọi AI khi…" ở AI-24. Rule
  /// engine [proposeDayBalance] chạy tức thì, cả khi ngoại tuyến, và cho ra
  /// đề xuất có lý do rõ ràng để học sinh duyệt (AI-4.6).
  Future<void> _quickReschedule() async {
    if (_isLoading) return;
    final tasks = TaskRepository.instance.getAllTasks();
    final proposals = proposeDayBalance(tasks: tasks, now: DateTime.now());

    if (proposals.isEmpty) {
      // AI-17: nói thật khi không đủ dữ liệu, không bịa đề xuất.
      final open =
          tasks.where((t) => !t.isDone && t.status != 'skipped').length;
      _pushAiMessage(
        open == 0
            ? 'Chưa có nhiệm vụ nào đang mở nên chưa có gì để điều chỉnh. '
                'Tạo nhiệm vụ trước nhé.'
            : 'Lịch hiện tại đã vừa sức — mỗi ngày không vượt quỹ '
                '$kDefaultDailyCapacityMinutes phút nên chưa cần dời gì. '
                'Bạn vẫn có thể tự kéo các bài sang ngày khác trong thẻ nhiệm vụ.',
      );
      return;
    }

    final moved = await showDayBalanceSheet(
      context,
      tasks: tasks,
      title: 'Điều chỉnh lịch 🧺',
      subtitle:
          'Hôm nay đang nặng hơn quỹ. Chọn những bài muốn dời — không có gì '
          'bị đổi khi bạn chưa duyệt.',
    );
    if (!mounted) return;
    if (moved > 0) {
      _pushAiMessage(
        'Đã dời $moved nhiệm vụ sang ngày còn quỹ. Hôm nay nhẹ hơn rồi 🧺',
      );
    }
  }

  void _showLoadingDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(message,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
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
                      return const SkeletonList(lines: 3);
                    }
                    if (snap.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Chưa soạn được câu hỏi lúc này. Kiểm tra kết nối rồi thử lại nhé.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
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
                                    subject:
                                        _inferSubjectFromNote(name ?? 'quiz'),
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

  Future<void> _sendMessage(
    String text, {
    AiContextLevel contextLevel = AiContextLevel.full,
    TodayTask? contextTask,
  }) async {
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

    final String response;
    try {
      response = await AiRouter.chat(
        model: _model,
        history: _messages.where((m) => !m.isLoading).toList(),
        userMessage: messageText,
        imageBytes: attachedImage,
        contextLevel: contextLevel,
        contextTask: contextTask,
      );
    } catch (_) {
      // Đặc tả 12 / AI-30: không xoá câu hỏi của người dùng, nói rõ chuyện gì
      // xảy ra và đưa hai lối ra — thử lại, hoặc tự học tiếp.
      if (!mounted) return;
      setState(() {
        _messages.remove(loadingMsg);
        _messages.add(ChatMessage(
          id: _uuid.v4(),
          text: 'AI đang không phản hồi. Bạn vẫn có thể tiếp tục học '
              'hoặc thử lại sau.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
          retryPrompt: messageText,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

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

  /// Thử lại một câu hỏi bị lỗi — giữ nguyên nội dung gốc (đặc tả 12).
  void _retryFailed(ChatMessage error) {
    final prompt = error.retryPrompt;
    if (prompt == null || prompt.isEmpty) return;
    setState(() => _messages.remove(error));
    _sendMessage(prompt);
  }

  /// "Tiếp tục tự học" — bỏ thông báo lỗi, đưa người dùng về kế hoạch hôm nay.
  void _closeErrorAndGoToday(ChatMessage error) {
    setState(() => _messages.remove(error));
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

  /// Trước đây chip là chuỗi tĩnh ("Giải thích dạng bài đạo hàm lớp 12") —
  /// với học sinh thi Lý hoặc chưa chọn kỳ thi thì gợi ý sai lệch hoàn toàn.
  /// Nay dựng từ: nhiệm vụ đầu tiên hôm nay, môn ưu tiên (yếu nhất theo điểm
  /// thi thử), tên kỳ thi thật và điểm yếu thật — nên luôn liên quan tới
  /// người đang dùng.
  /// Thiếu dữ liệu thì nói thật ("Chưa có kỳ thi…") thay vì bịa tên môn.
  List<String> _dynamicPrompts() {
    final prompts = <String>[];

    final firstTask = TodayService.getTodayTasksSorted()
        .where((t) => !t.isDone && t.status != 'skipped')
        .firstOrNull;
    if (firstTask != null) {
      prompts.add('Giải thích trọng tâm bài "${firstTask.title}"');
    }

    final examId = StorageService.getPrimaryExamId();
    final examName = examId == null
        ? null
        : () {
            final json = StorageService.getExamJson(examId);
            return json == null
                ? null
                : () {
                    try {
                      return ExamModel.fromJsonString(json).name;
                    } catch (_) {
                      return null;
                    }
                  }();
          }();
    if (examName != null) {
      prompts.add('Lập kế hoạch ôn thi $examName');
    }

    final weakest = AiCopilotService.weakestSubject();
    if (weakest != null) {
      prompts.add(
          'Môn ${weakest.$1} (${weakest.$2.toStringAsFixed(1)} điểm) cần cải thiện gì?');
    }

    prompts.add('Kiểm tra lần này sai ở đâu?');
    return prompts;
  }

  /// UX 5.11 — không mở picker model ngay tại màn chat (học sinh không cần
  /// biết tên model/nhà cung cấp). Chỉ chỉ đường dẫn tới Cài đặt.
  void _showModelPicker() {
    _showAiToast('Đổi model AI ở Tôi → Cài đặt → AI nâng cao. '
        'Mặc định EduPulse tự chọn model phù hợp câu hỏi.');
  }

  bool get _isModelPinned => StorageService.getAiModel().isNotEmpty;

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
          pinned: _isModelPinned,
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
                      Text('Bạn cần gì? 🦁',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Chọn nhanh một việc, hoặc hỏi tự do bên dưới.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      _AiQuickActions(
                        onRecommend: _quickRecommend,
                        onExplain: _quickExplain,
                        onPlan: _quickPlan,
                        onWeakness: _quickWeakness,
                        onReschedule: _quickReschedule,
                      ),
                      const SizedBox(height: 18),
                      Text('Hoặc hỏi nhanh:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final prompt in _dynamicPrompts())
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
                onRetry: _isIntroOnly
                    ? null
                    : () => _retryFailed(_messages[i - (_isIntroOnly ? 1 : 0)]),
                onContinueSelfStudy: _isIntroOnly
                    ? null
                    : () => _closeErrorAndGoToday(
                        _messages[i - (_isIntroOnly ? 1 : 0)]),
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

/// Lưới 4 Quick Actions của màn AI (FE-4.1).
///
/// Thay vì để màn chat trống trơn, người dùng được định hướng vào 4 việc thực
/// tế: hỏi nên học gì, giải thích bài, lập kế hoạch, phân tích điểm yếu.
class _AiQuickActions extends StatelessWidget {
  final VoidCallback onRecommend;
  final VoidCallback onExplain;
  final VoidCallback onPlan;
  final VoidCallback onWeakness;

  /// AI-4.7 — "Điều chỉnh lịch" (rule engine, không gọi LLM).
  final VoidCallback onReschedule;

  const _AiQuickActions({
    required this.onRecommend,
    required this.onExplain,
    required this.onPlan,
    required this.onWeakness,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.lightbulb_outline_rounded,
        'Tôi nên học gì?',
        AppColors.greenDark,
        onRecommend
      ),
      (
        Icons.menu_book_rounded,
        'Giải thích bài này',
        AppColors.blueDark,
        onExplain
      ),
      (
        Icons.calendar_month_rounded,
        'Lập kế hoạch',
        AppColors.purpleDark,
        onPlan
      ),
      (
        Icons.insights_rounded,
        'Phân tích điểm yếu',
        AppColors.orangeDark,
        onWeakness
      ),
      (
        Icons.balance_rounded,
        'Điều chỉnh lịch',
        AppColors.blueDark,
        onReschedule
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (icon, label, color, onTap) in items)
              SizedBox(
                width: half,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
