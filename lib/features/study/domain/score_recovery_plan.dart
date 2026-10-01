import 'models/study_models.dart';
import 'score_summary.dart';

/// Kế hoạch bù điểm ngắn, sinh từ dữ liệu điểm thi thử tại chỗ.
class ScoreRecoveryPlan {
  const ScoreRecoveryPlan({
    required this.subject,
    required this.sessionsPerWeek,
    required this.minutesPerSession,
    required this.reason,
  });

  final String subject;
  final int sessionsPerWeek;
  final int minutesPerSession;
  final String reason;

  String get taskTitle => 'Bù điểm $subject: luyện dạng bài còn yếu';
}

ScoreRecoveryPlan? buildScoreRecoveryPlan(
  List<MockScore> scores, {
  required int daysLeft,
}) {
  if (scores.isEmpty || daysLeft <= 0) return null;
  final summaries = summarizeMockScores(scores);
  if (summaries.isEmpty) return null;
  final weak = summaries.first;
  final urgent = daysLeft <= 30;
  return ScoreRecoveryPlan(
    subject: weak.subject,
    sessionsPerWeek: urgent ? 3 : 2,
    minutesPerSession: urgent ? 45 : 35,
    reason:
        '${weak.subject} đang có điểm TB thấp nhất (${weak.average.toStringAsFixed(1)}/10).',
  );
}
