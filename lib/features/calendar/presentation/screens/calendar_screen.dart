import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/optimize_week.dart';
import '../../../notes/presentation/screens/notes_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';

/// Agenda-first calendar for mobile. It intentionally shows only actionable
/// work: scheduled tasks, deadlines and recorded focus sessions.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDay;
  List<TodayTask> _tasks = const [];
  List<StudySession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    _load();
  }

  void _load() {
    _tasks = StorageService.getTodayTaskIds()
        .map(StorageService.getTodayTaskJson)
        .whereType<String>()
        .map(_taskOrNull)
        .whereType<TodayTask>()
        .toList();
    _sessions = StorageService.getStudySessionIds()
        .map(StorageService.getStudySessionJson)
        .whereType<String>()
        .map(_sessionOrNull)
        .whereType<StudySession>()
        .toList();
  }

  TodayTask? _taskOrNull(String value) {
    try {
      return TodayTask.fromJsonString(value);
    } catch (_) {
      return null;
    }
  }

  StudySession? _sessionOrNull(String value) {
    try {
      return StudySession.fromJsonString(value);
    } catch (_) {
      return null;
    }
  }

  /// Kỳ thi chính + revision milestone (mục 13: calendar hiển thị
  /// Primary exam + Important milestones).
  ExamModel? get _primaryExam {
    final id = StorageService.getPrimaryExamId();
    if (id == null) return null;
    final json = StorageService.getExamJson(id);
    if (json == null) return null;
    try {
      return ExamModel.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<TodayTask> get _scheduledTasks => _tasks
      .where((task) =>
          _isSameDay(task.scheduledAt ?? task.deadline ?? DateTime(0), _selectedDay))
      .toList();

  List<StudySession> get _daySessions => _sessions
      .where((session) => _isSameDay(session.completedAt, _selectedDay))
      .toList();

  /// "Tối ưu tuần" (đặc tả mục 13): AI đề xuất lịch cho task chưa xếp
  /// lịch — **Diff + lý do từng dòng + Accept/Edit/Reject** (mục 10.6).
  /// Không có gì được áp dụng cho đến khi người dùng duyệt từng dòng.
  void _openOptimizePreview() {
    final unscheduled = _tasks
        .where((task) =>
            !task.isDone && task.status != 'skipped' && task.scheduledAt == null)
        .toList();
    if (unscheduled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không có nhiệm vụ chưa xếp lịch để tối ưu.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final proposals = proposeWeekPlan(unscheduled, sessions: _sessions);
    // Trạng thái duyệt từng dòng: true = chấp nhận, false = từ chối.
    final accepted = List<bool>.filled(proposals.length, true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đề xuất lịch tuần',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'EduPulse chỉ đề xuất — chưa có thay đổi nào được áp dụng. Duyệt từng dòng hoặc sửa ngày trước khi chấp nhận.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.55,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: proposals.length,
                    itemBuilder: (context, i) {
                      final p = proposals[i];
                      final d = p.proposedStart;
                      final dayLabel = _weekdayShort(d.weekday);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: accepted[i]
                              ? AppColors.blueSoft.withValues(alpha: 0.5)
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accepted[i]
                                ? AppColors.blue.withValues(alpha: 0.4)
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(p.task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: accepted[i]
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted,
                                        decoration: accepted[i]
                                            ? null
                                            : TextDecoration.lineThrough,
                                      )),
                                ),
                                // Accept/Reject từng dòng (mục 10.6).
                                IconButton(
                                  tooltip: accepted[i]
                                      ? 'Bỏ đề xuất này'
                                      : 'Chấp nhận dòng này',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setSheetState(
                                      () => accepted[i] = !accepted[i]),
                                  icon: Icon(
                                    accepted[i]
                                        ? Icons.check_circle_rounded
                                        : Icons.remove_circle_outline_rounded,
                                    size: 20,
                                    color: accepted[i]
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$dayLabel ${d.day}/${d.month} • ${d.hour}h • ${p.task.estimateMinutes} phút',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blue),
                            ),
                            const SizedBox(height: 2),
                            Text('Vì sao: ${p.reason}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary)),
                            // Edit từng dòng: chọn ngày khác trong tuần.
                            if (accepted[i])
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: sheetContext,
                                      initialDate: p.proposedStart,
                                      firstDate: DateTime.now(),
                                      lastDate:
                                          DateTime.now().add(const Duration(days: 14)),
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        proposals[i] = WeekPlanProposal(
                                          task: p.task,
                                          proposedStart: DateTime(
                                              picked.year,
                                              picked.month,
                                              picked.day,
                                              p.proposedStart.hour),
                                          reason: p.reason,
                                        );
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.edit_calendar_rounded,
                                      size: 15),
                                  label: const Text('Sửa ngày',
                                      style: TextStyle(fontSize: 11.5)),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Từ chối tất cả'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          var applied = 0;
                          for (var i = 0; i < proposals.length; i++) {
                            if (!accepted[i]) continue;
                            final task = proposals[i].task;
                            task.scheduledAt = proposals[i].proposedStart;
                            StorageService.setTodayTaskJson(
                                task.id, task.toJsonString());
                            applied++;
                          }
                          Navigator.pop(sheetContext);
                          if (applied > 0) {
                            setState(_load);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Đã áp dụng $applied nhiệm vụ vào lịch.')),
                            );
                          }
                        },
                        child: Text(accepted.any((a) => a)
                            ? 'Áp dụng ${accepted.where((a) => a).length} dòng'
                            : 'Áp dụng'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _weekdayShort(int weekday) => const [
        'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN',
      ][weekday - 1];

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) => _dateOnly(DateTime.now()).add(Duration(days: index - 3)));
    final minutes = _daySessions.fold<int>(0, (total, session) => total + session.actualMinutes);
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Lịch học', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Ghi chú',
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotesScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final day = days[index];
                  final selected = _isSameDay(day, _selectedDay);
                  // DragTarget cho desktop drag (mục 13): thả task vào
                  // ngày bất kỳ, có xác nhận trước khi đổi.
                  return DragTarget<TodayTask>(
                    onWillAcceptWithDetails: (details) => true,
                    onAcceptWithDetails: (details) =>
                        _confirmReschedule(details.data, day),
                    builder: (context, candidate, rejected) => InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _selectedDay = day),
                      child: Container(
                        width: 58,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : (candidate.isNotEmpty
                                  ? AppColors.blueSoft
                                  : AppColors.cardWhite),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : (candidate.isNotEmpty
                                    ? AppColors.blue
                                    : AppColors.border),
                            width: candidate.isNotEmpty ? 2 : 1,
                          ),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_weekday(day), style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.textMuted)),
                          const SizedBox(height: 5),
                          Text('${day.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.textPrimary)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.insights_rounded, color: AppColors.blue),
                const SizedBox(width: 10),
                Expanded(child: Text('${_scheduledTasks.length} nhiệm vụ • $minutes phút Focus', style: const TextStyle(fontWeight: FontWeight.w800))),
                TextButton(onPressed: _openOptimizePreview, child: const Text('Tối ưu tuần')),
              ]),
            ),
            const SizedBox(height: 18),
            Text(_dayTitle(_selectedDay), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_scheduledTasks.isEmpty && _daySessions.isEmpty)
              _EmptyAgenda(onOptimize: _openOptimizePreview)
            else ...[
              ..._scheduledTasks.map((task) => _TaskAgendaRow(task: task)),
              ..._daySessions.map((session) => _SessionAgendaRow(session: session)),
            ],
            // Exam + milestones của ngày đã chọn (mục 13).
            ..._examRowsForDay(_selectedDay),
          ],
        ),
      ),
    );
  }

  String _weekday(DateTime date) => const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][date.weekday - 1];
  String _dayTitle(DateTime date) => '${_weekday(date)}, ${date.day}/${date.month}';

  /// Desktop drag (mục 13 — Scheduling): xác nhận trước khi thay đổi;
  /// vượt deadline → Warning + AI alternative (đề xuất ngày khác hoặc
  /// giữ nguyên).
  void _confirmReschedule(TodayTask task, DateTime newDay) {
    final check = checkReschedule(task, newDay, sessions: _sessions);

    if (!check.exceedsDeadline) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Dời nhiệm vụ?', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
              'Chuyển "${task.title}" sang ${_dayTitle(newDay)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _applyReschedule(task, newDay);
              },
              child: const Text('Dời lịch', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    // Vượt deadline — Warning + AI alternative (mục 13).
    final alternative = check.alternative;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.orange),
          SizedBox(width: 8),
          Text('Vượt deadline', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: Text(
          '"${task.title}" có deadline ${_dayTitle(task.deadline!)}. '
          'Ngày bạn chọn (${_dayTitle(newDay)}) sẽ trễ hơn deadline.'
          '${alternative == null ? '' : '\n\nEduPulse đề xuất: ${_dayTitle(alternative.proposedStart)} — ${alternative.reason}.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Giữ lịch cũ'),
          ),
          if (alternative != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _applyReschedule(task, alternative.proposedStart);
              },
              child: const Text('Dùng đề xuất'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _applyReschedule(task, newDay); // người dùng quyết định.
            },
            child: const Text('Vẫn dời', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _applyReschedule(TodayTask task, DateTime newDay) {
    task.scheduledAt = _dateOnly(newDay);
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    setState(_load);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã dời "${task.title}" sang ${_dayTitle(newDay)}.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Exam + revision milestones rơi vào [day] (mục 13: Primary exam,
  /// Important milestones).
  List<Widget> _examRowsForDay(DateTime day) {
    final exam = _primaryExam;
    if (exam == null) return const [];
    final rows = <Widget>[];
    final examDate = _dateOnly(exam.dateTime);
    // Revision bắt đầu 7 ngày trước thi (đặc tả mục 39).
    final revisionDate = _dateOnly(exam.dateTime).subtract(const Duration(days: 7));
    if (_isSameDay(examDate, day)) {
      rows.add(_ExamAgendaRow(
        icon: Icons.event_rounded,
        color: AppColors.red,
        title: '📅 ${exam.name} — NGÀY THI',
        subtitle: 'Giờ thi: ${exam.dateTime.hour.toString().padLeft(2, '0')}:${exam.dateTime.minute.toString().padLeft(2, '0')}',
      ));
    }
    if (_isSameDay(revisionDate, day)) {
      rows.add(const _ExamAgendaRow(
        icon: Icons.flag_rounded,
        color: AppColors.orange,
        title: '🏁 Bắt đầu giai đoạn tổng ôn',
        subtitle: '7 ngày trước thi — ưu tiên ôn thay vì học mới',
      ));
    }
    return rows;
  }
}

class _EmptyAgenda extends StatelessWidget {
  final VoidCallback onOptimize;

  const _EmptyAgenda({required this.onOptimize});
  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          const Icon(Icons.event_available_rounded, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 8),
          const Text('Ngày này đang trống', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Để EduPulse đề xuất lịch, hoặc tự thêm nhiệm vụ mới.',
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          // Actions đúng đặc tả mục 33 — Empty Calendar: Create + AI schedule.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onOptimize,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primaryDark,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                label: const Text('Tối ưu tuần', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ]),
      );
}

class _TaskAgendaRow extends StatelessWidget {
  const _TaskAgendaRow({required this.task});
  final TodayTask task;
  @override
  Widget build(BuildContext context) => GlassCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(task.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: task.isDone ? AppColors.primary : AppColors.blue),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: task.isDone ? TextDecoration.lineThrough : null)),
            Text('${task.subject} • ${task.estimateMinutes} phút', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ])),
        ]),
      );
}

class _SessionAgendaRow extends StatelessWidget {
  const _SessionAgendaRow({required this.session});
  final StudySession session;
  @override
  Widget build(BuildContext context) => GlassCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.timer_outlined, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text('Focus ${session.subject} • ${session.actualMinutes} phút', style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Hàng exam/milestone trong agenda (mục 13).
class _ExamAgendaRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ExamAgendaRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        borderColor: color.withValues(alpha: 0.5),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      );
}
