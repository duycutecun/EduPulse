import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/celebration_overlay.dart';
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

  const HomeScreen({
    super.key,
    required this.primaryExam,
    required this.onExamTap,
    required this.onOpenStudy,
    required this.onOpenAiCoach,
    required this.streak,
    required this.streakRecord,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  List<TodayTask> _tasks = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
    _loadTasks();
  }

  void _updateRemaining() {
    if (mounted) {
      setState(() {
        if (widget.primaryExam != null) {
          _remaining = widget.primaryExam!.remaining;
          if (_remaining.isNegative) _remaining = Duration.zero;
        }
      });
    }
  }

  void _loadTasks() {
    final ids = StorageService.getTodayTaskIds();
    _tasks = ids.map((id) {
      final json = StorageService.getTodayTaskJson(id);
      if (json == null) return null;
      return TodayTask.fromJsonString(json);
    }).whereType<TodayTask>().toList();
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
          HomeHeader(userName: userName, streak: widget.streak),
          const SizedBox(height: 16),
          HeroCountdownCard(
            primaryExam: widget.primaryExam,
            onTap: widget.onExamTap,
            remaining: _remaining,
          ),
          const SizedBox(height: 14),
          TodayMissionCard(
            tasks: _tasks,
            onAddTask: _showAddTaskDialog,
            onToggle: _toggleTask,
            onDelete: _deleteTask,
          ),
          const SizedBox(height: 14),
          QuickActionCard(
            onOpenStudy: widget.onOpenStudy,
            onOpenAiCoach: widget.onOpenAiCoach,
          ),
          const SizedBox(height: 14),
          const SmartNudgeCard(),
        ],
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    String selectedSubject = '📐 Toán';
    String selectedPriority = 'medium';
    int selectedMinutes = 45;
    final subjects = ['📐 Toán', '⚡ Lý', '🧪 Hóa', '📖 Văn', '🇬🇧 Anh', '🧬 Sinh', '💡 Khác'];
    final durations = [15, 30, 45, 60, 90];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border, width: 2),
            ),
            title: const Text('Thêm nhiệm vụ', style: TextStyle(fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Tên nhiệm vụ (VD: Giải 1 đề Toán)',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  const Text('Chọn môn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: subjects.map((sub) {
                      final sel = selectedSubject == sub;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedSubject = sub),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  const Text('Thời gian:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: durations.map((dur) {
                      final sel = selectedMinutes == dur;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedMinutes = dur),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                onPressed: () => Navigator.pop(ctx),
                child: Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    _addTask(titleCtrl.text.trim(), selectedSubject, selectedPriority, selectedMinutes);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Thêm', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }
}
