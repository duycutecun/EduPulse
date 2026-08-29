import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/celebration_overlay.dart';
import '../../../../shared/widgets/duo_hover_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../study/domain/models/study_models.dart';
import 'package:uuid/uuid.dart';

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
          _buildHeader(userName),
          const SizedBox(height: 16),
          _buildHeroCountdown(),
          const SizedBox(height: 14),
          _buildTodayMissions(),
          const SizedBox(height: 14),
          _buildQuickActions(),
          const SizedBox(height: 14),
          _buildSmartNudge(),
        ],
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset('assets/images/mascot.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào $userName!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hôm nay là ngày tuyệt vời để học',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.orange, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '${widget.streak}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCountdown() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final urgencyColor = widget.primaryExam != null
        ? _urgencyColor(widget.primaryExam!.daysLeft)
        : AppColors.textMuted;
    final progress = widget.primaryExam != null
        ? (1.0 - (widget.primaryExam!.daysLeft / 365.0)).clamp(0.05, 0.98)
        : 0.0;

    return GestureDetector(
      onTap: widget.onExamTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    widget.primaryExam?.emoji ?? '🎯',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.primaryExam?.name ?? 'Chưa chọn kỳ thi mục tiêu',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.primaryExam != null
                            ? '📅 ${_formatDate(widget.primaryExam!.dateTime)}'
                            : 'Chạm vào đây để chọn kỳ thi →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.primaryExam != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: urgencyColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.primaryExam!.urgencyLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimerTile(days.toString().padLeft(3, '0'), 'NGÀY'),
                _timerColon(),
                _buildTimerTile(hours.toString().padLeft(2, '0'), 'GIỜ'),
                _timerColon(),
                _buildTimerTile(minutes.toString().padLeft(2, '0'), 'PHÚT'),
                _timerColon(),
                _buildTimerTile(seconds.toString().padLeft(2, '0'), 'GIÂY'),
              ],
            ),
            if (widget.primaryExam != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chặng đường ôn luyện',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerTile(String value, String label) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.borderDark, blurRadius: 0, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerColon() {
    return Text(
      ':',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildTodayMissions() {
    final done = _tasks.where((t) => t.isDone).length;
    final progress = _tasks.isEmpty ? 0.0 : done / _tasks.length;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('📋', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Nhiệm vụ hôm nay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$done/${_tasks.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAddTaskDialog(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            ),
            const SizedBox(height: 12),
            ..._tasks.map((task) => _buildTaskItem(task)),
          ] else ...[
            const SizedBox(height: 14),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Chưa có nhiệm vụ. Nhấn nút + để thêm!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(TodayTask task) {
    Color priorityColor = AppColors.green;
    String priorityText = 'Thường';
    if (task.priority == 'high') {
      priorityColor = AppColors.red;
      priorityText = 'Quan trọng';
    } else if (task.priority == 'medium') {
      priorityColor = AppColors.orange;
      priorityText = 'Vừa';
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteTask(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 20),
      ),
      child: GestureDetector(
        onTap: () => _toggleTask(task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: task.isDone ? AppColors.greenLight.withValues(alpha: 0.4) : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: task.isDone ? AppColors.green : AppColors.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: task.isDone ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: task.isDone ? AppColors.green : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: task.isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 15)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${task.subject} ${task.title}',
                      style: TextStyle(
                        fontSize: 14,
                        color: task.isDone ? AppColors.textMuted : AppColors.textPrimary,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '⏱ ${task.estimateMinutes} phút',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          priorityText,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.timer_rounded,
          label: 'TẬP TRUNG NGAY',
          subtitle: 'Đồng hồ Pomodoro',
          onTap: widget.onOpenStudy,
        ),
        const SizedBox(height: 10),
        _buildActionButton(
          icon: Icons.auto_awesome_rounded,
          label: 'HỎI AI BÀI TẬP',
          subtitle: 'Giải đề qua ảnh OCR',
          onTap: widget.onOpenAiCoach,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    return DuoHoverButton(
      onTap: onTap,
      normalColor: isSecondary ? AppColors.cardWhite : AppColors.green,
      hoverColor: isSecondary ? AppColors.bgPage : AppColors.greenLight,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSecondary ? AppColors.cardWhite : AppColors.green,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSecondary ? AppColors.border : AppColors.greenDark,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSecondary ? AppColors.borderDark : AppColors.greenDark,
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSecondary ? AppColors.green : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSecondary ? AppColors.green : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSecondary ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isSecondary ? AppColors.textMuted : Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartNudge() {
    final nudges = [
      'Ôn tập 25 phút ngắt quãng (Active Recall) giúp nhớ lâu hơn 70%.',
      'Làm đề thi thử trong khung giờ thật giúp não bộ quen áp lực.',
      'Pomodoro: 25 phút tập trung, 5 phút nghỉ — thử ngay!',
      'Chia nhỏ mục tiêu: 3 nhiệm vụ/ngày = vượt 80% thí sinh.',
      'Kiên định từng ngày — bền bỉ tạo nên thủ khoa.',
    ];
    final today = DateTime.now().day % nudges.length;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      customColor: AppColors.yellow.withValues(alpha: 0.1),
      borderColor: AppColors.yellow,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nudges[today],
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _urgencyColor(int days) {
    if (days < 30) return AppColors.red;
    if (days < 90) return AppColors.orange;
    return AppColors.green;
  }
}
