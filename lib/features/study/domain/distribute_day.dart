import 'models/study_models.dart';
import 'optimize_week.dart';

/// Một đề xuất dời task từ hôm nay sang ngày khác (Phân bố hợp lý).
class MoveProposal {
  final TodayTask task;

  /// Ngày + giờ bắt đầu đề xuất (mặc định 19:00 của ngày còn quỹ).
  final DateTime proposedStart;

  /// Lý do ngắn gọn hiển thị cho học sinh.
  final String reason;

  const MoveProposal({
    required this.task,
    required this.proposedStart,
    required this.reason,
  });
}

/// Phân bố task hợp lý theo ngày — đáp ứng nguyện vọng "task chung phân bố
/// cho từng ngày sao cho hợp lý".
///
/// Nguyên tắc (thừa kế đặc tả mục 13 — AI chỉ ĐỀ XUẤT):
/// - **Quỹ ngày**: mỗi ngày tối đa [kDailyBudgetMinutes] phút nhiệm vụ —
///   cùng một giả định công khai với Optimize Week (mục 13).
/// - **Chỉ đề xuất khi thật sự cần**: hôm nay nhẹ hơn quỹ thì không có gì
///   để dời (không quấy rầy — Calm principle).
/// - **Không bao giờ dời**: task đã xong/bỏ qua, task có deadline hôm nay
///   hoặc đã quá hạn, và task đã được xếp giờ cụ thể trong hôm nay
///   (scheduledAt hôm nay — học sinh đã chủ động chốt khung giờ).
/// - **Dời trước mức ưu tiên thấp** — phần dễ chuyển nhất chuyển trước.
/// - **Ngày nhận**: ngày kế tiếp còn dư quỹ; không dời task vào đúng ngày
///   deadline của nó (cùng margin an toàn ≥1 ngày như Optimize Week).
List<MoveProposal> proposeDayBalance({
  required List<TodayTask> tasks,
  int budgetMinutes = kDefaultDailyCapacityMinutes,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);

  // Quỹ đã dùng hôm nay: TỔNG estimate của mọi task đang "nằm" hôm nay —
  // task chưa xếp lịch cũng tính, vì học sinh nhìn kế hoạch hôm nay là tất
  // cả những gì hiện trong thẻ Nhiệm vụ hôm nay.
  final todayTasks = tasks
      .where((t) => !t.isDone && t.status != 'skipped')
      .where((t) =>
          t.scheduledAt == null ||
          DateTime(t.scheduledAt!.year, t.scheduledAt!.month,
                  t.scheduledAt!.day) ==
              today)
      .toList();

  var load = todayTasks.fold(0, (sum, t) => sum + t.estimateMinutes);
  if (load <= budgetMinutes) return const []; // hôm nay hợp lý rồi.

  // Ứng viên dời: chưa xong, không deadline gắt hôm nay/đã quá hạn.
  bool movable(TodayTask t) {
    final dl = t.deadline;
    if (dl != null) {
      final dlDay = DateTime(dl.year, dl.month, dl.day);
      if (!dlDay.isAfter(today)) return false; // deadline hôm nay hoặc quá hạn.
    }
    return true;
  }

  final candidates = todayTasks.where(movable).toList()
    ..sort((a, b) {
      // Ưu tiên dời mức thấp trước, rồi task dài trước (giảm tải nhanh).
      final pa = _priorityWeight(a.priority);
      final pb = _priorityWeight(b.priority);
      if (pa != pb) return pb - pa; // weight lớn = mức thấp → trước.
      return b.estimateMinutes - a.estimateMinutes;
    });

  // Quỹ các ngày kế tiếp (đếm task đã "nằm" sẵn ở ngày đó).
  int dayIndex(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(today).inDays;
  final futureLoad = <int, int>{};
  for (final t in tasks) {
    if (t.isDone || t.status == 'skipped' || t.scheduledAt == null) continue;
    final idx = dayIndex(t.scheduledAt!);
    if (idx > 0 && idx < 7) {
      futureLoad[idx] = (futureLoad[idx] ?? 0) + t.estimateMinutes;
    }
  }

  final proposals = <MoveProposal>[];
  for (final task in candidates) {
    if (load <= budgetMinutes) break; // đủ nhẹ rồi — dừng.
    // Tìm ngày kế đầu tiên còn quỹ (≥1 ngày sau hôm nay).
    var day = -1;
    for (var i = 1; i < 7; i++) {
      final used = futureLoad[i] ?? 0;
      if (used + task.estimateMinutes <= budgetMinutes) {
        day = i;
        break;
      }
    }
    if (day < 0) continue; // tuần đầy — không ép dời.

    futureLoad[day] = (futureLoad[day] ?? 0) + task.estimateMinutes;
    load -= task.estimateMinutes;

    proposals.add(MoveProposal(
      task: task,
      proposedStart: DateTime(
          today.year, today.month, today.day + day, kDefaultStartHour),
      reason: 'Hôm nay đang nặng hơn quỹ $budgetMinutes phút '
          '• dời bớt để mỗi ngày một lượng vừa sức',
    ));
  }

  return proposals;
}

int _priorityWeight(String priority) => switch (priority) {
      'high' => 0,
      'medium' => 1,
      _ => 2,
    };
