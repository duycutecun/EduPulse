import 'models/study_models.dart';

/// Kết quả tổng hợp điểm thi thử cho từng môn.
class SubjectScoreSummary {
  final String subject;
  final double average;
  final double latest;
  final double best;
  final int count;

  const SubjectScoreSummary({
    required this.subject,
    required this.average,
    required this.latest,
    required this.best,
    required this.count,
  });

  /// Màu đánh giá: >=8 xanh, >=6.5 cam, còn lại đỏ.
  String get rating {
    if (average >= 8) return 'Khá giỏi';
    if (average >= 6.5) return 'Ổn định';
    return 'Cần cải thiện';
  }
}

/// Tổng hợp điểm theo môn: trung bình, mới nhất, cao nhất, số lần thi.
List<SubjectScoreSummary> summarizeMockScores(List<MockScore> scores) {
  final bySubject = <String, List<MockScore>>{};
  for (final s in scores) {
    bySubject.putIfAbsent(s.subject, () => []).add(s);
  }

  final result = <SubjectScoreSummary>[];
  bySubject.forEach((subject, list) {
    // Mới nhất trước.
    list.sort((a, b) => b.date.compareTo(a.date));
    final total = list.fold(0.0, (sum, s) => sum + s.score);
    result.add(SubjectScoreSummary(
      subject: subject,
      average: total / list.length,
      latest: list.first.score,
      best: list.map((s) => s.score).reduce((a, b) => a > b ? a : b),
      count: list.length,
    ));
  });

  result.sort((a, b) => a.average.compareTo(b.average));
  return result;
}

/// Điểm trung bình chung của tất cả lần thi.
double overallAverage(List<MockScore> scores) {
  if (scores.isEmpty) return 0;
  final total = scores.fold(0.0, (sum, s) => sum + s.score);
  return total / scores.length;
}

/// Môn yếu nhất (trung bình thấp nhất) — dùng cho AI prompt.
String? weakestSubject(List<MockScore> scores) {
  final summaries = summarizeMockScores(scores);
  if (summaries.isEmpty) return null;
  return summaries.first.subject;
}

/// Đoạn mô tả điểm thi thử dùng làm prompt cho AI phân tích.
String buildScorePrompt(List<MockScore> scores) {
  if (scores.isEmpty) return '';
  final buf = StringBuffer('Đây là các lần thi thử của em (thang điểm 10):\n');
  for (final s in scores) {
    buf.writeln(
        '- ${s.subject}: ${s.score.toStringAsFixed(1)} (${s.date.day}/${s.date.month})');
  }
  final weak = weakestSubject(scores);
  buf.writeln('Môn trung bình thấp nhất có vẻ là: ${weak ?? 'chưa xác định'}.');
  buf.writeln(
      'Hãy phân tích điểm yếu và đề xuất kế hoạch ôn tập ngắn gọn, cụ thể cho từng môn.');
  return buf.toString();
}