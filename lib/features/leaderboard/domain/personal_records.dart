import '../../study/domain/models/study_models.dart';
import '../../study/domain/weekly_summary.dart';

/// Một dòng "kỷ lục" trong Bảng vàng cá nhân (P2 — mở rộng leaderboard).
class PersonalRecord {
  final String id;
  final String emoji;
  final String title;

  /// Giá trị đã định dạng sẵn để hiển thị (vd "1 giờ 30 phút", "8.5 điểm").
  final String value;

  /// Chi tiết phụ (môn, ngày…) nếu có.
  final String? detail;

  /// Kỷ lục đáng nhấn mạnh (huy chương vàng).
  final bool highlight;

  const PersonalRecord({
    required this.id,
    required this.emoji,
    required this.title,
    required this.value,
    this.detail,
    this.highlight = false,
  });
}

/// Kết quả tính Bảng vàng kỷ lục từ dữ liệu cục bộ.
class PersonalRecords {
  final List<PersonalRecord> records;
  final bool hasData;
  final int totalSessions;
  final int totalMinutes;

  const PersonalRecords({
    required this.records,
    required this.hasData,
    required this.totalSessions,
    required this.totalMinutes,
  });

  static const PersonalRecords empty = PersonalRecords(
    records: [],
    hasData: false,
    totalSessions: 0,
    totalMinutes: 0,
  );
}

/// Định dạng số phút thành chuỗi tiếng Việt gọn (vd 95 → "1 giờ 35 phút").
String formatStudyMinutes(int minutes) {
  if (minutes <= 0) return '0 phút';
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours giờ';
  return '$hours giờ $rest phút';
}

String _shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String _shortWeek(DateTime weekStart) => _shortDate(weekStart);

/// Tính Bảng vàng kỷ lục **thuần** từ dữ liệu học tập (không I/O, dễ kiểm thử).
///
/// Cố ý **không** hồi sinh bảng xếp hạng toàn cầu trực tuyến: xếp hạng người
/// học khác sẽ đẩy dữ liệu học lên mạng, trái nguyên tắc riêng tư của kế hoạch.
/// Bảng vàng ở đây là cuộc đua với chính mình — và gia đình đã có màn riêng.
PersonalRecords computePersonalRecords({
  required List<StudySession> sessions,
  required List<MockScore> scores,
  required int streak,
  required int streakRecord,
  int notesCount = 0,
  DateTime? now,
}) {
  final records = <PersonalRecord>[];
  final totalMinutes =
      sessions.fold<int>(0, (sum, s) => sum + s.actualMinutes);
  final hasData = sessions.isNotEmpty ||
      scores.isNotEmpty ||
      streak > 0 ||
      streakRecord > 0 ||
      notesCount > 0;

  if (!hasData) return PersonalRecords.empty;

  // 1. Phiên học dài nhất.
  if (sessions.isNotEmpty) {
    final longest =
        sessions.reduce((a, b) => b.actualMinutes > a.actualMinutes ? b : a);
    records.add(PersonalRecord(
      id: 'longest_session',
      emoji: '⏳',
      title: 'Phiên học dài nhất',
      value: formatStudyMinutes(longest.actualMinutes),
      detail: '${longest.subject} · ${_shortDate(longest.completedAt)}',
    ));
  }

  // 2. Ngày học nhiều nhất (theo phút thực tế).
  if (sessions.isNotEmpty) {
    final byDay = <String, int>{};
    final dayRef = <String, DateTime>{};
    for (final s in sessions) {
      final d = s.completedAt;
      final key = '${d.year}-${d.month}-${d.day}';
      byDay[key] = (byDay[key] ?? 0) + s.actualMinutes;
      dayRef[key] = DateTime(d.year, d.month, d.day);
    }
    final bestDay = byDay.entries.reduce(
        (a, b) => b.value > a.value ? b : a);
    records.add(PersonalRecord(
      id: 'busiest_day',
      emoji: '📅',
      title: 'Ngày học nhiều nhất',
      value: formatStudyMinutes(bestDay.value),
      detail: _shortDate(dayRef[bestDay.key]!),
    ));
  }

  // 3. Tuần học nhiều nhất (tuần lịch Thứ 2 → Chủ nhật).
  if (sessions.isNotEmpty) {
    final byWeek = <String, int>{};
    final weekRef = <String, DateTime>{};
    for (final s in sessions) {
      final start = weekStartOf(s.completedAt);
      final key = '${start.year}-${start.month}-${start.day}';
      byWeek[key] = (byWeek[key] ?? 0) + s.actualMinutes;
      weekRef[key] = start;
    }
    final bestWeek = byWeek.entries.reduce(
        (a, b) => b.value > a.value ? b : a);
    records.add(PersonalRecord(
      id: 'best_week',
      emoji: '🗓️',
      title: 'Tuần học nhiều nhất',
      value: formatStudyMinutes(bestWeek.value),
      detail: 'Tuần ${_shortWeek(weekRef[bestWeek.key]!)}',
    ));
  }

  // 4. Chuỗi ngày hiện tại + 5. kỷ lục chuỗi.
  if (streak > 0) {
    records.add(PersonalRecord(
      id: 'current_streak',
      emoji: '🔥',
      title: 'Chuỗi ngày hiện tại',
      value: '$streak ngày',
      detail: streakRecord > 0 ? 'Kỷ lục: $streakRecord ngày' : null,
    ));
  }
  if (streakRecord > 0) {
    records.add(PersonalRecord(
      id: 'streak_record',
      emoji: '🏆',
      title: 'Kỷ lục chuỗi ngày',
      value: '$streakRecord ngày',
      highlight: streak >= streakRecord,
      detail: streak >= streakRecord ? 'Đang giữ kỷ lục!' : null,
    ));
  }

  // 6. Điểm thi thử cao nhất.
  if (scores.isNotEmpty) {
    final best = scores.reduce((a, b) => b.score > a.score ? b : a);
    records.add(PersonalRecord(
      id: 'best_score',
      emoji: '🎯',
      title: 'Điểm thi thử cao nhất',
      value: '${best.score.toStringAsFixed(1)} điểm',
      detail: '${best.subject} · ${_shortDate(best.date)}',
    ));
  }

  // 7. Tổng thời gian học.
  if (totalMinutes > 0) {
    records.add(PersonalRecord(
      id: 'total_time',
      emoji: '🧭',
      title: 'Tổng thời gian học',
      value: formatStudyMinutes(totalMinutes),
      detail: '${sessions.length} phiên học',
    ));
  }

  // 8. Số lần thi thử.
  if (scores.isNotEmpty) {
    records.add(PersonalRecord(
      id: 'score_count',
      emoji: '🧮',
      title: 'Số lần thi thử',
      value: '${scores.length} lần',
    ));
  }

  // 9. Ghi chú đã lưu.
  if (notesCount > 0) {
    records.add(PersonalRecord(
      id: 'notes_count',
      emoji: '📒',
      title: 'Ghi chú đã lưu',
      value: '$notesCount ghi chú',
    ));
  }

  return PersonalRecords(
    records: records,
    hasData: hasData,
    totalSessions: sessions.length,
    totalMinutes: totalMinutes,
  );
}
