import 'package:edupulse/features/onboarding/domain/onboarding_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingResponseParser.dailyMinutes', () {
    test('understands minutes, hours and a bare reasonable number', () {
      expect(OnboardingResponseParser.dailyMinutes('90 phút mỗi ngày'), 90);
      expect(OnboardingResponseParser.dailyMinutes('2 tiếng buổi tối'), 120);
      expect(OnboardingResponseParser.dailyMinutes('1.5 giờ'), 90);
      expect(OnboardingResponseParser.dailyMinutes('45'), 45);
    });

    test('rejects implausible study budgets', () {
      expect(OnboardingResponseParser.dailyMinutes('5 phút'), isNull);
      expect(OnboardingResponseParser.dailyMinutes('600 phút'), isNull);
    });
  });

  test('parses only real dd/mm/yyyy dates', () {
    expect(OnboardingResponseParser.examDate('thi 20/06/2027'),
        DateTime(2027, 6, 20));
    expect(OnboardingResponseParser.examDate('31/02/2027'), isNull);
  });

  test('extracts a valid baseline score', () {
    expect(OnboardingResponseParser.score('Hóa, lần gần nhất 5,5 điểm'), 5.5);
    expect(OnboardingResponseParser.score('11 điểm'), isNull);
  });
}
