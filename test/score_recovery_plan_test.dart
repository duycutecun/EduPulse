import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/score_recovery_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('targets the lowest-average subject with an urgent weekly cadence', () {
    final plan = buildScoreRecoveryPlan([
      MockScore(
          id: '1', subject: 'Toán', score: 7.5, date: DateTime(2026, 9, 1)),
      MockScore(
          id: '2', subject: 'Hóa', score: 5.5, date: DateTime(2026, 9, 2)),
    ], daysLeft: 20);

    expect(plan!.subject, 'Hóa');
    expect(plan.sessionsPerWeek, 3);
    expect(plan.minutesPerSession, 45);
  });

  test('does not create a recovery plan after the exam', () {
    expect(buildScoreRecoveryPlan([], daysLeft: 10), isNull);
    expect(
        buildScoreRecoveryPlan([
          MockScore(id: '1', subject: 'Toán', score: 5, date: DateTime(2026)),
        ], daysLeft: 0),
        isNull);
  });
}
