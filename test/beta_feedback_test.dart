import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/feedback/beta_feedback.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  tearDown(() => BetaFeedbackService.instance.clear());

  test('nội dung rỗng không được lưu', () {
    final ok =
        BetaFeedbackService.instance.submit(BetaFeedbackCategory.bug, '   ');
    expect(ok, isFalse);
    expect(BetaFeedbackService.instance.count, 0);
  });

  test('lưu phản hồi hợp lệ kèm nhóm và liên hệ', () {
    final ok = BetaFeedbackService.instance.submit(
      BetaFeedbackCategory.idea,
      'Thêm chế độ tối cho màn phiên học',
      contact: 'hs@example.com',
    );

    expect(ok, isTrue);
    final entry = BetaFeedbackService.instance.recent().single;
    expect(entry.category, BetaFeedbackCategory.idea);
    expect(entry.message, contains('chế độ tối'));
    expect(entry.contact, 'hs@example.com');
  });

  test('giữ đúng thứ tự thời gian khi thêm nhiều phản hồi', () {
    BetaFeedbackService.instance
        .submit(BetaFeedbackCategory.bug, 'Phản hồi một');
    BetaFeedbackService.instance
        .submit(BetaFeedbackCategory.idea, 'Phản hồi hai');

    final list = BetaFeedbackService.instance.recent();
    expect(list.length, 2);
    expect(list.first.message, 'Phản hồi một');
    expect(list.last.message, 'Phản hồi hai');
  });

  test('xuất văn bản gồm nhóm và nội dung', () {
    BetaFeedbackService.instance
        .submit(BetaFeedbackCategory.confusing, 'Onboarding bước 2 khó hiểu');

    final text = BetaFeedbackService.instance.exportText();
    expect(text, contains('Khó hiểu'));
    expect(text, contains('Onboarding bước 2 khó hiểu'));
  });

  test('xuất rỗng khi chưa có phản hồi', () {
    expect(BetaFeedbackService.instance.exportText(), '');
  });

  test('clear xóa hết phản hồi', () {
    BetaFeedbackService.instance.submit(BetaFeedbackCategory.other, 'gì đó');
    expect(BetaFeedbackService.instance.count, 1);

    BetaFeedbackService.instance.clear();
    expect(BetaFeedbackService.instance.count, 0);
  });
}
