import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/celebration_overlay.dart';
import '../../../../shared/widgets/confetti_burst.dart';
import '../../../../shared/widgets/spring_shake.dart';
import '../../../../shared/widgets/spring_stagger.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../study/domain/models/study_models.dart';
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
  final int streakRecord;
  final bool isActive;

  const HomeScreen({
    super.key,
    required this.primaryExam,
    required this.onExamTap,
    required this.onOpenStudy,
    required this.onOpenAiCoach,
    required this.streak,
    required this.streakRecord,
    this.isActive = true,
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
      _remainingNotifier.value = rem;
    } else {
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
      CelebrationOverlay.show(
        context,
        title: 'HOÀN THÀNH!',
        subtitle: '+10 XP',
        onContinue: () {},
      );
    }
  }

  void _deleteTask(TodayTask task) {
    StorageService.removeTodayTask(task.id);
    setState(() => _tasks.remove(task));
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
          SpringStagger(
            count: 4,
            stepDelay: const Duration(milliseconds: 120),
            itemBuilder: (context, index) {
              final cards = <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: HeroCountdownCard(
                    primaryExam: widget.primaryExam,
                    onTap: widget.onExamTap,
                    remainingListenable: _remainingNotifier,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TodayMissionCard(
                        tasks: _tasks,
                        onAddTask: _showAddTaskDialog,
                        onToggle: _toggleTask,
                        onDelete: _deleteTask,
                      ),
                      Positioned.fill(
                        top: -12,
                        left: -20,
                        right: -20,
                        bottom: -40,
                        child: ConfettiBurst(
                          active: _tasks.isNotEmpty &&
                              _tasks.every((t) => t.isDone),
                          particles: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: QuickActionCard(
                    onOpenStudy: widget.onOpenStudy,
                    onOpenAiCoach: widget.onOpenAiCoach,
                  ),
                ),
                const SmartNudgeCard(),
              ];
              return cards[index];
            },
          ),
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
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({required this.onAdd});

  final void Function(
      String title, String subject, String priority, int minutes) onAdd;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  String _subject = '📐 Toán';
  final String _priority = 'medium';
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    widget.onAdd(title, _subject, _priority, _minutes);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SpringShake(
      controller: _shakeCtrl,
      child: AlertDialog(
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
      ),
    );
  }
}
