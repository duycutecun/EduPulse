import 'models/study_models.dart';

/// Một dòng trong nhật ký học, đã gộp hai nguồn vốn là hai bảng riêng.
///
/// Vấn đề gốc: mỗi vòng Pomodoro ghi **hai** bản ghi cho cùng một khoảng
/// thời gian — một `StudyLog` (giờ thập phân) và một `StudySession` (phút
/// nguyên, có phản hồi). Hệ quả là thời gian học bị đếm hai lần ở mọi nơi
/// tổng hợp, và hai bảng lệch nhau khi người dùng sửa/xoá ở một bên.
///
/// Nay quy ước rõ ràng:
/// - **Pomodoro/phiên học thật** → `StudySession` (có `startedAt`, phản hồi).
/// - **Ghi chép nhập tay** → `StudyLog`. Không có phiên học thật nào đứng sau,
///   nên không giả vờ nó là một phiên.
class StudyTimelineEntry {
  /// ID của bản ghi gốc (`StudyLog.id` hoặc `StudySession.id`).
  final String id;

  /// `true` nếu dòng này đến từ `StudySession` — quyết định **xoá ở đâu**.
  final bool fromSession;

  final DateTime date;
  final String subject;
  final double hours;
  final String? note;

  /// Task liên quan, chỉ có với dòng từ phiên học.
  final String? taskId;

  const StudyTimelineEntry({
    required this.id,
    required this.fromSession,
    required this.date,
    required this.subject,
    required this.hours,
    this.note,
    this.taskId,
  });

  /// Từ một `StudyLog` (ghi chép nhập tay).
  factory StudyTimelineEntry.fromLog(StudyLog log) => StudyTimelineEntry(
        id: log.id,
        fromSession: false,
        date: log.date,
        subject: log.subject,
        hours: log.hours,
        note: log.note,
      );

  /// Từ một `StudySession` (phiên học thật).
  factory StudyTimelineEntry.fromSession(StudySession session) =>
      StudyTimelineEntry(
        id: session.id,
        fromSession: true,
        date: session.completedAt,
        subject: session.subject,
        hours: session.actualMinutes / 60,
        note: session.reflectionNote,
        taskId: session.taskId,
      );
}

/// Gộp hai nguồn thành một danh sách, mới nhất trước.
List<StudyTimelineEntry> buildStudyTimeline({
  required List<StudyLog> logs,
  required List<StudySession> sessions,
}) {
  final entries = <StudyTimelineEntry>[
    for (final log in logs) StudyTimelineEntry.fromLog(log),
    for (final session in sessions) StudyTimelineEntry.fromSession(session),
  ];
  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
}

/// Tổng giờ học của một danh sách dòng nhật ký.
double totalHoursOf(List<StudyTimelineEntry> entries) =>
    entries.fold(0.0, (sum, entry) => sum + entry.hours);
