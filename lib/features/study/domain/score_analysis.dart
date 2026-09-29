import 'models/study_models.dart';

/// Phân tích điểm mock/thi (đặc tả mục 41).
///
/// Nguyên tắc áp dụng:
/// - **Chỉ kết luận khi đủ dữ liệu** (mục 10.8): dưới 2 điểm không có
///   xu hướng; phân tích môn cần ≥ 2 điểm mỗi môn.
/// - **Không ngôn ngữ tiêu cực** khi điểm giảm (mục 40): dùng giọng động
///   viên + đề xuất hành động cụ thể.
/// - **Tăng điểm → phân tích yếu tố đóng góp** (mục 41): gợi ý liên hệ
///   với nhịp học, không khẳng định nguyên nhân.
class ScoreTrend {
  /// Xu hướng: 'up' | 'down' | 'flat'; null khi < 2 điểm.
  final String? trend;

  /// Chênh lệch điểm giữa 2 lần thi gần nhất.
  final double? delta;

  /// Số lần giảm liên tiếp tính từ điểm cao nhất gần đây.
  final int consecutiveDrops;

  const ScoreTrend({
    required this.trend,
    required this.delta,
    required this.consecutiveDrops,
  });
}

/// Điểm đã sort cũ → mới. `null` trend khi ít hơn 2 điểm.
ScoreTrend analyzeTrend(List<MockScore> scoresSortedAsc) {
  if (scoresSortedAsc.length < 2) {
    return const ScoreTrend(trend: null, delta: null, consecutiveDrops: 0);
  }
  final last = scoresSortedAsc.last.score;
  final prev = scoresSortedAsc[scoresSortedAsc.length - 2].score;
  final diff = last - prev;

  // Đếm lần giảm liên tiếp từ cuối dãy.
  var drops = 0;
  for (var i = scoresSortedAsc.length - 1; i > 0; i--) {
    if (scoresSortedAsc[i].score < scoresSortedAsc[i - 1].score) {
      drops++;
    } else {
      break;
    }
  }

  if (diff > 0.2) {
    return ScoreTrend(trend: 'up', delta: diff, consecutiveDrops: drops);
  }
  if (diff < -0.2) {
    return ScoreTrend(trend: 'down', delta: diff, consecutiveDrops: drops);
  }
  return ScoreTrend(trend: 'flat', delta: diff, consecutiveDrops: drops);
}

/// So điểm hiện tại với target. Trả về thông điệp phù hợp từng trường hợp.
String? targetMessage({
  required double? currentScore,
  required double? targetScore,
}) {
  if (currentScore == null || targetScore == null) return null;
  final gap = targetScore - currentScore;
  if (gap <= 0) {
    return 'Bạn đã đạt mục tiêu ${(currentScore - targetScore).toStringAsFixed(1)} điểm vượt kế hoạch. Duy trì nhé!';
  }
  return 'Còn ${(gap).toStringAsFixed(1)} điểm nữa tới mục tiêu — tập trung vào môn đang yếu nhất để thu khoảng cách.';
}

/// Phân tích theo môn: trung bình điểm từng môn (cần ≥ 2 điểm).
/// Trả về danh sách sort tăng dần — môn yếu nhất đầu tiên.
class SubjectScore {
  final String subject;
  final double avg;
  final int count;

  /// So điểm trung bình gần nhất với trước nhất của môn này.
  final double delta;

  const SubjectScore({
    required this.subject,
    required this.avg,
    required this.count,
    required this.delta,
  });

  bool get improving => delta > 0.2;
  bool get declining => delta < -0.2;
}

List<SubjectScore> analyzeBySubject(List<MockScore> scores) {
  final bySubject = <String, List<MockScore>>{};
  for (final s in scores) {
    (bySubject[s.subject] ??= []).add(s);
  }

  final result = <SubjectScore>[];
  for (final entry in bySubject.entries) {
    final list = entry.value..sort((a, b) => a.date.compareTo(b.date));
    if (list.length < 2) continue; // 1 điểm chưa đủ kết luận xu hướng.
    final avg = list.fold(0.0, (sum, s) => sum + s.score) / list.length;
    final delta = list.last.score - list.first.score;
    result.add(SubjectScore(
      subject: entry.key,
      avg: avg,
      count: list.length,
      delta: delta,
    ));
  }

  result.sort((a, b) => a.avg.compareTo(b.avg)); // yếu nhất đầu tiên.
  return result;
}

/// Insight tổng hợp — trả về câu insight phù hợp nhất, hoặc null khi
/// chưa đủ dữ liệu. Dùng cho card phân tích điểm sau thi / mock score.
String? scoreInsight(List<MockScore> scoresSortedAsc, {double? targetScore}) {
  if (scoresSortedAsc.length < 2) {
    return scoresSortedAsc.length == 1
        ? 'Mới có 1 điểm — thi thử thêm 1 lần nữa để EduPulse thấy xu hướng.'
        : null;
  }

  final trend = analyzeTrend(scoresSortedAsc);

  if (trend.consecutiveDrops >= 3) {
    // Mục 41: "Nếu điểm giảm nhiều lần → Analyze + propose adjustment".
    return 'Điểm giảm ${trend.consecutiveDrops} lần liên tiếp. Cân nhắc giảm khối lượng, tập trung ôn môn yếu nhất và ngủ đủ trước khi thi thử tiếp.';
  }

  if (trend.trend == 'up') {
    // Mục 41: "Nếu tăng → Analyze what contributed".
    return 'Điểm đang tăng +${trend.delta!.toStringAsFixed(1)}. Có vẻ nhịp học hiện tại đang phù hợp — duy trì và tiếp tục thi thử đều.';
  }

  // So target nếu có.
  final target = targetMessage(
    currentScore: scoresSortedAsc.last.score,
    targetScore: targetScore,
  );
  if (target != null) return target;

  if (trend.trend == 'down') {
    return 'Điểm lần này thấp hơn chút. Xem lại các câu sai để tìm dạng bài cần luyện thêm nhé.';
  }

  return 'Điểm đang ổn định. Giữ nhịp học và thi thử định kỳ để theo dõi tiến bộ.';
}
