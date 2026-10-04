import 'dart:convert';
import '../../../../core/utils/feedback_service.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../features/tasks/domain/repositories/task_repository.dart';
import '../constants/app_colors.dart';
import '../constants/subject_catalog.dart';
import '../pwa/pwa_service.dart';
import '../utils/storage_service.dart';
import 'ai_models.dart';
import 'ai_router.dart';

// ─── Data model ─────────────────────────────────────────────────────────────

/// Một task trong kế hoạch AI đề xuất (trước khi áp dụng).
///
/// Đây là model **duy nhất** cho lộ trình AI: cả màn "Lộ trình AI" và onboarding
/// đều dùng nó. Trước đây tồn tại thêm `AiPlanTask` trong
/// `features/study/domain/ai_plan.dart` với bộ parser riêng — hai luồng lập kế
/// hoạch song song, hai cách bóc JSON, hai cách đặt ngày. Nay đã gộp.
class AiPlannedTask {
  final String id; // action_id — idempotency key
  final String title;
  final String subject;
  final int estimateMinutes;
  final String priority;
  final DateTime scheduledAt;

  /// Ngày thứ mấy trong kế hoạch (1-based, so với ngày bắt đầu).
  /// Giữ lại để UI "T1…T7" của onboarding vẫn hoạt động.
  final int day;

  final String? reason; // lý do AI gợi ý task này

  const AiPlannedTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.estimateMinutes,
    required this.priority,
    required this.scheduledAt,
    this.day = 1,
    this.reason,
  });

  AiPlannedTask copyWith({
    String? title,
    String? subject,
    int? estimateMinutes,
    String? priority,
    DateTime? scheduledAt,
    int? day,
    String? reason,
  }) =>
      AiPlannedTask(
        id: id,
        title: title ?? this.title,
        subject: subject ?? this.subject,
        estimateMinutes: estimateMinutes ?? this.estimateMinutes,
        priority: priority ?? this.priority,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        day: day ?? this.day,
        reason: reason ?? this.reason,
      );
}

/// Kết quả generate plan từ AI.
class AiStudyPlan {
  final List<AiPlannedTask> tasks;
  final String summary; // tóm tắt ngắn từ AI
  final String? warning; // cảnh báo nếu plan có vấn đề

  const AiStudyPlan({
    required this.tasks,
    required this.summary,
    this.warning,
  });

  bool get isEmpty => tasks.isEmpty;
}

/// Trạng thái apply từng task.
enum ApplyStatus { pending, applying, done, skipped, failed }

/// Kết quả sau khi apply plan.
class ApplyResult {
  final int created;
  final int skipped; // đã có rồi
  final int failed;
  const ApplyResult({
    required this.created,
    required this.skipped,
    required this.failed,
  });
}

// ─── Service ────────────────────────────────────────────────────────────────

/// AI Study Planner — Sprint 4 AI-4.4 + AI-4.6.
///
/// Quy trình:
/// 1. Người dùng yêu cầu lập kế hoạch (qua Quick Action hoặc chat).
/// 2. Service gọi AI, parse kết quả thành [AiStudyPlan].
/// 3. UI hiển thị bước Preview — người dùng xem, chỉnh sửa từng task.
/// 4. Người dùng bấm [Áp dụng] → [applyPlan] tạo tasks thật qua TaskRepository.
/// 5. Idempotency: mỗi task có [AiPlanTask.id] — nếu đã tồn tại thì skip, không duplicate.
class AiStudyPlannerService {
  AiStudyPlannerService._();

  static const _uuid = Uuid();

  // ─── Generate ──────────────────────────────────────────────────────────────

