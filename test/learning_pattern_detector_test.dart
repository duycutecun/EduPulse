import 'package:edupulse/core/ai/learning_pattern_detector.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';

StudySession session({
  required String id,
  required DateTime at,
  int plannedMinutes = 25,
  int? focus,
  int? effectiveness,
}) =>
    StudySession(
      id: id,
      subject: 'Toán',
      completedAt: at,
      plannedMinutes: plannedMinutes,
      actualMinutes: plannedMinutes,
      focus: focus,
      effectiveness: effectiveness,
    );

void main() {
  final now = DateTime(2026, 10, 1, 22);

  test('finds an effective recurring study window', () {
    final patterns = LearningPatternDetector.detect([
      session(
          id: '1', at: DateTime(2026, 9, 29, 20), focus: 5, effectiveness: 5),
      session(
          id: '2', at: DateTime(2026, 9, 30, 20), focus: 4, effectiveness: 5),
      session(
          id: '3', at: DateTime(2026, 9, 30, 9), focus: 2, effectiveness: 2),
    ], now: now);

    expect(patterns.single.summary, contains('20:00–22:00'));
  });

  test('suggests shorter focus blocks only with enough voluntary ratings', () {
    final patterns = LearningPatternDetector.detect([
      session(
          id: '1', at: DateTime(2026, 9, 29, 19), plannedMinutes: 50, focus: 2),
      session(
          id: '2', at: DateTime(2026, 9, 30, 19), plannedMinutes: 45, focus: 2),
      session(
          id: '3', at: DateTime(2026, 10, 1, 19), plannedMinutes: 50, focus: 2),
    ], now: now);

    expect(patterns.any((p) => p.suggestion.contains('25 phút')), isTrue);
  });

  test('does not infer a pattern from sparse data', () {
    final patterns = LearningPatternDetector.detect([
      session(id: '1', at: DateTime(2026, 10, 1, 19)),
      session(id: '2', at: DateTime(2026, 10, 1, 20)),
    ], now: now);

    expect(patterns, isEmpty);
  });
}
