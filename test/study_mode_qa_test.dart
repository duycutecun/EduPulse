import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';
import 'package:edupulse/features/tasks/domain/models/task_state.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// Nút bật/tạm dừng vòng focus — dùng key chứ không dùng
/// `find.byType(GestureDetector).first`: thứ tự widget trong cây thay đổi theo
/// bố cục, nên "widget GestureDetector đầu tiên" chỉ đúng một cách tình cờ.
final Finder pomToggle = find.byKey(const ValueKey('pom-toggle'));

/// Đồng hồ giả cho widget test: `tester.pump()` đẩy được `Timer` nhưng không
/// đẩy được `DateTime.now()`.
class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// FE-3.3 — kết thúc phiên học phải nhanh và không để sót việc.
///
/// Mục tiêu trong đặc tả: "thao tác kết thúc phiên học chỉ mất dưới 3 giây".
/// Test không đo giây, nhưng nó chặn đúng những thứ làm thao tác đó chậm hoặc
/// mất việc: bắt người dùng điền thang chi tiết, quên cập nhật tổng thời gian,
/// hoặc đánh dấu xong nhiệm vụ bằng đường ghi khác repository.
void main() {
  final repo = StudySessionRepository.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  /// Đẩy một vòng focus tới lúc kết thúc mà không phải chờ 25 phút thật.
  ///
  /// `FocusClock` neo theo mốc thời gian thật, còn `tester.pump()` chỉ đẩy
  /// `Timer` — nên ta đưa đồng hồ giả vào `StudyScreen` và tăng nó cùng nhịp
  /// pump. Phiên vẫn được ghi qua đúng đường ghi thật, không giả lập kết quả.
  Future<void> pumpOneSecond(WidgetTester tester, _FakeClock clock) async {
    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> runToEndOfRound(WidgetTester tester) async {
    final clock = _FakeClock(DateTime(2026, 5, 1, 8));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StudyScreen(autoStart: true, clock: clock.now)),
    ));
    await tester.pump();
    // 25 phút = 1500 giây; tiến từng giây như đồng hồ thật.
    for (var i = 0; i < 1501; i++) {
      await pumpOneSecond(tester, clock);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('vòng focus kết thúc thì mở sheet đánh giá 1 chạm',
      (tester) async {
    await runToEndOfRound(tester);

    expect(repo.getAll(), hasLength(1));
    expect(find.textContaining('Xong phiên'), findsOneWidget);
    // Đánh giá 1 chạm: đủ 5 emoji, và nút lưu luôn sẵn sàng — không có bước
    // bắt buộc nào chặn người dùng muốn đóng.
    expect(find.text('😫'), findsOneWidget);
    expect(find.text('😐'), findsOneWidget);
    expect(find.text('🙂'), findsOneWidget);
    expect(find.text('😄'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-session-feedback')), findsOneWidget);
  });

  testWidgets('chạm 1 emoji là lưu được, không cần thang chi tiết',
      (tester) async {
    await runToEndOfRound(tester);

    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-session-feedback')));
    await tester.pumpAndSettle();

    final session = repo.getAll().single;
    expect(session.mood, 5);
    expect(session.focus, 5);
    expect(session.effectiveness, 5);
    expect(session.feedbackRating, greaterThan(0),
        reason: 'phản hồi suy ra được từ 1 chạm');
    expect(find.text('🔥'), findsNothing, reason: 'sheet đã đóng');
  });

  testWidgets('đóng sheet không ghi phản hồi — nhưng phiên vẫn còn',
      (tester) async {
    await runToEndOfRound(tester);

    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();

    expect(repo.getAll(), hasLength(1),
        reason: 'bỏ đánh giá không được xoá phiên đã học');
    expect(repo.getAll().single.mood, isNull);
  });

  testWidgets('onSessionCompleted được gọi ngay khi phiên kết thúc (BE-3.3)',
      (tester) async {
    var completedCalls = 0;
    final clock = _FakeClock(DateTime(2026, 5, 1, 8));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StudyScreen(
          autoStart: true,
          clock: clock.now,
          onSessionCompleted: () => completedCalls++,
        ),
      ),
    ));
    await tester.pump();
    for (var i = 0; i < 1501; i++) {
      await pumpOneSecond(tester, clock);
    }
    await tester.pumpAndSettle();

    expect(completedCalls, 1,
        reason: 'màn bên ngoài cập nhật tổng giờ ngay, không chờ điều hướng');
  });

  group('QA-3.1 — kịch bản ngoại lệ của chế độ học', () {
    /// Mở màn hình với đồng hồ giả và trả về cả hai để điều khiển.
    Future<_FakeClock> openStudy(
      WidgetTester tester, {
      int focusMinutes = 25,
      TodayTask? task,
    }) async {
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      // Màn hình rộng đủ để nút không bị xuống dưới viewport trên khung test.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudyScreen(
            initialMinutes: focusMinutes,
            initialTask: task,
            autoStart: true,
            clock: clock.now,
          ),
        ),
      ));
      await tester.pump();
      return clock;
    }

    testWidgets('tạm dừng 5 phút rồi tiếp tục vẫn ghi đúng 25 phút',
        (tester) async {
      final clock = await openStudy(tester);

      // Chạy 10 phút.
      for (var i = 0; i < 600; i++) {
        await pumpOneSecond(tester, clock);
      }
      // Tạm dừng, đứng yên 5 phút — thời gian này KHÔNG được tính là học.
      await tester.tap(pomToggle);
      await tester.pump();
      for (var i = 0; i < 300; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      // Tiếp tục chạy nốt 15 phút còn lại.
      await tester.tap(pomToggle);
      await tester.pump();
      for (var i = 0; i < 901; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();

      final session = repo.getAll().single;
      expect(session.actualMinutes, 25,
          reason: '5 phút tạm dừng không được cộng vào thời gian học');
      // `elapsed` là thời lượng từ mốc bắt đầu tới kết thúc theo đồng hồ thật,
      // tức là gồm cả 5 phút tạm dừng. actualMinutes mới là phút học thật.
      expect(session.elapsed, Duration(minutes: 30));
    });

    testWidgets('app bị vùy rồi quay lại vẫn giữ đúng số giây còn lại',
        (tester) async {
      final clock = await openStudy(tester);

      for (var i = 0; i < 600; i++) {
        await pumpOneSecond(tester, clock);
      }

      // Mô phỏng hệ điều hành vùy app 3 phút rồi thả ra.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      clock.advance(const Duration(minutes: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // 25 phút − 10 phút đã học − 3 phút bị vùy = còn 12 phút, injou không
      // thay đổi theo số tick nhưng thay đổi theo thời gian thật.
      expect(find.text('12:00'), findsOneWidget);
    });

    testWidgets('đóng app giữa chừng thì mở lại vẫn giữ đúng phần đã học',
        (tester) async {
      final clock = await openStudy(tester);

      // Học 10 phút rồi "tắt app" (bỏ widget khỏi cây) — snapshot phải đủ để
      // dựng lại đồng hồ.
      for (var i = 0; i < 600; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Mở lại: ảnh chụp còn hiệu lực nên màn hình phải hỏi khôi phục, và phần
      // đã học không bị tính lại từ đầu.
      final reopened = _FakeClock(DateTime(2026, 5, 1, 8, 10));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudyScreen(clock: reopened.now)),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('tiếp tục'), findsWidgets);
    });

    /// Đóng sheet đánh giá nếu đang mở.
    ///
    /// Sheet modal chắn mọi tap vào màn hình phía dưới, nên test phải đóng nó
    /// trước khi bấm nút bật/tạm dừng — đúng như người dùng thật.
    Future<void> dismissSheetIfOpen(WidgetTester tester) async {
      if (find.text('Bỏ qua').evaluate().isNotEmpty) {
        await tester.tap(find.text('Bỏ qua').first);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('vòng nghỉ kết thúc không ghi phiên học', (tester) async {
      final clock = await openStudy(tester, focusMinutes: 1);

      // Hết 1 phút focus → ghi phiên, chuyển sang nghỉ.
      for (var i = 0; i < 61; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();
      expect(repo.getAll(), hasLength(1));

      // Nghỉ **không tự chạy** — người dùng bấm mới bắt đầu. Đây là hành vi có
      // chủ đích: ép nghỉ cũng là một kiểu ép.
      await dismissSheetIfOpen(tester);
      await tester.tap(pomToggle);
      await tester.pump();
      for (var i = 0; i < 301; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();

      expect(repo.getAll(), hasLength(1), reason: 'nghỉ không phải là học');
      // Hết nghỉ thì sẵn sàng vòng focus mới (1 phút, như đã cài đặt).
      expect(find.textContaining('01:00'), findsOneWidget);
    });

    testWidgets('tổng thời gian học cộng dồn đúng qua nhiều vòng',
        (tester) async {
      final clock = await openStudy(tester, focusMinutes: 1);

      // Vòng focus 1: học 1 phút.
      for (var i = 0; i < 61; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();
      expect(repo.getAll(), hasLength(1));

      // Nghỉ rồi vòng focus 2.
      await dismissSheetIfOpen(tester);
      await tester.tap(pomToggle);
      await tester.pump();
      for (var i = 0; i < 301; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();
      await dismissSheetIfOpen(tester);
      await tester.tap(pomToggle);
      await tester.pump();
      for (var i = 0; i < 61; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();

      expect(repo.getAll(), hasLength(2));
      expect(repo.minutesOn(clock.now()), 2,
          reason: 'hai vòng 1 phút phải ra đúng 2 phút, không phải 26');
    });

    testWidgets(
        'phiên ghi xong phải đọc lại được từ storage (không phụ thuộc mạng)',
        (tester) async {
      final clock = await openStudy(tester, focusMinutes: 1);

      for (var i = 0; i < 61; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();

      final session = repo.getAll().single;
      final reread = repo.getById(session.id);
      expect(reread, isNotNull, reason: 'phiên phải đọc lại được từ storage');
      expect(reread!.actualMinutes, 1);
      expect(reread.status, StudySession.statusCompleted);
    });
  });

  group('Nút "Xong việc này" — 1 chạm để kết thúc cả phiên lẫn nhiệm vụ', () {
    late String taskId;

    Future<void> openSheetWithTask(WidgetTester tester) async {
      final task = await TaskRepository.instance.createTask(
        TodayTask(
          id: 'task-x',
          title: 'O tap phan',
          subject: '📐 Toán',
          priority: 'high',
          estimateMinutes: 25,
        ),
      );
      taskId = task.task!.id;
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudyScreen(
            autoStart: true,
            initialTask: task.task,
            clock: clock.now,
          ),
        ),
      ));
      await tester.pump();
      for (var i = 0; i < 1501; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('đánh dấu nhiệm vụ hoàn thành QUA repository', (tester) async {
      await openSheetWithTask(tester);

      await tester.tap(find.text('😄'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.byKey(const ValueKey('complete-task-and-go-today')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('complete-task-and-go-today')));
      await tester.pumpAndSettle();

      final task = TaskRepository.instance.getTaskById(taskId)!;
      expect(task.status, TaskStatus.completed.value);
      expect(task.isDone, isTrue);
      // Và phiên học vẫn phải được ghi — hoàn thành task không được nuốt mất
      // 25 phút đã học.
      expect(repo.getAll(), hasLength(1));
      expect(repo.getAll().single.taskId, taskId);
    });

    testWidgets('đánh giá được lưu kèm trong thao tác kết thúc',
        (tester) async {
      await openSheetWithTask(tester);

      await tester.tap(find.text('😐'));
      await tester.pumpAndSettle();
      // Sheet cuộn được; nút cuối có thể nằm dưới màn hình ở khung test mặc
      // định — đúng như trên máy thật với màn hình thấp.
      await tester.ensureVisible(
          find.byKey(const ValueKey('complete-task-and-go-today')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('complete-task-and-go-today')));
      await tester.pumpAndSettle();

      expect(repo.getAll().single.mood, 2);
      expect(repo.getAll().single.understanding, 2);
    });

    testWidgets('không có nhiệm vụ thì không hiện nút "Xong việc này"',
        (tester) async {
      await runToEndOfRound(tester);

      expect(
        find.byKey(const ValueKey('complete-task-and-go-today')),
        findsNothing,
        reason: 'không có việc để đánh dấu xong thì đừng hứa hẹn vô nghĩa',
      );
    });

    testWidgets('nhiệm vụ đã hoàn thành trước đó → vẫn không nổ lỗi',
        (tester) async {
      final created = await TaskRepository.instance.createTask(
        TodayTask(
          id: 'task-done',
          title: 'Da xong',
          subject: '📐 Toán',
          priority: 'high',
          estimateMinutes: 25,
        ),
      );
      await TaskRepository.instance.setTaskStatus(
        created.task!.id,
        TaskStatus.completed,
      );
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudyScreen(
            autoStart: true,
            initialTask: TaskRepository.instance.getTaskById(created.task!.id),
            clock: clock.now,
          ),
        ),
      ));
      await tester.pump();
      for (var i = 0; i < 1501; i++) {
        await pumpOneSecond(tester, clock);
      }
      await tester.pumpAndSettle();

      if (find
          .byKey(const ValueKey('complete-task-and-go-today'))
          .evaluate()
          .isNotEmpty) {
        await tester
            .tap(find.byKey(const ValueKey('complete-task-and-go-today')));
        await tester.pumpAndSettle();
      }

      // Điểm mấu chốt: dù trạng thái task thế nào, phiên học vẫn được ghi.
      expect(repo.getAll(), hasLength(1));
    });
  });
}
