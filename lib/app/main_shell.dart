import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'deep_link_handler.dart';
import '../../../../core/utils/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/migration/data_migration.dart';
import '../core/pwa/pwa_service.dart';
import '../core/sync/backup_service.dart';
import '../core/sync/sync_state.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/storage_service.dart';
import '../core/utils/supabase_service.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/exams/domain/exam_repository.dart';
import '../features/exams/domain/models/exam_model.dart';
import '../features/exams/presentation/screens/exams_page.dart';
import '../features/ai_coach/presentation/screens/ai_coach_screen.dart';
import '../features/progress/presentation/screens/progress_screen.dart';
import '../features/study/presentation/screens/study_page.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/account/presentation/screens/account_screen.dart';
import '../core/notifications/notification_tap_handler.dart';
import '../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../features/notes/presentation/screens/notes_screen.dart';
import 'desktop_sidebar.dart';
import 'desktop_aux_column.dart';
import 'tab_chrome.dart';
import 'widgets/shell_banners.dart';

class MainShellScreen extends StatefulWidget {
  /// Nguồn thời gian dùng cho các màn học tập (Home → Tập trung, Tập trung từ
  /// sidebar). Mặc định là đồng hồ thật; test E2E truyền đồng hồ giả.
  final DateTime Function() clock;

  /// ID task từ deep-link (nếu có). Nếu null, không làm gì thêm.
  final String? deepLinkTaskId;

