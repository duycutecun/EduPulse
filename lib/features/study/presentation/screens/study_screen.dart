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
import '../../../../core/gamification/achievement_service.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/notifications/adaptive_policy.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/mascot_avatar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/stat_card.dart';
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
import '../widgets/score_tab_view.dart';
import '../widgets/ai_post_focus_sheet.dart';
import '../widgets/study_entry_dialogs.dart';
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

  void _addScore(String subject, double score, String? note,
      {String? topic}) {
    final s = MockScore(
      id: _uuid.v4(),
      date: DateTime.now(),
      subject: subject,
      score: score,
      note: note,
      topic: (topic == null || topic.trim().isEmpty) ? null : topic.trim(),
    );
    StorageService.setMockScoreJson(s.id, s.toJsonString());
    final ids = StorageService.getMockScoreIds()..add(s.id);
    StorageService.setMockScoreIds(ids);
    setState(() => _scores.insert(0, s));
    _celebrateNewAchievements();
  }

  void _deleteScore(MockScore s) {
    StorageService.removeMockScore(s.id);
    setState(() => _scores.remove(s));
  }

  /// Xét huy hiệu sau khi ghi điểm/phiên học (P2 — gamification) và báo toast
  /// huy hiệu mới. Dùng ScaffoldMessenger gốc để không phụ thuộc sheet đang mở.
  void _celebrateNewAchievements() {
    final newly = AchievementService.instance.reconcile();
    if (newly.isEmpty || !mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('${newly.first.emoji} Huy hiệu mới: ${newly.first.title}'),
        duration: const Duration(seconds: 2),
      ));
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
    showAiPostFocusSheet(
      context: context,
      session: session,
      hasSelectedTask: _selectedTask != null,
      onSave: _saveSessionFeedback,
      onCompleteAndGo: _completeTaskAndGoToday,
      onScheduleReview: _scheduleReviewTaskTomorrow,
      onQuickNote: _showQuickNoteDialog,
      onTasksChanged: () {
        if (mounted) setState(_loadTasks);
      },
    );
  }

  /// Lưu phản hồi của phiên vừa học xong.
  ///
  /// [mood]…[effectiveness] lấy từ đánh giá 1 chạm hoặc từ các thanh chi tiết
  /// mà người dùng đã chỉnh; ghi chú rỗng thì không ghi (`null`) để phân biệt
  /// "không đánh giá" với "đánh giá rỗng".
  Future<void> _saveSessionFeedback(
    BuildContext sheetContext,
    StudySession session,
    SessionFeedback feedback,
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
    // Đánh giá (focus…) vừa được ghi → có thể mở khoá huy hiệu "Tâm trí sâu".
    _celebrateNewAchievements();
  }

  /// Đường 1 chạm của FE-3.3: lưu phản hồi → đánh dấu nhiệm vụ hoàn thành →
  /// về màn Hôm nay.
  ///
  /// Việc đánh dấu hoàn thành đi qua [TaskRepository] (Single Write Path) để
  /// state machine, streak và Home đều nhận đúng một lần ghi.
  Future<void> _completeTaskAndGoToday(
    BuildContext sheetContext,
    StudySession session,
    SessionFeedback feedback,
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
                // Vùng rỗng trong sheet dùng bản compact của khuôn chung:
                // một hàng gọn thay vì khối lớn chiếm chỗ.
                const EmptyStatePanel(
                  compact: true,
                  icon: Icons.playlist_add_check_rounded,
                  title: 'Chưa có nhiệm vụ chưa hoàn thành.',
                  description: 'Thêm nhiệm vụ ở tab Hôm nay rồi quay lại đây '
                      'để gắn việc với phiên học.',
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
            // thiếu gì / vì sao quan trọng / làm gì tiếp theo — qua khuôn
            // EmptyStatePanel dùng chung với các vùng rỗng khác.
            EmptyStatePanel(
              icon: Icons.timer_outlined,
              title: 'Chưa có phiên học nào.',
              description: 'Bắt đầu phiên đầu tiên hôm nay — sau đó bạn sẽ '
                  'thấy giờ focus, số phiên và xu hướng tiến bộ của mình.',
              actionLabel: 'Bắt đầu học',
              actionKey: const ValueKey('start-first-session'),
              actionIcon: Icons.play_arrow_rounded,
              onAction: _startFirstSession,
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
            const EmptyStatePanel(
              icon: Icons.menu_book_rounded,
              title: 'Chưa có nhật ký.',
              description: 'Ghi lại vài dòng sau mỗi phiên học để thấy mình '
                  'đã đi được bao xa.',
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

  /// Thẻ số liệu cho tab Nhật ký / Điểm thi.
  ///
  /// Trả về `Container` (KHÔNG tự bọc `Expanded`): mọi chỗ gọi đều đã đặt nó
  /// trong một `Expanded` của `Row`. Bọc thêm một lớp `Expanded` nữa khiến hai
  /// ParentDataWidget cùng ghi parent data lên một RenderObject — mở tab Nhật
  /// ký là Flutter ném lỗi ngay, và trên máy thật là một khung hình đỏ.
  Widget _statCard(String val, String label, Color color, IconData icon) {
    return StatCard(value: val, label: label, color: color, icon: icon);
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
    // Lát cắt trình bày đã tách sang `ScoreTabView` (kế hoạch §6.2) — màn cha
    // giữ state và các thao tác ghi, widget con chỉ nhận dữ liệu + callback.
    return ScoreTabView(
      scores: _scores,
      daysLeft: _primaryExam?.daysLeft ?? 90,
      onAddScore: _showAddScoreDialog,
      onAnalyze: _analyzeScoresWithAi,
      onAddRecoveryTask: _addRecoveryTask,
      onScheduleTopicReview: _scheduleTopicReview,
      onDeleteScore: _deleteScore,
    );
  }

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

  /// Thẻ chủ đề yếu: đã tách sang `ScoreTabView` cùng lát cắt Điểm thi (§6.2).
  /// Đặt một nhiệm vụ ôn tập cho đúng chủ đề yếu (mang theo `topic` để lần sau
  /// vẫn nhận diện được ở tầng phân tích).
  Future<void> _scheduleTopicReview(String subject, String topic) async {
    final sub = subject.trim().isEmpty ? 'Tổng hợp' : subject.trim();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final task = TodayTask(
      id: _uuid.v4(),
      title: 'Ôn chủ đề: $topic',
      subject: AppSubjects.normalize(sub),
      topic: topic,
      priority: 'high',
      estimateMinutes: 25,
      scheduledAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 0),
    );
    final result = await TaskRepository.instance.createTaskIfMissing(task);
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isDuplicate
            ? 'Ngày mai đã có nhiệm vụ "Ôn chủ đề: $topic" rồi.'
            : 'Không thêm được nhiệm vụ ôn chủ đề.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    AiRefreshService.notifyDataChanged();
    _loadTasks();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã thêm "Ôn chủ đề: $topic" vào lịch ngày mai!'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showAddScoreDialog() {
    showAddScoreDialog(
      context,
      onAdd: (subject, score, note, topic) {
        _addScore(subject, score, note, topic: topic);
      },
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

    // Gọi model một lần cho mỗi lần mở sheet. Giữ future trong biến ngoài
    // `builder` để nút "Thử lại" gọi lại được mà không khiến FutureBuilder tự
    // tạo future mới ở mỗi rebuild (mỗi rebuild = một lần gọi model).
    Future<String> request() => AiRouter.chat(
          model: AIModel.defaultModel,
          history: const [],
          userMessage: prompt,
          searchWeb: false,
        );

    var pending = request();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
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
                    future: pending,
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        // Cùng khuôn tải với các màn khác — không spinner trần.
                        return const LoadingStateView(
                            message: 'AI đang phân tích…');
                      }
                      if (snap.hasError) {
                        // Nói việc cần làm thay vì đổ nguyên văn exception cho
                        // học sinh, và luôn để lại đường thử lại (UX 12/AI-30).
                        return ErrorStateView(
                          title: 'Chưa phân tích được',
                          message: 'Không phân tích được điểm lúc này. Kiểm tra '
                              'kết nối mạng rồi thử lại nhé.',
                          onRetry: () =>
                              setSheetState(() => pending = request()),
                        );
                      }
                      return SingleChildScrollView(
                        child: Text(
                          snap.data ?? '',
                          style: const TextStyle(
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
      ),
    );
  }

  void _showAddLogDialog() {
    showAddLogDialog(
      context,
      onAdd: (subject, hours, note) {
        _addLog(subject, hours, note);
      },
    );
  }
}

/// Nút bấm hình tròn với độ lún vật lý xúc giác 3D (Duolingo tactile press).
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
