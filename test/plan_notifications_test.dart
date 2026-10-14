import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/notifications/plan_notifications.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

StudySession session(DateTime at, {int minutes = 30}) => StudySession(
      id: 's',
      completedAt: at,
      subject: 'Toán',
      plannedMinutes: minutes,
      actualMinutes: minutes,
    );

void main() {
  test('weeklyReportId === NotificationService.weeklyReportId', () {
    // phòng tránh lệch id nếu copy sai.
    expect(weeklyReportId, 1004);
  });

  test('không bật → không lên lịch', () {
    final now = DateTime(2026, 3, 18, 10);
    final planned = planAdvancedNotifications(
      now: now,
      sessions: const [],
      streak: 3,
      weeklyEnabled: false,
      streakGuardEnabled: false,
    );
    expect(planned, isEmpty);
  });

  test('báo cáo tuần lên Chủ nhật kế tiếp', () {
    final now = DateTime(2026, 3, 18, 10); // Thứ Tư
    final planned = planAdvancedNotifications(
      now: now,
      sessions: [
        session(DateTime(2026, 3, 17, 9), minutes: 60),
        session(DateTime(2026, 3, 15, 20), minutes: 30),
      ],
      streak: 2,
      weeklyEnabled: true,
      weeklyHour: 19,
    );
    expect(planned.length, 1);
    expect(planned.first.id, weeklyReportId);
    expect(planned.first.when.weekday, DateTime.sunday);
    expect(planned.first.when.hour, 19);
    expect(planned.first.payload, 'leaderboard');
  });

  test('streakGuard chỉ nhắc khi chưa học hôm nay nhưng học hôm qua + sau 16h',
      () {
    final now = DateTime(2026, 3, 18, 19); // hôm nay (thứ Tư) 19h
    final planned = planAdvancedNotifications(
      now: now,
      sessions: [
        session(DateTime(2026, 3, 17, 21), minutes: 30), // học hôm qua
      ],
      streak: 5,
      streakGuardEnabled: true,
      guardHour: 20,
      guardAfterHour: 16,
    );
    expect(planned.length, 1);
    expect(planned.first.id, streakGuardId);
    expect(planned.first.when.hour, 20);
    expect(planned.first.payload, 'home');
  });

  test('đã học hôm nay → không nhắc streakGuard', () {
    final now = DateTime(2026, 3, 18, 19);
    final planned = planAdvancedNotifications(
      now: now,
      sessions: [
        session(DateTime(2026, 3, 17, 21), minutes: 30),
        session(DateTime(2026, 3, 18, 10), minutes: 25), // học hôm nay
      ],
      streak: 5,
      streakGuardEnabled: true,
    );
    expect(planned.any((p) => p.id == streakGuardId), isFalse);
  });

  test('chưa học hôm qua → không nhắc streakGuard', () {
    final now = DateTime(2026, 3, 18, 19);
    final planned = planAdvancedNotifications(
      now: now,
      sessions: [session(DateTime(2026, 3, 15, 10), minutes: 25)],
      streak: 3,
      streakGuardEnabled: true,
    );
    expect(planned.any((p) => p.id == streakGuardId), isFalse);
  });

  test('chưa đủ 16h hôm nay → không nhắc ngay', () {
    final now = DateTime(2026, 3, 18, 15);
    final planned = planAdvancedNotifications(
      now: now,
      sessions: [session(DateTime(2026, 3, 17, 21), minutes: 30)],
      streak: 3,
      streakGuardEnabled: true,
    );
    expect(planned.any((p) => p.id == streakGuardId), isFalse);
  });

  test('nội dung báo cáo tuần phản ánh số phút', () {
    final now = DateTime(2026, 3, 18, 10);
    final planned = planAdvancedNotifications(
      now: now,
      sessions: [
        session(DateTime(2026, 3, 17, 9), minutes: 90),
      ],
      streak: 1,
      weeklyEnabled: true,
    );
    expect(planned.first.body, contains('1 giờ 30 phút'));
  });
}
