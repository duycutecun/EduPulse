import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../exams/domain/preset_exams.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/quick_add_parser.dart';
import '../../../study/domain/optimize_week.dart';
import '../../../study/presentation/screens/ai_plan_screen.dart';
import '../widgets/hero_countdown_card.dart';
import '../widgets/home_header.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/ai_copilot_hub_card.dart';
import '../widgets/ai_readiness_card.dart';
import '../widgets/today_mission_card.dart';
import '../../../ai_coach/presentation/screens/flashcard_review_screen.dart';

class HomeScreen extends StatefulWidget {
  final ExamModel? primaryExam;
  final List<ExamModel> exams;
  final VoidCallback onExamTap;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenAiCoach;

  /// Mở AI Coach kèm sẵn câu hỏi — dùng khi học sinh bấm vào một gợi ý AI.
  /// Có thể null thì bấm gợi ý chỉ chuyển tab AI như thường.
  final ValueChanged<String>? onOpenAiCoachWith;
  final VoidCallback onOpenCalendar;
  final int streak;
  final bool isActive;
  final VoidCallback? onStreakChanged;

  const HomeScreen({
    super.key,
    required this.primaryExam,
    required this.exams,
    required this.onExamTap,
    required this.onOpenStudy,
    required this.onOpenAiCoach,
    required this.onOpenCalendar,
    required this.streak,
    this.isActive = true,
    this.onStreakChanged,
    this.onOpenAiCoachWith,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({required this.exam, required this.tasks});

  final ExamModel exam;
  final List<TodayTask> tasks;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tiến độ mục tiêu',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tasks.isEmpty
              ? 'Chưa có nhiệm vụ gắn với ${exam.name}.'
              : '$completed/${tasks.length} nhiệm vụ đã hoàn thành'),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: AppColors.progressBg,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  final ValueNotifier<Duration> _remainingNotifier =
      ValueNotifier<Duration>(Duration.zero);
  List<TodayTask> _tasks = [];
  List<TodayTask> _allTasks = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    if (widget.isActive) {
      _startTimer();
    }
    _loadTasks();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _updateRemaining();
        _startTimer();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }
    if (oldWidget.primaryExam != widget.primaryExam) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    if (widget.primaryExam != null) {
      var rem = widget.primaryExam!.remaining;
      if (rem.isNegative) rem = Duration.zero;
      // Chỉ thông báo khi giây thay đổi — tránh rebuild 60x/s khở động màn.
      if (rem.inSeconds != _remainingNotifier.value.inSeconds) {
        _remainingNotifier.value = rem;
      }
    } else if (_remainingNotifier.value.inSeconds != 0) {
      _remainingNotifier.value = Duration.zero;
    }
  }

  void _loadTasks() {
    final ids = StorageService.getTodayTaskIds();
    _allTasks = ids
        .map((id) {
          final json = StorageService.getTodayTaskJson(id);
          if (json == null) return null;
          return TodayTask.fromJsonString(json);
        })
        .whereType<TodayTask>()
        .toList();
    final now = DateTime.now();
    _tasks = _allTasks.where((task) {
      final scheduled = task.scheduledAt;
      return scheduled == null ||
          (scheduled.year == now.year &&
              scheduled.month == now.month &&
              scheduled.day == now.day);
    }).toList();
  }

  void _addTask(String title, String subject, String priority, int minutes,
      {String? topic,
      DateTime? deadline,
      String? note,
      String? goalId,
      List<String> subtasks = const [],
      String? recurrence}) {
    final task = TodayTask(
      id: _uuid.v4(),
      title: title,
      subject: subject,
      priority: priority,
      estimateMinutes: minutes,
      topic: topic,
      deadline: deadline,
      note: note,
      goalId: goalId,
      subtasks: subtasks,
      recurrence: recurrence,
    );
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    final ids = StorageService.getTodayTaskIds()..add(task.id);
    StorageService.setTodayTaskIds(ids);
    setState(() {
      _allTasks.add(task);
      _tasks.add(task);
    });
  }

  void _toggleTask(TodayTask task) {
    final wasDone = task.isDone;
    task.isDone = !task.isDone;
    task.status = task.isDone ? 'completed' : 'todo';
    if (task.isDone) task.skipReason = null;
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    setState(() {});

    if (!wasDone && task.isDone) {
      HapticFeedback.mediumImpact();
      StorageService.addXp(10);
      StorageService.registerStudyActivity(); // cập nhật streak theo ngày
      StorageService.addMascotBondExp(10); // gắn kết linh vật
      _createNextRecurringTask(task);
      setState(() {});
      _notifyStreakChanged();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Đã hoàn thành nhiệm vụ'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Hoàn tác',
              onPressed: () {
                task.isDone = false;
                task.status = 'todo';
                StorageService.setTodayTaskJson(task.id, task.toJsonString());
                if (mounted) setState(() {});
              },
            ),
          ),
        );
    }
  }

  void _createNextRecurringTask(TodayTask completedTask) {
    final recurrence = completedTask.recurrence;
    if (recurrence != 'daily' && recurrence != 'weekly') return;
    final days = recurrence == 'daily' ? 1 : 7;
    final base = completedTask.scheduledAt ?? DateTime.now();
    final next = TodayTask(
      id: _uuid.v4(),
      title: completedTask.title,
      subject: completedTask.subject,
      topic: completedTask.topic,
      priority: completedTask.priority,
      estimateMinutes: completedTask.estimateMinutes,
      note: completedTask.note,
      goalId: completedTask.goalId,
      subtasks: completedTask.subtasks,
      recurrence: recurrence,
      scheduledAt:
          DateTime(base.year, base.month, base.day).add(Duration(days: days)),
    );
    StorageService.setTodayTaskJson(next.id, next.toJsonString());
    StorageService.setTodayTaskIds(
        [...StorageService.getTodayTaskIds(), next.id]);
    _allTasks.add(next);
  }

  void _showSkipSheet(TodayTask task) {
    const reasons = [
      'Không đủ thời gian',
      'Quá khó',
      'Không cần thiết nữa',
      'Chưa có tài liệu',
      'Chưa có động lực',
      'Khác',
    ];
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bỏ qua nhiệm vụ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Lý do giúp EduPulse điều chỉnh kế hoạch tốt hơn.'),
              const SizedBox(height: 10),
              ...reasons.map((reason) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      task.isDone = false;
                      task.status = 'skipped';
                      task.skipReason = reason;
                      StorageService.setTodayTaskJson(
                          task.id, task.toJsonString());
                      Navigator.pop(sheetContext);
                      setState(() {});
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rescheduleTask(TodayTask task) async {
    // Cảnh báo dời lịch nhiều lần + đề xuất chia nhỏ (mục 7.10) —
    // hiển thị TRƯỚC khi dời để user có thông tin quyết định.
    final splitTip = rescheduleSplitSuggestion(task);
    if (splitTip != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.content_cut_rounded, color: AppColors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text('Dời lại lần nữa?', style: TextStyle(fontSize: 17)),
            ),
          ]),
          content: Text(splitTip),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để nguyên'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Vẫn dời',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (proceed != true) return; // user chọn giữ nguyên — không đếm dời.
    }

    if (!mounted) return;
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          task.scheduledAt?.isAfter(now) == true ? task.scheduledAt! : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn ngày làm nhiệm vụ',
    );
    if (selected == null || !mounted) return;
    task.scheduledAt = selected;
    task.status = 'todo';
    task.skipReason = null;
    task.rescheduleCount++;
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    setState(_loadTasks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã dời "${task.title}" sang ngày mới')),
    );
  }

  void _deleteTask(TodayTask task) {
    StorageService.removeTodayTask(task.id);
    setState(() {
      _tasks.remove(task);
      _allTasks.remove(task);
    });
  }

  /// MainShell đọc lại streak sau khi task thay đổi để header cập nhật 🔥.
  void _notifyStreakChanged() {
    if (StorageService.getString('last_study_date') == _todayKey()) {
      widget.onStreakChanged?.call();
    }
  }

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = StorageService.getUserName();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeHeader(
            userName: userName,
            streak: widget.streak,
            mascotVisible: StorageService.getBool('mascot_enabled') ?? true,
          ),
          const SizedBox(height: 16),
          HeroCountdownCard(
            primaryExam: widget.primaryExam,
            onTap: widget.onExamTap,
            remainingListenable: _remainingNotifier,
          ),
          if (widget.primaryExam != null) ...[
            const SizedBox(height: 14),
            _GoalProgressCard(
              exam: widget.primaryExam!,
              tasks: _allTasks
                  .where((task) => task.goalId == widget.primaryExam!.id)
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          // Chỉ số sẵn sàng thi + bản tin AI hằng ngày (AI là trung tâm)
          AiReadinessCard(),
          const SizedBox(height: 14),
          // Trợ lý học tập EduPulse Copilot (Contextual & Actionable AI)
          AiCopilotHubCard(
            onOpenAiChat: widget.onOpenAiCoach,
            onOpenAiChatWith: widget.onOpenAiCoachWith,
            onTasksChanged: _loadTasks,
            onStreakChanged: _notifyStreakChanged,
          ),
          const SizedBox(height: 14),
          // Exam Mode (đặc tả mục 39–40): revision ≤7 ngày, exam day và post-exam.
          ..._examModeWidgets(),
          QuickActionCard(
            onOpenStudy: widget.onOpenStudy,
            onOpenAiCoach: widget.onOpenAiCoach,
            onOpenAiPlan: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiPlanScreen()),
              );
            },
            onOpenCalendar: widget.onOpenCalendar,
            onOpenFlashcards: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const FlashcardReviewScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          TodayMissionCard(
            tasks: _tasks,
            onAddTask: _showAddTaskDialog,
            onToggle: _toggleTask,
            onDelete: _deleteTask,
            onSkip: _showSkipSheet,
            onReschedule: _rescheduleTask,
            onAddSample: _showSampleTasksSheet,
            onQuickAdd: _showQuickAddSheet,
          ),
        ],
      ),
    );
  }

  /// Các widget Exam Mode theo giai đoạn của kỳ thi chính (đặc tả mục 39–40):
  /// - Revision (≤7 ngày): banner ôn tập trọng tâm + checklist chuẩn bị.
  /// - Exam day: thông tin thi + checklist, KHÔNG hiển thị nhiều task.
  /// - Post-exam: tổng kết nhẹ nhàng + hỏi tạo goal mới, không ngôn ngữ tiêu cực.
  List<Widget> _examModeWidgets() {
    final exam = widget.primaryExam;
    if (exam == null) return const [];
    switch (exam.examPhase) {
      case ExamPhase.revision:
        return [const _RevisionModeCard()];
      case ExamPhase.examDay:
        return [
          const _ExamDayCard(),
          const SizedBox(height: 14),
          _TodayMissionCardCompact(
            tasks: _tasks.take(3).toList(),
            onToggle: _toggleTask,
          ),
        ];
      case ExamPhase.postExam:
        final reached = exam.postExamResult;
        return [
          _PostExamCard(
            exam: exam,
            reachedTarget: reached,
            onOpenExam: widget.onExamTap,
            onScoreSaved: () => setState(() {}),
          ),
        ];
      case ExamPhase.normal:
        return const [];
    }
  }

  /// Quick Add bằng ngôn ngữ tự nhiên (đặc tả mục 25): parse offline →
  /// preview → user xác nhận. Không tự thêm task khi chưa confirm.
  void _showQuickAddSheet() {
    final controller = TextEditingController();
    showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final result = parseQuickAdd(controller.text, DateTime.now());
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thêm nhanh — viết tự nhiên',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('VD: "Mai 19h học toán hàm số 45 phút"',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Nhập nhiệm vụ của bạn…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (result != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.subject} ${result.title}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📅 ${result.scheduledAt.day}/${result.scheduledAt.month}'
                          ' • ⏰ ${result.scheduledAt.hour.toString().padLeft(2, '0')}:${result.scheduledAt.minute.toString().padLeft(2, '0')}'
                          ' • ⏱ ${result.minutes} phút'
                          ' • ${result.priority == 'high' ? '🔥 Quan trọng' : result.priority == 'low' ? '🌱 Nhẹ' : '⭐ Vừa'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _addTask(
                          result.title,
                          result.subject,
                          result.priority,
                          result.minutes,
                        );
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Thêm nhiệm vụ'),
                    ),
                  ),
                ] else if (controller.text.trim().isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Chưa nhận ra đủ dữ kiện — thêm giờ hoặc thời lượng nhé.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddTaskDialog(
        onAdd: _addTask,
        exams: widget.exams,
        primaryExamId: widget.primaryExam?.id,
      ),
    );
  }

  /// Sheet thêm nhanh nhiệm vụ mẫu theo kỳ thi mục tiêu đang ghim.
  void _showSampleTasksSheet() {
    final exam = widget.primaryExam;
    PresetExam? preset;
    if (exam != null) {
      for (final p in PresetExams.all) {
        if (exam.id == p.id ||
            exam.name.toLowerCase().contains(p.name.toLowerCase()) ||
            p.name.toLowerCase().contains(exam.name.toLowerCase())) {
          preset = p;
          break;
        }
      }
    }
    final samples = preset?.sampleTasks ?? PresetExams.all.first.sampleTasks;
    final presetName = preset?.name ?? PresetExams.all.first.name;

    showAppBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Nhiệm vụ mẫu — $presetName',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Chạm để thêm vào nhiệm vụ hôm nay',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            ...samples.map((t) {
              final added = _tasks.any(
                  (task) => task.title.toLowerCase() == t.title.toLowerCase());
              return GestureDetector(
                onTap: added
                    ? null
                    : () {
                        _addTask(t.title, t.subject, t.priority, t.minutes);
                        Navigator.pop(ctx);
                      },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        added
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 18,
                        color: added ? AppColors.primary : AppColors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.subject} ${t.title}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: added
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '⏱ ${t.minutes} phút',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        added ? 'Đã thêm' : 'Thêm',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: added ? AppColors.primary : AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

/// Banner chế độ ôn tập khi còn ≤7 ngày thi (đặc tả mục 39 — 7 ngày trước thi):
/// ưu tiên weakness, high-impact topics và review, giảm workload không cần thiết.
class _RevisionModeCard extends StatelessWidget {
  const _RevisionModeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.orangeSoft,
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('📚', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chế độ ôn tập đang bật',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ưu tiên ôn điểm yếu và nội dung quan trọng. Giảm bớt nhiệm vụ mới không cần thiết.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ ngày thi (đặc tả mục 39 — Exam Day): thông tin kỳ thi + checklist chuẩn bị,
/// không hiển thị quá nhiều task để giữ Home nhẹ nhàng.
class _ExamDayCard extends StatelessWidget {
  const _ExamDayCard();

  @override
  Widget build(BuildContext context) {
    const checklist = [
      'CMND/CCCD + giấy báo dự thi',
      'Bút, thước, máy tính được phép',
      'Bình nước + đồ ăn nhẹ',
      'Đến sớm trước giờ thi 30 phút',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🍀', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Hôm nay là ngày thi — làm tốt nhé!',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chỉ cần tập trung ôn nhẹ và chuẩn bị. EduPulse tạm ẩn danh sách nhiệm vụ dài.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ...checklist.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Phiên bản rút gọn của danh sách nhiệm vụ cho ngày thi (tối đa 3 task).
class _TodayMissionCardCompact extends StatelessWidget {
  const _TodayMissionCardCompact({
    required this.tasks,
    required this.onToggle,
  });

  final List<TodayTask> tasks;
  final ValueChanged<TodayTask> onToggle;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ôn nhẹ hôm nay (tùy chọn)',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ...tasks.map(
            (task) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onToggle(task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      task.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: task.isDone ? AppColors.primary : AppColors.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '⏱ ${task.estimateMinutes}p',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ sau kỳ thi (đặc tả mục 40): nhẹ nhàng, không tiêu cực, giữ lịch sử,
/// gợi ý tạo goal mới hoặc xem lại kỳ thi đã qua. Có **nhập điểm nhanh**
/// ngay tại card (mục 40: "Nếu có điểm: Update goal, Compare target,
/// Analyze, Suggest next step").
class _PostExamCard extends StatelessWidget {
  const _PostExamCard({
    required this.exam,
    required this.reachedTarget,
    required this.onOpenExam,
    required this.onScoreSaved,
  });

  final ExamModel exam;
  final bool? reachedTarget; // null = chưa đủ dữ liệu kết luận
  final VoidCallback onOpenExam;
  final VoidCallback onScoreSaved;

  Future<void> _quickScoreEntry(BuildContext context) async {
    final controller = TextEditingController(
      text: exam.currentScore?.toStringAsFixed(1) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nhập điểm của bạn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              exam.targetScore != null
                  ? 'Mục tiêu của bạn: ${exam.targetScore!.toStringAsFixed(1)} điểm'
                  : 'Chưa có mục tiêu điểm — nhập để lưu lịch sử.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'VD: 8.5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (parsed == null || parsed < 0 || parsed > 10) return;
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Lưu điểm'),
          ),
        ],
      ),
    );
    if (value == null) return;

    // Cập nhật điểm hiện tại của kỳ thi (lưu lịch sử, mục 40).
    final updated = exam.copyWithCurrent(value);
    StorageService.setExamJson(updated.id, updated.toJsonString());

    // Ghi thêm MockScore để biểu đồ điểm có dữ liệu (mục 41).
    final score = MockScore(
      id: const Uuid().v4(),
      date: DateTime.now(),
      subject: updated.name,
      score: value,
      note: 'Điểm ${updated.name}',
    );
    StorageService.setMockScoreJson(score.id, score.toJsonString());
    final ids = StorageService.getMockScoreIds()..add(score.id);
    StorageService.setMockScoreIds(ids);

    onScoreSaved();
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = reachedTarget != null;
    final title = reachedTarget == true
        ? 'Chúc mừng bạn đã hoàn thành ${exam.name}! 🎉'
        : reachedTarget == false
            ? '${exam.name} đã kết thúc. Cố gắng của bạn đều đáng giá.'
            : '${exam.name} đã kết thúc — đang chờ kết quả';

    final subtitle = reachedTarget == true
        ? 'Bạn đã đạt mục tiêu điểm. Muốn xem lại phân tích quá trình học không?'
        : reachedTarget == false
            ? 'Xem phân tích khoảng cách điểm để điều chỉnh kế hoạch tiếp theo nhé.'
            : 'Khi có điểm, cập nhật ở tab Mục tiêu để EduPulse phân tích giúp bạn.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
          ),
          if (hasResult) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: reachedTarget == true
                    ? AppColors.greenSoft
                    : AppColors.blueLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Điểm hiện tại ${exam.currentScore!.toStringAsFixed(1)} • Mục tiêu ${exam.targetScore!.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: reachedTarget == true
                      ? AppColors.primaryDark
                      : AppColors.blueDark,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Nhập điểm nhanh — luôn hiện khi chưa đủ target + current.
          if (!hasResult)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () => _quickScoreEntry(context),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Đã có điểm? Nhập ngay'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenExam,
                  child: const Text('Xem kỳ thi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Kỳ thi mới sẽ được tạo ở tab Mục tiêu → thêm kỳ thi.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Tạo mục tiêu mới'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({
    required this.onAdd,
    required this.exams,
    this.primaryExamId,
  });

  final void Function(
      String title, String subject, String priority, int minutes,
      {String? topic,
      DateTime? deadline,
      String? note,
      String? goalId,
      List<String> subtasks,
      String? recurrence}) onAdd;
  final List<ExamModel> exams;
  final String? primaryExamId;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _subtasksCtrl = TextEditingController();
  String _subject = '📐 Toán';
  String _priority = 'medium';
  int _minutes = 45;
  DateTime? _deadline;
  String? _goalId;
  String? _recurrence;
  final _subjects = [
    '📐 Toán',
    '⚡ Lý',
    '🧪 Hóa',
    '📖 Văn',
    '🇬🇧 Anh',
    '🧬 Sinh',
    '💡 Khác'
  ];
  final _durations = [15, 30, 45, 60, 90];
  final Map<String, String> _priorities = const {
    'high': '🔥 Quan trọng',
    'medium': '⭐ Vừa',
    'low': '🌱 Nhẹ',
  };

  @override
  void initState() {
    super.initState();
    _goalId = widget.primaryExamId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _topicCtrl.dispose();
    _noteCtrl.dispose();
    _subtasksCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      HapticFeedback.vibrate();
      return;
    }
    widget.onAdd(
      title,
      _subject,
      _priority,
      _minutes,
      topic: _topicCtrl.text.trim().isEmpty ? null : _topicCtrl.text.trim(),
      deadline: _deadline,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      goalId: _goalId,
      subtasks: _subtasksCtrl.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      recurrence: _recurrence,
    );
    Navigator.pop(context);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn hạn hoàn thành',
    );
    if (selected != null && mounted) setState(() => _deadline = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 2),
      ),
      title: const Text('Thêm nhiệm vụ',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'Tên nhiệm vụ (VD: Giải 1 đề Toán)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                hintText: 'Chủ đề (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Chọn môn:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _subjects.map((sub) {
                final sel = _subject == sub;
                return GestureDetector(
                  onTap: () => setState(() => _subject = sub),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_deadline == null
                  ? 'Thêm hạn hoàn thành'
                  : 'Hạn: ${_deadline!.day.toString().padLeft(2, '0')}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.year}'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ghi chú (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subtasksCtrl,
              decoration: const InputDecoration(
                hintText: 'Việc nhỏ (ngăn cách bằng dấu phẩy)',
              ),
            ),
            if (widget.exams.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _goalId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Kỳ thi / Mục tiêu'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Chưa gắn mục tiêu'),
                  ),
                  ...widget.exams.map(
                    (exam) => DropdownMenuItem<String?>(
                      value: exam.id,
                      child: Text(exam.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _goalId = value),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _recurrence,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lặp lại'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Không lặp lại')),
                DropdownMenuItem(value: 'daily', child: Text('Mỗi ngày')),
                DropdownMenuItem(value: 'weekly', child: Text('Mỗi tuần')),
              ],
              onChanged: (value) => setState(() => _recurrence = value),
            ),
            const SizedBox(height: 12),
            const Text('Thời gian:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _durations.map((dur) {
                final sel = _minutes == dur;
                return GestureDetector(
                  onTap: () => setState(() => _minutes = dur),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.blue : AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.blue : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$dur phút',
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Mức ưu tiên:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _priorities.entries.map((e) {
                final sel = _priority == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _priority = e.key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.orange : AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.orange : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Thêm',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