  const MainShellScreen({
    super.key,
    this.clock = DateTime.now,
    this.deepLinkTaskId,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  List<ExamModel> _exams = [];
  int _streak = 0;

  // Lazy tab: các tab chỉ được tạo khi user mở lần đầu tiên, sau đó giữ nguyên trong IndexedStack.
  final List<bool> _visited = List.filled(4, false);
  Widget? _cachedAi;
  Widget? _cachedStudy;
  Widget? _cachedAccount;

  /// Khoá để gọi được [AiCoachScreenState.sendPrompt] — tab AI được giữ trong
  /// IndexedStack nên screen tồn tại xuyên suốt, không cần tạo lại.
  final _aiCoachKey = GlobalKey<AiCoachScreenState>();

  bool _sidebarCollapsed = SidebarPreference.isCollapsed;

  /// Tablet (< desktop): sidebar rail thu gọn mặc định, nhưng vẫn cho phép mở
  /// rộng — trạng thái này tách khỏi preference của desktop.
  bool _tabletSidebarExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _visited[0] = true;
    _loadInitialData();
    // Điều hướng khi người dùng nhấn thông báo (P3): đọc payload đã lưu và mở
    // đúng đích (Home / Bảng vàng). Hoãn tới sau frame đầu để Navigator sẵn sàng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkNotificationTap();
    });
    // Notify user khi migration rollback (mục 42) — SnackBar nhẹ nhàng,
    // khẳng định dữ liệu an toàn, không gây lo lắng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final report = DataMigration.lastReport;
      if (report == null || !report.rolledBack || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(report.userMessage ??
            'Đã khôi phục dữ liệu nguyên trạng — không có gì bị mất.'),
        backgroundColor: AppColors.orangeDark,
      ));
    });
    PwaService.onlineNotifier.addListener(_onNetworkChanged);
    // Kỳ thi có thể đổi từ màn Tiến độ / onboarding — nghe repository để Home
    // luôn thấy bản mới nhất thay vì giữ bản sao cũ trong state.
    ExamRepository.instance.revision.addListener(_loadInitialData);
    SyncStateService.updateConnectivity(isOnline: PwaService.isOnline);
    // Keyboard navigation desktop (đặc tả mục 21): Ctrl+1/2/3 đổi tab,
    // Ctrl+B thu gọn/mở sidebar.
    ServicesBinding.instance.keyboard.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (!ctrl) return false;
    if (event.logicalKey == LogicalKeyboardKey.digit1) {
      _switchTab(0);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit2) {
      _switchTab(1);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit3) {
      _switchTab(2);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit4) {
      _switchTab(3);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyB &&
        isDesktopWidth(context)) {
      setState(() {
        _sidebarCollapsed = !_sidebarCollapsed;
        SidebarPreference.setCollapsed(_sidebarCollapsed);
      });
      return true;
    }
    return false;
  }

  void _onNetworkChanged() {
    SyncStateService.updateConnectivity(isOnline: PwaService.isOnline);
    if (PwaService.isOnline && SupabaseService.isConfigured) {
      // Qua SyncStateService để banner/chip phản ánh Syncing → Synced.
      SyncStateService.syncInBackground();
    }
    // Vừa có mạng lại: đẩy ngay thay đổi gẹn lúc offline, không bắt người
    // dùng chờ tới chu kỳ 20 giây.
    if (PwaService.isOnline) BackupService.notifyLocalChange();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PwaService.onlineNotifier.removeListener(_onNetworkChanged);
    ExamRepository.instance.revision.removeListener(_loadInitialData);
    ServicesBinding.instance.keyboard.removeHandler(_handleKey);
    super.dispose();
  }

  /// App chuyển nền = sắp bị treo hoặc giết.
  ///
  /// Đẩy ngay thay đổi đang chờ debounce: timer 2 giây không sống sót qua
  /// lúc app bị treo, nên không làm bước này thì sửa xong tắt app là mất.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      ExamRepository.instance.flushNow();
      TaskRepository.instance.flushNow();
      // Sao lưu toàn diện cũng phải đẩy ngay: timer poll/debounce không sống
      // sót qua lúc app bị treo.
      BackupService.flush();
      return;
    }
    // Quay lại từ nền: hỏi cloud ngay xem máy khác có ghi gì mới không thay vì
    // chờ tới chu kỳ 20 giây.
    if (state == AppLifecycleState.resumed) {
      BackupService.notifyLocalChange();
    }
  }

  void _loadInitialData() {
    if (!mounted) return;
    // Mọi đọc/ghi kỳ thi đi qua [ExamRepository] — một nguồn sự thật duy nhất.
    _exams = ExamRepository.instance.getAll();
    _streak = StorageService.getStreak();
    setState(() {});

    // Xử lý deep-link task (nếu có). HOÃN qua sau frame đầu: mở bottom sheet
    // ngay trong initState sẽ đụng Navigator lúc đang build (crash khởi động
    // nguội từ link /task/<id>).
    final deepLinkTaskId = widget.deepLinkTaskId;
    if (deepLinkTaskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleDeepLinkTask(deepLinkTaskId);
      });
    }
  }

  void _handleDeepLinkTask(String taskId) {
    // Gọi handler để mở chi tiết task.
    DeepLinkHandler.openTaskDetail(
      context,
      taskId: taskId,
    );
  }

  /// Xử lý payload từ thông báo (P3). Chỉ chạy khi có payload chờ; mở xong thì
  /// xoá để không điều hướng lặp lại mỗi lần rebuild.
  void _checkNotificationTap() {
    final payload = NotificationTapHandler.payload;
    if (payload == null || payload.isEmpty) return;
    if (!mounted) return;
    NotificationTapHandler.payload = null;
    switch (payload) {
      case 'home':
        _switchTab(0);
      case 'leaderboard':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        );
      default:
        break;
    }
  }

  void _setPrimaryExam(ExamModel exam) {
    // Repository tự bắn revision → _loadInitialData đọc lại và vẽ.
    ExamRepository.instance.setPrimary(exam.id);
  }

  void _addExam(ExamModel exam) {
    ExamRepository.instance.save(exam);
  }

  void _deleteExam(String id) {
    ExamRepository.instance.delete(id);
  }

  void _updateExam(ExamModel exam) {
    ExamRepository.instance.save(exam);
  }

  /// Kỳ thi chính theo đặc tả (mục 9.1, 40): ưu tiên kỳ thi đã ghim, tự chuyển
  /// sang kỳ thi sắp tới gần nhất khi kỳ thi ghim đã qua. Logic nằm ở
  /// [ExamRepository] để cả app dùng chung một quy tắc.
  ExamModel? get _effectivePrimaryExam => ExamRepository.instance.primaryExam;

  /// Đọc lại streak từ storage (gọi khi task hoàn thành / Pomodoro xong).
  void _reloadStreak() {
    if (!mounted) return;
    setState(() {
      _streak = StorageService.getStreak();
    });
  }

  void _switchTab(int index) {
    if (_currentIndex != index) {
      FeedbackService.selection();
      setState(() {
        _currentIndex = index;
        _visited[index] = true;
      });
    }
  }

  /// Mở "Mục tiêu" (kỳ thi) và "Tập trung" (Pomodoro/Nhật ký) dưới dạng
  /// full-screen page có nút back — giữ nội dung gốc, chỉ gọn điều hướng.
  void _openExamsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExamsPage(
          onSetPrimary: _setPrimaryExam,
          onAddExam: _addExam,
          onUpdateExam: _updateExam,
          onDeleteExam: _deleteExam,
        ),
      ),
    );
  }

  void _openStudyPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyPage(
          onStreakChanged: _reloadStreak,
          onSessionCompleted: _reloadStreak,
          clock: widget.clock,
        ),
      ),
    );
  }

  void _openCalendarPage() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CalendarScreen(),
    ));
  }

  void _openNotesPage() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const NotesScreen(),
    ));
  }

  /// Tạo widget của tab [index]. Các tab chưa từng mở hiển thị rỗng để không
  /// tốn chi phí initState/build khi khởi động; tab đã mở giữ nguyên state.
  Widget _tabAt(int index) {
    switch (index) {
      case 0:
        // Tab mặc định — Hôm nay
        return HomeScreen(
          clock: widget.clock,
          primaryExam: _effectivePrimaryExam,
          exams: _exams,
          onExamTap: _openExamsPage,
          onOpenStudy: _openStudyPage,
          onOpenAiCoach: () => _switchTab(1),
          onOpenAiCoachWith: (prompt) {
            _switchTab(1);
            _aiCoachKey.currentState?.sendPrompt(prompt);
          },
          onOpenCalendar: _openCalendarPage,
          onOpenProgress: () => _switchTab(2),
          streak: _streak,
          isActive: _currentIndex == 0,
          onStreakChanged: _reloadStreak,
        );
      case 1:
        // Tab 1: Trợ lý AI Copilot
        return AiCoachScreen(key: _aiCoachKey);
      case 2:
        // Tab 2: Tổng quan Tiến độ (FE-5.1/FE-5.2) — biểu đồ tuần, tiến độ
        // theo môn, đếm ngược kỳ thi. Pomodoro/Nhật ký vẫn ở trang "Tập trung".
        return ProgressScreen(
            onOpenExams: _openExamsPage, onStartStudy: _openStudyPage);
      case 3:
        // Tab 3: Tài khoản & cài đặt cá nhân
        return AccountScreen(onDataChanged: _loadInitialData);
      default:
        return const SizedBox.shrink();
    }
  }

  static const List<NavItem> _primaryNavItems = [
    NavItem(Icons.today_outlined, Icons.today_rounded, 'Hôm nay'),
    NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'AI'),
    NavItem(Icons.trending_up_rounded, Icons.insights_rounded, 'Tiến độ'),
    NavItem(Icons.person_outline, Icons.person_rounded, 'Tôi'),
  ];

  /// Mục phụ trên sidebar desktop: Calendar, Goals, Focus, Notes.
  List<DesktopNavAction> _desktopSecondaryActions() => [
        DesktopNavAction(
          icon: Icons.calendar_month_outlined,
          label: 'Calendar',
          onOpen: _openCalendarPage,
        ),
        DesktopNavAction(
          icon: Icons.flag_outlined,
          label: 'Goals',
          onOpen: _openExamsPage,
        ),
        DesktopNavAction(
          icon: Icons.timer_outlined,
          label: 'Focus',
          onOpen: _openStudyPage,
        ),
        DesktopNavAction(
          icon: Icons.sticky_note_2_outlined,
          label: 'Notes',
          onOpen: _openNotesPage,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= kDesktopBreakpoint;
    final isWide = width >= kTabletBreakpoint;
    final tabChildren = [
      _tabAt(0),
      _visited[1]
          ? (_cachedAi ??= AiCoachScreen(key: _aiCoachKey))
          : const SizedBox.shrink(),
      _visited[2]
          ? (_cachedStudy ??= ProgressScreen(
              onOpenExams: _openExamsPage, onStartStudy: _openStudyPage))
          : const SizedBox.shrink(),
      _visited[3]
          ? (_cachedAccount ??= AccountScreen(onDataChanged: _loadInitialData))
          : const SizedBox.shrink(),
    ];

    final content = IndexedStack(
      index: _currentIndex,
      children: tabChildren,
    );

    // Tablet (≥768) + Desktop (≥1024): sidebar trái + nội dung — 4 tabs chính
    // + mục phụ. Tablet dùng rail thu gọn để tận dụng chiều ngang thay vì
    // phóng to giao diện điện thoại (FE-6.2).
    if (isWide) {
      final collapsed = isDesktop ? _sidebarCollapsed : !_tabletSidebarExpanded;
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopSidebar(
              index: _currentIndex,
              items: _primaryNavItems,
              onChanged: _switchTab,
              secondaryItems: _desktopSecondaryActions(),
              collapsed: collapsed,
              onToggleCollapse: () {
                setState(() {
                  if (isDesktop) {
                    _sidebarCollapsed = !_sidebarCollapsed;
                    SidebarPreference.setCollapsed(_sidebarCollapsed);
                  } else {
                    _tabletSidebarExpanded = !_tabletSidebarExpanded;
                  }
                });
              },
              userName: StorageService.getUserName(),
            ),
            Expanded(
              child: Column(
                children: [
                  const OfflineBanner(),
                  // Desktop: giới hạn độ rộng nội dung cho dễ đọc, thay vì kéo
                  // dài hết màn hình rộng (FE-6.3). Khi màn đủ rộng, chừa thêm
                  // cột phụ để thông tin quan trọng luôn hiện, không phải cuộn
                  // mới thấy.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: isDesktop
                              ? Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 1200),
                                    child: content,
                                  ),
                                )
                              : content,
                        ),
                        if (isDesktop && hasAuxColumn(context))
                          DesktopAuxColumn(
                            tabIndex: _currentIndex,
                            primaryExam: _effectivePrimaryExam,
                            userName: StorageService.getUserName(),
                            streak: _streak,
                            onOpenCalendar: _openCalendarPage,
                            onOpenNotes: _openNotesPage,
                            onOpenExams: _openExamsPage,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile/tablet: bottom navigation chuẩn 4 tab của EduPulse v2.
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const InstallBanner(),
            const OfflineBanner(),
            Expanded(
              child: TabChrome(
                index: _currentIndex,
                onChanged: _switchTab,
                items: _primaryNavItems,
                children: tabChildren,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner trạng thái offline/online đã tách sang `widgets/shell_banners.dart`
/// cùng lát cắt "navigation shell" (kế hoạch §6.2).