  /// Tạo kế hoạch ôn thi từ AI.
  ///
  /// Trả về [AiStudyPlan] để UI hiển thị Preview.
  /// Ném exception nếu không online hoặc AI lỗi.
  ///
  /// [examName]/[daysLeft] dùng khi kỳ thi chưa được lưu (ví dụ onboarding):
  /// lúc đó không có gì trong storage để `_buildExamContext` đọc.
  static Future<AiStudyPlan> generatePlan({
    int daysAhead = 7,
    int dailyMinutes = 90,
    String? examName,
    int? daysLeft,
  }) async {
    if (!PwaService.isOnline) {
      throw Exception('offline');
    }

    // Thu thập ngữ cảnh
    final now = DateTime.now();
    final examCtx = examName != null
        ? 'KỲ THI:\n- $examName: còn ${daysLeft ?? 180} ngày'
        : _buildExamContext(now);
    final existingTasksCtx = _buildExistingTasksContext(now, daysAhead);
    final progressCtx = _buildProgressContext();

    final prompt = '''
Bạn là AI Coach EduPulse. Hãy lập kế hoạch ôn thi cho học sinh dựa trên thông tin sau:

$examCtx
$existingTasksCtx
$progressCtx

YÊU CẦU:
- Lập kế hoạch $daysAhead ngày tới, mỗi ngày tối đa $dailyMinutes phút học.
- Ưu tiên các môn yếu và deadline gần.
- KHÔNG tạo lại task đã có sẵn trong kế hoạch.
- Mỗi ngày có 2-4 task, thời lượng 20-60 phút mỗi task.
- Cân bằng các môn học, không nhồi nhét 1 môn.

FORMAT TRẢ LỜI:
Trả về JSON hợp lệ, không markdown code fence:
{
  "summary": "Mô tả ngắn kế hoạch 1-2 câu",
  "warning": "Cảnh báo nếu có (nullable)",
  "tasks": [
    {
      "title": "Tên nhiệm vụ cụ thể",
      "subject": "Môn học",
      "estimateMinutes": 30,
      "priority": "high|medium|low",
      "date": "YYYY-MM-DD",
      "reason": "Lý do ngắn gọn 1 câu"
    }
  ]
}

Chỉ trả về JSON, không thêm gì khác.
''';

    final raw = await AiRouter.chat(
      model: AIModel.defaultModel,
      history: const [],
      userMessage: prompt,
      searchWeb: false,
    );

    return parsePlan(raw, now);
  }

  // ─── Parse ─────────────────────────────────────────────────────────────────

  /// Phân tích JSON thô do AI trả về thành [AiStudyPlan].
  ///
  /// Công khai để test kiểm chứng trực tiếp việc bóc JSON, chuẩn hoá môn,
  /// kẹp ngày/thời lượng và bỏ qua phần tử hỏng mà không cần gọi mạng.
  static AiStudyPlan parsePlan(String raw, DateTime now) {
    // Tìm JSON block trong response
    String jsonStr = raw.trim();
    final jsonStart = jsonStr.indexOf('{');
    final jsonEnd = jsonStr.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      jsonStr = jsonStr.substring(jsonStart, jsonEnd + 1);
    }

