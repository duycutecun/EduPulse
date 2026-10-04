import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';
import 'package:edupulse/features/study/domain/focus_clock.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BE-3.2 — không để phiên học đang chạy bị mất khi app bị hệ điều hành kill.
void main() {
  late StudySessionRepository repo;

  final t0 = DateTime(2026, 5, 1, 8);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo = StudySessionRepository.instance;
  });

  FocusClock running({int total = 1500, String subject = 'Hoc'}) {
    final clock = FocusClock(totalSeconds: total)..start(at(0));
    return clock;
  }

  ActiveStudySession snapshot({
    int total = 1500,
    int remaining = 1200,
    DateTime? anchor,
    DateTime? startedAt,
    bool isBreak = false,
    bool paused = false,
  }) =>
      ActiveStudySession(
        taskId: 't1',
        taskTitle: 'On ham so',
        subject: 'Hoc',
        totalSeconds: total,
        remainingAtAnchor: remaining,
        // `anchor: null` là "đã tạm dừng", nên phải phân biệt được với
        // "không truyền" — vì vậy có cờ `paused` thay vì dựa vào null.
        anchorAt: paused ? null : (anchor ?? at(0)),
        startedAt: startedAt ?? at(0),
        round: 2,
        isBreak: isBreak,
      );

  group('Tính lại thời gian khi app vừa mở lại', () {
    test('đồng hồ tiếp tục từ đúng số giây còn lại', () {
      final snap = snapshot(remaining: 1500);

      // App bị kill, mở lại 10 phút sau: vòng chạy 600s, còn 900s.
      expect(snap.remainingAt(at(600)), 900);
      expect(snap.elapsedSecondsAt(at(600)), 600);
      expect(snap.elapsedMinutesAt(at(600)), 10);
    });

    test('vòng đã trôi quá thời lượng thì về 0, không âm', () {
      final snap = snapshot(remaining: 300);

      expect(snap.remainingAt(at(3600)), 0);
      expect(snap.elapsedSecondsAt(at(3600)), 1500);
      expect(snap.elapsedMinutesAt(at(3600)), 25);
    });

    test('cộng dồn cả phần đã học trước lúc tạm dừng', () {
      // Vòng 1500s: đã học 300s rồi tạm dừng (còn 1200s); mở lại 120s sau khi
      // đã bấm tiếp tục.
      final snap = snapshot(remaining: 1200);

      expect(snap.remainingAt(at(120)), 1080);
      expect(snap.elapsedSecondsAt(at(120)), 420);
      expect(snap.elapsedMinutesAt(at(120)), 7);
    });

    test('vòng đã tạm dừng (anchorAt null) không trôi thêm', () {
      final snap = snapshot(remaining: 1200, paused: true);

      expect(snap.remainingAt(at(3600)), 1200);
      expect(snap.elapsedSecondsAt(at(3600)), 300);
    });
  });

  group('Hết hạn', () {
    test('quá 6 giờ thì không hỏi nữa', () {
      expect(snapshot().isExpiredAt(at(3600 * 5)), isFalse);
      expect(snapshot().isExpiredAt(at(3600 * 6)), isTrue);
    });

    test('vòng treo cả đêm cũng hết hạn dù đang tạm dừng', () {
      final snap = snapshot(remaining: 1200, anchor: null, startedAt: at(0));

      expect(snap.isExpiredAt(at(3600 * 7)), isTrue);
    });

    test('vòng hết hạn thì khôi phục ở trạng thái dừng, không chạy vô í', () {
      final clock = snapshot().restoreClock(now: at(3600 * 7));

      expect(clock.isRunning, isFalse);
      expect(clock.remainingAt(at(3600 * 7)), 0);
    });
  });

  group('Khôi phục đồng hồ', () {
    test('giữ mốc bắt đầu gốc, không trôi theo số lần app bị kill', () {
      final clock = snapshot(remaining: 1500, startedAt: at(0))
          .restoreClock(now: at(300));

      expect(clock.startedAt, at(0));
      expect(clock.remainingAt(at(300)), 1200);
      expect(clock.isRunning, isTrue);
    });

    test('tiếp tục chạy thì neo vào lúc mở app, không neo vào lúc kill', () {
      // Người dùng mở app nhưng chưa bấm gì: 5 phút đó không thuộc phiên học.
      final clock = snapshot(remaining: 1500).restoreClock(now: at(300));
      final later = at(600);

      expect(clock.remainingAt(later), 900);
    });

    test('tổng luôn khớp: đã học + còn lại = tổng thời lượng', () {
      final clock = snapshot(remaining: 1200).restoreClock(now: at(120));

      expect(clock.totalSeconds,
          clock.elapsedAt(at(120)) + clock.remainingAt(at(120)));
      expect(clock.elapsedAt(at(120)), 420);
      expect(clock.remainingAt(at(120)), 1080);
    });

    test('vòng tạm dừng thì khôi phục vẫn dừng', () {
      final clock =
          snapshot(remaining: 1200, paused: true).restoreClock(now: at(120));

      expect(clock.isRunning, isFalse);
      expect(clock.remainingAt(at(9999)), 1200);
    });
  });

  group('Chụp trạng thái từ đồng hồ đang chạy', () {
    test('lưu rồi đọc lại được, giữ nguyên số giây còn lại', () {
      final clock = running();
      repo.saveActive(ActiveStudySession.fromClock(
        clock: clock,
        taskId: 't1',
        taskTitle: 'On Toan',
        subject: 'Toan',
        round: 3,
      ));

      final restored = repo.getActive();
      expect(restored, isNotNull);
      expect(restored!.taskId, 't1');
      expect(restored.taskTitle, 'On Toan');
      expect(restored.round, 3);
      expect(restored.isBreak, isFalse);
      expect(restored.remainingAt(clock.anchorAt!), 1500);
      expect(restored.startedAt, at(0));
    });

    test('khoá là duy nhất: lưu vòng mới đè vòng cũ', () {
      repo.saveActive(snapshot());
      repo.saveActive(snapshot(remaining: 60));

      expect(repo.getActive()!.remainingAtAnchor, 60);
    });

    test('xoá thì không còn gì để hỏi', () {
      repo.saveActive(snapshot());
      repo.clearActive();

      expect(repo.getActive(), isNull);
    });

    test('JSON hỏng không làm sập màn hình', () {
      StorageService.setString(
          StudySessionRepository.activeSessionKey, '{khong phai json');
      expect(repo.getActive(), isNull);

      StorageService.setString(
          StudySessionRepository.activeSessionKey, '{"totalSeconds":0}');
      expect(repo.getActive(), isNull);
    });

    test('ảnh chụp sống dai qua vòng ghi/đọc', () {
      final snap = snapshot(remaining: 1234, isBreak: true);
      repo.saveActive(snap);

      final restored = repo.getActive()!;
      expect(restored.totalSeconds, 1500);
      expect(restored.remainingAtAnchor, 1234);
      expect(restored.isBreak, isTrue);
      expect(restored.elapsedSecondsAt(restored.anchorAt!), 1500 - 1234);
      expect(restored.startedAt, at(0));
    });
  });

  group('Trên màn hình thật', () {
    /// Ảnh chụp của một vòng chạy được 12 phút rồi bị kill 3 phút trước:
    /// còn 780s = 13 phút.
    void seedAbandoned() {
      repo.saveActive(ActiveStudySession(
        taskId: 't1',
        taskTitle: 'On tich phan',
        subject: 'Toan',
        totalSeconds: 1500,
        remainingAtAnchor: 1500,
        anchorAt: DateTime.now().subtract(const Duration(minutes: 12)),
        startedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        round: 1,
      ));
    }

    Future<void> pumpStudy(WidgetTester tester) async {
      // StudyScreen không tự bọc `Material`, nên test cần Scaffold bao ngoài —
      // giống hệt lúc nó nằm trong một tab thật.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StudyScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('mo lai thi hoi khoi phuc, ke ca so phut da hoc',
        (tester) async {
      seedAbandoned();
      await pumpStudy(tester);

      expect(find.text('Phiên học đang bỏ dở'), findsOneWidget);
      expect(find.textContaining('đã học 12 phút'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);
      expect(find.text('Kết thúc phiên'), findsOneWidget);
    });

    testWidgets('chon "Kết thúc phiên" thì ghi phiên cancelled và xoá anh chup',
        (tester) async {
      seedAbandoned();
      await pumpStudy(tester);

      await tester.tap(find.text('Kết thúc phiên'));
      await tester.pumpAndSettle();

      expect(repo.getActive(), isNull);
      final sessions = repo.getAll();
      expect(sessions, hasLength(1));
      expect(sessions.single.status, StudySession.statusCancelled);
      expect(sessions.single.actualMinutes, 12);
      expect(sessions.single.startedAt, isNotNull);
      expect(sessions.single.plannedMinutes, 25);
    });

    testWidgets('vong moi mo man hinh thi khong hoi gì ca', (tester) async {
      await pumpStudy(tester);

      expect(find.text('Phiên học đang bở dở'), findsNothing);
      expect(find.text('Phiên học đang bỏ dở'), findsNothing);
      expect(repo.getActive(), isNull);
    });

    testWidgets('vong da hoc duoi 1 phut thi bo qua, khong lam phiền',
        (tester) async {
      repo.saveActive(ActiveStudySession(
        taskId: 't1',
        subject: 'Toan',
        totalSeconds: 1500,
        remainingAtAnchor: 1495,
        anchorAt: DateTime.now(),
        startedAt: DateTime.now(),
      ));
      await pumpStudy(tester);

      expect(find.text('Phiên học đang bỏ dở'), findsNothing);
      expect(repo.getActive(), isNull);
    });

    testWidgets('vong het gio thi khong hoi, chi dung 1 phut da hoc',
        (tester) async {
      repo.saveActive(ActiveStudySession(
        taskId: 't1',
        subject: 'Toan',
        totalSeconds: 1500,
        remainingAtAnchor: 300,
        anchorAt: DateTime.now().subtract(const Duration(minutes: 10)),
        startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ));
      await pumpStudy(tester);

      expect(find.text('Phiên học đang bỏ dở'), findsNothing);
      expect(repo.getActive(), isNull);
    });

    testWidgets('anh chup qua han 6 gio thi tu don, khong hoi', (tester) async {
      // Ảnh chụp tạm dừng còn giờ nhưng đã quá hạn: nếu hỏi, người dùng bấm
      // "Tiếp tục" sẽ được một đồng hồ không chạy (đứng yên vĩnh viễn).
      repo.saveActive(ActiveStudySession(
        taskId: 't1',
        subject: 'Toan',
        totalSeconds: 1500,
        remainingAtAnchor: 900,
        anchorAt: null,
        startedAt: DateTime.now().subtract(const Duration(hours: 7)),
      ));
      await pumpStudy(tester);

      expect(find.text('Phiên học đang bỏ dở'), findsNothing);
      expect(repo.getActive(), isNull);
    });

    testWidgets('autoStart van hoi khoi phuc truoc khi bat dau vong moi',
        (tester) async {
      seedAbandoned();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StudyScreen(autoStart: true)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Phiên học đang bỏ dở'), findsOneWidget);

      // Chọn "Kết thúc phiên": phiên cũ được ghi, rồi mới bắt đầu vòng mới —
      // ảnh chụp của phiên cũ không bị ghi đè âm thầm.
      await tester.tap(find.text('Kết thúc phiên'));
      await tester.pumpAndSettle();

      expect(repo.getAll(), hasLength(1));
      expect(repo.getAll().single.status, StudySession.statusCancelled);
    });
  });
}
