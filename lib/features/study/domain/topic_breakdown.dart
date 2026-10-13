import 'models/study_models.dart';

/// Một chủ đề (trong một môn) được tổng hợp từ các lần thi thử.
class WeakTopic {
  final String subject;
  final String topic;
  final double average; // 0..10
  final int attempts;
  final DateTime latestAt;

  const WeakTopic({
    required this.subject,
    required this.topic,
    required this.average,
    required this.attempts,
    required this.latestAt,
  });

  /// Nhãn đánh giá theo cùng ngưỡng với mức môn (score_summary.dart) để hai
  /// tầng insight không nói hai kiểu khác nhau.
  String get rating {
    if (average >= 8) return 'Khá giỏi';
    if (average >= 6.5) return 'Ổn định';
    return 'Cần cải thiện';
  }
}

/// Ngưỡng coi là "yếu": dưới 6.5 thì đáng để nhắc ôn lại.
const double kWeakTopicThreshold = 6.5;

/// Tổng hợp điểm thi thử theo (môn, chủ đề). Bỏ qua bản ghi không có chủ đề —
/// không bịa chủ đề cho dữ liệu cũ chỉ có môn. Sắp yếu nhất trước.
List<WeakTopic> analyzeTopicWeakness(List<MockScore> scores) {
  final byKey = <String, List<MockScore>>{};
  // Nhãn hiển thị gốc (giữ nguyên hoa/thường người dùng gõ) theo khoá so khớp.
  final labels = <String, (String, String)>{};

  for (final s in scores) {
    final topic = s.topic?.trim() ?? '';
    final subject = s.subject.trim();
    if (topic.isEmpty || subject.isEmpty) continue;

    final key = '${subject.toLowerCase()}|${topic.toLowerCase()}';
    byKey.putIfAbsent(key, () => []).add(s);
    labels.putIfAbsent(key, () => (subject, topic));
  }

  final result = <WeakTopic>[];
  byKey.forEach((key, list) {
    list.sort((a, b) => b.date.compareTo(a.date));
    final total = list.fold(0.0, (sum, s) => sum + s.score);
    final (subject, topic) = labels[key]!;
    result.add(WeakTopic(
      subject: subject,
      topic: topic,
      average: total / list.length,
      attempts: list.length,
      latestAt: list.first.date,
    ));
  });

  // Yếu nhất trước; cùng điểm thì chủ đề thi nhiều lần hơn lên trước (nhiều
  // bằng chứng hơn về việc chủ đề đó đang là điểm nghẽn).
  result.sort((a, b) {
    final byScore = a.average.compareTo(b.average);
    return byScore != 0 ? byScore : b.attempts.compareTo(a.attempts);
  });
  return result;
}

/// Chủ đề yếu nhất nếu có bản ghi chủ đề và điểm trung bình dưới [threshold];
/// ngược lại trả `null` để UI không nhắc thừa khi mọi chủ đề đều ổn.
WeakTopic? weakestTopic(
  List<MockScore> scores, {
  double threshold = kWeakTopicThreshold,
}) {
  final topics = analyzeTopicWeakness(scores);
  if (topics.isEmpty) return null;
  final weakest = topics.first;
  return weakest.average < threshold ? weakest : null;
}
