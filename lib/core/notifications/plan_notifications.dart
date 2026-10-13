import '../../features/study/domain/models/study_models.dart';

/// Một thông báo nâng cao đã được lên kế hoạch (P2 — native/notification).
class PlannedNotification {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final String? payload;

  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    this.payload,
  });
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Tổng phút học trong tuần lịch (T2–CN) chứa [now].
int _minutesThisWeek(List<StudySession> sessions, DateTime now) {
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final end = monday.add(const Duration(days: 7));
  var total = 0;
  for (final s in sessions) {
    if (!s.completedAt.isBefore(monday) && s.completedAt.isBefore(end)) {
      total += s.actualMinutes;
    }
  }
  return total;
}

/// Lên kế hoạch thông báo nâng cao — **thuần**, không I/O, dễ kiểm thử.
///
/// Gồm hai loại (đều do người dùng bật/tắt trong màn Tôi):
/// 1. **Báo cáo tuần** ([weeklyReportId]): mỗi Chủ nhật [weeklyHour]:00 tóm tắt
///    số phút/phiên học của tuần vừa qua — một nhịp nhìn lại nhẹ nhàng.
/// 2. **Nhắc bảo vệ chuỗi** ([streakGuardId]): nếu đã học hôm qua, chưa học hôm
///    nay, còn chuỗi và đã quá [guardAfterHour] giờ → một nhắc dịu vào [guardHour].
///    Ngôn ngữ nhẹ nhàng, không ép (kế hoạch mục 44).
List<PlannedNotification> planAdvancedNotifications({
  required DateTime now,
  required List<StudySession> sessions,
  required int streak,
  bool weeklyEnabled = false,
  bool streakGuardEnabled = false,
  int weeklyHour = 19,
  int guardHour = 20,
  int guardAfterHour = 16,
}) {
  final planned = <PlannedNotification>[];

  if (weeklyEnabled) {
    // Chủ nhật kế tiếp (luôn sau `now` ít nhất 1 phút).
    var daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
    var when = DateTime(now.year, now.month, now.day + daysUntilSunday, weeklyHour);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 7));
    }

    final weekMinutes = _minutesThisWeek(sessions, now);
    final hours = weekMinutes ~/ 60;
    final minutes = weekMinutes % 60;
    final span = hours > 0
        ? (minutes > 0 ? '$hours giờ $minutes phút' : '$hours giờ')
        : '$minutes phút';
    final body = weekMinutes > 0
        ? 'Tuần này bạn học $span. Mỗi tuần một chút — cả năm một bước tiến.'
        : 'Tuần mới bắt đầu — đặt một mục tiêu nhỏ và bắt đầu nhé!';

    planned.add(PlannedNotification(
      id: weeklyReportId,
      when: when,
      title: 'Tổng kết tuần học 📊',
      body: body,
      payload: 'leaderboard',
    ));
  }

  if (streakGuardEnabled && streak > 0) {
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final studiedToday =
        sessions.any((s) => _dateKey(s.completedAt) == today);
    final studiedYesterday =
        sessions.any((s) => _dateKey(s.completedAt) == yesterday);

    final when = DateTime(now.year, now.month, now.day, guardHour);
    if (!studiedToday &&
        studiedYesterday &&
        now.hour >= guardAfterHour &&
        when.isAfter(now)) {
      planned.add(PlannedNotification(
        id: streakGuardId,
        when: when,
        title: 'Giữ chuỗi $streak ngày 🔥',
        body: 'Chỉ 15 phút nữa là hôm nay vẫn trọn vẹn — bắt đầu ngay nhé!',
        payload: 'home',
      ));
    }
  }

  return planned;
}

/// Id thông báo báo cáo tuần.
const int weeklyReportId = 1004;

/// Id thông báo nhắc bảo vệ chuỗi.
const int streakGuardId = 1005;

/// Ghi chú: giữ chữ ký id ở cuối để tránh vòng import — planner dùng hằng này,
/// NotificationService có thể tham chiếu lại cùng giá trị.
String planDebugSummary(List<PlannedNotification> planned) =>
    planned.map((p) => '#${p.id}@${_shortDate(p.when)}').join(', ');
