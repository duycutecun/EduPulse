import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/animated_pulse.dart';
import '../../../../shared/widgets/sound_wave_visualizer.dart';
import '../../domain/models/study_models.dart';
import '../widgets/weekly_chart_widget.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final _uuid = const Uuid();
  List<StudyLog> _logs = [];
  int _activeTab = 0; // 0: Pomodoro, 1: Biểu đồ, 2: Nhật ký

  // Pomodoro settings
  int _focusMinutes = 25;
  int _breakMinutes = 5;
  int _pomSeconds = 25 * 60;
  bool _pomRunning = false;
  bool _isBreak = false;
  int _pomRound = 0;
  Timer? _pomTimer;

  // Ambient sound mode
  bool _isSoundPlaying = false;
  int _soundModeIndex = 0;
  final List<Map<String, String>> _soundModes = [
    {'name': 'Tiếng mưa rơi nhẹ', 'icon': '🌧️'},
    {'name': 'Quán Cafe Lo-Fi', 'icon': '☕'},
    {'name': 'Đêm yên tĩnh', 'icon': '🌙'},
    {'name': 'Thư viện trường học', 'icon': '📚'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    final ids = StorageService.getStudyLogIds();
    _logs = ids.map((id) {
      final json = StorageService.getStudyLogJson(id);
      if (json == null) return null;
      return StudyLog.fromJsonString(json);
    }).whereType<StudyLog>().toList();
    _logs.sort((a, b) => b.date.compareTo(a.date));
  }

  void _addLog(String subject, double hours, String? note) {
    final log = StudyLog(
      id: _uuid.v4(),
      date: DateTime.now(),
      subject: subject,
      hours: hours,
      note: note,
    );
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
    setState(() {
      _focusMinutes = focus;
      _breakMinutes = brk;
      _pomRunning = false;
      _isBreak = false;
      _pomSeconds = focus * 60;
    });
  }

  void _togglePomodoro() {
    if (_pomRunning) {
      _pomTimer?.cancel();
      setState(() => _pomRunning = false);
    } else {
      setState(() => _pomRunning = true);
      _pomTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_pomSeconds > 0) {
          setState(() => _pomSeconds--);
        } else {
          _pomTimer?.cancel();
          setState(() {
            _pomRunning = false;
            _pomRound++;
            if (_isBreak) {
              _isBreak = false;
              _pomSeconds = _focusMinutes * 60;
            } else {
              _isBreak = true;
              _pomSeconds = _breakMinutes * 60;
              _addLog('Pomodoro Tập trung', _focusMinutes / 60.0, 'Hoàn thành phiên $_pomRound');
            }
          });
        }
      });
    }
  }

  void _resetPomodoro() {
    _pomTimer?.cancel();
    setState(() {
      _pomRunning = false;
      _isBreak = false;
      _pomSeconds = _focusMinutes * 60;
    });
  }

  void _nextSound() {
    setState(() {
      _soundModeIndex = (_soundModeIndex + 1) % _soundModes.length;
    });
  }

  @override
  void dispose() {
    _pomTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Tab switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1D1C2A).withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                _tabBtn(0, '⏰ Pomodoro', isDark),
                _tabBtn(1, '📊 Biểu đồ', isDark),
                _tabBtn(2, '📓 Nhật ký', isDark),
              ],
            ),
          ),
        ),
        Expanded(
          child: _activeTab == 0
              ? _buildPomodoroTab(isDark)
              : (_activeTab == 1
                  ? _buildChartTab(isDark)
                  : _buildLogTab(isDark)),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label, bool isDark) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0xFF322F4C) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPomodoroTab(bool isDark) {
    final minutes = _pomSeconds ~/ 60;
    final seconds = _pomSeconds % 60;
    final totalSec = _isBreak ? (_breakMinutes * 60) : (_focusMinutes * 60);
    final progress = totalSec > 0 ? (1 - (_pomSeconds / totalSec)).clamp(0.0, 1.0) : 0.0;
    final activeColor = _isBreak ? AppColors.appleGreen : AppColors.neonCyan;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        children: [
          // Mode presets
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _modeChip(25, 5, '25/5 Chuẩn', isDark),
              const SizedBox(width: 8),
              _modeChip(50, 10, '50/10 Sâu', isDark),
              const SizedBox(width: 8),
              _modeChip(90, 20, '90/20 Max', isDark),
            ],
          ),
          const SizedBox(height: 20),

          // Lo-Fi Sound Visualizer
          SoundWaveVisualizer(
            isPlaying: _isSoundPlaying,
            soundModeName: _soundModes[_soundModeIndex]['name']!,
            soundModeIcon: _soundModes[_soundModeIndex]['icon']!,
            onToggle: () => setState(() => _isSoundPlaying = !_isSoundPlaying),
            onNextSound: _nextSound,
          ),
          const SizedBox(height: 24),

          // Status Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeColor.withValues(alpha: 0.4), width: 0.8),
            ),
            child: Text(
              _isBreak
                  ? '☕ Nghỉ giải lao ($_breakMinutes phút)'
                  : '🎯 Phiên tập trung ($_focusMinutes phút)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: activeColor,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Apple Activity Ring Style Timer
          PulsingGlow(
            glowColor: activeColor,
            maxBlur: _pomRunning ? 36 : 0,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isDark
                          ? const Color(0xFF222036)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: isDark ? Colors.white : Colors.black87,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'VÒNG $_pomRound',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _resetPomodoro,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF232236)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_counterclockwise,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _togglePomodoro,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isBreak
                          ? [AppColors.appleGreen, const Color(0xFF24B846)]
                          : [AppColors.appleIndigo, AppColors.neonCyan],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _pomRunning ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _pomRunning
                ? '⚡ Đang trong phiên học — Đặt điện thoại xa tầm tay nhé!'
                : 'Bắt đầu phiên để tính thời gian và duy trì chuỗi học',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : Colors.black45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(int focus, int brk, String label, bool isDark) {
    final sel = _focusMinutes == focus;
    return GestureDetector(
      onTap: () => _setPomodoroMode(focus, brk),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.appleIndigo
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? AppColors.appleIndigo : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
            color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildChartTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: WeeklyChartWidget(logs: _logs),
    );
  }

  Widget _buildLogTab(bool isDark) {
    final totalHours = _logs.fold(0.0, (sum, l) => sum + l.hours);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      child: Column(
        children: [
          // Stat Highlights
          Row(
            children: [
              _statLiquidCard('${totalHours.toStringAsFixed(1)}h', 'Tổng thời gian học', AppColors.appleIndigo, '⚡', isDark),
              const SizedBox(width: 12),
              _statLiquidCard('${_logs.length}', 'Buổi học hoàn thành', AppColors.appleGreen, '🎯', isDark),
            ],
          ),
          const SizedBox(height: 14),

          // Add Log Button
          GestureDetector(
            onTap: () => _showAddLogDialog(isDark),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.appleIndigo, AppColors.neonCyan],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.appleIndigo.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.plus_circle_fill, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ghi Nhật Ký Học Tập',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Logs List
          if (_logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Text('📚', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(
                    'Chưa có nhật ký học tập nào.\nGhi chép mỗi ngày để tạo thói quen bền vững!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._logs.map((log) => _buildLiquidLogItem(log, isDark)),
        ],
      ),
    );
  }

  Widget _statLiquidCard(String val, String label, Color color, String icon, bool isDark) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(val,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.5,
                    )),
                Text(icon, style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white54 : Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidLogItem(StudyLog log, bool isDark) {
    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteLog(log),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.appleRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(CupertinoIcons.trash, color: AppColors.appleRed),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.appleIndigo, AppColors.neonCyan],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${log.hours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.subject,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (log.note != null && log.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        log.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${log.date.day}/${log.date.month}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddLogDialog(bool isDark) {
    final subjectCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '1.0');
    final noteCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ghi Nhật Ký Học'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(
                controller: subjectCtrl,
                placeholder: 'Môn học (VD: Toán Giải tích, Lý Sóng)',
                autofocus: true,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: hoursCtrl,
                placeholder: 'Số giờ học (VD: 1.5)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: noteCtrl,
                placeholder: 'Nội dung ôn luyện (tùy chọn)',
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
              if (subjectCtrl.text.isNotEmpty) {
                _addLog(
                  subjectCtrl.text.trim(),
                  double.tryParse(hoursCtrl.text) ?? 1.0,
                  noteCtrl.text.isEmpty ? null : noteCtrl.text,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
