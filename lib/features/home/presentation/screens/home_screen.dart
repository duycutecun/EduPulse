import 'dart:async';
import '../../../../core/utils/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_refresh_service.dart';
import '../../../../core/ai/study_rhythm.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../features/study/domain/distribute_day.dart';
import '../../../study/presentation/widgets/day_balance_sheet.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/skeleton_card.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../exams/domain/preset_exams.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/quick_add_parser.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../../../tasks/domain/models/task_state.dart';
import '../../../tasks/domain/repositories/task_repository.dart';
import '../../../tasks/presentation/widgets/delete_task_dialog.dart';
import '../../../tasks/presentation/widgets/reschedule_dialog.dart';
import '../../../tasks/presentation/widgets/split_task_dialog.dart';
import '../../../tasks/presentation/widgets/task_detail_sheet.dart';
import '../../../tasks/presentation/widgets/task_edit_sheet.dart';
import '../../../study/presentation/screens/ai_plan_screen.dart';
import '../widgets/home_header.dart';
import '../widgets/ai_actions_row.dart';
import '../widgets/today_mission_card.dart';
import '../widgets/daily_summary_card.dart';
import '../widgets/progress_insight_card.dart';
import '../../domain/services/today_service.dart';
import '../../../study/presentation/screens/study_page.dart';
import '../../../ai_coach/presentation/screens/flashcard_review_screen.dart';

class HomeScreen extends StatefulWidget {
  final ExamModel? primaryExam;
  final List<ExamModel> exams;
  final VoidCallback onExamTap;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenAiCoach;

  /// Mở AI Coach kèm sẵn câu hỏi — dùng khi học sinh bấm vào một gợi ý AI.
  /// Có thể null thì bấm gợi ý chỉ chuyển tab AI như thường.
  final ValueChanged<String>? onOpenAiCoachWith;
  final VoidCallback onOpenCalendar;

  /// Chuyển sang tab Tiến độ — thẻ "Nhận định tuần" dùng để mở chi tiết.
  final VoidCallback? onOpenProgress;
  final int streak;
  final bool isActive;
  final VoidCallback? onStreakChanged;

  /// Nguồn thời gian truyền xuống màn Tập trung, xem [StudyPage.clock].
  /// Mặc định là đồng hồ thật; test E2E truyền đồng hồ giả để chạy hết một
  /// vòng focus mà không phải chờ 25 phút thật.
  final DateTime Function() clock;

