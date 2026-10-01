import 'package:edupulse/core/ai/exam_countdown_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every requested countdown stage to a practical strategy', () {
    expect(
        ExamCountdownStrategy.phaseForDaysLeft(31), ExamStudyPhase.foundation);
    expect(ExamCountdownStrategy.phaseForDaysLeft(30), ExamStudyPhase.practice);
    expect(ExamCountdownStrategy.phaseForDaysLeft(15), ExamStudyPhase.practice);
    expect(ExamCountdownStrategy.phaseForDaysLeft(14), ExamStudyPhase.revision);
    expect(ExamCountdownStrategy.phaseForDaysLeft(7), ExamStudyPhase.revision);
    expect(ExamCountdownStrategy.phaseForDaysLeft(6), ExamStudyPhase.crunch);
    expect(ExamCountdownStrategy.phaseForDaysLeft(0), ExamStudyPhase.examDay);
    expect(
        ExamCountdownStrategy.phaseForDaysLeft(-1), ExamStudyPhase.completed);
  });

  test('crunch guidance explicitly lowers pressure', () {
    final guidance = ExamCountdownStrategy.guidanceForDaysLeft(3);
    expect(guidance, contains('bình tĩnh'));
    expect(guidance, contains('tránh tạo áp lực'));
  });
}
