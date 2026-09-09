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
  final VoidCallback onExamTap;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenAiCoach;
  final int streak;
  final bool isActive;
  final VoidCallback? onStreakChanged;

  const HomeScreen({
    super.key,
    required this.primaryExam,
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

  void _addTask(String title, String subject, String priority, int minutes) {
    final task = TodayTask(
      id: _uuid.v4(),
      title: title,
      subject: subject,
      priority: priority,
      estimateMinutes: minutes,
    );
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    final ids = StorageService.getTodayTaskIds()..add(task.id);
    StorageService.setTodayTaskIds(ids);
    setState(() => _tasks.add(task));
  }

  void _toggleTask(TodayTask task) {
    final wasDone = task.isDone;
    task.isDone = !task.isDone;
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    setState(() {});

    if (!wasDone && task.isDone) {
      HapticFeedback.mediumImpact();
      StorageService.addXp(10);
      StorageService.registerStudyActivity(); // cập nhật streak theo ngày
      StorageService.addMascotBondExp(10); // gắn kết linh vật
      setState(() {});
      _notifyStreakChanged();
    }
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeHeader(
            userName: userName,
            streak: widget.streak,
            daysLeft: _remainingNotifier.value.inDays,
            remainingTasks: _tasks.where((t) => !t.isDone).length,
            isAllTasksCompleted:
                _tasks.isNotEmpty && _tasks.every((t) => t.isDone),
          ),
          const SizedBox(height: 16),
          HeroCountdownCard(
            primaryExam: widget.primaryExam,
            onTap: widget.onExamTap,
            remainingListenable: _remainingNotifier,
          ),
          const SizedBox(height: 14),
          TodayMissionCard(
            tasks: _tasks,
            onAddTask: _showAddTaskDialog,
            onToggle: _toggleTask,
            onDelete: _deleteTask,
            onAddSample: _showSampleTasksSheet,
          ),
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
          const SmartNudgeCard(),
        ],
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddTaskDialog(onAdd: _addTask),
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
                        color: added ? AppColors.green : AppColors.blue,
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
                          color: added ? AppColors.green : AppColors.blue,
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
  const _AddTaskDialog({required this.onAdd});

  final void Function(
      String title, String subject, String priority, int minutes) onAdd;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  String _subject = '📐 Toán';
  String _priority = 'medium';
  int _minutes = 45;
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
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      HapticFeedback.vibrate();
      return;
    }
    widget.onAdd(title, _subject, _priority, _minutes);
    Navigator.pop(context);
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
                        color: sel ? AppColors.green : AppColors.bgPage,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? AppColors.green : AppColors.border,
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
                    color: AppColors.green, fontWeight: FontWeight.w800)),
          ),
        ],
    );
  }
}
