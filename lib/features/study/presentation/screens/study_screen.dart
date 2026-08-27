import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
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
  int _activeTab = 0;

  int _focusMinutes = 25;
  int _breakMinutes = 5;
  int _pomSeconds = 25 * 60;
  bool _pomRunning = false;
  bool _isBreak = false;
  int _pomRound = 0;
  Timer? _pomTimer;

  @override
  void initState() {
    super.initState();
    _loadLogs();
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
              _addLog('Pomodoro', _focusMinutes / 60.0, 'Phiên $_pomRound');
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

  @override
  void dispose() {
    _pomTimer?.cancel();
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
              ],
            ),
          ),
        ),
        Expanded(
          child: _activeTab == 0
              ? _buildPomodoroTab()
              : (_activeTab == 1 ? _buildChartTab() : _buildLogTab()),
        ),
      ],
    );
  }

  Widget _tabBtn(int index, String label) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPomodoroTab() {
    final minutes = _pomSeconds ~/ 60;
    final seconds = _pomSeconds % 60;
    final totalSec = _isBreak ? (_breakMinutes * 60) : (_focusMinutes * 60);
    final progress =
        totalSec > 0 ? (1 - (_pomSeconds / totalSec)).clamp(0.0, 1.0) : 0.0;
    final activeColor = _isBreak ? AppColors.green : AppColors.blue;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _modeChip(25, 5, '25/5'),
              const SizedBox(width: 8),
              _modeChip(50, 10, '50/10'),
              const SizedBox(width: 8),
              _modeChip(90, 20, '90/20'),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
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
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'PHIÊN $_pomRound',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isBreak ? '☕ Nghỉ giải lao' : '🎯 Đang tập trung',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: activeColor),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _resetPomodoro,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: Icon(CupertinoIcons.arrow_counterclockwise,
                      color: AppColors.textPrimary, size: 20),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _togglePomodoro,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _pomRunning ? AppColors.red : AppColors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_pomRunning
                            ? AppColors.redDark
                            : AppColors.greenDark),
                        blurRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _pomRunning
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _pomRunning ? 'Đang trong phiên học!' : 'Bắt đầu để tính thời gian',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(int focus, int brk, String label) {
    final sel = _focusMinutes == focus;
    return GestureDetector(
      onTap: () => _setPomodoroMode(focus, brk),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.green : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.green : AppColors.border, width: 2),
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
      child: WeeklyChartWidget(logs: _logs),
    );
  }

  Widget _buildLogTab() {
    final totalHours = _logs.fold(0.0, (sum, l) => sum + l.hours);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              _statCard('${totalHours.toStringAsFixed(1)}h', 'Tổng giờ học',
                  AppColors.blue, Icons.access_time),
              const SizedBox(width: 12),
              _statCard('${_logs.length}', 'Buổi học', AppColors.green,
                  Icons.check_circle),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _showAddLogDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.greenDark,
                      blurRadius: 0,
                      offset: Offset(0, 4)),
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
          const SizedBox(height: 16),
          if (_logs.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Text('📚', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 10),
                  Text(
                    'Chưa có nhật ký.\nGhi chép mỗi ngày!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            )
          else
            ..._logs.map((log) => _buildLogItem(log)),
        ],
      ),
    );
  }

  Widget _statCard(String val, String label, Color color, IconData icon) {
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
                        fontWeight: FontWeight.w800,
                        color: color)),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(CupertinoIcons.trash, color: AppColors.red),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.greenDark,
                      blurRadius: 0,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Center(
                child: Text(
                  '${log.hours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.subject,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (log.note != null && log.note!.isNotEmpty)
                    Text(log.note!,
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${log.date.day}/${log.date.month}',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
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
                    color: AppColors.green, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
