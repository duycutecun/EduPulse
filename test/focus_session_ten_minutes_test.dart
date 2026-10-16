import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/focus_clock.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';

/// V2 (`docs/BAN_THAY_DOI_V2.md` mục A + C.2): người dùng 18 tuổi nói thẳng
/// "từng bấm Pomodoro cho có" với phiên 25 phút. Thiết kế mới: **phiên mặc
/// định 10 phút**, mốc 10/20/35 cho ai muốn dài, hết 10 phút app hỏi **"Thêm
/// 10 phút?"** — người học tự kéo dài, không bị ép. Đồng hồ phải hiện **việc
/// đang làm**, vì một đồng hồ trần là thứ người ta tắt đi sau 30 giây.
class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    StudySessionRepository.instance.clearActive();
  });

  group('FocusClock kéo dài phiên', () {
    test('thêm 10 phút giữ nguyên phần đã học và vẫn đang chạy', () {
      final start = DateTime(2026, 5, 1, 8);
      final clock = FocusClock(totalSeconds: 10 * 60);
      clock.start(start);

      final ended = start.add(const Duration(minutes: 10));
      expect(clock.remainingAt(ended), 0, reason: 'vòng 10 phút đã hết');

      final longer = clock.extended(10 * 60, ended);
      expect(longer.totalSeconds, 20 * 60);
      expect(longer.remainingAt(ended), 10 * 60,
          reason: 'phần đã học không được cộng dồn thành thời gian mới');
      expect(longer.elapsedAt(ended), 10 * 60);
      expect(longer.isRunning, isTrue,
          reason: 'đang học thì kéo dài liền mạch');
      expect(longer.startedAt, start,
          reason: 'mốc bắt đầu thật của phiên không được trôi');
    });

    test('đồng hồ đang tạm dừng thì kéo dài vẫn đứng yên', () {
      final start = DateTime(2026, 5, 1, 8);
      final clock = FocusClock(totalSeconds: 10 * 60);
      clock.start(start);
      clock.pause(start.add(const Duration(minutes: 4)));

      final longer =
          clock.extended(10 * 60, start.add(const Duration(minutes: 4)));
      expect(longer.isRunning, isFalse);
      expect(
          longer.remainingAt(start.add(const Duration(minutes: 4))), 16 * 60);
      expect(longer.elapsedAt(start.add(const Duration(minutes: 4))), 4 * 60);
    });

    test('số giây thêm không hợp lệ bị từ chối', () {
      final clock = FocusClock(totalSeconds: 10 * 60);
      expect(
          () => clock.extended(0, DateTime(2026, 5, 1)), throwsArgumentError);
      expect(
          () => clock.extended(-60, DateTime(2026, 5, 1)), throwsArgumentError);
    });
  });

  group('Phiên mặc định 10 phút', () {
    Widget harness({_FakeClock? clock, TodayTask? task}) => MaterialApp(
          home: Scaffold(
            body: StudyScreen(
              clock: (clock ?? _FakeClock(DateTime(2026, 5, 1, 8))).now,
              initialTask: task,
            ),
          ),
        );

    testWidgets('mở màn là 10:00 và mốc 10/3 đang chọn', (tester) async {
      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.text('10:00'), findsOneWidget,
          reason: 'mặc định 10 phút, không phải 25 phút nữa');
      expect(find.text('10/3'), findsOneWidget);
      expect(find.text('20/5'), findsOneWidget);
      expect(find.text('35/10'), findsOneWidget);
      expect(find.text('25/5'), findsNothing);
    });

    testWidgets('đồng hồ hiện việc đang làm', (tester) async {
      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        task: TodayTask(id: 't1', title: 'Ôn hàm số', subject: 'Toán'),
      ));
      await tester.pump();

      // V2: "chống chán bằng cách hiển thị việc đang làm trên màn đồng hồ thay
      // vì đồng hồ trần" — nên tên việc phải nằm ngay dưới con số đếm ngược.
      final clockTask = find.byKey(const ValueKey('clock-current-task'));
      expect(clockTask, findsOneWidget);
      expect(
        tester.widget<Text>(clockTask).data,
        contains('Ôn hàm số'),
      );
    });

    testWidgets('hết 10 phút → hỏi "Thêm 10 phút?"', (tester) async {
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(clock: clock));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pom-toggle')));
      await tester.pump();

      for (var i = 0; i < 10 * 60; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();

      expect(find.text('Thêm 10 phút'), findsOneWidget);
      expect(find.text('Nghỉ'), findsOneWidget);
      expect(StudySessionRepository.instance.getAll(), isEmpty,
          reason: 'chưa chốt kéo dài hay nghỉ thì chưa ghi phiên');
    });

    testWidgets('chọn "Thêm 10 phút" → còn 10 phút nữa, cùng một phiên',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(clock: clock));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pom-toggle')));
      await tester.pump();

      for (var i = 0; i < 10 * 60; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();
      await tester.tap(find.text('Thêm 10 phút'));
      await tester.pumpAndSettle();

      expect(find.text('10:00'), findsOneWidget,
          reason: 'đồng hồ chạy tiếp 10 phút nữa thay vì đẩy sang nghỉ');
      // Bộ đếm vòng không tăng: kéo dài là **cùng** phiên, không phải phiên mới
      // (chỉ khi kết thúc vòng mới `_pomRound++` và sang nghỉ).
      expect(find.text('Phiên 0'), findsOneWidget,
          reason: 'kéo dài là cùng một phiên, không phải phiên mới');
      expect(StudySessionRepository.instance.getAll(), isEmpty);

      // Học nốt 10 phút đã xin: giờ mới chốt phiên 20 phút.
      await tester.tap(find.byKey(const ValueKey('finish-session-early')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final sessions = StudySessionRepository.instance.getAll();
      expect(sessions, hasLength(1));
      expect(sessions.single.plannedMinutes, 20,
          reason: 'thời lượng đã xin phải được ghi đúng, không cắt về 10');
      expect(sessions.single.actualMinutes, 10,
          reason: 'số phút thật đã học vẫn đo từ mốc thời gian');
    });

    testWidgets('chọn "Nghỉ" → ghi phiên rồi mới sang vòng nghỉ',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(clock: clock));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pom-toggle')));
      await tester.pump();

      for (var i = 0; i < 10 * 60; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();
      await tester.tap(find.text('Nghỉ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final sessions = StudySessionRepository.instance.getAll();
      expect(sessions, hasLength(1));
      expect(sessions.single.plannedMinutes, 10);
      expect(sessions.single.actualMinutes, 10);
      expect(find.text('☕ Nghỉ giải lao'), findsOneWidget);
    });
  });
}
