import 'models/study_models.dart';

/// Phân tích dữ liệu StudySession theo đặc tả mục 12 (Study Log & Analytics).
///
/// Toàn bộ hàm là pure function để kiểm thử độc lập. Nguyên tắc áp dụng:
/// - **Chỉ kết luận khi đủ dữ liệu** (mục 12.5, 10.8): trả `null` khi không
///   đủ mẫu, không đoán như sự thật.
/// - **Hypothesis ≠ fact** (mục 36): các gợi ý dùng ngôn ngữ "thử", "có vẻ",
///   không kết luận nguyên nhân tuyệt đối.

DateTime _startOfWeek(DateTime now) =>
    DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

// ---------------------------------------------------------------------------
// 12.2 So sánh tuần này vs tuần trước
// ---------------------------------------------------------------------------

class WeeklyComparison {
  final int thisWeekMinutes;
  final int lastWeekMinutes;

  const WeeklyComparison({
    required this.thisWeekMinutes,
    required this.lastWeekMinutes,
  });

  /// % thay đổi so với tuần trước; `null` khi tuần trước = 0 phút
  /// (không có mốc so sánh).
  int? get percentDelta {
    if (lastWeekMinutes <= 0) return null;
    return (((thisWeekMinutes - lastWeekMinutes) / lastWeekMinutes) * 100)
        .round();
  }

  /// Thông điệp nhẹ nhàng, không phán xét (Principle 5 Calm).
  /// `null` khi chưa đủ dữ liệu để so sánh.
  String? get message {
    final delta = percentDelta;
    if (delta == null) {
      if (thisWeekMinutes > 0 && lastWeekMinutes == 0) {
        return 'Tuần trước chưa có dữ liệu — tuần này bạn đã bắt đầu rồi đấy!';
      }
      return null;
    }
    if (delta > 0) return 'Tuần này bạn học nhiều hơn $delta%.';
    if (delta < 0) {
      return 'Tuần này bạn học ít hơn ${-delta}% so với tuần trước. Nghỉ ngơi hợp lý cũng là một phần của học.';
    }
    return 'Tuần này bạn duy trì đều như tuần trước.';
  }
}

/// Gộp phút focus theo tuần: tuần này (từ thứ 2) và tuần trước.
WeeklyComparison compareWeeks(List<StudySession> sessions, DateTime now) {
  final startThis = _startOfWeek(now);
  final startLast = startThis.subtract(const Duration(days: 7));
  int minutesWhere(bool Function(DateTime) inRange) => sessions
      .where((s) => inRange(s.completedAt))
      .fold(0, (sum, s) => sum + s.actualMinutes);

  return WeeklyComparison(
    thisWeekMinutes: minutesWhere(
        (d) => !d.isBefore(startThis) && d.isBefore(startThis.add(const Duration(days: 7)))),
    lastWeekMinutes: minutesWhere(
        (d) => !d.isBefore(startLast) && d.isBefore(startThis)),
  );
}

// ---------------------------------------------------------------------------
// 12.3 Efficiency composite
// ---------------------------------------------------------------------------

class EfficiencyReport {
  /// 0–100, composite từ focus + effectiveness + understanding.
  final int score;

  /// Chênh lệch điểm so với tuần trước; `null` nếu tuần trước không đủ mẫu.
  final int? deltaVsLastWeek;

  /// Số phiên có reflection được tính — để UI minh bạch căn cứ.
  final int sampleCount;

  /// Mô tả ngắn theo mức điểm, không phán xét.
  final String description;

  const EfficiencyReport({
    required this.score,
    required this.deltaVsLastWeek,
    required this.sampleCount,
    required this.description,
  });
}

const int _minSample = 3;

