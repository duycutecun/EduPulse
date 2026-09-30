import 'models/study_models.dart';

/// Optimize Week (đặc tả mục 13) — AI đề xuất lịch tuần từ signal
/// **thật có trong app**, không tự chế dữ liệu không có:
///
/// - **Deadline** của mỗi task (mục 13 liệt kê đầu tiên).
/// - **Priority** (high → xếp trước trong ngày).
/// - **Efficiency/energy theo khung giờ trong tuần**: lấy từ
///   [StudySession] đã lưu (completedAt + effectiveness/focus phản
///   ánh sau mỗi phiên — mục 11.9, 12.4) — học tốt lúc nào xếp môn
///   khó lúc đó; chưa có dữ liệu → mặc định buổi tối, có ghi rõ.
/// - **Quỹ thời gian còn trống trong ngày**: giả định công khai — mỗi
///   ngày tối đa [dailyCapacityMinutes], trừ các task đã xếp.
///
/// Kết quả là **diff** (chỉ task chưa xếp lịch), mỗi dòng kèm **lý do**
/// ngắn gọn; người dùng Accept / Edit / Reject từng dòng (mục 10.4,
/// 10.6 — AI chỉ đề xuất, không tự ghi đè).
class WeekPlanProposal {
  final TodayTask task;

  /// Thời điểm đề xuất (ngày + giờ bắt đầu).
  final DateTime proposedStart;

  /// Lý do ngắn gọn hiển thị cho người dùng.
  final String reason;

  const WeekPlanProposal({
    required this.task,
    required this.proposedStart,
    required this.reason,
  });
}

/// Slot 2 giờ buổi tối mặc định khi chưa có đủ dữ liệu phiên.
const int kDefaultDailyCapacityMinutes = 120;

const int kDefaultStartHour = 19;

/// Sinh đề xuất lịch cho các task chưa xếp lịch trong vòng 7 ngày tới.
///
/// [sessions] để trống → dùng khung mặc định 19h, lý do ghi rõ
/// "mặc định" (trung thực về nguồn đề xuất — mục 10.8).
/// [now] inject được cho test.
List<WeekPlanProposal> proposeWeekPlan(
  List<TodayTask> unscheduledTasks, {
  List<StudySession> sessions = const [],
  int dailyCapacityMinutes = kDefaultDailyCapacityMinutes,
  int startHour = kDefaultStartHour,
  DateTime? now,
}) {
  final base = now ?? DateTime.now();
  final today = DateTime(base.year, base.month, base.day);

  // ── Signal 1: năng lượng theo khung giờ từ phản hồi phiên ──────────
  // Chọn khung có effectiveness/focus trung bình cao nhất (≥ 2 phiên
  // mới kết luận — mục 12.4); thiếu dữ liệu → null, dùng mặc định.
  final hourBuckets = <int, List<int>>{};
  for (final s in sessions) {
    final rating = s.effectiveness ?? s.focus;
    if (rating == null) continue;
    final bucket = s.completedAt.hour < 12 ? 0 : (s.completedAt.hour < 18 ? 1 : 2);
    (hourBuckets[bucket] ??= []).add(rating);
  }
  String bestBucketLabel = 'buổi tối';
  int? bestStartHour;
  for (final entry in hourBuckets.entries) {
    if (entry.value.length < 2) continue; // 1 phiên chưa đủ kết luận.
    final avg = entry.value.fold(0, (a, b) => a + b) / entry.value.length;
    // Threshold: mới chỉ dùng khi có tín hiệu rõ (avg ≥ 3.5/5).
    if (avg >= 3.5 && bestStartHour == null) {
      bestStartHour = switch (entry.key) {
        0 => 8, // sáng
        1 => 14, // chiều
        _ => 19, // tối
      };
      bestBucketLabel = switch (entry.key) {
        0 => 'buổi sáng',
        1 => 'buổi chiều',
        _ => 'buổi tối',
      };
    }
  }
  final effectiveStartHour = bestStartHour ?? startHour;
  if (bestStartHour == null) {
    bestBucketLabel = 'buổi tối (mặc định)';
  }

  // ── Signal 2: quỹ thời gian còn trống mỗi ngày ─────────────────────
  // Chỉ đề xuất cho task chưa xếp lịch; task đã xếp không bị đụng tới.
  final result = <WeekPlanProposal>[];

  // Task sort: deadline gần nhất trước, rồi priority, rồi thứ tự gốc.
  final ordered = List<TodayTask>.from(unscheduledTasks)
    ..sort((a, b) {
      final da = a.deadline;
      final db = b.deadline;
      if (da != null && db != null) {
        final c = da.compareTo(db);
        if (c != 0) return c;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }
      final pa = _priorityWeight(a.priority);
      final pb = _priorityWeight(b.priority);
      if (pa != pb) return pa - pb;
      return 0;
    });

  final dayLoad = List<int>.filled(7, 0);

  for (final task in ordered) {
    // Ngày bắt đầu tìm chỗ: hôm nay; deadline trong 7 ngày → tối đa
    // deadline - 1 (đề xuất xong trước deadline ít nhất 1 ngày).
    final deadline = task.deadline;
    var lastDay = 6;
    if (deadline != null) {
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      final diff = deadlineDay.difference(today).inDays;
      if (diff < 0) continue; // quá hạn — không đề xuất lại ở đây.
      lastDay = diff == 0 ? 0 : (diff - 1).clamp(0, 6);
    }

    // Tìm ngày đầu tiên còn chỗ.
    var chosen = -1;
    for (var d = 0; d <= lastDay; d++) {
      if (dayLoad[d] + task.estimateMinutes <= dailyCapacityMinutes) {
        chosen = d;
        break;
      }
    }
    if (chosen < 0) chosen = lastDay; // đầy → vẫn đề xuất ngày muộn nhất.

    dayLoad[chosen] += task.estimateMinutes;
    final start = DateTime(
      today.year, today.month, today.day + chosen, effectiveStartHour,
    );

    // ── Lý do ngắn gọn, trung thực về nguồn tín hiệu ─────────────────
    final reasons = <String>[];
    if (deadline != null) {
      final days = deadline.difference(today).inDays;
      reasons.add('deadline ${days <= 0 ? 'hôm nay' : 'sau $days ngày'}');
    }
    if (task.priority == 'high') reasons.add('ưu tiên cao');
    if (bestStartHour != null) {
      reasons.add('bạn học tốt $bestBucketLabel');
    }

    final reason = reasons.isEmpty
        ? 'Còn trống — xếp $bestBucketLabel, ${task.estimateMinutes} phút'
        : '${reasons.join(' • ')} • xếp $bestBucketLabel';

    result.add(WeekPlanProposal(
      task: task,
      proposedStart: start,
      reason: reason,
    ));
  }

  return result;
}

int _priorityWeight(String priority) => switch (priority) {
      'high' => 0,
      'medium' => 1,
      _ => 2,
    };