    try {
      final data = _parseJson(jsonStr);
      if (data == null) {
        return _emptyPlan('AI không tạo được kế hoạch. Hãy thử lại.');
      }

      final summary = (data['summary'] as String?) ?? 'Kế hoạch ôn thi cá nhân';
      final warning = data['warning'] as String?;
      final rawTasks = data['tasks'] as List<dynamic>? ?? [];

      final tasks = <AiPlannedTask>[];
      for (final t in rawTasks) {
        if (t is! Map<String, dynamic>) continue;
        final title = (t['title'] as String?) ?? '';
        final subject =
            AppSubjects.normalize((t['subject'] as String?) ?? 'Tổng hợp');
        final minutes = (t['estimateMinutes'] as num?)?.toInt() ?? 30;
        final priority = (t['priority'] as String?) ?? 'medium';
        final dateStr = t['date'] as String?;
        final reason = t['reason'] as String?;

        if (title.isEmpty) continue;

        // Neo ngày vào 00:00 hôm nay để "ngày thứ N" không lệ thuộc giờ gọi.
        final base = DateTime(now.year, now.month, now.day);
        final dayRaw = (t['day'] as num?)?.toInt();
        int day;
        DateTime scheduledAt;
        if (dayRaw != null && dateStr == null) {
          // Prompt kiểu cũ trả `day` (1-based) — vẫn nhận để tương thích.
          day = dayRaw < 1 ? 1 : dayRaw;
          scheduledAt = base.add(Duration(days: day - 1));
        } else {
          scheduledAt =
              dateStr != null ? (DateTime.tryParse(dateStr) ?? base) : base;
          final maxDate = base.add(const Duration(days: 30));
          if (scheduledAt.isBefore(base)) scheduledAt = base;
          if (scheduledAt.isAfter(maxDate)) scheduledAt = maxDate;
          day = scheduledAt.difference(base).inDays + 1;
        }

        // Clamp minutes
        final clampedMinutes = minutes.clamp(10, 120);

        tasks.add(AiPlannedTask(
          id: _uuid.v4(), // unique action_id cho idempotency
          title: title,
          subject: subject,
          estimateMinutes: clampedMinutes,
          priority: priority,
          scheduledAt: scheduledAt,
          day: day,
          reason: reason,
        ));
      }

      return AiStudyPlan(
        tasks: tasks,
        summary: summary,
        warning: (warning?.trim().isEmpty ?? true) ? null : warning,
      );
    } catch (_) {
      return _emptyPlan('AI trả về định dạng không hợp lệ. Hãy thử lại.');
    }
  }

  static AiStudyPlan _emptyPlan(String message) => AiStudyPlan(
        tasks: const [],
        summary: message,
        warning: null,
      );

  // Micro JSON parser không dùng dart:convert để tránh lỗi encoding kỳ lạ
  static Map<String, dynamic>? _parseJson(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Apply ─────────────────────────────────────────────────────────────────

  /// Áp dụng kế hoạch đã được người dùng xác nhận vào TaskRepository.
  ///
  /// Idempotency: kiểm tra [AiPlannedTask.id] trước khi tạo — nếu đã có task
  /// với tên + ngày trùng thì skip (không tạo duplicate).
  ///
  /// Progress callback [onProgress] được gọi sau mỗi task để UI update spinner.
  static Future<ApplyResult> applyPlan(
    List<AiPlannedTask> tasks, {
    void Function(int done, int total)? onProgress,
  }) async {
    int created = 0;
    int skipped = 0;
    int failed = 0;
    final repo = TaskRepository.instance;

    for (int i = 0; i < tasks.length; i++) {
      final pt = tasks[i];

      final task = TodayTask(
        id: pt.id, // dùng action_id làm task ID → tự nhiên idempotent
        title: pt.title,
        subject: pt.subject,
        estimateMinutes: pt.estimateMinutes,
        priority: pt.priority,
        scheduledAt: pt.scheduledAt,
        note: pt.reason != null ? 'AI: ${pt.reason}' : null,
      );

      try {
        final result = await repo.createTaskIfMissing(task);
        if (result.isDuplicate) {
          skipped++;
        } else if (result.failed) {
          failed++;
        } else {
          created++;
        }
      } catch (_) {
        failed++;
      }

      onProgress?.call(i + 1, tasks.length);
    }

    return ApplyResult(created: created, skipped: skipped, failed: failed);
  }

  // ─── Context builders ──────────────────────────────────────────────────────

  static String _buildExamContext(DateTime now) {
    final examIds = StorageService.getExamIds();
    final primaryId = StorageService.getPrimaryExamId();

    final lines = <String>['KỲ THI:'];
    for (final id in examIds) {
      final raw = StorageService.getExamJson(id);
      if (raw == null) continue;
      try {
        final exam = ExamModel.fromJsonString(raw);
        final daysLeft = exam.dateTime.difference(now).inDays;
        final marker = (id == primaryId) ? ' [KỲ THI CHÍNH]' : '';
        final when = daysLeft > 0
            ? 'còn $daysLeft ngày'
            : daysLeft == 0
                ? 'thi hôm nay'
                : 'đã qua ${-daysLeft} ngày';
        lines.add('- ${exam.name}$marker: '
            '${exam.dateTime.day}/${exam.dateTime.month}/${exam.dateTime.year} ($when)');
        if (exam.currentScore != null || exam.targetScore != null) {
          final current = exam.currentScore?.toStringAsFixed(1) ?? 'chưa có';
          final target = exam.targetScore?.toStringAsFixed(1) ?? 'chưa có';
          lines.add('  + điểm $current → mục tiêu $target/10');
        }
      } catch (_) {
        continue;
      }
    }

    if (lines.length == 1) return '';
    return lines.join('\n');
  }

  static String _buildExistingTasksContext(DateTime now, int daysAhead) {
    final taskIds = StorageService.getTodayTaskIds();
    final endDate = now.add(Duration(days: daysAhead));
    final lines = <String>['NHIỆM VỤ ĐÃ CÓ (không tạo lại):'];

    for (final id in taskIds) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        final task = TodayTask.fromJsonString(raw);
        final scheduled = task.scheduledAt;
        if (scheduled != null && scheduled.isAfter(endDate)) continue;
        if (task.isDone) continue;
        final dateStr = scheduled != null
            ? '${scheduled.day}/${scheduled.month}'
            : 'hôm nay';
        lines.add(
            '- [${task.subject}] ${task.title} ($dateStr, ${task.estimateMinutes}ph)');
      } catch (_) {
        continue;
      }
    }

    if (lines.length == 1) return '';
    return lines.take(20).join('\n'); // Giới hạn để không quá dài
  }

  static String _buildProgressContext() {
    final mockIds = StorageService.getMockScoreIds();
    if (mockIds.isEmpty) return '';

    final scoreBySubject = <String, List<double>>{};
    for (final id in mockIds.take(20)) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        final score = MockScore.fromJsonString(raw);
        scoreBySubject.putIfAbsent(score.subject, () => []).add(score.score);
      } catch (_) {
        continue;
      }
    }

    if (scoreBySubject.isEmpty) return '';

    final lines = <String>['ĐIỂM THI THỬ GẦN ĐÂY:'];
    for (final entry in scoreBySubject.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      lines.add('- ${entry.key}: TB ${avg.toStringAsFixed(1)}/10');
    }
    return lines.join('\n');
  }
}