  const HomeScreen({
    super.key,
    this.clock = DateTime.now,
    required this.primaryExam,
    required this.exams,
    required this.onExamTap,
    required this.onOpenStudy,
    required this.onOpenAiCoach,
    required this.onOpenCalendar,
    this.onOpenProgress,
    required this.streak,
    this.isActive = true,
    this.onStreakChanged,
    this.onOpenAiCoachWith,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// G3-A — ngữ nghĩa phản hồi bằng BA kênh: icon + màu nền + chữ.
///
/// Trước đây mọi SnackBar đều nền xanh mặc định và chỉ có chữ: học sinh không
/// phân biệt được “đã xoá” với “không xoá được” nếu không đọc kỹ từng chữ.
/// Giờ mỗi loại có một icon riêng — người mù màu vẫn đọc được.
enum SnackKind {
  /// Hành động đã thành công.
  success(Icons.check_circle_rounded, AppColors.greenDark),

  /// Thông tin trung tính / thay đổi lịch.
  moved(Icons.event_rounded, AppColors.orangeDark),

  /// Xoá hẳn — cần nút Hoàn tác đi kèm.
  destructive(Icons.delete_rounded, AppColors.red),

  /// Không làm được vì lý do chủ quan (đã có dữ liệu, hết hạn…).
  warning(Icons.warning_rounded, AppColors.orangeDark),

  /// Lỗi hệ thống / thất bại.
  error(Icons.error_rounded, AppColors.redDark),

  /// Trạng thái trung tính, không có gì để ăn mừng.
  info(Icons.info_rounded, AppColors.blueDark);

  const SnackKind(this.icon, this.background);

  final IconData icon;
  final Color background;

  /// Nền snack đậm → chữ/nút luôn dùng trắng để đủ tương phản (WCAG AA).
  Color get onBackground => Colors.white;
}

/// Icon + chữ trong SnackBar. Tách riêng để phần trình bày không lẫn vào
/// logic của [HomeScreenState._showSnack].
class _SnackMessage extends StatelessWidget {
  const _SnackMessage({required this.message, required this.kind});

  final String message;
  final SnackKind kind;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(kind.icon, size: 20, color: kind.onBackground),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: Text(
            message,
            style: AppTokens.body.copyWith(
              color: kind.onBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  final ValueNotifier<Duration> _remainingNotifier =
      ValueNotifier<Duration>(Duration.zero);
  List<TodayTask> _tasks = [];
  List<TodayTask> _allTasks = [];

  /// G3-C: khung đầu tiên hiện khung xương thay vì màn trắng, rồi mới đổ
  /// dữ liệu thật vào. Bộ nhớ cục bộ đọc đồng bộ nên vốn không có “đang tải” —
  /// nhưng vẫn cần một khung hình: đọc + dựng cây widget đủ để thấy nháy
  /// trắng khi mở app lạnh trên máy yếu.
  bool _isLoadingTasks = true;

  /// Khoảng dừng ngắn để khung xương kịp hiện (xem chú thích ở `initState`).
  /// Không nhân tạo độ trễ vô tình: đây là đánh đổi có chủ đích giữa
  /// “mở app tức thì” và “không nháy màn trắng”.
  static const Duration _skeletonDelay = Duration(milliseconds: 300);

  /// Giữ tham chiếu để HUỶ được khi rời màn. Dùng `Future.delayed` là timer
  /// vẫn treo sau khi widget đã dispose — vừa rò rỉ vừa làm test báo “pending
  /// timer”; `mounted` chỉ chặn được `setState`, không huỷ được chính timer.
  Timer? _skeletonTimer;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    if (widget.isActive) {
      _startTimer();
    }
    _loadTasks();
    // Mọi thay đổi task — kể cả do AI, onboarding hay màn khác — đều báo qua
    // repository. Trước đây Home chỉ tự load lại lúc vào màn, nên task AI tạo
    // ở nền không hiện cho tới khi người dùng chuyển tab.
    TaskRepository.instance.revision.addListener(_onTasksChanged);
    // Phiên học vừa kết thúc (BE-3.3): tổng giờ học hôm nay phải nhảy ngay,
    // không chờ người dùng điều hướng. Thẻ tổng kết đọc `TodayService` trong
    // `build`, nên chỉ cần vẽ lại là số phút mới hiện.
    StudySessionRepository.instance.revision.addListener(_onSessionsChanged);
    // Khung xương giữ đúng một nhịp ngắn rồi mới thay bằng dữ liệu thật.
    //
    // Vì sao có độ trễ chứ không thay ngay ở khung hình đầu: một khung hình là
    // nhanh đến mức người dùng không kịp THẤY — thấy màn trắng rồi thấy nội
    // dung, tệ hơn là thấy một lần “đang tải” gọn gàng rồi nội dung hiện ra.
    // 300ms đủ để shimmer kịp xuất hiện mà vẫn tạo cảm giác mở app tức thì.
    _skeletonTimer = Timer(_skeletonDelay, () {
      if (!mounted) return;
      setState(() {
        _loadTasks();
        _isLoadingTasks = false;
      });
    });
  }

  void _onTasksChanged() {
    if (!mounted) return;
    setState(_loadTasks);
  }

  void _onSessionsChanged() {
    if (!mounted) return;
    setState(() {});
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
      // Chỉ thông báo khi giây thay đổi — tránh rebuild 60x/s khở động màn.
      if (rem.inSeconds != _remainingNotifier.value.inSeconds) {
        _remainingNotifier.value = rem;
      }
    } else if (_remainingNotifier.value.inSeconds != 0) {
      _remainingNotifier.value = Duration.zero;
    }
  }

  void _loadTasks() {
    _tasks = TodayService.getTodayTasksSorted();
    _allTasks = TaskRepository.instance.getAllTasks();
  }

  void _startStudyForTask(TodayTask task) {
    // G3-B: bắt đầu học = rung nhẹ, báo hiệu "sẵn sàng" mà không giật.
    FeedbackService.light();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyPage(
          initialTask: task,
          initialSubject: task.subject,
          initialMinutes: task.estimateMinutes,
          autoStart: true,
          clock: widget.clock,
          onStreakChanged: _notifyStreakChanged,
          onSessionCompleted: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    )
        .then((_) {
      _loadTasks();
      if (mounted) setState(() {});
    });
  }

  void _addTask(String title, String subject, String priority, int minutes,
      {String? topic,
      DateTime? deadline,
      String? note,
      String? goalId,
      List<String> subtasks = const [],
      String? recurrence,
      bool announce = true}) {
    final task = TodayTask(
      id: _uuid.v4(),
      title: title,
      subject: AppSubjects.normalize(subject),
      priority: priority,
      estimateMinutes: minutes,
      topic: topic,
      deadline: deadline,
      note: note,
      goalId: goalId,
      subtasks: subtasks,
      recurrence: recurrence,
    );
    // Mọi ghi task đi qua repository (BE-2.1): đóng dấu thời gian, phát tín
    // hiệu refresh UI, kích hoạt chu trình AI và hẹn sync cloud.
    TaskRepository.instance.createTask(task);
    setState(_loadTasks);
    // Đặc tả 5.3: sau khi tạo phải khẳng định rõ đã vào hôm nay, rồi đưa ra
    // lựa chọn tiếp theo — bắt đầu luôn, hay tiếp tục lập kế hoạch.
    if (!announce) return;
    _showSnack(
      'Đã thêm vào hôm nay',
      kind: SnackKind.success,
      primaryLabel: 'Bắt đầu ngay',
      onPrimary: () => _startStudyForTask(task),
    );
  }

  /// Banner "hôm nay hơi nặng" — chỉ hiện khi kế hoạch hôm nay vượt quỹ
  /// phút hợp lý và còn task có thể dời. Nhẹ nhàng, bấm mới mở đề xuất.
  Widget _buildDayBalanceBanner() {
    final proposals = proposeDayBalance(tasks: _allTasks, now: DateTime.now());
    if (proposals.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showDayBalanceSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.orangeLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.balance_rounded,
                size: 20, color: AppColors.orangeDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hôm nay hơi nặng — AI có cách chia lại cho vừa sức (${proposals.length} nhiệm vụ có thể dời)',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.orangeDark,
                    height: 1.35),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.orangeDark),
          ],
        ),
      ),
    );
  }

  /// Phân bố hợp lý: duyệt từng đề xuất dời task sang ngày còn quỹ.
  /// Dùng chung sheet với Quick Action "Điều chỉnh lịch" của AI Coach —
  /// rule engine, không gọi LLM (AI-24).
  Future<void> _showDayBalanceSheet() async {
    final moved = await showDayBalanceSheet(context, tasks: _allTasks);
    if (moved <= 0 || !mounted) return;
    setState(_loadTasks);
    _toast('Đã dời $moved nhiệm vụ — hôm nay nhẹ hơn rồi!',
        kind: SnackKind.moved);
  }

  /// Nhịp học cá nhân đề xuất thứ tự: môn khó + môn bị bỏ quên lên trước.
  /// Chỉ đổi THỨ TỰ trong bộ nhớ (lưu IDs theo thứ tự mới) — học sinh chốt.
  void _applySuggestedOrder() {
    final ordered = StudyRhythm.suggestOrder(_tasks);
    bool sameOrder = ordered.length == _tasks.length;
    if (sameOrder) {
      for (var i = 0; i < ordered.length; i++) {
        if (ordered[i].id != _tasks[i].id) {
          sameOrder = false;
          break;
        }
      }
    }
    if (sameOrder) {
      _toast('Thứ tự hiện tại đã hợp lý rồi — không cần đổi gì!',
          kind: SnackKind.info);
      return;
    }
    setState(() => _tasks = ordered);
    // Đổi thứ tự cũng là ghi dữ liệu → qua repository để không tụt chu trình AI.
    TaskRepository.instance.reorderTasks(ordered.map((t) => t.id).toList());
    FeedbackService.selection();
    _toast('Đã xếp môn cần sức nhất lên trước — theo nhịp học của bạn',
        kind: SnackKind.success);
  }

  Future<void> _toggleTask(TodayTask task) async {
    final result = await TaskRepository.instance.toggleTaskDone(task.id);
    if (result.failed) {
      _toast(result.error ?? 'Không cập nhật được nhiệm vụ',
          kind: SnackKind.error);
      return;
    }

    final nowDone = result.task?.isDone ?? task.isDone;
    setState(_loadTasks);
    if (!nowDone) return;

    FeedbackService.medium();
    StorageService.addXp(10);
    StorageService.registerStudyActivity(); // cập nhật streak theo ngày
    StorageService.addMascotBondExp(10); // gắn kết linh vật
    final doneTask = result.task;
    if (doneTask != null) _createNextRecurringTask(doneTask);
    _notifyStreakChanged();
    _toast(
      'Đã hoàn thành nhiệm vụ',
      kind: SnackKind.success,
      undo: () => TaskRepository.instance.toggleTaskDone(task.id),
    );
  }

  void _createNextRecurringTask(TodayTask completedTask) {
    final recurrence = completedTask.recurrence;
    if (recurrence != 'daily' && recurrence != 'weekly') return;
    final days = recurrence == 'daily' ? 1 : 7;
    final base = completedTask.scheduledAt ?? DateTime.now();
    final next = TodayTask(
      id: _uuid.v4(),
      title: completedTask.title,
      subject: completedTask.subject,
      topic: completedTask.topic,
      priority: completedTask.priority,
      estimateMinutes: completedTask.estimateMinutes,
      note: completedTask.note,
      goalId: completedTask.goalId,
      subtasks: completedTask.subtasks,
      recurrence: recurrence,
      scheduledAt:
          DateTime(base.year, base.month, base.day).add(Duration(days: days)),
    );
    // Task lặp phải sinh qua repository để không bỏ sót sync cloud + chu trình AI.
    TaskRepository.instance.createTask(next);
  }

  void _showSkipSheet(TodayTask task) {
    const reasons = [
      'Không đủ thời gian',
      'Quá khó',
      'Không cần thiết nữa',
      'Chưa có tài liệu',
      'Chưa có động lực',
      'Khác',
    ];
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bỏ qua nhiệm vụ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Lý do giúp EduPulse điều chỉnh kế hoạch tốt hơn.'),
              const SizedBox(height: 10),
              ...reasons.map((reason) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await TaskRepository.instance
                          .skipTask(task.id, reason: reason);
                      if (!mounted) return;
                      if (result.failed) {
                        _toast(result.error ?? 'Không bỏ qua được',
                            kind: SnackKind.error);
                        return;
                      }
                      setState(_loadTasks);
                      // Undo: bỏ qua có thể là nhấn nhầm, cần lối quay lại.
                      _toast(
                        'Đã bỏ qua: $reason',
                        kind: SnackKind.warning,
                        undo: () => TaskRepository.instance
                            .setTaskStatus(task.id, TaskStatus.scheduled),
                      );
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rescheduleTask(TodayTask task) async {
    if (!mounted) return;
    final picked = await RescheduleDialog.show(
      context,
      task: task,
      onSplitWithAi: () => _askAiToSplit(task),
      onSplit: () => _splitTask(task),
    );
    if (picked == null) {
      if (mounted) setState(_loadTasks);
      return;
    }
    await _applyReschedule(task, picked);
  }

  /// Ghi lịch mới — cập nhật chính task này, **không tạo bản sao** (FE-2.4).
  Future<void> _applyReschedule(TodayTask task, DateTime date) async {
    // G3-B: dời lịch là thao tác duyệt chọn → rung “tick” nhẹ, KHÔNG rung như
    // khi hoàn thành hay xoá (người dùng chưa mất dữ liệu).
    FeedbackService.selection();
    final result = await TaskRepository.instance.rescheduleTask(task.id, date);
    if (!mounted) return;
    if (result.failed) {
      _toast(result.error ?? 'Không dời lịch được', kind: SnackKind.error);
      return;
    }
    setState(_loadTasks);
    final moved = result.task ?? task;
    _toast('Đã dời "${task.title}" sang ngày mới', kind: SnackKind.moved);
    // Đặc tả 5.5: dời nhiều lần thì gợi ý thu nhỏ — đề nghị chứ không tự
    // sửa. AI must suggest, not silently modify.
    if (moved.rescheduleCount >= 3) {
      await _offerShrinkTask(moved);
    }
  }

  /// Hộp thoại sau lần dời thứ 3: giảm thời lượng / chia nhỏ / giữ nguyên.
  ///
  /// Không có lựa chọn nào được chọn sẵn và hành động nào cũng phải bấm mới
  /// chạy — người học hoàn toàn quyết định.
  Future<void> _offerShrinkTask(TodayTask task) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text('Bài này có vẻ hơi lớn',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Bạn đã dời "${task.title}" ${task.rescheduleCount} lần. '
          'Có thể giảm thời lượng hoặc chia nhỏ nhiệm vụ không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'shrink'),
            child: const Text('Giảm thời lượng'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'split'),
            child: const Text('Chia nhỏ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Giữ nguyên',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'split') {
      await _splitTask(TaskRepository.instance.getTaskById(task.id) ?? task);
      return;
    }

    // Giữ nguyên thứ tự ưu tiên: chia nhỏ giữ được nội dung, giảm thời lượng
    // chỉ khi bài đã ngắn mà vẫn quá tải.
    final current = TaskRepository.instance.getTaskById(task.id) ?? task;
    final minutes = (current.estimateMinutes / 2).round().clamp(10, 240);
    current.estimateMinutes = minutes;
    final updated = await TaskRepository.instance.updateTask(current);
    if (!mounted || updated.failed) {
      _toast(updated.error ?? 'Không đổi được thời lượng',
          kind: SnackKind.error);
      return;
    }
    setState(_loadTasks);
    _toast('Đã giảm còn $minutes phút', kind: SnackKind.success);
  }

  /// Gợi ý AI chia nhỏ bài học (FE-2.4 / AI-2.1) — có nguồn hiển thị, không
  /// tự tạo task rác (§10).
  void _askAiToSplit(TodayTask task) {
    final prompt = 'Bài học "${task.title}" môn ${task.subject} tôi đã dời '
        '${task.rescheduleCount} lần. Gợi ý chia thành các phần nhỏ hơn '
        'mỗi phần khoảng 25 phút, mỗi phần nêu rõ nội dung cụ thể.';
    widget.onOpenAiCoachWith?.call(prompt);
  }

  /// Chia nhỏ nhiệm vụ dài thành các phần 25–30 phút (FE-2.1/FE-2.2).
  ///
  /// Xem trước → xác nhận → ghi qua repository, rồi **luôn** kèm Hoàn tác.
  Future<void> _splitTask(TodayTask task) async {
    if (!mounted) return;
    final parts = await SplitTaskDialog.show(context, task: task);
    if (parts == null || !mounted) return;

    final split =
        await TaskRepository.instance.splitTask(task.id, parts: parts);
    if (!mounted) return;
    if (split.failed) {
      _toast(split.error ?? 'Không chia nhỏ được nhiệm vụ',
          kind: SnackKind.error);
      return;
    }
    setState(_loadTasks);
    _toast(
      'Đã chia "${task.title}" thành ${split.parts.length} phần',
      kind: SnackKind.success,
      undo: () => TaskRepository.instance.undoSplit(split),
    );
  }

  /// Xóa nhiệm vụ — **luôn xác nhận trước, luôn có Hoàn tác** (FE-2.5).
  Future<void> _deleteTask(TodayTask task) async {
    if (!mounted) return;
    final confirmed = await showConfirmDelete(context, task);
    if (confirmed != true || !mounted) return;
    // G3-B: xoá là hành động không hoàn lại được trong mắt người dùng cho tới
    // khi bấm “Hoàn tác” — rung NẶNG để họ biết mình vừa phá huỷ thứ gì đó.
    FeedbackService.heavy();

    try {
      final ref = await TaskRepository.instance.deleteTask(task.id);
      setState(_loadTasks);
      _toast(
        'Đã xóa "${task.title}"',
        kind: SnackKind.destructive,
        undo: () => TaskRepository.instance.restoreTask(ref),
      );
    } catch (e) {
      _toast('Không xóa được nhiệm vụ', kind: SnackKind.error);
    }
  }

  /// Mở form sửa nhiệm vụ (FE-2.3). `copyWith` giữ nguyên id/createdAt/lịch sử.
  Future<void> _editTask(TodayTask task) async {
    final result = await TaskEditSheet.show(context, initialTask: task);
    if (result == null || !mounted) return;
    if (result.isNew) {
      await TaskRepository.instance.createTask(result.task);
    } else {
      await TaskRepository.instance.updateTask(result.task);
    }
    if (!mounted) return;
    setState(_loadTasks);
    _toast(result.isNew ? 'Đã tạo nhiệm vụ' : 'Đã lưu thay đổi',
        kind: SnackKind.success);
  }

  /// Mở màn chi tiết nhiệm vụ (FE-2.2) — mọi hành động bên trong đều ghi qua
  /// repository, không có đường ghi tắt.
  Future<void> _openTaskDetail(TodayTask task) async {
    await TaskDetailSheet.show(
      context,
      task: task,
      onTaskUpdated: _toggleTask,
      onStartStudy: _startStudyForTask,
      onEdit: _editTask,
      onReschedule: _rescheduleTask,
      onDelete: _deleteTask,
      onSplit: _splitTask,
      onAskAi: (t) => _askAiAbout(t),
      onSplitWithAi: _askAiToSplit,
    );
    if (mounted) setState(_loadTasks);
  }

  void _askAiAbout(TodayTask task) {
    widget.onOpenAiCoachWith?.call(
      'Cho tôi xin tài liệu tham khảo và hướng dẫn học bài "${task.title}" '
      'môn ${AppSubjects.displayName(task.subject)}'
      '${task.topic == null ? '' : ', chủ đề ${task.topic}'}.',
    );
  }

  /// SnackBar thống nhất, hỗ trợ nút Hoàn tác (đặc tả FE-2.5).
  ///
  /// G3-A: `kind` quyết định icon + màu nền để phản hồi mang ngữ nghĩa —
  /// chỉ đọc màu cũng không đủ, nên luôn kèm ICON.
  void _toast(String message,
      {Future<void> Function()? undo, SnackKind kind = SnackKind.info}) {
    _showSnack(message, undo: undo, kind: kind);
  }

  /// SnackBar có hành động chính (ví dụ "Bắt đầu ngay" sau khi tạo nhiệm vụ).
  ///
  /// `SnackBar` chỉ cho một `action`, nên khi có hành động chính thì thao tác
  /// hoàn tác được bỏ qua — thao tác chính quan trọng hơn vào lúc này.
  void _showSnack(
    String message, {
    Future<void> Function()? undo,
    String? primaryLabel,
    VoidCallback? onPrimary,
    SnackKind kind = SnackKind.info,
  }) {
    if (!mounted) return;
    final hasPrimary = primaryLabel != null && onPrimary != null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: kind.background,
          content: _SnackMessage(message: message, kind: kind),
          duration: Duration(seconds: (undo == null && !hasPrimary) ? 3 : 6),
          behavior: SnackBarBehavior.floating,
          action: hasPrimary
              ? SnackBarAction(
                  label: primaryLabel,
                  textColor: kind.onBackground,
                  onPressed: () {
                    onPrimary();
                  },
                )
              : (undo == null
                  ? null
                  : SnackBarAction(
                      label: 'Hoàn tác',
                      textColor: kind.onBackground,
                      onPressed: () async {
                        await undo();
                        if (mounted) setState(_loadTasks);
                      },
                    )),
        ),
      );
  }

  /// MainShell đọc lại streak sau khi task thay đổi để header cập nhật 🔥.
  void _notifyStreakChanged() {
    if (StorageService.getString('last_study_date') == _todayKey()) {
      widget.onStreakChanged?.call();
    }
  }

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _skeletonTimer?.cancel();
    _remainingNotifier.dispose();
    TaskRepository.instance.revision.removeListener(_onTasksChanged);
    StudySessionRepository.instance.revision.removeListener(_onSessionsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = StorageService.getUserName();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header 1 hàng (~48px): lời chào không được đẩy nhiệm vụ xuống fold.
          HomeHeader(
            userName: userName,
            streak: widget.streak,
            mascotVisible: StorageService.getBool('mascot_enabled') ?? true,
          ),
          const SizedBox(height: 12),
          DailySummaryCard(
            summary: TodayService.getDailySummary(),
            primaryExam: widget.primaryExam,
            onExamTap: widget.onExamTap,
            // Đồng hồ đếm ngược tự chạy mỗi giây qua notifier, không rebuild
            // cả cây widget Home.
            remainingListenable: _remainingNotifier,
          ),
          const SizedBox(height: 14),
          // **Nhiệm vụ hôm nay lên ngay** — nguyên tắc "Mở app là biết mình
          // phải làm gì": thứ người học cần thấy đầu tiên là việc cần làm,
          // không phải nhận định AI hay công cụ.
          if (_isLoadingTasks)
            const SkeletonTaskList()
          else
            TodayMissionCard(
              tasks: _tasks,
              onAddTask: _showAddTaskDialog,
              onToggle: _toggleTask,
              onDelete: _deleteTask,
              onSkip: _showSkipSheet,
              onReschedule: _rescheduleTask,
              onSplit: _splitTask,
              onAddSample: _showSampleTasksSheet,
              onOpenAiPlan: _openAiPlanScreen,
              onQuickAdd: _showQuickAddSheet,
              onSuggestOrder: _applySuggestedOrder,
              onStartStudy: _startStudyForTask,
              onEdit: _editTask,
              onOpenDetail: _openTaskDetail,
            ),
          const SizedBox(height: 14),
          // Nhận định tiến độ tuần (AI-5.1): số liệu thật, offline-safe.
          // Đặt SAU nhiệm vụ — nó là thông tin bổ sung, không phải việc cần làm.
          ProgressInsightCard(
            onOpenProgress: widget.onOpenProgress,
            onAskAi: widget.onOpenAiCoachWith,
          ),
          const SizedBox(height: 14),
          // Gộp 3 block AI cũ (Copilot hub / Quick action / Readiness) thành
          // **một** hàng hành động: 3 card AI riêng biệt cạnh tranh chỗ dưới
          // fold và làm loãng điểm nhấn (U-03).
          AiActionsRow(
            onOpenStudy: widget.onOpenStudy,
            onOpenAiChat: widget.onOpenAiCoach,
            onOpenAiChatWith: widget.onOpenAiCoachWith,
            onOpenAiPlan: _openAiPlanScreen,
            onOpenCalendar: widget.onOpenCalendar,
            onTasksChanged: _loadTasks,
            onStreakChanged: _notifyStreakChanged,
            onOpenFlashcards: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const FlashcardReviewScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          // Exam Mode (đặc tả mục 39–40): revision ≤7 ngày, exam day và post-exam.
          ..._examModeWidgets(),
          const SizedBox(height: 14),
          _buildDayBalanceBanner(),
        ],
      ),
    );
  }

  /// Các widget Exam Mode theo giai đoạn của kỳ thi chính (đặc tả mục 39–40):
  /// - Revision (≤7 ngày): banner ôn tập trọng tâm + checklist chuẩn bị.
  /// - Exam day: thông tin thi + checklist, KHÔNG hiển thị nhiều task.
  /// - Post-exam: tổng kết nhẹ nhàng + hỏi tạo goal mới, không ngôn ngữ tiêu cực.
  List<Widget> _examModeWidgets() {
    final exam = widget.primaryExam;
    if (exam == null) return const [];
    switch (exam.examPhase) {
      case ExamPhase.revision:
        return [const _RevisionModeCard()];
      case ExamPhase.examDay:
        return [
          const _ExamDayCard(),
          const SizedBox(height: 14),
          _TodayMissionCardCompact(
            tasks: _tasks.take(3).toList(),
            onToggle: _toggleTask,
          ),
        ];
      case ExamPhase.postExam:
        final reached = exam.postExamResult;
        return [
          _PostExamCard(
            exam: exam,
            reachedTarget: reached,
            onOpenExam: widget.onExamTap,
            onScoreSaved: () => setState(() {}),
          ),
        ];
      case ExamPhase.normal:
        return const [];
    }
  }

  /// Quick Add bằng ngôn ngữ tự nhiên (đặc tả mục 25): parse offline →
  /// preview → user xác nhận. Không tự thêm task khi chưa confirm.
  /// Mở màn "Lộ trình AI" — nhánh "AI lập kế hoạch" của empty state (đặc tả 11).
  void _openAiPlanScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiPlanScreen()),
    );
  }

  void _showQuickAddSheet() {
    final controller = TextEditingController();
    showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final result = parseQuickAdd(controller.text, DateTime.now());
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thêm nhanh — viết tự nhiên',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('VD: "Mai 19h học toán hàm số 45 phút"',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Nhập nhiệm vụ của bạn…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (result != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.subject} ${result.title}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📅 ${result.scheduledAt.day}/${result.scheduledAt.month}'
                          ' • ⏰ ${result.scheduledAt.hour.toString().padLeft(2, '0')}:${result.scheduledAt.minute.toString().padLeft(2, '0')}'
                          ' • ⏱ ${result.minutes} phút'
                          ' • ${result.priority == 'high' ? '🔥 Quan trọng' : result.priority == 'low' ? '🌱 Nhẹ' : '⭐ Vừa'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _addTask(
                          result.title,
                          result.subject,
                          result.priority,
                          result.minutes,
                        );
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Thêm nhiệm vụ'),
                    ),
                  ),
                ] else if (controller.text.trim().isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Chưa nhận ra đủ dữ kiện — thêm giờ hoặc thời lượng nhé.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddTaskDialog(
        onAdd: _addTask,
        exams: widget.exams,
        primaryExamId: widget.primaryExam?.id,
      ),
    );
  }

  /// Sheet thêm nhanh nhiệm vụ mẫu theo kỳ thi mục tiêu đang ghim.
  void _showSampleTasksSheet() {
    final exam = widget.primaryExam;
    PresetExam? preset;
    if (exam != null) {
      for (final p in PresetExams.all) {
        if (exam.id == p.id ||
            exam.name.toLowerCase().contains(p.name.toLowerCase()) ||
            p.name.toLowerCase().contains(exam.name.toLowerCase())) {
          preset = p;
          break;
        }
      }
    }
    final samples = preset?.sampleTasks ?? PresetExams.all.first.sampleTasks;
    final presetName = preset?.name ?? PresetExams.all.first.name;

    showAppBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Nhiệm vụ mẫu — $presetName',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Chạm để thêm vào nhiệm vụ hôm nay',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            ...samples.map((t) {
              final added = _tasks.any(
                  (task) => task.title.toLowerCase() == t.title.toLowerCase());
              return GestureDetector(
                onTap: added
                    ? null
                    : () {
                        _addTask(t.title, t.subject, t.priority, t.minutes,
                            announce: false);
                        Navigator.pop(ctx);
                      },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        added
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 18,
                        color: added ? AppColors.primary : AppColors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.subject} ${t.title}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: added
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '⏱ ${t.minutes} phút',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        added ? 'Đã thêm' : 'Thêm',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: added ? AppColors.primary : AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

/// Banner chế độ ôn tập khi còn ≤7 ngày thi (đặc tả mục 39 — 7 ngày trước thi):
/// ưu tiên weakness, high-impact topics và review, giảm workload không cần thiết.
class _RevisionModeCard extends StatelessWidget {
  const _RevisionModeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.orangeSoft,
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('📚', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chế độ ôn tập đang bật',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ưu tiên ôn điểm yếu và nội dung quan trọng. Giảm bớt nhiệm vụ mới không cần thiết.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ ngày thi (đặc tả mục 39 — Exam Day): thông tin kỳ thi + checklist chuẩn bị,
/// không hiển thị quá nhiều task để giữ Home nhẹ nhàng.
class _ExamDayCard extends StatelessWidget {
  const _ExamDayCard();

  @override
  Widget build(BuildContext context) {
    const checklist = [
      'CMND/CCCD + giấy báo dự thi',
      'Bút, thước, máy tính được phép',
      'Bình nước + đồ ăn nhẹ',
      'Đến sớm trước giờ thi 30 phút',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🍀', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Hôm nay là ngày thi — làm tốt nhé!',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chỉ cần tập trung ôn nhẹ và chuẩn bị. EduPulse tạm ẩn danh sách nhiệm vụ dài.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ...checklist.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Phiên bản rút gọn của danh sách nhiệm vụ cho ngày thi (tối đa 3 task).
class _TodayMissionCardCompact extends StatelessWidget {
  const _TodayMissionCardCompact({
    required this.tasks,
    required this.onToggle,
  });

  final List<TodayTask> tasks;
  final ValueChanged<TodayTask> onToggle;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ôn nhẹ hôm nay (tùy chọn)',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ...tasks.map(
            (task) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onToggle(task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      task.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: task.isDone ? AppColors.primary : AppColors.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '⏱ ${task.estimateMinutes}p',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ sau kỳ thi (đặc tả mục 40): nhẹ nhàng, không tiêu cực, giữ lịch sử,
/// gợi ý tạo goal mới hoặc xem lại kỳ thi đã qua. Có **nhập điểm nhanh**
/// ngay tại card (mục 40: "Nếu có điểm: Update goal, Compare target,
/// Analyze, Suggest next step").
class _PostExamCard extends StatelessWidget {
  const _PostExamCard({
    required this.exam,
    required this.reachedTarget,
    required this.onOpenExam,
    required this.onScoreSaved,
  });

  final ExamModel exam;
  final bool? reachedTarget; // null = chưa đủ dữ liệu kết luận
  final VoidCallback onOpenExam;
  final VoidCallback onScoreSaved;

  Future<void> _quickScoreEntry(BuildContext context) async {
    final controller = TextEditingController(
      text: exam.currentScore?.toStringAsFixed(1) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nhập điểm của bạn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              exam.targetScore != null
                  ? 'Mục tiêu của bạn: ${exam.targetScore!.toStringAsFixed(1)} điểm'
                  : 'Chưa có mục tiêu điểm — nhập để lưu lịch sử.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'VD: 8.5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (parsed == null || parsed < 0 || parsed > 10) return;
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Lưu điểm'),
          ),
        ],
      ),
    );
    if (value == null) return;

    // Cập nhật điểm hiện tại của kỳ thi (lưu lịch sử, mục 40).
    final updated = exam.copyWithCurrent(value);
    StorageService.setExamJson(updated.id, updated.toJsonString());

    // Ghi thêm MockScore để biểu đồ điểm có dữ liệu (mục 41).
    final score = MockScore(
      id: const Uuid().v4(),
      date: DateTime.now(),
      subject: updated.name,
      score: value,
      note: 'Điểm ${updated.name}',
    );
    StorageService.setMockScoreJson(score.id, score.toJsonString());
    final ids = StorageService.getMockScoreIds()..add(score.id);
    StorageService.setMockScoreIds(ids);

    // Chu trình AI: điểm mới thay đổi readiness → bản tin/gợi ý tính lại.
    AiRefreshService.notifyDataChanged();

    onScoreSaved();
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = reachedTarget != null;
    final title = reachedTarget == true
        ? 'Chúc mừng bạn đã hoàn thành ${exam.name}! 🎉'
        : reachedTarget == false
            ? '${exam.name} đã kết thúc. Cố gắng của bạn đều đáng giá.'
            : '${exam.name} đã kết thúc — đang chờ kết quả';

    final subtitle = reachedTarget == true
        ? 'Bạn đã đạt mục tiêu điểm. Muốn xem lại phân tích quá trình học không?'
        : reachedTarget == false
            ? 'Xem phân tích khoảng cách điểm để điều chỉnh kế hoạch tiếp theo nhé.'
            : 'Khi có điểm, cập nhật ở tab Mục tiêu để EduPulse phân tích giúp bạn.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
          Text(
            title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
          ),
          if (hasResult) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: reachedTarget == true
                    ? AppColors.greenSoft
                    : AppColors.blueLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Điểm hiện tại ${exam.currentScore!.toStringAsFixed(1)} • Mục tiêu ${exam.targetScore!.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: reachedTarget == true
                      ? AppColors.primaryDark
                      : AppColors.blueDark,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Nhập điểm nhanh — luôn hiện khi chưa đủ target + current.
          if (!hasResult)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () => _quickScoreEntry(context),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Đã có điểm? Nhập ngay'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenExam,
                  child: const Text('Xem kỳ thi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Kỳ thi mới sẽ được tạo ở tab Mục tiêu → thêm kỳ thi.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Tạo mục tiêu mới'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({
    required this.onAdd,
    required this.exams,
    this.primaryExamId,
  });

  final void Function(
      String title, String subject, String priority, int minutes,
      {String? topic,
      DateTime? deadline,
      String? note,
      String? goalId,
      List<String> subtasks,
      String? recurrence}) onAdd;
  final List<ExamModel> exams;
  final String? primaryExamId;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _subtasksCtrl = TextEditingController();
  String _subject = AppSubjects.toan.name;
  String _priority = 'medium';
  int _minutes = 45;
  DateTime? _deadline;
  String? _goalId;
  String? _recurrence;
  final _durations = [15, 30, 45, 60, 90];
  final Map<String, String> _priorities = const {
    'high': '🔥 Quan trọng',
    'medium': '⭐ Vừa',
    'low': '🌱 Nhẹ',
  };

  @override
  void initState() {
    super.initState();
    _goalId = widget.primaryExamId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _topicCtrl.dispose();
    _noteCtrl.dispose();
    _subtasksCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      FeedbackService.vibrate();
      return;
    }
    widget.onAdd(
      title,
      _subject,
      _priority,
      _minutes,
      topic: _topicCtrl.text.trim().isEmpty ? null : _topicCtrl.text.trim(),
      deadline: _deadline,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      goalId: _goalId,
      subtasks: _subtasksCtrl.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      recurrence: _recurrence,
    );
    Navigator.pop(context);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn hạn hoàn thành',
    );
    if (selected != null && mounted) setState(() => _deadline = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            const SizedBox(height: 10),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                hintText: 'Chủ đề (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Chọn môn:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppSubjects.all.map((subject) {
                final sel = _subject == subject.name;
                final color = subject.color;
                return GestureDetector(
                  onTap: () => setState(() => _subject = subject.name),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? color : AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? color : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      subject.plainName,
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
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_deadline == null
                  ? 'Thêm hạn hoàn thành'
                  : 'Hạn: ${_deadline!.day.toString().padLeft(2, '0')}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.year}'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ghi chú (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subtasksCtrl,
              decoration: const InputDecoration(
                hintText: 'Việc nhỏ (ngăn cách bằng dấu phẩy)',
              ),
            ),
            if (widget.exams.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _goalId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Kỳ thi / Mục tiêu'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Chưa gắn mục tiêu'),
                  ),
                  ...widget.exams.map(
                    (exam) => DropdownMenuItem<String?>(
                      value: exam.id,
                      child: Text(exam.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _goalId = value),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _recurrence,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lặp lại'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Không lặp lại')),
                DropdownMenuItem(value: 'daily', child: Text('Mỗi ngày')),
                DropdownMenuItem(value: 'weekly', child: Text('Mỗi tuần')),
              ],
              onChanged: (value) => setState(() => _recurrence = value),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            const SizedBox(height: 12),
            const Text('Mức ưu tiên:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _priorities.entries.map((e) {
                final sel = _priority == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _priority = e.key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.orange : AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.orange : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      e.value,
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
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
