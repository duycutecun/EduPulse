import '../../study/domain/models/study_models.dart';
import '../../study/domain/score_analysis.dart';
import '../../study/domain/score_summary.dart';
import '../../study/domain/study_analytics.dart';
import '../../study/domain/topic_breakdown.dart';
import '../../study/domain/weekly_summary.dart';

/// Một tuần lịch (Thứ 2 → Chủ nhật) gộp điểm thi thử.
class WeeklyScoreBucket {
  final DateTime weekStart;
  final double average;
  final int count;

  const WeeklyScoreBucket({
    required this.weekStart,
    required this.average,
    required this.count,
  });

  /// Nhãn dạng "12/10–18/10" cho biểu đồ xu hướng.
  String get label {
    final end = weekStart.add(const Duration(days: 6));
    return '${weekStart.day}/${weekStart.month}–${end.day}/${end.month}';
  }
}

/// Trung bình điểm theo từng tuần lịch, sắp tăng dần theo thời gian, giữ tối đa
/// [maxWeeks] tuần gần nhất để biểu đồ không rối khi có nhiều dữ liệu cũ.
List<WeeklyScoreBucket> weeklyAverageScores(
  List<MockScore> scores, {
  int maxWeeks = 8,
}) {
  final buckets = <String, List<MockScore>>{};
  for (final s in scores) {
    final key = weekStartOf(s.date).toIso8601String();
    buckets.putIfAbsent(key, () => []).add(s);
  }

  final weeks = buckets.entries.map((entry) {
    final list = entry.value;
    final total = list.fold(0.0, (sum, s) => sum + s.score);
    return WeeklyScoreBucket(
      weekStart: weekStartOf(list.first.date),
      average: total / list.length,
      count: list.length,
    );
  }).toList();

  weeks.sort((a, b) => a.weekStart.compareTo(b.weekStart));
  return weeks.length > maxWeeks
      ? weeks.sublist(weeks.length - maxWeeks)
      : weeks;
}

/// Báo cáo sâu (P2) — gộp toàn bộ phân tích dài hạn từ [scores] và [sessions].
///
/// Toàn bộ là mảnh ráp thuần: các domain đã có (score_analysis,
/// topic_breakdown, study_analytics, weekly_summary) chịu tính toán, đây chỉ là
/// nơi ráp để màn hình render. Không gọi AI, không cần mạng — chạy hoàn toàn
/// trên dữ liệu cục bộ.
class DeepReport {
  final List<WeeklyScoreBucket> weeklyBuckets;
  final ScoreTrend scoreTrend;
  final List<SubjectScore> subjects;
  final List<SubjectScoreSummary> summaries;
  final List<WeakTopic> weakTopics;
  final WeeklyComparison hoursComparison;
  final EfficiencyReport? efficiencyReport;
  final String? bestTimeTip;
  final String? focusPatternTipValue;
  final bool hasScores;
  final bool hasSessions;

  const DeepReport({
    required this.weeklyBuckets,
    required this.scoreTrend,
    required this.subjects,
    required this.summaries,
    required this.weakTopics,
    required this.hoursComparison,
    required this.efficiencyReport,
    required this.bestTimeTip,
    required this.focusPatternTipValue,
    required this.hasScores,
    required this.hasSessions,
  });

  factory DeepReport.build(
    List<MockScore> scores,
    List<StudySession> sessions, {
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final asc = [...scores]..sort((a, b) => a.date.compareTo(b.date));

    return DeepReport(
      weeklyBuckets: weeklyAverageScores(scores),
      scoreTrend: analyzeTrend(asc),
      subjects: analyzeBySubject(scores),
      summaries: summarizeMockScores(scores),
      weakTopics: analyzeTopicWeakness(scores)
          .where((t) => t.average < kWeakTopicThreshold)
          .take(5)
          .toList(),
      hoursComparison: compareWeeks(sessions, ref),
      efficiencyReport: efficiency(sessions, ref),
      bestTimeTip: bestStudyTime(sessions),
      focusPatternTipValue: focusPatternTip(sessions),
      hasScores: scores.isNotEmpty,
      hasSessions: sessions.isNotEmpty,
    );
  }

  /// Điểm trung bình chung của toàn bộ lần thi thử.
  double get overallAverage => overallAverageOf(summaries);
}

/// Trung bình môn trung bình — dùng để trình bày ở màn báo cáo sâu mà không
/// phải trộn lại từng điểm (tránh trọng số khác nhau giữa các môn).
double overallAverageOf(List<SubjectScoreSummary> summaries) {
  if (summaries.isEmpty) return 0;
  final total = summaries.fold(0.0, (s, it) => s + it.average);
  return total / summaries.length;
}