// ─── UI Widget — Preview Sheet ───────────────────────────────────────────────

/// Sheet Preview kế hoạch AI — FE-4.1 (Plan Preview flow).
///
/// Người dùng xem danh sách tasks, có thể bỏ tick từng task trước khi áp dụng.
class AiPlanPreviewSheet extends StatefulWidget {
  final AiStudyPlan plan;
  final VoidCallback? onApplied;

  const AiPlanPreviewSheet({
    super.key,
    required this.plan,
    this.onApplied,
  });

  static Future<bool?> show(
    BuildContext context, {
    required AiStudyPlan plan,
    VoidCallback? onApplied,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiPlanPreviewSheet(plan: plan, onApplied: onApplied),
    );
  }

  @override
  State<AiPlanPreviewSheet> createState() => _AiPlanPreviewSheetState();
}

class _AiPlanPreviewSheetState extends State<AiPlanPreviewSheet> {
  late List<bool> _selected;
  late List<AiPlannedTask> _tasks;
  bool _applying = false;
  int _applyProgress = 0;

  @override
  void initState() {
    super.initState();
    _tasks = List.of(widget.plan.tasks);
    _selected = List.filled(_tasks.length, true);
  }

  List<AiPlannedTask> get _selectedTasks => [
        for (int i = 0; i < _tasks.length; i++)
          if (_selected[i]) _tasks[i],
      ];

  Future<void> _apply() async {
    final tasks = _selectedTasks;
    if (tasks.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _applying = true;
      _applyProgress = 0;
    });

    FeedbackService.medium();

    final result = await AiStudyPlannerService.applyPlan(
      tasks,
      onProgress: (done, total) {
        if (mounted) setState(() => _applyProgress = done);
      },
    );

    if (!mounted) return;

    widget.onApplied?.call();
    Navigator.pop(context, true);

    // Hiện kết quả
    if (mounted) {
      final msg = result.created > 0
          ? 'Đã thêm ${result.created} nhiệm vụ vào kế hoạch! 🎯'
          : 'Tất cả nhiệm vụ đã có sẵn trong kế hoạch.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor:
              result.created > 0 ? AppColors.primary : AppColors.textMuted,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((v) => v).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kế hoạch AI đề xuất',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            Text('Xem và chỉnh sửa trước khi áp dụng',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.purpleLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.plan.summary,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.purple,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.plan.warning != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(widget.plan.warning!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.orange)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Task list
            Expanded(
              child: _applying
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                              color: AppColors.purple),
                          const SizedBox(height: 16),
                          Text(
                            'Đang thêm $_applyProgress/${_selectedTasks.length} nhiệm vụ...',
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _TaskPreviewCard(
                        task: _tasks[i],
                        selected: _selected[i],
                        onToggle: () =>
                            setState(() => _selected[i] = !_selected[i]),
                        onEdit: (updated) =>
                            setState(() => _tasks[i] = updated),
                      ),
                    ),
            ),

            // Footer buttons
            if (!_applying)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Huỷ',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: selectedCount > 0 ? _apply : null,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            'Áp dụng $selectedCount nhiệm vụ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Card hiển thị một task trong Preview.
class _TaskPreviewCard extends StatelessWidget {
  final AiPlannedTask task;
  final bool selected;
  final VoidCallback onToggle;
  final void Function(AiPlannedTask) onEdit;

  const _TaskPreviewCard({
    required this.task,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final date = task.scheduledAt;
    final weekdays = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final dateStr = '${weekdays[date.weekday]} ${date.day}/${date.month}';

    final priorityColor = task.priority == 'high'
        ? AppColors.red
        : task.priority == 'medium'
            ? AppColors.orange
            : AppColors.textMuted;

    return AnimatedOpacity(
      opacity: selected ? 1 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : AppColors.bgPageSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.purple.withValues(alpha: 0.4)
                  : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: selected ? AppColors.purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? AppColors.purple : AppColors.border,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          decoration:
                              selected ? null : TextDecoration.lineThrough,
                        )),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Chip(task.subject, AppColors.blue),
                        _Chip(dateStr, AppColors.textMuted),
                        _Chip('${task.estimateMinutes}ph', AppColors.primary),
                        if (task.priority != 'low')
                          _Chip(
                            task.priority == 'high' ? '🔴 Cao' : '🟡 TB',
                            priorityColor,
                          ),
                      ],
                    ),
                    if (task.reason != null && selected) ...[
                      const SizedBox(height: 4),
                      Text(task.reason!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
