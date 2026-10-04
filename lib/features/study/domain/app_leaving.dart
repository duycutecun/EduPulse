/// App-leaving pattern (đặc tả mục 11.5): nếu người dùng **thường xuyên
/// rời app giữa phiên focus** → gợi ý nhẹ nhàng, không tạo áp lực:
/// - Gentle reminder (đã rời app N lần gần đây)
/// - Break suggestion (rời app nhiều → có vẻ cần nghỉ)
/// - Shorter session (phiên dài hay bị bỏ dở → gợi ý phiên ngắn hơn)
/// - Pattern analysis (chỉ nội bộ, không kết luận cứng nhắc)
///
/// Nguyên tắc áp dụng: **hypothesis ≠ fact** (mục 36) — mọi câu trả
/// lời dùng "có vẻ/thử"; thiếu dữ liệu → null (mục 10.8); ngưỡng đủ
/// cao để không biến thành nudge ép học (mục 44 — không dùng streak ép).
class AppLeavingEvent {
  /// Phiên bị rời giữa chừng (không hoàn thành).
  final int plannedMinutes;

  /// Phút đã học trước khi rời.
  final int studiedMinutes;

  const AppLeavingEvent({
    required this.plannedMinutes,
    required this.studiedMinutes,
  });

  /// true nếu phiên này bị bỏ dở dưới một nửa kế hoạch.
  bool get abandoned => studiedMinutes < plannedMinutes / 2;
}

/// Kết quả phân tích pattern rời app.
class AppLeavingInsight {
  /// Số phiên bị bỏ dở gần đây (trong mẫu đã cho).
  final int abandonedCount;

  /// Tổng phiên trong mẫu phân tích.
  final int sampleCount;

  /// Loại gợi ý: 'reminder' | 'break' | 'shorter' | null.
  final String? kind;

  /// Câu gợi ý hiển thị cho người dùng (null khi chưa đủ dữ liệu).
  final String? message;

  /// Số phút gợi ý cho phiên ngắn hơn (chỉ khi kind == 'shorter').
  final int? suggestedMinutes;

  const AppLeavingInsight({
    required this.abandonedCount,
    required this.sampleCount,
    this.kind,
    this.message,
    this.suggestedMinutes,
  });

  /// Chưa đủ dữ liệu để nói gì cả.
  static const AppLeavingInsight none = AppLeavingInsight(
    abandonedCount: 0,
    sampleCount: 0,
  );
}

/// Phân tích các sự kiện rời app gần đây (sort mới → cũ, lấy tối đa
/// 10 sự kiện gần nhất — pattern gần mới phản ánh hiện tại).
///
/// Ngưỡng: cần **≥ 3 sự kiện** và **≥ 2 phiên bỏ dở** mới nói gì —
/// 1-2 lần rời app là bình thường, không đáng gợi ý gì cả.
AppLeavingInsight analyzeAppLeaving(List<AppLeavingEvent> recentEvents) {
  final sample = recentEvents.take(10).toList();
  if (sample.length < 3) {
    return AppLeavingInsight.none;
  }

  final abandoned = sample.where((e) => e.abandoned).toList();
  if (abandoned.length < 2) {
    return AppLeavingInsight(
      abandonedCount: abandoned.length,
      sampleCount: sample.length,
    );
  }

  // Ưu tiên gợi ý phù hợp nhất theo pattern:
  // 1. Phiên dài hay bị bỏ dở → gợi ý phiên ngắn hơn (cụ thể nhất).
  // 2. Rời app nhiều gần đây → break suggestion.
  // 3. Còn lại → gentle reminder về việc quay lại.
  final longAbandoned = abandoned.where((e) => e.plannedMinutes >= 50).toList();

  if (longAbandoned.length >= 2) {
    // Gợi ý phiên ngắn ~ 2/3 phút đã học trung bình trước khi rời.
    final avgStudied =
        abandoned.map((e) => e.studiedMinutes).fold(0, (a, b) => a + b) /
            abandoned.length;
    final suggested = (avgStudied * 2 / 3 / 5).round() * 5; // làm tròn 5'.
    final safeSuggested = suggested.clamp(15, 25);
    return AppLeavingInsight(
      abandonedCount: abandoned.length,
      sampleCount: sample.length,
      kind: 'shorter',
      message:
          'Dạo này phiên dài hay bị dừng giữa chừng. Có vẻ phiên ~$safeSuggested phút sẽ vừa sức hơn — thử xem sao.',
      suggestedMinutes: safeSuggested,
    );
  }

  if (abandoned.length >= 3) {
    return AppLeavingInsight(
      abandonedCount: abandoned.length,
      sampleCount: sample.length,
      kind: 'break',
      message:
          'Bạn hay rời app giữa phiên dạo này. Có thể bạn đang cần nghỉ thật sự — nghỉ ngơi cũng là một phần của việc ôn thi.',
    );
  }

  return AppLeavingInsight(
    abandonedCount: abandoned.length,
    sampleCount: sample.length,
    kind: 'reminder',
    message:
        'Phiên vừa rồi chưa xong mà đã rời mất. Không sao cả — quay lại bất cứ lúc nào bạn sẵn sàng nhé.',
  );
}
