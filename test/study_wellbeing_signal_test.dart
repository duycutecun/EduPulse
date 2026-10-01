import 'package:edupulse/core/ai/study_wellbeing_signal.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';

StudySession rated(String id, DateTime at, {int? mood, int? focus}) =>
    StudySession(
      id: id,
      subject: 'Toán',
      completedAt: at,
      plannedMinutes: 25,
      actualMinutes: 25,
      mood: mood,
      focus: focus,
    );

void main() {
  final now = DateTime(2026, 10, 1, 20);

  test('does not infer a state from fewer than three optional ratings', () {
    final signal = StudyWellbeingDetector.detect([
      rated('1', now, mood: 1),
      rated('2', now, focus: 1),
    ], now: now);
    expect(signal.state, StudyWellbeingState.unknown);
  });

  test('suggests a gentler plan only for a sustained low self-rating', () {
    final signal = StudyWellbeingDetector.detect([
      rated('1', now, mood: 2, focus: 2),
      rated('2', now.subtract(const Duration(days: 1)), mood: 2, focus: 2),
      rated('3', now.subtract(const Duration(days: 2)), mood: 3, focus: 2),
    ], now: now);
    expect(signal.state, StudyWellbeingState.gentle);
    expect(signal.guidance, contains('không tăng áp lực'));
  });

  test('reports steady only after enough recent ratings', () {
    final signal = StudyWellbeingDetector.detect([
      rated('1', now, mood: 4, focus: 4),
      rated('2', now.subtract(const Duration(days: 1)), mood: 4, focus: 3),
      rated('3', now.subtract(const Duration(days: 2)), mood: 5, focus: 4),
    ], now: now);
    expect(signal.state, StudyWellbeingState.steady);
  });
}
