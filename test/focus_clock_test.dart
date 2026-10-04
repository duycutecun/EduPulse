import 'package:edupulse/features/study/domain/focus_clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// FE-3.2 — đồng hồ đếm ngược neo theo mốc thời gian thật.
void main() {
  // Mốc cố định để test không phụ thuộc thời gian thật.
  final t0 = DateTime(2026, 5, 1, 8);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  group('Tính thời gian còn lại', () {
    test('chưa bấm bắt đầu thì giữ nguyên tổng', () {
      final clock = FocusClock(totalSeconds: 1500);

      expect(clock.isRunning, isFalse);
      expect(clock.remainingAt(at(0)), 1500);
      expect(clock.elapsedAt(at(600)), 0);
    });

    test('đếm theo thời gian đã trôi, không theo số lần tick', () {
      final clock = FocusClock(totalSeconds: 1500)..start(at(0));

      // App bị vùy 10 phút: chỉ có 3 tick được gọi trong khi đó.
      for (final t in [at(300), at(600), at(900)]) {
        expect(clock.remainingAt(t), 1500 - t.difference(t0).inSeconds);
      }
      expect(clock.remainingAt(at(600)), 900);
      expect(clock.elapsedAt(at(600)), 600);
    });

    test('không âm khi vượt quá thời lượng', () {
      final clock = FocusClock(totalSeconds: 60)..start(at(0));

      expect(clock.remainingAt(at(120)), 0);
      expect(clock.elapsedAt(at(120)), 60);
    });

    test('bỏ qua phần giây lẻ thay vì làm tròn kiểu tick', () {
      final clock = FocusClock(totalSeconds: 100)..start(at(0));

      // Tick đầu tiên của `Timer.periodic(1s)` chạy ở ~1.0s; nếu app bị vùy
      // thì nó chạy muộn hơn nhiều, nên phải dùng phần nguyên đã trôi.
      expect(clock.remainingAt(at(0)), 100);
      expect(clock.remainingAt(t0.add(const Duration(milliseconds: 999))), 100);
      expect(clock.remainingAt(t0.add(const Duration(milliseconds: 1000))), 99);
    });
  });

  group('Tạm dừng và tiếp tục', () {
    test('tạm dừng giữ đúng số giây còn lại', () {
      final clock = FocusClock(totalSeconds: 1500)..start(at(0));
      clock.pause(at(300));

      expect(clock.isRunning, isFalse);
      expect(clock.remainingAt(at(300)), 1200);
      // Thời gian trôi trong lúc dừng không bị trừ.
      expect(clock.remainingAt(at(3600)), 1200);
    });

    test('tạm dừng không làm mất phần đã học khi tiếp tục', () {
      final clock = FocusClock(totalSeconds: 1500)..start(at(0));
      clock.pause(at(300));

      clock.start(at(1200)); // dừng 15 phút rồi tiếp tục
      expect(clock.remainingAt(at(1200)), 1200);
      expect(clock.remainingAt(at(1500)), 900);
      expect(clock.elapsedAt(at(1500)), 600);
    });

    test('gọi start hai lần không reset âm thầm', () {
      final clock = FocusClock(totalSeconds: 1500)
        ..start(at(0))
        ..start(at(600));

      expect(clock.remainingAt(at(600)), 900);
    });

    test('gọi pause khi đã dừng là không-op', () {
      final clock = FocusClock(totalSeconds: 1500)..pause(at(600));

      expect(clock.remainingAt(at(600)), 1500);
      expect(clock.elapsedAt(at(600)), 0);
    });
  });

  group('Mốc thời gian thật của phiên', () {
    test('startedAt là lần bấm đầu tiên, không phải lần bấm sau', () {
      final clock = FocusClock(totalSeconds: 1500)
        ..start(at(0))
        ..pause(at(600))
        ..start(at(900));

      expect(clock.startedAt, at(0));
      // Mốc đang chạy là lần bấm gần nhất — dùng để chụp ảnh phiên.
      expect(clock.anchorAt, at(900));
    });

    test('chưa bấm bắt đầu thì không có startedAt (không bịa mốc)', () {
      expect(FocusClock(totalSeconds: 60).startedAt, isNull);
    });

    test('reset xoá cả mốc bắt đầu và số đã học', () {
      final clock = FocusClock(totalSeconds: 1500)
        ..start(at(0))
        ..pause(at(300))
        ..reset();

      expect(clock.remainingAt(at(300)), 1500);
      expect(clock.elapsedAt(at(300)), 0);
      expect(clock.startedAt, isNull);
      expect(clock.hasStarted, isFalse);
    });
  });

  group('withTotal khi đổi cài đặt giữa chừng', () {
    test('giữ số giây đã học khi vòng dài hơn', () {
      final clock = FocusClock(totalSeconds: 1500)
        ..start(at(0))
        ..pause(at(300));
      // `withTotal` lấy mốc hiện tại để neo, nên truyền `now` thật ở đây.
      final longer = clock.withTotal(3000);

      expect(longer.elapsedAt(DateTime.now()), 300);
      expect(longer.remainingAt(DateTime.now()), 2700);
      expect(longer.startedAt, clock.startedAt);
    });

    test('vòng ngắn hơn không âm và coi phần dư là chưa học', () {
      final clock = FocusClock(totalSeconds: 3000)..start(at(0));
      final shorter = clock.withTotal(600);

      expect(shorter.remainingAt(DateTime.now()), 0);
      expect(shorter.elapsedAt(DateTime.now()), 600);
    });
  });

  group('Kiểm tra đầu vào và định dạng', () {
    test('từ chối thời lượng âm', () {
      expect(() => FocusClock(totalSeconds: -1), throwsArgumentError);
    });

    test('định dạng mm:ss và h:mm:ss', () {
      final clock = FocusClock(totalSeconds: 3661);

      expect(clock.formatSeconds(0), '00:00');
      expect(clock.formatSeconds(59), '00:59');
      expect(clock.formatSeconds(600), '10:00');
      expect(clock.formatSeconds(3661), '1:01:01');
      expect(clock.formatSeconds(-5), '00:00');
    });
  });
}