EfficiencyReport? efficiency(
    List<StudySession> sessions, DateTime now) {
  final startThis = _startOfWeek(now);
  final startLast = startThis.subtract(const Duration(days: 7));

  int? scoreFor(bool Function(DateTime) inRange) {
    final rated = sessions
        .where((s) =>
            s.focus != null &&
            s.effectiveness != null &&
            inRange(s.completedAt))
        .toList();
    if (rated.length < _minSample) return null;

    double avg(List<int> Function(StudySession) pick) {
      final values = rated.expand(pick).toList();
      if (values.isEmpty) return 3;
      return values.fold(0, (a, b) => a + b) / values.length;
    }

    // Trọng số composite: focus 40%, effectiveness 35%, understanding 25%.
    final composite = (avg((s) => [s.focus!]) * 0.40 +
            avg((s) => [s.effectiveness!]) * 0.35 +
            avg((s) => [s.understanding ?? 3]) * 0.25) /
        5.0;
    return (composite * 100).round().clamp(0, 100);
  }

  final thisWeek = scoreFor((d) => !d.isBefore(startThis));
  if (thisWeek == null) return null;

  final lastWeek =
      scoreFor((d) => d.isBefore(startThis) && !d.isBefore(startLast));

  String describe(int score) {
    if (score >= 80) {
      return 'Rất hiệu quả — bạn đang học đúng cách hơn chứ không chỉ nhiều hơn.';
    }
    if (score >= 60) return 'Ổn định. Giữ nhịp học hiện tại nhé!';
    return 'Đang thấp. Thử phiên ngắn hơn hoặc nghỉ giữa các phiên xem sao.';
  }

  return EfficiencyReport(
    score: thisWeek,
    deltaVsLastWeek: lastWeek == null ? null : thisWeek - lastWeek,
    sampleCount: sessions
        .where((s) =>
            s.focus != null &&
            s.effectiveness != null &&
            !s.completedAt.isBefore(startThis))
        .length,
    description: describe(thisWeek),
  );
}

// ---------------------------------------------------------------------------
// 12.4 Focus pattern — phiên dài có focus thấp hơn?
// ---------------------------------------------------------------------------

/// Nếu các phiên ≥50 phút có focus thấp hơn hẳn phiên ngắn → đề xuất phiên
/// ngắn hơn (đúng ví dụ mục 12.4). Cần ≥3 phiên mỗi nhóm; không đủ → null.
String? focusPatternTip(List<StudySession> sessions) {
  final rated =
      sessions.where((s) => s.focus != null).toList();
  Iterable<StudySession> group(bool Function(StudySession) predicate) =>
      rated.where(predicate);
  double avgFocus(Iterable<StudySession> group_) {
    final list = group_.toList();
    if (list.isEmpty) return 0;
    return list.fold(0, (sum, s) => sum + s.focus!) / list.length;
  }

  final long = group((s) => s.actualMinutes >= 50);
  final short = group((s) => s.actualMinutes < 50);
  if (long.length < _minSample || short.length < _minSample) return null;

  final longAvg = avgFocus(long);
  final shortAvg = avgFocus(short);
  if (shortAvg - longAvg >= 0.8) {
    return 'Có vẻ các phiên dài focus kém hơn phiên ngắn. Thử rút còn khoảng 35–45 phút mỗi phiên nhé.';
  }
  return null;
}

// ---------------------------------------------------------------------------
// 12.5 Best study time — khung giờ tập trung tốt nhất
// ---------------------------------------------------------------------------

/// Trả về thông điệp khung giờ học tốt nhất, hoặc `null` khi dữ liệu chưa
/// đủ (mỗi khung giờ cần ≥3 phiên có chấm focus và dẫn trước khung kia
/// ít nhất 0.5 điểm mới kết luận).
String? bestStudyTime(List<StudySession> sessions) {
  const buckets = <String, String>{
    'sáng': 'Sáng (5h–11h)',
    'chiều': 'Chiều (11h–17h)',
    'tối': 'Tối (17h–23h)',
    'đêm': 'Đêm (23h–5h)',
  };

  final ratedFocus = <String, List<int>>{};
  for (final s in sessions) {
    if (s.focus == null) continue;
    final hour = s.completedAt.hour;
    final key = hour >= 5 && hour < 11
        ? 'sáng'
        : hour >= 11 && hour < 17
            ? 'chiều'
            : hour >= 17 && hour < 23
                ? 'tối'
                : 'đêm';
    (ratedFocus[key] ??= []).add(s.focus!);
  }

  String? bestKey;
  double bestAvg = 0;
  double secondAvg = 0;
  for (final entry in ratedFocus.entries) {
    if (entry.value.length < _minSample) continue;
    final avg = entry.value.fold(0, (a, b) => a + b) / entry.value.length;
    if (avg > bestAvg) {
      secondAvg = bestAvg;
      bestAvg = avg;
      bestKey = entry.key;
    } else if (avg > secondAvg) {
      secondAvg = avg;
    }
  }

  if (bestKey == null || bestAvg - secondAvg < 0.5) return null;
  return 'Bạn tập trung tốt nhất vào ${buckets[bestKey]!.toLowerCase()}. Cố bố trí môn khó vào khung này xem sao.';
}
