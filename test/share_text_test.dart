import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/share/share_text.dart';

/// Nội dung chia sẻ là thứ người khác nhìn thấy — sai số liệu hoặc chia sẻ
/// toàn số 0 sẽ làm người dùng mất mặt, nên khoá lại bằng test.
void main() {
  group('ShareText.progressSummary', () {
    test('có số liệu thật thì in đủ thời gian, tỉ lệ và streak', () {
      final text = ShareText.progressSummary(
        weekHours: 12.34,
        completionRatePercent: 78,
        streakDays: 9,
      );

      expect(text, contains('12.3 giờ'));
      expect(text, contains('78%'));
      expect(text, contains('🔥 9 ngày'));
      expect(text, contains(ShareText.signature));
      // Chưa có kỳ thi → không được bịa dòng đếm ngược.
      expect(text, isNot(contains('còn')));
    });

    test('streak 0 thì ẩn dòng chuỗi ngày (không khoe số 0)', () {
      final text = ShareText.progressSummary(
        weekHours: 3,
        completionRatePercent: 50,
        streakDays: 0,
      );

      expect(text, isNot(contains('🔥')));
    });

    test('có kỳ thi thì thêm đếm ngược, và chặn số ngày âm', () {
      final withExam = ShareText.progressSummary(
        weekHours: 5,
        completionRatePercent: 60,
        streakDays: 2,
        examName: 'THPTQG 2027',
        daysToExam: 45,
      );
      expect(withExam, contains('THPTQG 2027: còn 45 ngày'));

      final pastExam = ShareText.progressSummary(
        weekHours: 5,
        completionRatePercent: 60,
        streakDays: 2,
        examName: 'THPTQG 2026',
        daysToExam: -3,
      );
      expect(pastExam, isNot(contains('còn -3')));
    });

    test('tỉ lệ phần trăm ngoài 0–100 được kẹp lại', () {
      expect(
        ShareText.progressSummary(
          weekHours: 1,
          completionRatePercent: 145,
          streakDays: 1,
        ),
        contains('100%'),
      );
    });
  });

  group('ShareText.taskSummary và appInvite', () {
    test('taskSummary có tiêu đề, môn và thời lượng dự kiến', () {
      final text = ShareText.taskSummary(
        title: '  Ôn chương 3  ',
        subject: '📐 Toán',
        estimateMinutes: 45,
      );

      expect(text, contains('Ôn chương 3'));
      expect(text, contains('📐 Toán'));
      expect(text, contains('45 phút'));
    });

    test('taskSummary bỏ qua thời lượng khi không có', () {
      final text = ShareText.taskSummary(title: 'Đọc SGK', subject: '');
      expect(text, isNot(contains('Dự kiến')));
      expect(text, isNot(contains('Môn:')));
    });

    test('appInvite luôn kèm link cài app', () {
      expect(ShareText.appInvite(), contains(ShareText.appLink));
    });
  });
}
