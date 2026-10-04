import 'dart:async';
import '../../../../core/utils/feedback_service.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_copilot_service.dart';
import '../../../../core/ai/ai_refresh_service.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/notifications/adaptive_policy.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/mascot_avatar.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../domain/models/study_models.dart';
import '../../domain/active_study_session.dart';
import '../../domain/app_leaving.dart';
import '../../domain/focus_clock.dart';
import '../../domain/study_timeline.dart';
import '../../../tasks/domain/models/task_state.dart';
import '../../domain/score_summary.dart';
import '../../domain/score_recovery_plan.dart';
import '../../domain/study_analytics.dart';
import '../../domain/repositories/study_session_repository.dart';
import '../widgets/score_chart_widget.dart';
import '../widgets/weekly_chart_widget.dart';
import '../../../tasks/domain/repositories/task_repository.dart';
import '../../../exams/domain/models/exam_model.dart';

class StudyScreen extends StatefulWidget {
  final VoidCallback? onStreakChanged;

  /// Gọi sau khi phiên học vừa kết thúc (BE-3.3) để màn bên ngoài vẽ lại tổng
  /// thời gian học ngay, không chờ người dùng tự điều hướng.
  final VoidCallback? onSessionCompleted;
  final String? initialSubject;
  final int? initialMinutes;
  final TodayTask? initialTask;
  final bool autoStart;

  /// Nguồn thời gian cho toàn bộ màn hình, mặc định là đồng hồ thật.
  ///
  /// `FocusClock` neo theo mốc thời gian (FE-3.2) — đúng cho sản phẩm, nhưng
  /// `tester.pump()` chỉ đẩy được `Timer`, không đẩy được `DateTime.now()`.
  /// Không có tham số này thì **không test nổi** việc một vòng 25 phút thật sự
  /// kết thúc, và test buộc phải chờ hoặc giả vờ — tức là không kiểm chứng
  /// được đường ghi dữ liệu quan trọng nhất của màn hình.
  final DateTime Function() clock;

