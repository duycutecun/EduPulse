import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';
import 'package:edupulse/features/study/domain/focus_clock.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V2-M1' — phiên Pomodoro phải sống sót qua "kill app" nhờ mốc thời gian thật
/// (timestamp-based) thay vì dựa vào số lần tick của Timer.periodic.
///
/// Mục tiêu đo được: sau khi app bị kill → reopen, đồng hồ vẫn bám thời gian đã
/// trôi theo `DateTime`, không mất phút học và `pausedAccumMs` được lưu/ch팔 lại
/// nhất quán qua SharedPreferences.
void main() {
  late StudySessionRepository repo;

  final t0 = DateTime(2026, 5, 1, 8);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo = StudySessionRepository.instance;
  });

  group('timestamp-based session survives kill', () {
    test('khi app bị kill giữa phiên chạy, reopen vẫn còn đúng thời gian', () {
      final clock = FocusClock(totalSeconds: 1500)..start(at(0));

      repo.saveActive(ActiveStudySession.fromClock(
        clock: clock,
        taskId: 'kill-1',
        taskTitle: 'Task Kill',
        subject: 'Toan',
        round: 1,
        now: at(0),
      ));

      // Khỏi động lại 300s sau: snapshot neo tại at(0), reopen tại at(300).
      final killAt = at(300);
      final restored = repo.getActive();
      expect(restored, isNotNull, reason: 'snapshot phải tồn tại sau kill');
      expect(restored!.remainingAt(killAt), 1200,
          reason: 'phải còn đúng 1200s, không tick-based drift');
      // pausedAccumMs chụp ở at(0) → 0 (vòng đang neo); intermediates được tính lại qua anchor.
      expect(restored.pausedAccumMs, 0);
    });

    test('phần còn lại không bị tick-based mất đi khi app reopening muộn', () {
      final clock = FocusClock(totalSeconds: 600)..start(at(0));

      repo.saveActive(ActiveStudySession.fromClock(
        clock: clock,
        taskId: 'kill-2',
        taskTitle: 'Long',
        subject: 'Ly',
        round: 2,
        now: at(0),
      ));

      // Mở lại sau 450s thì còn 150s; nếu là tick-based thì giữ y nguyên 600.
      final reopened = repo.getActive();
      expect(reopened, isNotNull);
      expect(reopened!.remainingAt(at(450)), 150);
      expect(reopened.elapsedSecondsAt(at(450)), 450);
      expect(reopened.pausedAccumMs, 0,
          reason: 'vòng đang chạy → pausedAccumMs tại snapshot = 0');
    });

    test('khi vòng bị tạm dừng, pausedAccumMs giữ số giây đã học', () {
      final clock = FocusClock(totalSeconds: 1500)..start(at(0));
      // Chạy 200s rồi tạm dừng.
      clock.pause(at(200));

      repo.saveActive(ActiveStudySession.fromClock(
        clock: clock,
        taskId: 'pause-1',
        taskTitle: 'Paused',
        subject: 'Hoa',
        round: 1,
      ));

      final restored = repo.getActive()!;
      expect(restored.anchorAt, isNull, reason: 'dừng rồi thì không anchor');
      // round-trip pausedAccumMs = 200
      expect(restored.pausedAccumMs, 200);
      expect(restored.remainingAt(at(9999)), 1300,
          reason: 'tạm dừng không trôi thêm');
    });

    test('chụp RTL survival qua SharedPreferences: pausedAccumMs round-trips',
        () async {
      final clock = FocusClock(totalSeconds: 1500)..start(at(0));
      clock.pause(at(200));

      repo.saveActive(ActiveStudySession.fromClock(
        clock: clock,
        taskId: 'rt-1',
        taskTitle: 'Round Trip',
        subject: 'Sinh',
        round: 4,
      ));

      // Simulate kill: reopen simulated by reading from storage again.
      final reRead = repo.getActive();
      expect(reRead, isNotNull);
      expect(reRead!.pausedAccumMs, clock.elapsedAt(at(200)));
      expect(reRead.remainingAt(at(9999)), reRead.remainingAtAnchor);

      // pausedAccumMs phải nhất quán: всего загруженное не может превышать total.
      expect(reRead.pausedAccumMs, lessThanOrEqualTo(reRead.totalSeconds));
    });
  });

  group('timestamp-based elapsed không phụ thuộc tick', () {
    test(
        'remainingAtAnchor = totalSeconds - pausedAccumMs (invariant preserved)',
        () {
      final clock = FocusClock(totalSeconds: 1200)..start(at(0));
      clock.pause(at(450));

      expect(clock.remainingAt(at(450)), 750);
      expect(clock.elapsedAt(at(450)), 450);

      final snap = ActiveStudySession.fromClock(
        clock: clock,
        taskId: 'inv-1',
        taskTitle: 'Invariant',
        subject: 'Van',
        round: 1,
      );
      expect(snap.pausedAccumMs + snap.remainingAtAnchor, snap.totalSeconds);
    });
  });
}
