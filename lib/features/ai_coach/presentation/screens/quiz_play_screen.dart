import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../study/domain/models/study_models.dart';
import '../../domain/quiz_models.dart';

/// Màn hình luyện quiz do AI sinh: chọn đáp án từng câu, xem giải thích,
/// chấm điểm khi kết thúc.
///
/// Liên kết chặt chẽ với phần còn lại của app qua AI trung gian:
/// - **Ghi ngược kết quả vào dữ liệu học tập**: mỗi bài quiz được lưu thành
///   `MockScore` (thang 10) — AI Coach sẽ "nhìn thấy" kết quả này qua
///   [AiStudyContext] ở lượt tư vấn tiếp theo, khép vòng lặp
///   AI → làm bài → dữ liệu → AI tư vấn lại theo thực tế mới.
/// - **Cộng streak/XP**: làm quiz cũng là học, nên được ghi nhận như một
///   hoạt động học tập (không làm đứt chuỗi học).
/// - **Lỗi sai thành Ghi chú**: các câu sai được lưu thành `StudyNote` gắn
///   thẻ `#lỗi-sai` và môn học, kèm nút tạo task ôn lại liên kết hai chiều
///   (task ↔ note) để AI lần sau tư vấn đúng phần yếu.
/// - **Hỏi AI cách khắc phục**: mở chat AI kèm sẵn ngữ cảnh các câu sai để
///   AI phân tích lỗi sai ngay thay vì phải chụp lại hoặc gõ lại đề.
class QuizPlayScreen extends StatefulWidget {
  final List<QuizQuestion> questions;

  /// Môn & chủ đề của bài quiz — dùng để lưu điểm đúng môn và đặt tiêu đề
  /// ghi chú lỗi sai có nghĩa.
  final String subject;
  final String topic;

  /// Báo UI liên quan (Home) đọc lại dữ liệu sau khi quiz ghi kết quả.
  final VoidCallback? onTasksChanged;

  /// Báo MainShell đọc lại streak (🔥) sau khi quiz được ghi nhận là hoạt
  /// động học tập.
  final VoidCallback? onStreakChanged;