  const StudyScreen({
    super.key,
    this.onStreakChanged,
    this.onSessionCompleted,
    this.initialSubject,
    this.initialMinutes,
    this.initialTask,
    this.autoStart = false,
    this.clock = DateTime.now,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> with WidgetsBindingObserver {
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

  /// Đang chờ bắt đầu vòng mới vì câu hỏi khôi phục chưa được trả lời xong.
  bool _pendingAutoStart = false;
  bool _isBreak = false;
  int _pomRound = 0;
  Timer? _pomTimer;

  // Đồng hồ neo theo mốc thời gian thật (FE-3.2): timer chỉ đẩy giao diện
  // cập nhật, số giây còn lại luôn tính từ `DateTime.now()`.
  FocusClock _clock = FocusClock(totalSeconds: 25 * 60);

  // App-leaving tracking (mục 11.5): đo phút đã học trước khi rời app
  // giữa phiên; pattern phân tích khi user quay lại.
  DateTime? _leftAt;
  AppLeavingInsight _leavingInsight = AppLeavingInsight.none;

  @override
  void initState() {
    super.initState();
    _clock = FocusClock(totalSeconds: _focusMinutes * 60);
    if (widget.initialMinutes != null) {
      _focusMinutes = widget.initialMinutes!;
      _clock = FocusClock(totalSeconds: _focusMinutes * 60);
      _pomSecondsNotifier.value = _focusMinutes * 60;
    }
    if (widget.initialTask != null) {
      _selectedTask = widget.initialTask;
    }
    _loadLogs();
    _loadScores();
    _loadTasks();
    _loadSessions();
    // Lifecycle để phát hiện rời app giữa phiên focus (mục 11.5).
    WidgetsBinding.instance.addObserver(this);

    // Hỏi sau khi cây dựng xong: `showDialog` cần `Localizations`/`Navigator`
    // của context, mà trong `initState` context chưa gắn vào cây.
    //
    // Auto-start cũng phải qua đây: mở bằng "học ngay" mà có phiên bỏ dở thì
    // bắt đầu vòng mới sẽ xoá mất ảnh chụp của phiên cũ (BE-3.2).
    final wantsAutoStart = widget.autoStart;
    _pendingAutoStart = wantsAutoStart;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final snapshot = StudySessionRepository.instance.getActive();
      if (snapshot != null) {
        await _offerActiveSessionRecovery();
      }
      _startPendingAutoStart();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lưu ảnh chụp vòng đang chạy **trước** mọi nhánh còn lại: đây là lúc cuối
    // cùng app còn sống, và nó phải chạy kể cả khi vòng đang nghỉ (BE-3.2).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _persistActiveSession();
    }

    if (!_pomRunning || _isBreak) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftAt = widget.clock();
    } else if (state == AppLifecycleState.resumed && _leftAt != null) {
      final away = widget.clock().difference(_leftAt!);
      _leftAt = null;
      // Rời app lâu hơn 2 phút coi như bỏ dở phiên này — ghi sự kiện
      // và phân tích pattern khi đủ dữ liệu (mục 11.5).
      if (away.inMinutes >= 2) {
        _recordAppLeaving();
      }
    }
    // App vừa quay lại: đồng hồ phải nhảy thẳng tới số giây đúng, không chờ
    // tick kế tiếp. Đây là chỗ lỗi "mất thời gian học" lộ ra rõ nhất (FE-3.2).
    if (state == AppLifecycleState.resumed) {
      _syncClockToUi();
    }
  }

  /// Đồng bộ giao diện với mốc thời gian thật; vòng đã hết thì kết thúc ngay.
  void _syncClockToUi() {
    if (!mounted || !_pomRunning || _isBreak) return;
    final remaining = _clock.remainingAt(widget.clock());
    _pomSecondsNotifier.value = remaining;
    if (remaining == 0) _finishRound();
  }

  void _recordAppLeaving() {
    final planned = _focusMinutes;
    // Lấy từ đồng hồ chứ không tự trừ: đây là lúc app đang bị vùy, tức là lúc
    // `Timer.periodic` đã bị hệ điều hành giữ lại và số đếm không đáng tin.
    final studied =
        (_clock.elapsedAt(widget.clock()) / 60).round().clamp(0, planned);
    StorageService.setString(
      'app_leaving_events',
      _appendLeavingEvent(planned, studied),
    );
    // Phân tích pattern từ lịch sử — chỉ hiện khi đủ mẫu & ngưỡng.
    final events = _parseLeavingEvents();
    final insight = analyzeAppLeaving(events);
    if (insight.message != null && mounted) {
      setState(() => _leavingInsight = insight);
    }
  }

  /// Lưu trữ sự kiện rời app dạng JSON list, giữ tối đa 10 gần nhất.
  String _appendLeavingEvent(int planned, int studied) {
    final events = _parseLeavingEvents();
    events.insert(
        0, AppLeavingEvent(plannedMinutes: planned, studiedMinutes: studied));
    return jsonEncode(events
        .take(10)
        .map((e) => {
              'planned': e.plannedMinutes,
              'studied': e.studiedMinutes,
            })
        .toList());
  }

  List<AppLeavingEvent> _parseLeavingEvents() {
    final raw = StorageService.getString('app_leaving_events');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AppLeavingEvent(
                plannedMinutes: (e['planned'] as num?)?.toInt() ?? 25,
                studiedMinutes: (e['studied'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _loadSessions() {
    _sessions = StudySessionRepository.instance.getAll();
  }

  void _loadTasks() {
    _tasks = TaskRepository.instance
        .getAllTasks()
        .where((task) => !task.isDone && task.status != 'skipped')
        .toList();
  }

  /// Tên task theo ID, để dòng nhật ký từ phiên học hiện đúng nơi đã học.
  Map<String, String> get _taskTitles => {
        for (final task in TaskRepository.instance.getAllTasks())
          task.id: task.title,
      };

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

  /// Ghi chép nhập tay. Vòng Pomodoro **không** gọi hàm này nữa — nó đã được
  /// ghi thành `StudySession`, ghi thêm ở đây là đếm trùng một khoảng thời gian
  /// vào hai bảng.
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

  /// Nhật ký học gộp cả phiên học lẫn ghi chép nhập tay, mới nhất trước.
  List<StudyTimelineEntry> get _timeline =>
      buildStudyTimeline(logs: _logs, sessions: _sessions);

  /// Xoá một dòng nhật ký — về đúng bảng gốc của nó.
  ///
  /// Xoá nhầm bảng là mất dữ liệu âm thầm: xoá `StudyLog` của một phiên học
  /// thì phiên vẫn còn trong thống kê, và ngược lại thì phiên biến mất khỏi
  /// lịch sử của nhiệm vụ.
  void _deleteTimelineEntry(StudyTimelineEntry entry) {
    if (entry.fromSession) {
      StudySessionRepository.instance.delete(entry.id);
      setState(() => _sessions.removeWhere((s) => s.id == entry.id));
    } else {
      StorageService.removeStudyLog(entry.id);
      setState(() => _logs.removeWhere((l) => l.id == entry.id));
    }
  }

  /// Ghi chú hiển thị cho một dòng nhật ký.
  ///
  /// Dòng từ phiên học gắn task nên hiện tên task; task đã bị xoá thì không bịa
  /// lại tên, chỉ ghi "Pomodoro".
  String? _entryNote(StudyTimelineEntry entry) {
    if (entry.note != null && entry.note!.isNotEmpty) return entry.note;
    final taskId = entry.taskId;
    if (taskId == null) return null;
    final title = _taskTitles[taskId];
    return title == null ? 'Pomodoro' : 'Focus: $title';
  }

  void _setPomodoroMode(int focus, int brk) {
    _pomTimer?.cancel();
    _focusMinutes = focus;
    _breakMinutes = brk;
    _pomRunning = false;
    _isBreak = false;
    _clock = FocusClock(totalSeconds: focus * 60);
    _pomSecondsNotifier.value = focus * 60;
    StudySessionRepository.instance.clearActive();
    setState(() {});
  }

  void _togglePomodoro() {
    FeedbackService.light();
    if (_pomRunning) {
      _pomTimer?.cancel();
      _clock.pause(widget.clock());
      setState(() => _pomRunning = false);
      // Thoát Focus → cho phép notification thường trở lại.
      AdaptivePolicy.setInFocus(false);
    } else {
      _clock.start(widget.clock());
      setState(() => _pomRunning = true);
      // Vào Focus → tạm dừng notification không quan trọng (đặc tả mục 16).
      AdaptivePolicy.setInFocus(true);
      _startPomodoroTimer();
    }
    _persistActiveSession();
  }

  /// Ghi ảnh chụp vòng đang chạy xuống storage (BE-3.2).
  ///
  /// Không chụp khi vòng chưa từng chạy: một vòng 25 phút mới mở màn hình rồi
  /// bị kill cũng không phải phiên học, và hỏi "tiếp tục?" cho nó là hỏi nhầm.
  void _persistActiveSession() {
    final repo = StudySessionRepository.instance;
    if (!_clock.hasStarted) {
      repo.clearActive();
      return;
    }
    final task = _selectedTask;
    repo.saveActive(ActiveStudySession.fromClock(
      clock: _clock,
      taskId: task?.id ?? 'pomodoro',
      taskTitle: task?.title,
      subject: task?.subject ?? 'Pomodoro',
      round: _pomRound,
      isBreak: _isBreak,
    ));
  }

  /// Hỏi khôi phục vòng bị bỏ dở khi app bị kill (BE-3.2).
  ///
  /// Chỉ hỏi khi vòng **còn giá trị**: đã học được ít nhất 1 phút và còn giờ.
  /// Hỏi về một vòng mới 3 giây là gây phiền vô nghĩa.
  Future<void> _offerActiveSessionRecovery() async {
    final snapshot = StudySessionRepository.instance.getActive();
    if (snapshot == null || !mounted) return;

    final now = widget.clock();
    // Ảnh chụp quá hạn (mặc định 6 giờ) là dữ liệu tạm cũ, và một vòng focus
    // dài nhất cũng chỉ 60 phút — hỏi người dùng về nó chỉ gây rối. Ảnh chụp còn
    // hiệu lực thì hỏi như bình thường.
    if (snapshot.isExpiredAt(now)) {
      StudySessionRepository.instance.clearActive();
      return;
    }
    final elapsedMinutes = snapshot.elapsedMinutesAt(now);
    final remaining = snapshot.remainingAt(now);
    if (elapsedMinutes < 1 || remaining <= 0) {
      StudySessionRepository.instance.clearActive();
      return;
    }

    final shouldResume = await ConfirmationDialog.show(
      context,
      title: 'Phiên học đang bỏ dở',
      content: 'Bạn đã học $elapsedMinutes phút của phiên '
          '"${snapshot.taskTitle ?? snapshot.subject}" trước khi ứng dụng bị đóng.\n'
          'Còn ${snapshot.remainingAt(now) ~/ 60} phút. Bạn muốn tiếp tục?',
      confirmLabel: 'Tiếp tục',
      cancelLabel: 'Kết thúc phiên',
      isDestructive: true,
    );
    if (!mounted) return;

    if (shouldResume == true) {
      _resumeFromSnapshot(snapshot, now);
    } else if (shouldResume == false) {
      _finishAbandonedSession(snapshot, now);
    }
    // `null` = bấm ra ngoài: giữ ảnh chụp lại, lần sau còn hỏi được.
    _startPendingAutoStart();
  }

  /// Mở màn hình học bằng nút "học ngay" (`autoStart`) không được âm thầm bỏ qua
  /// một phiên đang bỏ dở: nó sẽ ghi đè ảnh chụp và mất thời gian đã học.
  ///
  /// Vì vậy auto-start phải đợi người dùng trả lời xong câu hỏi khôi phục.
  void _startPendingAutoStart() {
    final shouldStart = _pendingAutoStart;
    _pendingAutoStart = false;
    if (!shouldStart || !mounted || _pomRunning) return;
    _togglePomodoro();
  }

  /// Nối lại đồng hồ đã khôi phục và chạy tiếp.
  void _resumeFromSnapshot(ActiveStudySession snapshot, DateTime now) {
    setState(() {
      _clock = snapshot.restoreClock(now: now);
      _isBreak = snapshot.isBreak;
      _pomRound = snapshot.round;
      _pomSecondsNotifier.value = _clock.remainingAt(now);
    });
    if (_clock.remainingAt(now) <= 0) return;

    // Đồng hồ khôi phục phải đang chạy thì mới bật được nút chạy. Nếu không,
    // giao diện báo "đang học" trong khi đồng hồ đứng yên — số giây không bao
    // giờ giảm, vòng treo vô hạn và thời gian học không được ghi.
    if (!_clock.isRunning) return;

    setState(() => _pomRunning = true);
    AdaptivePolicy.setInFocus(true);
    _startPomodoroTimer();
  }

  /// Người dùng chọn kết thúc: ghi phần đã học thành phiên `cancelled` rồi xoá
  /// ảnh chụp — bỏ dở không được nghĩa là không có gì được ghi.
  void _finishAbandonedSession(ActiveStudySession snapshot, DateTime now) {
    final minutes = snapshot.elapsedMinutesAt(now);
    final repo = StudySessionRepository.instance;
    repo.clearActive();
    if (minutes < 1) return;

    final session = StudySession(
      id: _uuid.v4(),
      completedAt: now,
      taskId: snapshot.taskId == 'pomodoro' ? null : snapshot.taskId,
      subject: snapshot.subject,
      plannedMinutes: (snapshot.totalSeconds / 60).round(),
      actualMinutes: minutes,
      startedAt: snapshot.startedAt,
      endedAt: now,
      status: StudySession.statusCancelled,
    );
    repo.save(session);
    setState(() => _sessions.insert(0, session));
    AiRefreshService.notifyDataChanged();
  }

  /// Timer chỉ đẩy giao diện; số giây còn lại do [FocusClock] tính từ mốc
  /// thời gian (FE-3.2). Vì vậy tick bị trễ hay bị gộp cũng không sai số.
  /// Kết thúc phiên sớm — ghi những gì đã học và mở bước đánh giá 1 chạm.
  ///
  /// Không ai học đúng bằng số phút cài sẵn: đặc tả 5.6 yêu cầu "Allow
  /// completion without requiring a timer to reach zero". Chỉ ghi phiên khi đã
  /// học ít nhất 1 phút — nếu không thì đây là một cú bấm nhầm, không phải một
  /// phiên học.
  void _finishSessionEarly() {
    final now = widget.clock();
    final elapsedMinutes = (_clock.elapsedAt(now) / 60).round();
    if (!_clock.hasStarted || elapsedMinutes < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hãy bắt đầu phiên học trước rồi bấm Hoàn thành nhé.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    _pomTimer?.cancel();
    StudySessionRepository.instance.clearActive();
    setState(() => _pomRunning = false);
    // Ghi phiên + streak + mở sheet đánh giá — cùng đường ghi như khi đồng hồ
    // chạy tự nhiên về 0, chỉ khác mốc thời gian bắt đầu.
    _recordCompletedFocus();
    StorageService.registerStudyActivity();
    StorageService.addMascotBondExp(25);
    widget.onStreakChanged?.call();
    FeedbackService.medium();
  }

  /// UX mục 11 "No study history" — nút "Bắt đầu học" trong empty state của
  /// thẻ phân tích. Chỉ bắt đầu vòng Focus khi đồng hồ đang đứng yên, để
  /// không bao giờ vô tình dừng phiên đang chạy.
  void _startFirstSession() {
    if (_pomRunning || _isBreak) return;
    _togglePomodoro();
  }

  void _startPomodoroTimer() {
    _pomTimer?.cancel();
    _pomTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _pomTimer?.cancel();
        return;
      }
      final remaining = _clock.remainingAt(widget.clock());
      _pomSecondsNotifier.value = remaining;
      if (remaining > 0) return;
      _finishRound();
    });
  }

  /// Kết thúc một vòng: nghỉ → vòng focus mới, focus → sang nghỉ và ghi phiên.
  void _finishRound() {
    if (!mounted) return;
    _pomTimer?.cancel();
    // Vòng vừa kết thúc nên không còn gì để khôi phục; ảnh chụp cũ sẽ khiến
    // lần mở sau hỏi tiếp tục một phiên đã xong.
    StudySessionRepository.instance.clearActive();
    // Chụp lại đồng hồ vòng focus **trước** khi thay bằng đồng hồ nghỉ:
    // `_recordCompletedFocus()` đọc `elapsedAt` của chính nó, và nếu đổi trước
    // thì nó sẽ đo đồng hồ mới (0 giây đã học) → mọi phiên đều ghi 0 phút.
    final finishedClock = _clock;
    setState(() {
      _pomRunning = false;
      if (_isBreak) {
        _isBreak = false;
        _clock = FocusClock(totalSeconds: _focusMinutes * 60);
        _pomSecondsNotifier.value = _focusMinutes * 60;
      } else {
        _pomRound++;
        _isBreak = true;
        _clock = FocusClock(totalSeconds: _breakMinutes * 60);
        _pomSecondsNotifier.value = _breakMinutes * 60;
        // Haptic hết giờ (mục 54: Timer end) — báo ngay cả khi
        // người dùng đang nhìn chỗ khác.
        FeedbackService.medium();
        _recordCompletedFocus(clock: finishedClock);
        // Kết thúc phiên tập trung → streak + EXP gắn kết linh vật.
        StorageService.registerStudyActivity();
        StorageService.addMascotBondExp(25);
        widget.onStreakChanged?.call();
      }
    });
  }

  /// Ghi `StudySession` cho một vòng focus vừa hoàn thành (BE-3.1).
  ///
  /// [clock] là đồng hồ của vòng vừa kết thúc, truyền vào tường minh thay vì
  /// đọc `_clock`: sau khi chuyển sang vòng nghỉ, `_clock` không còn là đồng hồ
  /// của phiên đang ghi, và mọi phép đo sẽ ra 0.
  void _recordCompletedFocus({FocusClock? clock}) {
    final focusClock = clock ?? _clock;
    final plannedMinutes = _focusMinutes;
    final task = _selectedTask;
    final subject = task?.subject ?? 'Pomodoro';
    // Cố ý **không** ghi `StudyLog` ở đây nữa: vòng pomodoro đã có phiên học
    // thật, ghi thêm dòng log là thời gian học bị đếm hai lần ở mọi tổng hợp.

    final now = widget.clock();
    // Phút thật đã học, đo từ mốc thời gian — không phải số phút trong cài đặt.
    // Nếu để nguyên `_focusMinutes` thì một phiên bị tạm dừng nhiều lần vẫn ghi
    // 25 phút, và mọi tổng thời gian học sau này đều thừa (BE-3.1).
    final actualMinutes =
        (focusClock.elapsedAt(now) / 60).round().clamp(0, plannedMinutes);
    final session = StudySession(
      id: _uuid.v4(),
      completedAt: now,
      taskId: task?.id,
      subject: subject,
      plannedMinutes: plannedMinutes,
      actualMinutes: actualMinutes,
      // Mốc thật do người dùng bấm bắt đầu, không phải ước lượng (BE-3.1).
      startedAt: focusClock.startedAt ?? now,
      endedAt: now,
      status: StudySession.statusCompleted,
    );
    // Ghi qua repository để màn chi tiết Task đọc lịch sử phiên học từ đúng
    // một nguồn (FE-2.2).
    StudySessionRepository.instance.save(session);
    AiRefreshService.notifyDataChanged();
    setState(() => _sessions.insert(0, session));
    // Màn bên ngoài cần số phút mới ngay, không chờ người dùng điều hướng
    // (BE-3.3).
    widget.onSessionCompleted?.call();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (mounted) _showAiPostFocusSheet(session);
      },
    );
  }

  void _showAiPostFocusSheet(StudySession session) {
    var understandingLevel = 1; // 1: Hiểu tốt, 0: Cần củng cố
    bool showDetailed = false;
    // Đánh giá 1 chạm (FE-3.3): 5 emoji → 5 mức. Chạm một lần là đủ để lưu,
    // không bắt người dùng chờ điền thang chi tiết 5 dòng.
    var quickRating = 0;
    var mood = 4;
    var focus = 4;
    var difficulty = 3;
    var understanding = 4;
    var effectiveness = 4;
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.greenSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xuất sắc! Xong phiên ${session.actualMinutes}p',
                              style: const TextStyle(
                                  fontSize: 16.5, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Môn ${session.subject} • +25 EXP Mascot',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 20),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Phiên học thế nào? Chạm 1 emoji là xong',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final option in _quickRatings)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: option == _quickRatings.last ? 0 : 6),
                            child: GestureDetector(
                              key: ValueKey('quick-rating-${option.value}'),
                              onTap: () => setSheetState(() {
                                quickRating = option.value;
                                mood = option.mood;
                                focus = option.focus;
                                difficulty = option.difficulty;
                                understanding = option.understanding;
                                effectiveness = option.effectiveness;
                                understandingLevel = option.understood ? 1 : 0;
                              }),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: quickRating == option.value
                                      ? AppColors.primary
                                          .withValues(alpha: 0.15)
                                      : AppColors.cardLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: quickRating == option.value
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(option.emoji,
                                        style: const TextStyle(fontSize: 22)),
                                    const SizedBox(height: 2),
                                    Text(option.label,
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight:
                                                quickRating == option.value
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                            color: quickRating == option.value
                                                ? AppColors.primary
                                                : AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Bạn nắm kiến thức phiên này thế nào?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() {
                            understandingLevel = 1;
                            understanding = 4;
                            effectiveness = 4;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: understandingLevel == 1
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: understandingLevel == 1
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('👍',
                                    style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Hiểu tốt',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: understandingLevel == 1
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: understandingLevel == 1
                                            ? AppColors.primary
                                            : AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() {
                            understandingLevel = 0;
                            understanding = 2;
                            effectiveness = 3;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: understandingLevel == 0
                                  ? AppColors.orange.withValues(alpha: 0.15)
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: understandingLevel == 0
                                    ? AppColors.orange
                                    : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🤔',
                                    style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Cần củng cố',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: understandingLevel == 0
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: understandingLevel == 0
                                            ? AppColors.orange
                                            : AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.purpleSoft.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.purple.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.bolt_rounded,
                                color: AppColors.purple, size: 16),
                            SizedBox(width: 6),
                            Text('Liên kết AI thông minh:',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.purple)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.quiz_rounded,
                                  size: 15, color: AppColors.purple),
                              label: const Text('🧠 Test nhanh 1 câu AI'),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                  color:
                                      AppColors.purple.withValues(alpha: 0.4)),
                              labelStyle: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purple),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                final sub = session.subject.isEmpty ||
                                        session.subject == 'Pomodoro'
                                    ? 'Toán'
                                    : session.subject;
                                AiCopilotService.executeAction(
                                  context,
                                  AiCopilotAction(
                                    type: AiActionType.takeQuiz,
                                    label: 'Kiểm tra nhanh',
                                    icon: Icons.quiz_rounded,
                                    payload: {
                                      'subject': sub,
                                      'topic': 'Củng cố kiến thức môn $sub',
                                      'onTasksChanged': () {
                                        if (mounted) setState(_loadTasks);
                                      },
                                    },
                                  ),
                                );
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.sticky_note_2_rounded,
                                  size: 15, color: AppColors.blue),
                              label: const Text('📝 Ghi chú nhanh'),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                  color: AppColors.blue.withValues(alpha: 0.4)),
                              labelStyle: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blue),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _showQuickNoteDialog(session.subject,
                                    sessionId: session.id);
                              },
                            ),
                            if (understandingLevel == 0)
                              ActionChip(
                                avatar: const Icon(Icons.calendar_today_rounded,
                                    size: 15, color: AppColors.orange),
                                label: const Text('📅 Ôn lại ngày mai'),
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                    color: AppColors.orange
                                        .withValues(alpha: 0.4)),
                                labelStyle: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.orange),
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _scheduleReviewTaskTomorrow(session.subject);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => showDetailed = !showDetailed),
                        child: Text(
                          showDetailed
                              ? 'Thu gọn đánh giá'
                              : 'Thêm đánh giá chi tiết ▾',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Bỏ qua',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                  if (showDetailed) ...[
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
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const ValueKey('save-session-feedback'),
                      onPressed: () => _saveSessionFeedback(
                        sheetContext,
                        session,
                        _SessionFeedback(
                          mood: mood,
                          focus: focus,
                          difficulty: difficulty,
                          understanding: understanding,
                          effectiveness: effectiveness,
                          note: noteController.text,
                        ),
                      ),
                      child: Text(quickRating > 0
                          ? 'Lưu đánh giá & Hoàn tất'
                          : 'Lưu phản hồi & Hoàn tất'),
                    ),
                  ),
                  // Đường 1 chạm: xong việc thì đánh dấu nhiệm vụ hoàn thành
                  // và về thẳng màn Hôm nay — đúng tinh thần "xong việc này,
                  // sang việc tiếp theo" (FE-3.3).
                  if (_selectedTask != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('complete-task-and-go-today'),
                        onPressed: () => _completeTaskAndGoToday(
                          sheetContext,
                          session,
                          _SessionFeedback(
                            mood: mood,
                            focus: focus,
                            difficulty: difficulty,
                            understanding: understanding,
                            effectiveness: effectiveness,
                            note: noteController.text,
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          'Xong việc này — về Hôm nay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(noteController.dispose);
  }

  /// Một mức đánh giá 1 chạm (FE-3.3).
  ///
  /// Emoji là thứ người dùng thật sự bấm; các thang đánh giá chi tiết suy ra từ
  /// đó theo một quy tắc cố định thay vì để người dùng điền 5 dòng — nếu
  /// không có quy tắc, số phản hồi sẽ là dữ liệu bịa.
  static const List<_QuickRating> _quickRatings = [
    _QuickRating(
      emoji: '😫',
      label: 'Khó',
      value: 1,
      mood: 1,
      focus: 2,
      difficulty: 5,
      understanding: 1,
      effectiveness: 2,
      understood: false,
    ),
    _QuickRating(
      emoji: '😐',
      label: 'Tạm',
      value: 2,
      mood: 2,
      focus: 3,
      difficulty: 4,
      understanding: 2,
      effectiveness: 2,
      understood: false,
    ),
    _QuickRating(
      emoji: '🙂',
      label: 'Ổn',
      value: 3,
      mood: 3,
      focus: 3,
      difficulty: 3,
      understanding: 3,
      effectiveness: 3,
      understood: true,
    ),
    _QuickRating(
      emoji: '😄',
      label: 'Tốt',
      value: 4,
      mood: 4,
      focus: 4,
      difficulty: 3,
      understanding: 4,
      effectiveness: 4,
      understood: true,
    ),
    _QuickRating(
      emoji: '🔥',
      label: 'Chất',
      value: 5,
      mood: 5,
      focus: 5,
      difficulty: 2,
      understanding: 5,
      effectiveness: 5,
      understood: true,
    ),
  ];

  /// Lưu phản hồi của phiên vừa học xong.
  ///
  /// [mood]…[effectiveness] lấy từ đánh giá 1 chạm hoặc từ các thanh chi tiết
  /// mà người dùng đã chỉnh; ghi chú rỗng thì không ghi (`null`) để phân biệt
  /// "không đánh giá" với "đánh giá rỗng".
  Future<void> _saveSessionFeedback(
    BuildContext sheetContext,
    StudySession session,
    _SessionFeedback feedback,
  ) async {
    await StudySessionRepository.instance.updateFeedback(
      session.id,
      mood: feedback.mood,
      focus: feedback.focus,
      difficulty: feedback.difficulty,
      understanding: feedback.understanding,
      effectiveness: feedback.effectiveness,
      reflectionNote:
          feedback.note.trim().isEmpty ? null : feedback.note.trim(),
    );
    AiRefreshService.notifyDataChanged();
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  /// Đường 1 chạm của FE-3.3: lưu phản hồi → đánh dấu nhiệm vụ hoàn thành →
  /// về màn Hôm nay.
  ///
  /// Việc đánh dấu hoàn thành đi qua [TaskRepository] (Single Write Path) để
  /// state machine, streak và Home đều nhận đúng một lần ghi.
  Future<void> _completeTaskAndGoToday(
    BuildContext sheetContext,
    StudySession session,
    _SessionFeedback feedback,
  ) async {
    await _saveSessionFeedback(sheetContext, session, feedback);

    final task = _selectedTask;
    if (task != null) {
      final result = await TaskRepository.instance.setTaskStatus(
        task.id,
        TaskStatus.completed,
      );
      if (mounted && !result.success && result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
    }

    widget.onSessionCompleted?.call();
    if (mounted) setState(_loadTasks);
  }

  String _getAiSubjectTip(String subject) {
    switch (subject.toLowerCase().trim()) {
      case 'toán':
      case 'toan':
        return 'Toán: Rèn phản xạ giải nhanh dạng nhận biết/thông hiểu, kiểm tra kỹ điều kiện.';
      case 'vật lý':
      case 'vat ly':
      case 'lý':
      case 'ly':
        return 'Vật lý: Phác thảo sơ đồ hiện tượng và đổi đúng đơn vị SI trước khi bấm máy.';
      case 'hóa học':
      case 'hoa hoc':
      case 'hóa':
      case 'hoa':
        return 'Hóa học: Áp dụng định luật bảo toàn e/khối lượng để giải nhanh trắc nghiệm.';
      case 'tiếng anh':
      case 'tieng anh':
      case 'anh':
      case 'english':
        return 'Tiếng Anh: Đọc lướt câu hỏi trước để bắt từ khóa trước khi đọc cả đoạn văn.';
      case 'ngữ văn':
      case 'ngu van':
      case 'văn':
      case 'van':
        return 'Ngữ văn: Vạch nhanh 3 luận điểm cốt lõi trước khi đặt bút viết phân tích.';
      case 'sinh học':
      case 'sinh hoc':
      case 'sinh':
        return 'Sinh học: Ghi nhớ bằng sơ đồ tư duy quy luật di truyền và chu trình sinh thái.';
      case 'lịch sử':
      case 'lich su':
      case 'sử':
        return 'Lịch sử: Nhớ sự kiện theo dòng thời gian và mối quan hệ nguyên nhân - kết quả.';
      case 'địa lý':
      case 'dia ly':
      case 'địa':
        return 'Địa lý: Khai thác tối đa kỹ năng đọc Atlat để chắc chắn điểm các câu thực hành.';
      default:
        return 'AI Mẹo: Chia nhỏ mục tiêu phiên học thành 2–3 bài tập trọng tâm để dứt điểm.';
    }
  }

  Future<void> _scheduleReviewTaskTomorrow(String subject) async {
    final sub = subject.isEmpty || subject == 'Pomodoro' ? 'Toán' : subject;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final task = TodayTask(
      id: _uuid.v4(),
      title: 'Ôn củng cố: $sub',
      subject: AppSubjects.normalize(sub),
      priority: 'high',
      estimateMinutes: 25,
      scheduledAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 0),
    );
    // Qua repository: có createdAt, chống trùng và phát tín hiệu revision
    // để Home vẽ lại — giống hệt khi người dùng tự thêm.
    final result = await TaskRepository.instance.createTaskIfMissing(task);
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.isDuplicate
              ? 'Ngày mai đã có nhiệm vụ "Ôn củng cố: $sub" rồi.'
              : 'Không thêm được nhiệm vụ ôn củng cố.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    AiRefreshService.notifyDataChanged();
    _loadTasks();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm nhiệm vụ "Ôn củng cố: $sub" vào lịch ngày mai!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQuickNoteDialog(String subject, {String? sessionId}) {
    final sub = subject.isEmpty || subject == 'Pomodoro' ? 'Tổng kết' : subject;
    final titleCtrl = TextEditingController(text: 'Tổng kết: $sub');
    final bodyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.sticky_note_2_rounded, color: AppColors.purple),
            SizedBox(width: 8),
            Text('Ghi chú nhanh AI',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ý chính bạn đọng lại sau phiên học...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final note = StudyNote(
                id: _uuid.v4(),
                title: titleCtrl.text.trim().isEmpty
                    ? 'Ghi chú $sub'
                    : titleCtrl.text.trim(),
                body: bodyCtrl.text.trim(),
                subject: sub,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                tags: ['Pomodoro', sub],
                sessionId: sessionId,
              );
              StorageService.setStudyNoteJson(note.id, note.toJsonString());
              final noteIds = StorageService.getStudyNoteIds()..add(note.id);
              StorageService.setStudyNoteIds(noteIds);
              AiRefreshService.notifyDataChanged();
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã lưu ghi chú thành công!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Lưu ghi chú'),
          ),
        ],
      ),
    );
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
                      color:
                          selected ? AppColors.primary : AppColors.borderStrong,
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
                      subtitle: Text(
                          '${task.subject} · ${task.estimateMinutes} phút'),
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
    _clock = FocusClock(totalSeconds: _focusMinutes * 60);
    _pomSecondsNotifier.value = _focusMinutes * 60;
    StudySessionRepository.instance.clearActive();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pomTimer?.cancel();
    // Rời màn khi vòng đã dừng = người dùng chủ động bỏ; giữ ảnh chụp lại sẽ
    // mở lên lại lại hỏi "tiếp tục phiên?" cho một việc họ đã dừng.
    if (!_pomRunning) {
      StudySessionRepository.instance.clearActive();
    } else {
      _persistActiveSession();
    }
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
        // App-leaving insight (mục 11.5): gợi ý nhẹ nhàng khi quay lại,
        // dismiss được — không ép học, không phán xét.
        if (_leavingInsight.message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              customColor: AppColors.blueSoft.withValues(alpha: 0.5),
              child: Row(
                children: [
                  const Icon(Icons.self_improvement_rounded,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_leavingInsight.message!,
                        style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                        () => _leavingInsight = AppLeavingInsight.none),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
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
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                        Text(_selectedTask?.title ?? 'Focus tự do',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Icon(
                      _pomRunning
                          ? Icons.lock_outline
                          : Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (!_pomRunning) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final currentSub = _selectedTask?.subject ??
                    AiCopilotService.preferredSubject();
                final tip = _getAiSubjectTip(currentSub);
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.purpleSoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.purple, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedTask != null
                              ? 'AI Mẹo: $tip'
                              : 'AI gợi ý: $tip (Ưu tiên $currentSub)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_selectedTask == null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            _setPomodoroMode(25, 5);
                            _togglePomodoro();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.purple,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Focus ngay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(activeColor),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                key: const ValueKey('pom-toggle'),
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
          // Đặc tả 5.6 / QA "complete early": xong việc thì kết thúc được,
          // không bắt ngồi đợi đồng hồ về 0. Nút chỉ có ở vòng focus — khi đang
          // nghỉ thì không có gì để "hoàn thành".
          if (!_isBreak) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const ValueKey('finish-session-early'),
              onPressed: _finishSessionEarly,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Hoàn thành'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(int focus, int brk, String label) {
    final sel = _focusMinutes == focus;
    return GestureDetector(
      onTap: () {
        FeedbackService.selection();
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

  /// Kỳ thi chính (đọc trực tiếp Storage để chart vẽ đường target).
  ExamModel? get _primaryExam {
    final id = StorageService.getPrimaryExamId();
    if (id == null) return null;
    final json = StorageService.getExamJson(id);
    if (json == null) return null;
    return ExamModel.fromJsonString(json);
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
          ScoreChartWidget(scores: _scores, primaryExam: _primaryExam),
          const SizedBox(height: 16),
          WeeklyChartWidget(
              entries: _timeline, onStartStudy: _startFirstSession),
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
          if (comparison.message != null)
            _analyticsRow(
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
    final totalMinutes =
        thisWeek.fold<int>(0, (sum, session) => sum + session.actualMinutes);
    final ratedFocus =
        thisWeek.where((session) => session.focus != null).toList();
    final ratedEffectiveness =
        thisWeek.where((session) => session.effectiveness != null).toList();
    final avgFocus = ratedFocus.isEmpty
        ? null
        : ratedFocus.fold<int>(0, (sum, session) => sum + session.focus!) /
            ratedFocus.length;
    final avgEffectiveness = ratedEffectiveness.isEmpty
        ? null
        : ratedEffectiveness.fold<int>(
                0, (sum, session) => sum + session.effectiveness!) /
            ratedEffectiveness.length;

    String? insight;
    if (ratedFocus.length >= 3 && avgFocus! < 3) {
      insight =
          'Focus trung bình đang thấp. Hãy thử phiên ngắn hơn hoặc nghỉ sớm hơn.';
    } else if (ratedEffectiveness.length >= 3 && avgEffectiveness! >= 4) {
      insight =
          'Bạn đang học hiệu quả trong tuần này. Duy trì nhịp hiện tại nhé!';
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
              _analyticsMetric(
                  avgFocus == null ? '—' : '${avgFocus.toStringAsFixed(1)}/5',
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
            // UX mục 11 "No study history": đủ 3 câu trả lời —
            // thiếu gì / vì sao quan trọng / làm gì tiếp theo.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgPageSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chưa có phiên học nào.',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  const Text(
                      'Bắt đầu phiên đầu tiên hôm nay — sau đó bạn sẽ thấy '
                      'giờ focus, số phiên và xu hướng tiến bộ của mình.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      key: const ValueKey('start-first-session'),
                      onPressed: _startFirstSession,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Bắt đầu học'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTab() {
    final entries = _timeline;
    final totalHours = totalHoursOf(entries);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          // Thống kê tổng.
          Row(
            children: [
              Expanded(
                child: _statCard('${totalHours.toStringAsFixed(1)}h',
                    'Tổng giờ học', AppColors.blue, Icons.access_time),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard('${entries.length}', 'Buổi học',
                    AppColors.primary, Icons.check_circle),
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
          if (entries.isEmpty)
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
                for (final entry in entries) _buildLogItem(entry),
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

  Widget _buildLogItem(StudyTimelineEntry entry) {
    final note = _entryNote(entry);
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteTimelineEntry(entry),
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
              child: Center(
                child: Text(
                  '${entry.hours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.subject,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (note != null && note.isNotEmpty)
                    Text(note,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${entry.date.day}/${entry.date.month}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreTab() {
    final summaries = summarizeMockScores(_scores);
    final avg = overallAverage(_scores);
    final recovery =
        buildScoreRecoveryPlan(_scores, daysLeft: _primaryExam?.daysLeft ?? 90);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          // Thống kê.
          Row(
            children: [
              Expanded(
                child: _statCard('${_scores.length}', 'Lần thi thử',
                    AppColors.blue, Icons.assignment_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(avg > 0 ? avg.toStringAsFixed(1) : '—',
                    'Điểm TB', AppColors.primary, Icons.stars_rounded),
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
                                  color:
                                      AppColors.purple.withValues(alpha: 0.3),
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
            if (recovery != null) ...[
              _buildRecoveryPlanCard(recovery),
              const SizedBox(height: 14),
            ],
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

  Widget _buildRecoveryPlanCard(ScoreRecoveryPlan plan) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.purpleSoft.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_graph_rounded, size: 17, color: AppColors.purple),
            SizedBox(width: 7),
            Text('Kế hoạch bù điểm',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.purple)),
          ]),
          const SizedBox(height: 7),
          Text(
              '${plan.reason} Gợi ý ${plan.sessionsPerWeek} phiên/tuần, ${plan.minutesPerSession} phút/phiên.',
              style: const TextStyle(fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _addRecoveryTask(plan),
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('Thêm phiên đầu tiên'),
            ),
          ),
        ]),
      );

  Future<void> _addRecoveryTask(ScoreRecoveryPlan plan) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final task = TodayTask(
      id: _uuid.v4(),
      title: plan.taskTitle,
      subject: AppSubjects.normalize(plan.subject),
      priority: 'high',
      estimateMinutes: plan.minutesPerSession,
      scheduledAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19),
    );
    final result = await TaskRepository.instance.createTaskIfMissing(task);
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isDuplicate
            ? 'Ngày mai đã có "${plan.taskTitle}" rồi.'
            : 'Không thêm được phiên bù điểm.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    AiRefreshService.notifyDataChanged();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã thêm phiên bù điểm vào lịch ngày mai.'),
      behavior: SnackBarBehavior.floating,
    ));
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
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  void _showAddScoreDialog() {
    final subjectCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final subjects = [
      '📐 Toán',
      '📖 Văn',
      '🇬🇧 Anh',
      '⚡ Lý',
      '🧪 Hóa',
      '🧬 Sinh'
    ];

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
            String subject =
                subjectCtrl.text.isEmpty ? '📐 Toán' : subjectCtrl.text;
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
                    decoration:
                        const InputDecoration(hintText: 'Điểm (0–10, VD: 7.5)'),
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
              final score =
                  double.tryParse(scoreCtrl.text.trim().replaceAll(',', '.'));
              final subject = subjectCtrl.text.trim();
              if (subject.isNotEmpty &&
                  score != null &&
                  score >= 0 &&
                  score <= 10) {
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
/// Năm mức đánh giá phiên học, chọn bằng 1 chạm (FE-3.3).
class _QuickRating {
  final String emoji;
  final String label;
  final int value;
  final int mood;
  final int focus;
  final int difficulty;
  final int understanding;
  final int effectiveness;

  /// Đã nắm được kiến thức hay còn cần củng cố — quyết định có gợi ý "Ôn lại
  /// ngày mai" hay không.
  final bool understood;

  const _QuickRating({
    required this.emoji,
    required this.label,
    required this.value,
    required this.mood,
    required this.focus,
    required this.difficulty,
    required this.understanding,
    required this.effectiveness,
    required this.understood,
  });
}

/// Phản hồi gom lại từ các điều khiển trong sheet, để hàm lưu không phải giữ
/// tham chiếu tới `StatefulBuilder`.
class _SessionFeedback {
  final int mood;
  final int focus;
  final int difficulty;
  final int understanding;
  final int effectiveness;
  final String note;

  const _SessionFeedback({
    required this.mood,
    required this.focus,
    required this.difficulty,
    required this.understanding,
    required this.effectiveness,
    required this.note,
  });
}

class _TactileCircleButton extends StatelessWidget {
  const _TactileCircleButton({
    super.key,
    required this.size,
    required this.color,
    required this.shadowColor,
    required this.child,
    required this.onTap,
    this.border,
  });

  final double size;
  final Color color;
  final Color shadowColor;
  final Border? border;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FeedbackService.light();
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
