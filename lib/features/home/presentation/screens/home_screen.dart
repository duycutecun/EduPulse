import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../exams/domain/preset_exams.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/presentation/screens/ai_plan_screen.dart';
import '../widgets/hero_countdown_card.dart';
import '../widgets/home_header.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/smart_nudge_card.dart';
import '../widgets/today_mission_card.dart';

class HomeScreen extends StatefulWidget {
  final ExamModel? primaryExam;
  final List<ExamModel> exams;
  final VoidCallback onExamTap;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenAiCoach;
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
    required this.streak,
    this.isActive = true,
    this.onStreakChanged,
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
    _tasks = ids
        .map((id) {
          final json = StorageService.getTodayTaskJson(id);
          if (json == null) return null;
          return TodayTask.fromJsonString(json);
        })
        .whereType<TodayTask>()
        .toList();
  }

  void _addTask(String title, String subject, String priority, int minutes,
      {String? topic, DateTime? deadline, String? note, String? goalId}) {
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
    );
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    final ids = StorageService.getTodayTaskIds()..add(task.id);
    StorageService.setTodayTaskIds(ids);
    setState(() => _tasks.add(task));
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

  void _showSkipSheet(TodayTask task) {
    const reasons = [
      'Không đủ thời gian',
      'Quá khó',
      'Không cần thiết nữa',
      'Chưa có tài liệu',
      'Chưa có động lực',
      'Khác',
    ];
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                      StorageService.setTodayTaskJson(task.id, task.toJsonString());
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
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: task.deadline?.isAfter(now) == true ? task.deadline! : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn ngày làm nhiệm vụ',
    );
    if (selected == null || !mounted) return;
    task.deadline = selected;
    task.status = 'todo';
    task.skipReason = null;
    task.rescheduleCount++;
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã dời "${task.title}" sang ngày mới')),
    );
  }

  void _deleteTask(TodayTask task) {
    StorageService.removeTodayTask(task.id);
    setState(() => _tasks.remove(task));
  }

  /// MainShell đọc lại streak sau khi task thay đổi để header cập nhật 🔥.
  void _notifyStreakChanged() {
    if (StorageService.getString('last_study_date') ==
        _todayKey()) {
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
              tasks: _tasks
                  .where((task) => task.goalId == widget.primaryExam!.id)
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          QuickActionCard(
            onOpenStudy: widget.onOpenStudy,
            onOpenAiCoach: widget.onOpenAiCoach,
            onOpenAiPlan: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiPlanScreen()),
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
          ),
          const SizedBox(height: 14),
          SmartNudgeCard(
            tasks: _tasks,
            primaryExam: widget.primaryExam,
            onAskAi: widget.onOpenAiCoach,
          ),
        ],
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

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
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

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({
    required this.onAdd,
    required this.exams,
    this.primaryExamId,
  });

  final void Function(String title, String subject, String priority, int minutes,
      {String? topic, DateTime? deadline, String? note, String? goalId}) onAdd;
  final List<ExamModel> exams;
  final String? primaryExamId;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _subject = '📐 Toán';
  String _priority = 'medium';
  int _minutes = 45;
  DateTime? _deadline;
  String? _goalId;
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
              if (widget.exams.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _goalId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kỳ thi / Mục tiêu'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Chưa gắn mục tiêu'),
                    ),
                    ...widget.exams.map(
                      (exam) => DropdownMenuItem<String?>(
                        value: exam.id,
                        child: Text(exam.name,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _goalId = value),
                ),
              ],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