  const QuizPlayScreen({
    super.key,
    required this.questions,
    this.subject = 'Tổng hợp',
    this.topic = 'Trắc nghiệm tổng hợp',
    this.onTasksChanged,
    this.onStreakChanged,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _index = 0;
  final List<int> _answers = []; // đáp án user đã chọn, theo thứ tự câu
  int? _selected;
  int _correctCount = 0;
  bool _finished = false;
  bool _resultSaved = false;
  final _uuid = const Uuid();

  QuizQuestion get _q => widget.questions[_index];

  void _choose(int i) {
    if (_selected != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selected = i;
      _answers.add(i);
      if (i == _q.correctIndex) _correctCount++;
    });
  }

  void _next() {
    if (_index + 1 >= widget.questions.length) {
      _saveResult();
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  /// Ghi kết quả vào dữ liệu học tập (gọi 1 lần duy nhất khi kết thúc).
  ///
  /// Quy đổi: đúng % × 10 → điểm thang 10 lưu vào `MockScore` với môn đúng
  /// [widget.subject] và ghi chú chủ đề quiz. Nhờ vậy biểu đồ điểm, phân
  /// tích AI và gợi ý "môn yếu nhất" (AiCopilotService.weakestSubject) tự
  /// cập nhật mà không cần nhập tay.
  void _saveResult() {
    if (_resultSaved) return;
    _resultSaved = true;

    final total = widget.questions.length;
    if (total == 0) return;

    // 1. Lưu điểm thang 10 để toàn hệ thống (biểu đồ, AI) nhìn thấy.
    final score = (_correctCount / total) * 10;
    final mockScore = MockScore(
      id: _uuid.v4(),
      date: DateTime.now(),
      subject: widget.subject,
      score: double.parse(score.toStringAsFixed(1)),
      note: 'Quiz AI · ${widget.topic}',
    );
    StorageService.setMockScoreJson(mockScore.id, mockScore.toJsonString());
    final mockIds = StorageService.getMockScoreIds();
    if (!mockIds.contains(mockScore.id)) {
      mockIds.add(mockScore.id);
      StorageService.setMockScoreIds(mockIds);
    }

    // 2. Làm quiz được tính là hoạt động học: giữ chuỗi, cộng EXP, gắn kết
    // linh vật — nhất quán với việc hoàn thành nhiệm vụ ở Home.
    StorageService.addXp(5 + _correctCount * 2);
    StorageService.registerStudyActivity();
    StorageService.addMascotBondExp(5);
    widget.onStreakChanged?.call();

    // 3. Nếu có câu sai → lưu thành ghi chú lỗi sai để AI & phần Ghi chú
    // cùng nhìn thấy. Không có lỗi sai thì không tạo ghi chú rỗng.
    if (_wrongQuestions.isNotEmpty) {
      _saveMistakeNote();
    }
  }

  List<QuizQuestion> get _wrongQuestions => [
        for (var i = 0; i < widget.questions.length; i++)
          if (i < _answers.length && _answers[i] != widget.questions[i].correctIndex)
            widget.questions[i],
      ];

  /// Lưu ghi chú tổng hợp lỗi sai, gắn thẻ `lỗi-sai` + tên môn để tìm kiếm
  /// và để `AiStudyContext` kể cho AI nghe trong lượt tư vấn kế tiếp.
  void _saveMistakeNote() {
    final wrong = _wrongQuestions;
    final buffer = StringBuffer();
    buffer.writeln('Bài quiz AI môn ${widget.subject} — chủ đề: ${widget.topic}');
    buffer.writeln('Kết quả: $_correctCount/${widget.questions.length} câu đúng.');
    buffer.writeln();
    for (var i = 0; i < wrong.length; i++) {
      final q = wrong[i];
      buffer.writeln('${i + 1}. ${q.question}');
      buffer.writeln(
          '   ✅ Đáp án đúng: ${String.fromCharCode(65 + q.correctIndex)}. ${q.options[q.correctIndex]}');
      if (q.explanation.isNotEmpty) {
        buffer.writeln('   💡 ${q.explanation}');
      }
      buffer.writeln();
    }

    final note = StudyNote(
      id: _uuid.v4(),
      title: 'Lỗi sai — ${widget.topic}',
      body: buffer.toString().trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      subject: widget.subject,
      tags: const ['AI Coach', 'lỗi-sai'],
    );
    StorageService.setStudyNoteJson(note.id, note.toJsonString());
    final noteIds = StorageService.getStudyNoteIds();
    if (!noteIds.contains(note.id)) {
      noteIds.add(note.id);
      StorageService.setStudyNoteIds(noteIds);
    }
  }

  /// Sheet kết quả: điểm, ghi ngược dữ liệu, và các hành động liên kết
  /// (tạo task ôn lại ↔ ghi chú lỗi sai, hỏi AI cách khắc phục).
  Widget _buildResult() {
    final total = widget.questions.length;
    final percent = total == 0 ? 0.0 : _correctCount / total;
    final color = percent >= 0.8
        ? AppColors.primary
        : (percent >= 0.5 ? AppColors.orange : AppColors.red);
    final title = percent >= 0.8
        ? 'Xuất sắc! 🎉'
        : (percent >= 0.5 ? 'Khá lắm! 💪' : 'Cần ôn thêm 📚');
    final wrong = _wrongQuestions;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$_correctCount/$total',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Đúng ${(percent * 100).round()}% — đã lưu ${score10.toStringAsFixed(1)}đ vào biểu đồ điểm thi thử.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (wrong.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Đã lưu ${wrong.length} câu sai vào Ghi chú (#lỗi-sai)',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.purple),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Hành động liên kết do AI trung gian: task ôn lại ↔ ghi chú
            // lỗi sai, hoặc hỏi AI phân tích ngay tại chỗ.
            if (wrong.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createReviewTask,
                  icon: const Icon(Icons.add_task_rounded, size: 18),
                  label: const Text('Tạo task ôn lại phần yếu',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _askAiHowToFix,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Hỏi AI cách khắc phục',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  side: BorderSide(
                      color: AppColors.purple.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('XONG',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get score10 {
    final total = widget.questions.length;
    if (total == 0) return 0;
    return double.parse(((_correctCount / total) * 10).toStringAsFixed(1));
  }

  /// Tạo task ôn lại liên kết với ghi chú lỗi sai vừa lưu (task-linked,
  /// mục 14) — AI lần sau thấy task này + ghi chú và tư vấn nhất quán.
  void _createReviewTask() {
    final wrong = _wrongQuestions;
    if (wrong.isEmpty) return;

    // Tìm ghi chú lỗi sai vừa lưu (mới nhất có tag lỗi-sai).
    String? noteId;
    String? latestBody;
    DateTime? latestAt;
    for (final id in StorageService.getStudyNoteIds()) {
      final raw = StorageService.getStudyNoteJson(id);
      if (raw == null) continue;
      try {
        final n = StudyNote.fromJsonString(raw);
        if (!n.tags.contains('lỗi-sai')) continue;
        if (latestAt == null || n.updatedAt.isAfter(latestAt)) {
          latestAt = n.updatedAt;
          noteId = n.id;
          latestBody = n.body;
        }
      } catch (_) {
        continue;
      }
    }

    final task = TodayTask(
      id: _uuid.v4(),
      title: 'Ôn lại ${wrong.length} câu sai: ${widget.topic}',
      subject: widget.subject,
      priority: 'high',
      estimateMinutes: 20,
      note: latestBody == null
          ? null
          : 'Xem ghi chú "Lỗi sai — ${widget.topic}" để ôn đúng chỗ yếu.',
      scheduledAt: DateTime.now(),
    );
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    final ids = StorageService.getTodayTaskIds();
    if (!ids.contains(task.id)) {
      ids.add(task.id);
      StorageService.setTodayTaskIds(ids);
    }
    widget.onTasksChanged?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(latestBody != null
            ? 'Đã tạo task ôn lại, kèm tóm tắt ${wrong.length} câu sai'
            : 'Đã tạo task ôn lại phần yếu'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Mở ghi chú',
          textColor: Colors.white,
          onPressed: () {
            if (noteId == null || !mounted) return;
            // Ghi chú lỗi sai nằm trong tab Ghi chú; mở bằng bottom sheet
            // xem nhanh nội dung để không rời khỏi luồng quiz.
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.cardWhite,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lỗi sai đã lưu vào Ghi chú',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(latestBody ?? '',
                            style: const TextStyle(fontSize: 13, height: 1.5)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Đã hiểu'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ));
    HapticFeedback.mediumImpact();
  }

  /// Hỏi AI cách khắc phục: gửi ngữ cảnh câu sai (kèm giải thích AI đã tạo)
  /// thẳng vào chat AI Coach để phân tích sâu — thay vì để học sinh tự chụp
  /// lại hoặc gõ lại đề.
  Future<void> _askAiHowToFix() async {
    final wrong = _wrongQuestions;
    final subject = widget.subject;

    final buffer = StringBuffer();
    buffer.writeln(
        'Tôi vừa làm quiz $subject chủ đề "${widget.topic}", sai ${wrong.length}/${widget.questions.length} câu.');
    if (wrong.isEmpty) {
      buffer.write(
          'Hãy khen và gợi ý hướng luyện tiếp theo để giữ đà tiến bộ nhé!');
    } else {
      buffer.writeln('Các câu mình bị sai:');
      for (var i = 0; i < wrong.length; i++) {
        final q = wrong[i];
        buffer.writeln('${i + 1}. ${q.question}');
        buffer.writeln(
            '   Đáp án đúng: ${String.fromCharCode(65 + q.correctIndex)}. ${q.options[q.correctIndex]}');
        if (q.explanation.isNotEmpty) buffer.writeln('   Giải thích: ${q.explanation}');
      }
      buffer.write(
          'Hãy phân tích lỗi sai thuộc dạng nào (kiến thức thiếu, hiểu sai đề, hay bẫy trắc nghiệm), và chỉ ra cách khắc phục cụ thể từng câu.');
    }
    final prompt = buffer.toString();

    if (!PwaService.isOnline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cần kết nối mạng để hỏi AI!'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Gọi AI lấy phân tích nhanh, hiển thị ngay trong sheet — không bắt
    // người dùng rời màn hình quiz.
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 20, color: AppColors.purple),
                const SizedBox(width: 8),
                Text('AI phân tích lỗi sai',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 340,
                child: FutureBuilder<String>(
                  future: AiRouter.chat(
                    model: AIModel.defaultModel,
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
                                    fontSize: 13,
                                    color: AppColors.textMuted)),
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
                      child: Text(snap.data ?? '',
                          style: const TextStyle(
                              fontSize: 13.5, height: 1.5)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('Luyện quiz 📝',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _finished ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / widget.questions.length,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_index + 1}/${widget.questions.length}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Question
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Text(
              _q.question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Options
          ...List.generate(_q.options.length, (i) {
            final isCorrect = i == _q.correctIndex;
            final isSelected = _selected == i;
            Color bg = AppColors.cardWhite;
            Color border = AppColors.border;
            Color textColor = AppColors.textPrimary;
            IconData? icon;

            if (_selected != null) {
              if (isCorrect) {
                bg = AppColors.greenSoft;
                border = AppColors.primary;
                textColor = AppColors.primaryDark;
                icon = Icons.check_circle_rounded;
              } else if (isSelected) {
                bg = AppColors.redSoft;
                border = AppColors.red;
                textColor = AppColors.redDark;
                icon = Icons.cancel_rounded;
              }
            }

            return GestureDetector(
              onTap: () => _choose(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${String.fromCharCode(65 + i)}. ${_q.options[i]}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.3),
                      ),
                    ),
                    if (icon != null) Icon(icon, color: border, size: 20),
                  ],
                ),
              ),
            );
          }),
          if (_selected != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue, width: 1.5),
              ),
              child: Text(
                _q.explanation.isEmpty
                    ? 'Đáp án: ${String.fromCharCode(65 + _q.correctIndex)}'
                    : '💡 ${_q.explanation}',
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                    height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _next,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.primaryDark,
                        blurRadius: 0,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: Text(
                    _index + 1 >= widget.questions.length
                        ? 'XEM KẾT QUẢ'
                        : 'CÂU TIẾP THEO →',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
