import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/ai/ai_sprint4_planner.dart';
import 'package:edupulse/core/pwa/pwa_service.dart';
import 'package:edupulse/core/sync/sync_state.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/core/utils/supabase_service.dart';
import 'package:edupulse/features/home/domain/services/today_service.dart';
import 'package:edupulse/features/progress/domain/progress_engine.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_page.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// Sprint 7 — E2E-1..E2E-4: bốn kịch bản người dùng thật, chạy trên đúng app
/// đang phát hành (`MainShellScreen` + repository + SharedPreferences thật).
///
/// Nguyên tắc của bộ test này: **không giả lập kết quả**. Mọi bước đều bấm
/// vào widget thật, và mọi khẳng định đều đọc lại từ nguồn sự thật
/// (repository / storage / `ProgressEngine`) chứ không tin vào cái UI hiển thị.
///
/// `FocusClock` neo theo mốc thời gian thật nên `tester.pump()` không đẩy được
/// nó. Vì vậy `MainShellScreen` nhận tham số `clock` (mặc định `DateTime.now`)
/// và các kịch bản có phiên học truyền đồng hồ giả — vòng focus vẫn được ghi
/// qua đúng đường ghi thật của `StudyScreen`, chỉ là không phải chờ 30 phút.
///
/// Lưu ý: KHÔNG dùng `pumpAndSettle` khi đang ở màn Hôm nay — `HomeScreen`
/// chạy `Timer.periodic` 1s nên `pumpAndSettle` sẽ không bao giờ về tới.
class _FakeClock {
  _FakeClock(this._now);
  DateTime _now;
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Sĩ tử 2k9',
      'user_target': 'ĐH Bách Khoa Hà Nội',
      'streak': 9,
      'streak_record': 21,
    });
    await StorageService.init();
  });

  tearDown(() {
    // Trạng thái mạng là singleton — dọn sau mỗi kịch bản để test sau không
    // bị kế thừa "đang offline".
    SyncStateService.updateConnectivity(isOnline: true);
  });

  /// Mốc giả ở 08:00 hôm nay: giữa ngày nên vòng focus 30 phút không bao giờ
  /// tràn qua nửa đêm và làm sai các khẳng định "hôm nay".
  DateTime todayAt8() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 8);
  }

  Future<void> pumpShell(
    WidgetTester tester,
    DateTime Function() clock, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MainShellScreen(clock: clock),
    ));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Đẩy đồng hồ giả đi [seconds] giây, mỗi giây một nhịp pump — đúng nhịp
  /// `Timer.periodic` mà `StudyScreen` dùng để ghi vòng focus.
  Future<void> runFocusRound(
    WidgetTester tester,
    _FakeClock clock,
    int seconds,
  ) async {
    for (var i = 0; i < seconds; i++) {
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Mở màn Tập trung cho một nhiệm vụ từ màn Hôm nay.
  ///
  /// Đi theo đường người dùng thật: bấm thẻ nhiệm vụ → màn chi tiết → nút
  /// "Bắt đầu học ngay".
  Future<void> startTaskFromToday(WidgetTester tester, String title) async {
    final card = find.text(title);
    expect(card, findsWidgets);
    await tester.tapAt(tester.getCenter(card.first));
    await tester.pump(const Duration(milliseconds: 600));
    final start = find.text('Bắt đầu học ngay');
    expect(start, findsOneWidget, reason: 'màn chi tiết nhiệm vụ chưa mở');
    await tester.ensureVisible(start);
    await tester.pump(const Duration(milliseconds: 400));
    final center = tester.getCenter(start);
    await tester.tapAt(center);
    // Đóng sheet + mở trang mới = 2 lần chuyển cảnh liên tiếp; cần nhiều
    // khung hình thì cây widget mới được dựng hết.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Mở bảng xem trước kế hoạch AI (giữ nguyên bước Preview → Áp dụng mà app
  /// thật dùng, chỉ bỏ bước gọi mạng sinh kế hoạch).
  Future<void> pumpPlanPreview(WidgetTester tester, AiStudyPlan plan) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => AiPlanPreviewSheet.show(ctx, plan: plan),
              child: const Text('Mở kế hoạch AI'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Mở kế hoạch AI'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Bấm nút [Áp dụng] trong sheet và chờ ghi xong.
  Future<void> applyPlanFromSheet(WidgetTester tester) async {
    await tester.tap(find.textContaining('Áp dụng'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  // ─── E2E-1: Kịch bản A ───────────────────────────────────────────────────

  testWidgets('A — tạo task → học → đánh giá → số liệu tiến độ tăng',
      (tester) async {
    final clock = _FakeClock(todayAt8());
    await pumpShell(tester, clock.now);

    // 1. Tạo nhiệm vụ mới ngay trên màn Hôm nay.
    await tester.tap(find.text('+ Thêm nhiệm vụ'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Thêm nhiệm vụ'), findsOneWidget); // hộp thoại đã mở
    await tester.enterText(find.byType(TextField).first, 'Giải đề hàm số');
    await tester.tap(find.text('30 phút'));
    await tester.pump();
    await tester.tap(find.text('Thêm'));
    await tester.pump(const Duration(milliseconds: 500));

    // Không mất dữ liệu: nhiệm vụ đã xuống storage, không chỉ nằm trong RAM.
    final tasks = TaskRepository.instance.getAllTasks();
    expect(tasks, hasLength(1));
    final task = tasks.single;
    expect(task.title, 'Giải đề hàm số');
    expect(task.estimateMinutes, 30);
    expect(StorageService.getTodayTaskJson(task.id), isNotNull);

    // 2. Nhiệm vụ xuất hiện ở Hôm nay ngay lập tức.
    expect(
      TodayService.getTodayTasksSorted().map((t) => t.id),
      contains(task.id),
    );
    expect(find.text('Giải đề hàm số'), findsWidgets);

    // 3. Bấm "Bắt đầu học" → vào chế độ học tập trung cho đúng nhiệm vụ này.
    await startTaskFromToday(tester, 'Giải đề hàm số');
    expect(find.byType(StudyPage), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget); // đồng hồ vừa bắt đầu chạy

    // 4. Học hết vòng 30 phút (đồng hồ giả) → phiên được ghi thật.
    await runFocusRound(tester, clock, 1801);

    final sessions = StudySessionRepository.instance.getAll();
    expect(sessions, hasLength(1));
    final session = sessions.single;
    expect(session.taskId, task.id);
    expect(session.actualMinutes, 30, reason: 'thời gian học phải chuẩn');
    expect(session.status, StudySession.statusCompleted);
    // Phiên phải còn nằm trong storage — không chỉ trong RAM.
    expect(StorageService.getStudySessionJson(session.id), isNotNull);

    // 5. Đánh giá 1 chạm (đường ngắn của người dùng) rồi lưu.
    await tester.tap(find.text('🔥'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Lưu đánh giá & Hoàn tất'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-session-feedback')));
    await tester.pump(const Duration(milliseconds: 500));

    final rated = StudySessionRepository.instance.getById(session.id)!;
    expect(rated.mood, isNotNull, reason: 'phải lưu được đánh giá cảm xúc');
    expect(rated.understanding, isNotNull);

    // 6. Về Hôm nay — số liệu tiến độ tăng ngay, không cần tải lại app.
    // Trang Tập trung được mở dạng fullscreenDialog nên nút quay lại là Close.
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);
    expect(find.text('30m'), findsWidgets); // thẻ tổng kết hôm nay nhảy số phút

    final snapshot = ProgressEngine.snapshot(
      StudySessionRepository.instance.getAll(),
      TaskRepository.instance.getAllTasks(),
      clock.now(),
    );
    expect(snapshot.today.studyMinutes, 30);
    expect(snapshot.today.tasksTotal, 1);

    // 7. Tab Tiến độ phản ánh ngay phiên vừa học.
    await tester.tap(find.text('Tiến độ').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ─── E2E-2: Kịch bản B ───────────────────────────────────────────────────

  testWidgets('B — AI lập kế hoạch: xem trước → áp dụng → task vào Hôm nay',
      (tester) async {
    final clock = _FakeClock(todayAt8());
    final plan = AiStudyPlan(
      summary: 'Kế hoạch ôn 2 ngày',
      tasks: [
        AiPlannedTask(
          id: 'ai-act-1',
          title: 'Ôn hàm số',
          subject: 'Toán',
          estimateMinutes: 30,
          priority: 'high',
          scheduledAt: clock.now(),
          day: 1,
        ),
        AiPlannedTask(
          id: 'ai-act-2',
          title: 'Đọc văn bài 5',
          subject: 'Ngữ văn',
          estimateMinutes: 25,
          priority: 'medium',
          scheduledAt: clock.now(),
          day: 1,
        ),
        AiPlannedTask(
          id: 'ai-act-3',
          title: 'Nghe IELTS ngày 1',
          subject: 'Tiếng Anh',
          estimateMinutes: 20,
          priority: 'low',
          scheduledAt: clock.now().add(const Duration(days: 1)),
          day: 2,
        ),
      ],
    );

    await pumpPlanPreview(tester, plan);

    // Bước "xem trước": AI được phép đề xuất nhưng không tự ghi — trước khi
    // bấm Áp dụng, kế hoạch vẫn trống.
    expect(find.text('Kế hoạch AI đề xuất'), findsOneWidget);
    expect(find.text('Áp dụng 3 nhiệm vụ'), findsOneWidget);
    expect(TaskRepository.instance.getAllTasks(), isEmpty);

    // Xác nhận [Áp dụng].
    await applyPlanFromSheet(tester);
    expect(find.textContaining('Đã thêm 3 nhiệm vụ'), findsOneWidget);

    final created = TaskRepository.instance.getAllTasks();
    expect(created, hasLength(3));
    // Id lấy từ action của AI → bấm lại lần nữa không sinh bản sao.
    expect(created.map((t) => t.id).toSet(),
        {'ai-act-1', 'ai-act-2', 'ai-act-3'});

    // Áp dụng lại đúng kế hoạch đó: không tạo duplicate.
    await pumpPlanPreview(tester, plan);
    await applyPlanFromSheet(tester);
    expect(find.textContaining('đã có sẵn'), findsOneWidget);
    expect(TaskRepository.instance.getAllTasks(), hasLength(3));

    // Task AI hoạt động y hệt task thủ công: lọc theo ngày đúng như app thật.
    final tomorrow = clock.now().add(const Duration(days: 1));
    expect(
      TaskRepository.instance.getTasksForDay().map((t) => t.id),
      containsAll(['ai-act-1', 'ai-act-2']),
    );
    expect(
      TaskRepository.instance.getTasksForDay().map((t) => t.id),
      isNot(contains('ai-act-3')),
    );
    expect(TaskRepository.instance.getTasksForDay(tomorrow).single.id, 'ai-act-3');

    // Vào app thật: task AI hiện ở Hôm nay và bắt đầu học được bình thường.
    await pumpShell(tester, clock.now);
    expect(find.text('Ôn hàm số'), findsWidgets);
    expect(find.text('Nghe IELTS ngày 1'), findsNothing);
    await startTaskFromToday(tester, 'Ôn hàm số');
    expect(find.byType(StudyPage), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
  });

  // ─── E2E-3: Kịch bản C ───────────────────────────────────────────────────

  testWidgets('C — dời lịch sang ngày mai: giữ nguyên ID và lịch sử',
      (tester) async {
    final clock = _FakeClock(todayAt8());
    final task = TodayTask(
      id: 'e2e-reschedule',
      title: 'Ôn chuyên đề đạo hàm',
      subject: 'Toán',
      estimateMinutes: 30,
      scheduledAt: clock.now(),
    );
    await TaskRepository.instance.createTask(task);
    // Lịch sử gắn với nhiệm vụ phải sống sót qua việc dời lịch.
    await StudySessionRepository.instance.save(StudySession(
      id: 'e2e-reschedule-session',
      completedAt: clock.now().subtract(const Duration(days: 1)),
      taskId: task.id,
      subject: 'Toán',
      plannedMinutes: 30,
      actualMinutes: 30,
      status: StudySession.statusCompleted,
    ));
    final createdAtBefore = task.createdAt;

    await pumpShell(tester, clock.now);
    expect(find.text('Ôn chuyên đề đạo hàm'), findsWidgets);

    // Mở chi tiết → Dời lịch → Ngày mai → Xác nhận dời.
    await tester.tapAt(tester.getCenter(find.text('Ôn chuyên đề đạo hàm').first));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.text('Dời lịch'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Dời lịch'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Dời lịch nhiệm vụ'), findsOneWidget);

    await tester.tap(find.text('Ngày mai'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Xác nhận dời'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // ID giữ nguyên, chỉ đổi ngày — không tạo bản sao, không mất lịch sử.
    final all = TaskRepository.instance.getAllTasks();
    expect(all, hasLength(1));
    final moved = all.single;
    expect(moved.id, 'e2e-reschedule');
    expect(moved.title, 'Ôn chuyên đề đạo hàm');
    expect(moved.createdAt, createdAtBefore);
    expect(moved.rescheduleCount, 1);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(moved.scheduledAt!.day, tomorrow.day);
    expect(moved.scheduledAt!.month, tomorrow.month);

    // Biến mất khỏi Hôm nay, xuất hiện ở ngày mai.
    expect(
      TodayService.getTodayTasksSorted().map((t) => t.id),
      isNot(contains(moved.id)),
    );
    expect(
      TaskRepository.instance.getTasksForDay(tomorrow).map((t) => t.id),
      contains(moved.id),
    );
    expect(
      StudySessionRepository.instance.getForTask(moved.id),
      hasLength(1),
      reason: 'lịch sử phiên học gắn với nhiệm vụ không được đứt đoạn',
    );
    expect(find.textContaining('Đã dời'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ─── E2E-4: Kịch bản D ───────────────────────────────────────────────────

  testWidgets('D — ngoại tuyến: học và lưu vẫn an toàn, có mạng lại không mất gì',
      (tester) async {
    final clock = _FakeClock(todayAt8());
    PwaService.onlineNotifier.value = false;
    SyncStateService.updateConnectivity(isOnline: false);
    addTearDown(() {
      PwaService.onlineNotifier.value = true;
      SyncStateService.updateConnectivity(isOnline: true);
    });

    await pumpShell(tester, clock.now);

    // App mở được khi offline và nói rõ dữ liệu vẫn an toàn.
    expect(find.textContaining('Dữ liệu đang được lưu an toàn'), findsOneWidget);

    // Tạo nhiệm vụ khi offline — ghi local phải thành công.
    await tester.tap(find.text('+ Thêm nhiệm vụ'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
        find.byType(TextField).first, 'Ôn tích phân thức');
    await tester.tap(find.text('30 phút'));
    await tester.pump();
    await tester.tap(find.text('Thêm'));
    await tester.pump(const Duration(milliseconds: 500));

    final task = TaskRepository.instance.getAllTasks().single;
    expect(task.title, 'Ôn tích phân thức');

    // Học 30 phút khi offline.
    await startTaskFromToday(tester, 'Ôn tích phân thức');
    expect(find.byType(StudyPage), findsOneWidget);
    await runFocusRound(tester, clock, 1801);
    await tester.tap(find.byKey(const ValueKey('save-session-feedback')));
    await tester.pump(const Duration(milliseconds: 500));

    final offlineSession = StudySessionRepository.instance.getAll().single;
    expect(offlineSession.taskId, task.id);
    expect(offlineSession.actualMinutes, 30);

    // Bật lại mạng — app tự thử đồng bộ. Trong môi trường test Supabase chưa
    // cấu hình nên bước đồng bộ là no-op an toàn; điều cần chặn là dữ liệu
    // offline bị ghi đè hoặc mất.
    PwaService.onlineNotifier.value = true;
    await tester.pump(const Duration(milliseconds: 600));
    await SyncStateService.syncInBackground();
    await tester.pump(const Duration(milliseconds: 600));

    final afterSync = StudySessionRepository.instance.getAll();
    expect(afterSync, hasLength(1), reason: 'không được sinh phiên trùng');
    expect(afterSync.single.id, offlineSession.id);
    expect(afterSync.single.actualMinutes, 30);

    final tasksAfterSync = TaskRepository.instance.getAllTasks();
    expect(tasksAfterSync, hasLength(1));
    expect(tasksAfterSync.single.id, task.id);
    expect(tasksAfterSync.single.title, 'Ôn tích phân thức');

    // Dữ liệu vẫn nằm trong storage và vẫn được tổng hợp vào Tiến độ.
    expect(StorageService.getStudySessionJson(offlineSession.id), isNotNull);
    expect(StorageService.getTodayTaskJson(task.id), isNotNull);
    final snapshot = ProgressEngine.snapshot(
      afterSync,
      tasksAfterSync,
      clock.now(),
    );
    expect(snapshot.today.studyMinutes, 30);

    // Đường nguy hiểm nhất của luồng offline: khôi phục từ cloud không được
    // xoá bất cứ dữ liệu local nào.
    await SupabaseService.restoreAll();
    expect(StudySessionRepository.instance.getAll(), hasLength(1));
    expect(TaskRepository.instance.getAllTasks(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  // @@PART2@@
}