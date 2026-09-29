import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/notifications/adaptive_policy.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/mascot_avatar.dart';
import '../../domain/models/study_models.dart';
import '../../domain/score_summary.dart';
import '../../domain/study_analytics.dart';
import '../widgets/weekly_chart_widget.dart';

class StudyScreen extends StatefulWidget {
  final VoidCallback? onStreakChanged;

  const StudyScreen({super.key, this.onStreakChanged});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final _uuid = const Uuid();
  List<StudyLog> _logs = [];
  List<MockScore> _scores = [];
  List<StudySession> _sessions = [];
  List<TodayTask> _tasks = [];
  TodayTask? _selectedTask;
  int _activeTab = 0;

  int _focusMinutes = 25;
  int _breakMinutes = 5;
  late final ValueNotifier<int> _pomSecondsNotifier =
      ValueNotifier<int>(_focusMinutes * 60);
  bool _pomRunning = false;
  bool _isBreak = false;
  int _pomRound = 0;
  Timer? _pomTimer;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadScores();
    _loadTasks();
    _loadSessions();
  }

  void _loadSessions() {
    _sessions = StorageService.getStudySessionIds()
        .map((id) {
          final json = StorageService.getStudySessionJson(id);
          return json == null ? null : StudySession.fromJsonString(json);
        })
        .whereType<StudySession>()
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  void _loadTasks() {
    _tasks = StorageService.getTodayTaskIds()
        .map((id) {
          final json = StorageService.getTodayTaskJson(id);
          return json == null ? null : TodayTask.fromJsonString(json);
        })
        .whereType<TodayTask>()
        .where((task) => !task.isDone && task.status != 'skipped')
        .toList();
  }

  void _loadScores() {
    final ids = StorageService.getMockScoreIds();
    _scores = ids
        .map((id) {
          final json = StorageService.getMockScoreJson(id);
          if (json == null) return null;
          return MockScore.fromJsonString(json);
        })
        .whereType<MockScore>()
        .toList();
    _scores.sort((a, b) => b.date.compareTo(a.date));
  }

  void _addScore(String subject, double score, String? note) {
    final s = MockScore(
      id: _uuid.v4(),
      date: DateTime.now(),
      subject: subject,
      score: score,
      note: note,
    );
    StorageService.setMockScoreJson(s.id, s.toJsonString());
    final ids = StorageService.getMockScoreIds()..add(s.id);
    StorageService.setMockScoreIds(ids);
    setState(() => _scores.insert(0, s));
  }

  void _deleteScore(MockScore s) {
    StorageService.removeMockScore(s.id);
    setState(() => _scores.remove(s));
  }

  void _loadLogs() {
    final ids = StorageService.getStudyLogIds();
    _logs = ids
        .map((id) {
          final json = StorageService.getStudyLogJson(id);
          if (json == null) return null;
          return StudyLog.fromJsonString(json);
        })
        .whereType<StudyLog>()
        .toList();
    _logs.sort((a, b) => b.date.compareTo(a.date));
  }

  void _addLog(String subject, double hours, String? note) {
    final log = StudyLog(
        id: _uuid.v4(),
        date: DateTime.now(),
        subject: subject,
        hours: hours,
        note: note);
    StorageService.setStudyLogJson(log.id, log.toJsonString());
    final ids = StorageService.getStudyLogIds()..add(log.id);
    StorageService.setStudyLogIds(ids);
    setState(() => _logs.insert(0, log));
  }

  void _deleteLog(StudyLog log) {
    StorageService.removeStudyLog(log.id);
    setState(() => _logs.remove(log));
  }

  void _setPomodoroMode(int focus, int brk) {
    _pomTimer?.cancel();
    _focusMinutes = focus;
    _breakMinutes = brk;
    _pomRunning = false;
    _isBreak = false;
    _pomSecondsNotifier.value = focus * 60;
    setState(() {});
  }

  void _togglePomodoro() {
    HapticFeedback.lightImpact();
    if (_pomRunning) {
      _pomTimer?.cancel();
      setState(() => _pomRunning = false);
      // Thoát Focus → cho phép notification thường trở lại.
      AdaptivePolicy.setInFocus(false);
    } else {
      setState(() => _pomRunning = true);
      // Vào Focus → tạm dừng notification không quan trọng (đặc tả mục 16).
      AdaptivePolicy.setInFocus(true);
      _pomTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_pomSecondsNotifier.value > 0) {
          _pomSecondsNotifier.value--;
        } else {
          _pomTimer?.cancel();
          setState(() {
            _pomRunning = false;
            if (_isBreak) {
              _isBreak = false;
              _pomSecondsNotifier.value = _focusMinutes * 60;
            } else {
              _pomRound++;
              _isBreak = true;
              _pomSecondsNotifier.value = _breakMinutes * 60;
              _recordCompletedFocus();
              // Kết thúc phiên tập trung → streak + EXP gắn kết linh vật.
              StorageService.registerStudyActivity();
              StorageService.addMascotBondExp(25);
              widget.onStreakChanged?.call();
            }
          });
        }
      });
    }
  }

  void _recordCompletedFocus() {
    final task = _selectedTask;
    final subject = task?.subject ?? 'Pomodoro';
    final note = task == null ? 'Phiên $_pomRound' : 'Focus: ${task.title}';
    _addLog(subject, _focusMinutes / 60.0, note);

    final session = StudySession(
      id: _uuid.v4(),
      completedAt: DateTime.now(),
      taskId: task?.id,
      subject: subject,
      plannedMinutes: _focusMinutes,
      actualMinutes: _focusMinutes,
    );
    StorageService.setStudySessionJson(session.id, session.toJsonString());
    final ids = StorageService.getStudySessionIds()..add(session.id);
    StorageService.setStudySessionIds(ids);
    setState(() => _sessions.insert(0, session));
    // Reflection is intentionally occasional: it gives useful signal without
    // making the end of every Pomodoro feel like a form.
    if (_pomRound % 3 == 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (mounted) _showReflectionSheet(session);
        },
      );
    }
  }

  void _showReflectionSheet(StudySession session) {
    var mood = 3;
    var focus = 3;
    var difficulty = 3;
    var understanding = 3;
    var effectiveness = 3;
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phiên học vừa rồi thế nào?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Chỉ mất vài giây — bạn có thể bỏ qua.'),
                  const SizedBox(height: 16),
                  _reflectionScale('Tâm trạng', mood,
                      (value) => setSheetState(() => mood = value)),
                  _reflectionScale('Tập trung', focus,
                      (value) => setSheetState(() => focus = value)),
                  _reflectionScale('Độ khó', difficulty,
                      (value) => setSheetState(() => difficulty = value)),
                  _reflectionScale('Mức độ hiểu', understanding,
                      (value) => setSheetState(() => understanding = value)),
                  _reflectionScale('Hiệu quả', effectiveness,
                      (value) => setSheetState(() => effectiveness = value)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Ghi chú thêm (không bắt buộc)'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Bỏ qua'),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            session
                              ..mood = mood
                              ..focus = focus
                              ..difficulty = difficulty
                              ..understanding = understanding
                              ..effectiveness = effectiveness
                              ..reflectionNote = noteController.text.trim().isEmpty
                                  ? null
                                  : noteController.text.trim();
                            StorageService.setStudySessionJson(
                                session.id, session.toJsonString());
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Lưu phản hồi'),
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
    ).whenComplete(noteController.dispose);
  }

  Widget _reflectionScale(
      String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 112,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          ...List.generate(
            5,
            (index) {
              final score = index + 1;
              final selected = score <= value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(score),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      selected ? Icons.circle_rounded : Icons.circle_outlined,
                      color: selected ? AppColors.primary : AppColors.borderStrong,
                      size: 22,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTaskPicker() {
    _loadTasks();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chọn nhiệm vụ để tập trung',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Focus tự do'),
                trailing: _selectedTask == null
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedTask = null);
                  Navigator.pop(sheetContext);
                },
              ),
              if (_tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Chưa có nhiệm vụ chưa hoàn thành.'),
                )
              else
                ..._tasks.map((task) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.checklist_rounded,
                          color: AppColors.blue),
                      title: Text(task.title),
                      subtitle: Text('${task.subject} · ${task.estimateMinutes} phút'),
                      trailing: _selectedTask?.id == task.id
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() => _selectedTask = task);
                        Navigator.pop(sheetContext);
                      },
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _resetPomodoro() {
    _pomTimer?.cancel();
    _pomRunning = false;
    _isBreak = false;
    _pomSecondsNotifier.value = _focusMinutes * 60;
    setState(() {});
  }

  @override
  void dispose() {
    _pomTimer?.cancel();
    _pomSecondsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Row(
              children: [
                _tabBtn(0, 'Pomodoro'),
                _tabBtn(1, 'Biểu đồ'),
                _tabBtn(2, 'Nhật ký'),
                _tabBtn(3, 'Điểm thi'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _activeTab == 0
              ? _buildPomodoroTab()
              : (_activeTab == 1
                  ? _buildChartTab()
                  : (_activeTab == 2 ? _buildLogTab() : _buildScoreTab())),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.cardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPomodoroTab() {
    final totalSec = _isBreak ? (_breakMinutes * 60) : (_focusMinutes * 60);
    final activeColor = _isBreak ? AppColors.primary : AppColors.blue;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          InkWell(
            onTap: _pomRunning ? null : _showTaskPicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checklist_rounded, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nhiệm vụ hiện tại',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(_selectedTask?.title ?? 'Focus tự do',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Icon(_pomRunning ? Icons.lock_outline : Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Nút chọn chế độ Pomodoro.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _modeChip(25, 5, '25/5'),
              const SizedBox(width: 10),
              _modeChip(50, 10, '50/10'),
              const SizedBox(width: 10),
              _modeChip(90, 20, '90/20'),
            ],
          ),
          const SizedBox(height: 32),
          // Đồng hồ countdown — vòng tròn xanh lá.
          SizedBox(
            width: 200,
            height: 200,
            child: ValueListenableBuilder<int>(
              valueListenable: _pomSecondsNotifier,
              builder: (context, secondsRemaining, _) {
                final minutes = secondsRemaining ~/ 60;
                final seconds = secondsRemaining % 60;
                final progress = totalSec > 0
                    ? (1 - (secondsRemaining / totalSec)).clamp(0.0, 1.0)
                    : 0.0;
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Nền vòng tròn.
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.progressBg,
                          valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                        ),
                      ),
                      // Số giờ đồng hồ.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Phiên $_pomRound',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Mascot + trạng thái.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MascotAvatar(
                size: 38,
                mood: _pomRunning
                    ? (_isBreak ? MascotMood.relax : MascotMood.focus)
                    : MascotMood.idle,
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activeColor, width: 1.2),
                ),
                child: Text(
                  _isBreak
                      ? '☕ Nghỉ giải lao'
                      : (_pomRunning ? '🎯 Đang tập trung' : '⏳ Sẵn sàng học'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: activeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Nút play/pause + reset — tá áo lớn, bo tròn, xanh lá.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TactileCircleButton(
                size: 56,
                color: AppColors.cardWhite,
                shadowColor: AppColors.borderStrong.withValues(alpha: 0.5),
                border: Border.all(color: AppColors.border, width: 2),
                onTap: _resetPomodoro,
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 28),
              _TactileCircleButton(
                size: 76,
                color: _pomRunning ? AppColors.red : AppColors.primary,
                shadowColor:
                    _pomRunning ? AppColors.redDark : AppColors.primaryDark,
                onTap: _togglePomodoro,
                child: Icon(
                  _pomRunning
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  key: ValueKey(_pomRunning),
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _pomRunning ? 'Đang trong phiên học!' : 'Bắt đầu để tính thời gian',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(int focus, int brk, String label) {
    final sel = _focusMinutes == focus;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _setPomodoroMode(focus, brk);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.border, width: 1.5),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
            color: sel ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildChartTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _buildFocusAnalytics(),
          const SizedBox(height: 16),
          _buildAdvancedAnalytics(),
          const SizedBox(height: 16),
          WeeklyChartWidget(logs: _logs),
        ],
      ),
    );
  }

  /// Analytics nâng cao (đặc tả mục 12.2–12.5): so sánh tuần, efficiency
  /// composite, focus pattern và khung giờ học tốt. Mỗi mục chỉ hiện khi
  /// đủ dữ liệu — không kết luận khi thiếu mẫu.
  Widget _buildAdvancedAnalytics() {
    final now = DateTime.now();
    final comparison = compareWeeks(_sessions, now);
    final efficiencyReport = efficiency(_sessions, now);
    final focusTip = focusPatternTip(_sessions);
    final timeTip = bestStudyTime(_sessions);

    final hasAnything = comparison.thisWeekMinutes > 0 ||
        comparison.lastWeekMinutes > 0 ||
        efficiencyReport != null ||
        focusTip != null ||
        timeTip != null;
    if (!hasAnything) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân tích nâng cao',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (comparison.message != null) _analyticsRow(
            icon: Icons.compare_arrows_rounded,
            color: AppColors.blue,
            text: comparison.message!,
          ),
          if (efficiencyReport != null) ...[
            _analyticsRow(
              icon: Icons.speed_rounded,
              color: AppColors.primary,
              text:
                  'Efficiency ${efficiencyReport.score}%${efficiencyReport.deltaVsLastWeek == null ? '' : ' (${efficiencyReport.deltaVsLastWeek! >= 0 ? '+' : ''}${efficiencyReport.deltaVsLastWeek}% vs tuần trước)'} — dựa trên ${efficiencyReport.sampleCount} phiên có phản hồi.',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 30),
              child: Text(efficiencyReport.description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ],
          if (focusTip != null)
            _analyticsRow(
              icon: Icons.timer_outlined,
              color: AppColors.orange,
              text: focusTip,
            ),
          if (timeTip != null)
            _analyticsRow(
              icon: Icons.schedule_rounded,
              color: AppColors.purple,
              text: timeTip,
            ),
        ],
      ),
    );
  }

  Widget _analyticsRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAnalytics() {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final thisWeek = _sessions
        .where((session) => !session.completedAt.isBefore(startOfWeek))
        .toList();
    final totalMinutes = thisWeek.fold<int>(
        0, (sum, session) => sum + session.actualMinutes);
    final ratedFocus = thisWeek.where((session) => session.focus != null).toList();
    final ratedEffectiveness =
        thisWeek.where((session) => session.effectiveness != null).toList();
    final avgFocus = ratedFocus.isEmpty
        ? null
        : ratedFocus.fold<int>(0, (sum, session) => sum + session.focus!) /
            ratedFocus.length;
    final avgEffectiveness = ratedEffectiveness.isEmpty
        ? null
        : ratedEffectiveness.fold<int>(0,
                (sum, session) => sum + session.effectiveness!) /
            ratedEffectiveness.length;

    String? insight;
    if (ratedFocus.length >= 3 && avgFocus! < 3) {
      insight = 'Focus trung bình đang thấp. Hãy thử phiên ngắn hơn hoặc nghỉ sớm hơn.';
    } else if (ratedEffectiveness.length >= 3 && avgEffectiveness! >= 4) {
      insight = 'Bạn đang học hiệu quả trong tuần này. Duy trì nhịp hiện tại nhé!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Focus tuần này',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _analyticsMetric('$totalMinutes phút', 'Thời gian focus'),
              const SizedBox(width: 8),
              _analyticsMetric('${thisWeek.length}', 'Phiên hoàn thành'),
              const SizedBox(width: 8),
              _analyticsMetric(avgFocus == null ? '—' : '${avgFocus.toStringAsFixed(1)}/5',
                  'Focus TB'),
            ],
          ),
          if (insight != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.purpleLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppColors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(insight,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ] else if (_sessions.isEmpty) ...[
            const SizedBox(height: 12),
            const Text('Hoàn thành một phiên Focus để bắt đầu xem dữ liệu.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _analyticsMetric(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.bgPageSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTab() {
    final totalHours = _logs.fold(0.0, (sum, l) => sum + l.hours);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          // Thống kê tổng.
          Row(
            children: [
              Expanded(
                child: _statCard('${totalHours.toStringAsFixed(1)}h', 'Tổng giờ học',
                    AppColors.blue, Icons.access_time),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard('${_logs.length}', 'Buổi học', AppColors.primary,
                    Icons.check_circle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Nút thêm nhật ký — xanh lá, bo tròn, nổi.
          GestureDetector(
            onTap: () => _showAddLogDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('GHI NHẬT KÝ',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Text('📚', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(
                    'Chưa có nhật ký.\nGhi chép mỗi ngày!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final log in _logs) _buildLogItem(log),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statCard(String val, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(val,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(StudyLog log) {
    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteLog(log),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 18),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ô giờ bên trái — xanh lá.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.subject,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (log.note != null && log.note!.isNotEmpty)
                    Text(log.note!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${log.date.day}/${log.date.month}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreTab() {
    final summaries = summarizeMockScores(_scores);
    final avg = overallAverage(_scores);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          // Thống kê.
          Row(
            children: [
              Expanded(
                child: _statCard('${_scores.length}', 'Lần thi thử', AppColors.blue,
                    Icons.assignment_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(avg > 0 ? avg.toStringAsFixed(1) : '—', 'Điểm TB',
                    AppColors.primary, Icons.stars_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Hai nút action.
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showAddScoreDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('GHI ĐIỂM THI THỬ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _scores.isEmpty ? null : _analyzeScoresWithAi,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _scores.isEmpty
                          ? AppColors.cardLight
                          : AppColors.purple,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _scores.isEmpty
                            ? AppColors.border
                            : AppColors.purple,
                        width: 1.5,
                      ),
                      boxShadow: _scores.isEmpty
                          ? null
                          : [
                              BoxShadow(
                                  color: AppColors.purple.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('AI PHÂN TÍCH',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_scores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(
                    'Chưa có điểm thi thử.\nGhi lại điểm để theo dõi tiến bộ!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            )
          else ...[
            if (summaries.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 1),
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
                    Text('Tổng hợp theo môn',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    ...summaries.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.subject,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                  Text(
                                    '${s.average.toStringAsFixed(1)} • ${s.rating}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: s.average >= 8
                                          ? AppColors.primary
                                          : (s.average >= 6.5
                                              ? AppColors.orange
                                              : AppColors.red),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (s.average / 10).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: AppColors.progressBg,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    s.average >= 8
                                        ? AppColors.progressDone
                                        : (s.average >= 6.5
                                            ? AppColors.orange
                                            : AppColors.red),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            ..._scores.map((s) => _buildScoreItem(s)),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreItem(MockScore s) {
    final color = s.score >= 8
        ? AppColors.primary
        : (s.score >= 6.5 ? AppColors.orange : AppColors.red);
    return Dismissible(
      key: Key(s.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteScore(s),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 18),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Score circle — nền xanh lá/cam/red tùy điểm.
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  s.score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.subject,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (s.note != null && s.note!.isNotEmpty)
                    Text(s.note!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${s.date.day}/${s.date.month}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  void _showAddScoreDialog() {
    final subjectCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final subjects = ['📐 Toán', '📖 Văn', '🇬🇧 Anh', '⚡ Lý', '🧪 Hóa', '🧬 Sinh'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text('Ghi điểm thi thử',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            String subject = subjectCtrl.text.isEmpty
                ? '📐 Toán'
                : subjectCtrl.text;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: subjects.map((sub) {
                    final sel = subject == sub;
                    return GestureDetector(
                      onTap: () => setDialogState(() {
                        subjectCtrl.text = sub;
                        subject = sub;
                      }),
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
                const SizedBox(height: 10),
                TextField(
                    controller: subjectCtrl,
                    decoration:
                        const InputDecoration(hintText: 'Hoặc nhập môn khác')),
                const SizedBox(height: 8),
                TextField(
                    controller: scoreCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Điểm (0–10, VD: 7.5)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: noteCtrl,
                    decoration:
                        const InputDecoration(hintText: 'Ghi chú (tùy chọn)')),
              ],
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              final score = double.tryParse(
                  scoreCtrl.text.trim().replaceAll(',', '.'));
              final subject = subjectCtrl.text.trim();
              if (subject.isNotEmpty && score != null && score >= 0 && score <= 10) {
                _addScore(subject, score,
                    noteCtrl.text.isEmpty ? null : noteCtrl.text.trim());
              } else if (score == null || score < 0 || score > 10) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập điểm từ 0 đến 10'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeScoresWithAi() async {
    if (!PwaService.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI cần kết nối mạng — hãy thử lại khi online!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final prompt = buildScorePrompt(_scores);
    if (prompt.isEmpty) return;

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
              Text(
                '🧠 Phân tích điểm yếu',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 320,
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
                                color: AppColors.primary),
                            const SizedBox(height: 12),
                            Text('AI đang phân tích...',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Lỗi: ${snap.error}',
                          style: const TextStyle(color: AppColors.red),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Text(
                        snap.data ?? '',
                        style: TextStyle(
                          fontSize: 14,
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

  void _showAddLogDialog() {
    final subjectCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '1.0');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text('Ghi nhật ký học',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(hintText: 'Môn học'),
                autofocus: true),
            const SizedBox(height: 8),
            TextField(
                controller: hoursCtrl,
                decoration: const InputDecoration(hintText: 'Số giờ'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(hintText: 'Ghi chú (tùy chọn)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              if (subjectCtrl.text.isNotEmpty) {
                _addLog(
                    subjectCtrl.text.trim(),
                    double.tryParse(hoursCtrl.text) ?? 1.0,
                    noteCtrl.text.isEmpty ? null : noteCtrl.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Nút bấm hình tròn với độ lún vật lý xúc giác 3D (Duolingo tactile press)
class _TactileCircleButton extends StatelessWidget {
  final double size;
  final Color color;
  final Color shadowColor;
  final Border? border;
  final Widget child;
  final VoidCallback onTap;

  const _TactileCircleButton({
    required this.size,
    required this.color,
    required this.shadowColor,
    this.border,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
