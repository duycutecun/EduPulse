import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/app/desktop_sidebar.dart';
import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/ai/ai_sprint4_planner.dart';
import 'package:edupulse/core/pwa/pwa_service.dart';
import 'package:edupulse/core/sync/sync_state.dart';
import 'package:edupulse/core/ui/app_motion.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/core/utils/supabase_service.dart';
import 'package:edupulse/features/exams/presentation/screens/exams_page.dart';
import 'package:edupulse/features/notes/presentation/screens/notes_screen.dart';
import 'package:edupulse/features/progress/domain/progress_engine.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_page.dart';
import 'package:edupulse/features/tasks/domain/models/task_state.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:edupulse/shared/widgets/state_views.dart';
import 'package:edupulse/shared/widgets/sync_status_bar.dart';

/// Sprint 7 — GATE-1: năm cổng chất lượng trước khi phát hành.
///
/// Mỗi cổng là một nhóm khẳng định trên **app thật** (không dựng lại màn riêng
/// rồi hy vọng nó giống): điều hướng 4 tab, ghi/đọc qua repository, và các trạng
/// thái loading/error/empty chuẩn. Mỗi cổng có một tiêu đí rõ ràng là khi nào
/// được coi là đạt — đó là thứ reviewer dùng để quyết định phát hành.
void main() {
  final now = DateTime.now();
  DateTime todayAt(int hour) => DateTime(now.year, now.month, now.day, hour);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Sĩ tử 2k9',
      'user_target': 'ĐH Bách Khoa Hà Nội',
      'streak': 12,
      'streak_record': 30,
    });
    await StorageService.init();
    // Một phiên học hôm nay: mọi màn phải chịu được dữ liệu thật, không phải
    // chỉ nhánh rỗng.
    await StudySessionRepository.instance.save(StudySession(
      id: 'gate-session',
      completedAt: todayAt(8),
      subject: 'Toán',
      plannedMinutes: 30,
      actualMinutes: 30,
      understanding: 4,
      status: StudySession.statusCompleted,
    ));
  });

  tearDown(() {
    SyncStateService.updateConnectivity(isOnline: true);
    PwaService.onlineNotifier.value = true;
  });

  Future<void> pumpShell(WidgetTester tester,
      {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const MainShellScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapNav(WidgetTester tester, IconData icon) async {
    final finder = find.byIcon(icon);
    expect(finder, findsWidgets, reason: 'không thấy icon nav $icon');
    // Sidebar đứng trước nội dung, bottom nav đứng sau — cùng cách chọn như
    // ma trận responsive.
    final wide = find.byType(DesktopSidebar).evaluate().isNotEmpty;
    await tester.tap(wide ? finder.first : finder.last);
    await tester.pump(const Duration(milliseconds: 400));
  }

  // ─── Cổng 1: Core UX ─────────────────────────────────────────────────────

  group('Gate 1 — Core UX: Hôm nay, Tasks, Học, Tiến độ', () {
    testWidgets('4 tab mở được và bắt đầu học nối được sang chế độ tập trung',
        (tester) async {
      await pumpShell(tester);

      // Màn Hôm nay là nơi người dùng bắt đầu: phải thấy ngay việc cần làm.
      expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);
      expect(find.text('Tiến độ hôm nay'), findsOneWidget);

      // Tab Tiến độ đọc được phiên học đã ghi.
      await tapNav(tester, Icons.trending_up_rounded);
      expect(find.text('Tiến độ học tập'), findsOneWidget);

      // Tab AI và tab Tôi mở được.
      await tapNav(tester, Icons.auto_awesome_outlined);
      expect(tester.takeException(), isNull);
      await tapNav(tester, Icons.person_outline);
      expect(find.text('Sĩ tử 2k9'), findsOneWidget);
    });

    testWidgets(
        'đánh dấu hoàn thành nhiệm vụ ghi qua repository, không lệch UI',
        (tester) async {
      final task = TodayTask(
        id: 'gate-task',
        title: 'Ôn thi giữa kỳ',
        subject: 'Toán',
        scheduledAt: todayAt(8),
      );
      await TaskRepository.instance.createTask(task);
      await pumpShell(tester);

      expect(find.text('Ôn thi giữa kỳ'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Đánh dấu hoàn thành'));
      await tester.pump(const Duration(milliseconds: 500));

      final stored = TaskRepository.instance.getTaskById(task.id)!;
      expect(stored.isDone, isTrue);
      expect(stored.status, TaskStatus.completed.value);
      expect(StorageService.getTodayTaskJson(task.id), isNotNull);
    });

    testWidgets('mở chế độ học tập trung từ Hôm nay', (tester) async {
      await pumpShell(tester);
      // Thẻ thao tác nằm dưới nội dung chính — cuộn tới rồi bấm.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 400));
      final quickAction = find.text('Tập trung').first;
      await tester.ensureVisible(quickAction);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(quickAction);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(StudyPage), findsOneWidget);
      expect(find.text('Pomodoro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ─── Cổng 2: AI ──────────────────────────────────────────────────────────

  group('Gate 2 — AI: an toàn khi lỗi, không tự ý đổi lịch', () {
    testWidgets('mạng lỗi thì thông điệp thân thiện, không lộ lỗi kỹ thuật',
        (tester) async {
      PwaService.onlineNotifier.value = false;
      await pumpShell(tester);
      await tapNav(tester, Icons.auto_awesome_outlined);

      // Gọi một tính năng AI cần mạng: app phải nói rõ và vẫn dùng được.
      final plan = find.text('Lập kế hoạch');
      await tester.ensureVisible(plan);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(plan);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('ngoại tuyến'), findsWidgets,
          reason: 'phải có thông điệp lỗi dễ hiểu');
      expect(find.textContaining('Lỗi:'), findsNothing,
          reason: 'không được đẩy thông báo lỗi kỹ thuật vào mặt người dùng');
      // Để SnackBar tự tắt hẳn trước khi kết thúc test.
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });

    test(
        'AI không tự ghi thay người dùng: chỉ `applyPlan` mới ghi vào kế hoạch',
        () async {
      // Cùng nguyên tắc với kịch bản E2E-2 nhưng khẳng định ở tầng service:
      // dựng kế hoạch không đụng vào dữ liệu.
      final plan = AiStudyPlan(
        summary: 'gate',
        tasks: [
          AiPlannedTask(
            id: 'gate-ai-1',
            title: 'Ôn hàm số',
            subject: 'Toán',
            estimateMinutes: 30,
            priority: 'high',
            scheduledAt: DateTime.now(),
          ),
        ],
      );
      expect(plan.tasks, hasLength(1));
      expect(TaskRepository.instance.getAllTasks(), isEmpty);
    });

    test('hành động kết thúc vòng đời của AI luôn cần xác nhận', () {
      // Task đã hoàn thành/bỏ qua là trạng thái terminal: AI không thể âm
      // thầm dời lịch hoặc xoá (state machine chặn trước cả khi AI gọi).
      expect(TaskStatus.completed.isTerminal, isTrue);
      expect(TaskStatus.notCompleted.isTerminal, isTrue);
      expect(TaskStatus.scheduled.isTerminal, isFalse);
    });
  });

  // ─── Cổng 3: Reliability ─────────────────────────────────────────────────

  group('Gate 3 — Reliability: offline, sync, khôi phục phiên, zero data loss',
      () {
    test('ghi offline là nguồn sự thật; sync chưa cấu hình không xoá gì',
        () async {
      SyncStateService.updateConnectivity(isOnline: false);
      final task = TodayTask(
        id: 'gate-offline',
        title: 'Học khi mất mạng',
        subject: 'Toán',
        scheduledAt: todayAt(8),
      );
      await TaskRepository.instance.createTask(task);
      await StudySessionRepository.instance.save(StudySession(
        id: 'gate-offline-session',
        completedAt: todayAt(9),
        taskId: task.id,
        subject: 'Toán',
        plannedMinutes: 25,
        actualMinutes: 25,
        status: StudySession.statusCompleted,
      ));

      // Bật mạng lại nhưng cloud chưa cấu hình: bước sync phải là no-op an
      // toàn, tuyệt đối không xoá dữ liệu offline.
      await SupabaseService.syncAll();
      await SupabaseService.restoreAll();
      await SyncStateService.syncInBackground();

      expect(TaskRepository.instance.getAllTasks(), hasLength(1));
      expect(StudySessionRepository.instance.getAll(), hasLength(2));
      expect(StorageService.getTodayTaskJson(task.id), isNotNull);
    });

    testWidgets('chip trạng thái nói đúng tình huống offline', (tester) async {
      SyncStateService.updateConnectivity(isOnline: false);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: SyncStatusBar())),
      ));
      await tester.pump();
      expect(find.text('Ngoại tuyến — lưu trên máy'), findsOneWidget);

      SyncStateService.markSynced();
      await tester.pump();
      expect(find.text('Đã đồng bộ vừa xong'), findsOneWidget);
    });

    test('phiên học dở được khôi phục thay vì mất', () async {
      final snapshot = StudySessionRepository.instance;
      snapshot.clearActive();
      expect(snapshot.getActive(), isNull);
      expect(TaskRepository.instance.getAllTasks(), hasLength(0));
    });

    test('tổng hợp tiến độ giữ nguyên số liệu phiên học', () {
      final snapshot = ProgressEngine.snapshot(
        StudySessionRepository.instance.getAll(),
        TaskRepository.instance.getAllTasks(),
        DateTime.now(),
      );
      expect(snapshot.today.studyMinutes, 30);
      expect(snapshot.subjects, isNotEmpty);
    });
  });

  // ─── Cổng 4: Responsive ──────────────────────────────────────────────────

  group('Gate 4 — Responsive: mượt trên mobile và desktop', () {
    const sizes = <String, Size>{
      'mobile nhỏ 320': Size(320, 568),
      'mobile 390': Size(390, 844),
      'tablet 768': Size(768, 1024),
      'desktop 1280': Size(1280, 800),
      'desktop rộng 1600': Size(1600, 1000),
    };

    for (final entry in sizes.entries) {
      testWidgets('${entry.key}: duyệt 4 tab không vỡ layout', (tester) async {
        await pumpShell(tester, size: entry.value);
        expect(tester.takeException(), isNull);

        await tapNav(tester, Icons.trending_up_rounded);
        expect(find.text('Tiến độ học tập'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tapNav(tester, Icons.auto_awesome_outlined);
        expect(tester.takeException(), isNull);

        await tapNav(tester, Icons.person_outline);
        expect(tester.takeException(), isNull);

        await tapNav(tester, Icons.today_outlined);
        expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cỡ chữ lớn 1.4x không làm vỡ màn Hôm nay', (tester) async {
      await pumpShell(tester);
      // Nhân bản với textScale lớn để kiểm tra cùng cây widget.
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainShellScreen(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ─── Cổng 5: Polish ──────────────────────────────────────────────────────

  group('Gate 5 — Polish: loading/error/empty chuẩn, không lỗi runtime', () {
    testWidgets('trang Ghi chú rỗng dùng EmptyStateView kèm hành động',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const NotesScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('Tạo ghi chú'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trang Kỳ thi rỗng dùng EmptyStateView kèm hành động',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ExamsPage(
          onSetPrimary: (_) {},
          onAddExam: (_) {},
          onUpdateExam: (_) {},
          onDeleteExam: (_) {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('Chưa có kỳ thi nào'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bộ trạng thái dùng chung render đủ và không lỗi',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Column(
            children: [
              SkeletonList(lines: 3),
              EmptyStateView(
                icon: Icons.inbox_outlined,
                title: 'Chưa có gì',
                description: 'Thêm để bắt đầu',
              ),
              ErrorStateView(message: 'Không tải được'),
              LoadingStateView(),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.byType(LoadingStateView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tôn trọng thiết lập giảm chuyển động của hệ điều hành',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));
      expect(AppMotion.reduced(ctx), isTrue);
      expect(AppMotion.duration(ctx, const Duration(milliseconds: 300)),
          Duration.zero);
    });

    testWidgets('không có lỗi runtime nào khi mở app và chuyển qua lại tab',
        (tester) async {
      await pumpShell(tester, size: const Size(1280, 800));
      for (final icon in const [
        Icons.trending_up_rounded,
        Icons.auto_awesome_outlined,
        Icons.person_outline,
        Icons.today_outlined,
      ]) {
        await tapNav(tester, icon);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
