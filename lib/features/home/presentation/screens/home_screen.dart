import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
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
  final String _selectedSubjectFilter = 'Tất cả';

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
    task.isDone = !task.isDone;
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    setState(() {});
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = StorageService.getUserName();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          _buildHeader(userName, isDark),
          const SizedBox(height: 16),

          // 1. HERO COUNTDOWN CARD
          _buildHeroCountdown(isDark),
          const SizedBox(height: 14),

          // 2. QUICK ACTIONS (Pomodoro & AI Coach)
          _buildQuickActionCards(isDark),
          const SizedBox(height: 14),

          // 3. TODAY'S MISSIONS CHECKLIST
          _buildTodayMissions(isDark),
          const SizedBox(height: 14),

          // 4. MOTIVATIONAL NUDGE
          _buildSmartNudge(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(String userName, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chào $userName 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Hôm nay là ngày tuyệt vời để bứt phá mục tiêu!',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.appleIndigo.withValues(alpha: isDark ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.appleIndigo.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                'Sĩ tử 2026',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFA59CDA) : AppColors.appleIndigo,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCountdown(bool isDark) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final urgencyColor = widget.primaryExam != null
        ? _urgencyColor(widget.primaryExam!.daysLeft)
        : AppColors.appleIndigo;

    final progress = widget.primaryExam != null
        ? (1.0 - (widget.primaryExam!.daysLeft / 365.0)).clamp(0.05, 0.98)
        : 0.0;

    return GestureDetector(
      onTap: widget.onExamTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF1E1742).withValues(alpha: 0.95),
                    const Color(0xFF121128).withValues(alpha: 0.90),
                    const Color(0xFF0C142A).withValues(alpha: 0.95),
                  ]
                : [
                    const Color(0xFF5E5CE6).withValues(alpha: 0.10),
                    const Color(0xFF0A84FF).withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.95),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark
                ? AppColors.appleIndigo.withValues(alpha: 0.4)
                : AppColors.appleIndigo.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.appleIndigo.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Exam Info & Urgency Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.appleIndigo.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          widget.primaryExam?.emoji ?? '🎯',
                          style: const TextStyle(fontSize: 22),
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
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.primaryExam != null
                                  ? '📅 ${_formatDate(widget.primaryExam!.dateTime)}'
                                  : 'Chạm vào đây để chọn hoặc thêm kỳ thi →',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFA69EDA) : AppColors.appleIndigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.primaryExam != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: urgencyColor.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.primaryExam!.urgencyLabel,
                            style: TextStyle(
                              color: urgencyColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Countdown Flip Tiles (Days, Hours, Mins, Secs)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimerTile(days.toString().padLeft(3, '0'), 'NGÀY', isDark),
                      _timerColon(isDark),
                      _buildTimerTile(hours.toString().padLeft(2, '0'), 'GIỜ', isDark),
                      _timerColon(isDark),
                      _buildTimerTile(minutes.toString().padLeft(2, '0'), 'PHÚT', isDark),
                      _timerColon(isDark),
                      _buildTimerTile(seconds.toString().padLeft(2, '0'), 'GIÂY', isDark),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar Towards Exam
                  if (widget.primaryExam != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Chặng đường ôn luyện',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.neonCyan : AppColors.appleIndigo,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              urgencyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerTile(String value, String label, bool isDark) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF27234A).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : Colors.black87,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? const Color(0xFFA69CDA) : AppColors.appleIndigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerColon(bool isDark) {
    return Text(
      ':',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: isDark ? const Color(0xFF7064B0) : const Color(0xFFAFA8DE),
      ),
    );
  }

  Widget _buildQuickActionCards(bool isDark) {
    return Row(
      children: [
        // 1. Pomodoro Focus
        Expanded(
          child: GestureDetector(
            onTap: widget.onOpenStudy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF26194C).withValues(alpha: 0.8),
                          const Color(0xFF1B143A).withValues(alpha: 0.8),
                        ]
                      : [
                          const Color(0xFF5E5CE6).withValues(alpha: 0.12),
                          const Color(0xFF5E5CE6).withValues(alpha: 0.05),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.appleIndigo.withValues(alpha: isDark ? 0.35 : 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.appleIndigo.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.timer, color: AppColors.appleIndigo, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tập trung',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Đồng hồ Pomodoro',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 2. AI Coach Solver
        Expanded(
          child: GestureDetector(
            onTap: widget.onOpenAiCoach,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF11294A).withValues(alpha: 0.8),
                          const Color(0xFF0C1D38).withValues(alpha: 0.8),
                        ]
                      : [
                          const Color(0xFF0A84FF).withValues(alpha: 0.12),
                          const Color(0xFF0A84FF).withValues(alpha: 0.05),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.appleBlue.withValues(alpha: isDark ? 0.35 : 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.appleBlue.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.camera_fill, color: AppColors.appleBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hỏi bài AI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Quét ảnh giải đề',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayMissions(bool isDark) {
    final filtered = _selectedSubjectFilter == 'Tất cả'
        ? _tasks
        : _tasks.where((t) => t.subject.contains(_selectedSubjectFilter)).toList();

    final done = _tasks.where((t) => t.isDone).length;
    final progress = _tasks.isEmpty ? 0.0 : done / _tasks.length;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mission Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Nhiệm vụ hôm nay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.appleGreen.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$done/${_tasks.length} xong',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.appleGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAddTaskDialog(isDark),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.appleIndigo, AppColors.appleBlue],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(CupertinoIcons.add, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.appleGreen),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 12),
            ...filtered.map((task) => _buildTaskItem(task, isDark)),
          ] else ...[
            const SizedBox(height: 14),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Chưa có nhiệm vụ hôm nay.\nNhấn nút + để thêm mục tiêu cần học!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(TodayTask task, bool isDark) {
    Color priorityColor = AppColors.appleGreen;
    String priorityText = 'Thường';
    if (task.priority == 'high') {
      priorityColor = AppColors.appleRed;
      priorityText = 'Ưu tiên 🔥';
    } else if (task.priority == 'medium') {
      priorityColor = AppColors.appleOrange;
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
          color: AppColors.appleRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(CupertinoIcons.trash, color: AppColors.appleRed, size: 18),
      ),
      child: GestureDetector(
        onTap: () => _toggleTask(task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark
                ? (task.isDone
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.07))
                : (task.isDone
                    ? Colors.black.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: task.isDone
                  ? Colors.transparent
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: task.isDone ? AppColors.appleGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: task.isDone ? AppColors.appleGreen : Colors.grey,
                    width: 1.8,
                  ),
                ),
                child: task.isDone
                    ? const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 13)
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
                        fontSize: 13.5,
                        color: task.isDone
                            ? (isDark ? Colors.white38 : Colors.black38)
                            : (isDark ? Colors.white : Colors.black87),
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '⏱ ${task.estimateMinutes} phút',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          priorityText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
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

  Widget _buildSmartNudge(bool isDark) {
    final nudges = [
      '💡 Ôn tập 25 phút ngắt quãng (Active Recall) giúp bạn nhớ lâu hơn 70% so với đọc lại liên tục.',
      '🧠 Làm đề thi thử trong khung giờ thật giúp não bộ làm quen với áp lực thi cử.',
      '⏰ Pomodoro: Tập trung sâu 25 phút, nghỉ 5 phút — thử ngay trong tab Tập trung!',
      '🎯 Chia nhỏ mục tiêu: Mỗi ngày hoàn thành 3 nhiệm vụ là bạn đã vượt lên 80% thí sinh khác.',
      '🔥 Kiên định từng ngày — sự bền bỉ tạo nên thủ khoa.',
    ];
    final today = DateTime.now().day % nudges.length;

    return GlassCard(
      padding: const EdgeInsets.all(15),
      customColor: AppColors.appleIndigo.withValues(alpha: isDark ? 0.12 : 0.06),
      borderColor: AppColors.appleIndigo.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.appleIndigo.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.lightbulb_fill, color: AppColors.appleOrange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nudges[today],
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFFD3D0EE) : const Color(0xFF3B336A),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(bool isDark) {
    final titleCtrl = TextEditingController();
    String selectedSubject = '📐 Toán';
    String selectedPriority = 'medium';
    int selectedMinutes = 45;
    final subjects = ['📐 Toán', '⚡ Lý', '🧪 Hóa', '📖 Văn', '🇬🇧 Anh', '🧬 Sinh', '💡 Khác'];
    final durations = [15, 30, 45, 60, 90];

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return CupertinoAlertDialog(
            title: const Text('Thêm Nhiệm Vụ Hôm Nay'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  CupertinoTextField(
                    controller: titleCtrl,
                    placeholder: 'Tên nhiệm vụ (VD: Giải 1 đề Toán TSA)',
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  const Text('Chọn môn học:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: subjects.map((sub) {
                      final sel = selectedSubject == sub;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedSubject = sub),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.appleIndigo : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sub,
                            style: TextStyle(
                              fontSize: 11,
                              color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Thời gian dự kiến:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: durations.map((dur) {
                      final sel = selectedMinutes == dur;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedMinutes = dur),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.appleBlue : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$dur p',
                            style: TextStyle(
                              fontSize: 11,
                              color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
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
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    _addTask(
                      titleCtrl.text.trim(),
                      selectedSubject,
                      selectedPriority,
                      selectedMinutes,
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Thêm'),
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
    if (days < 30) return AppColors.appleRed;
    if (days < 90) return AppColors.appleOrange;
    return AppColors.appleGreen;
  }
}
