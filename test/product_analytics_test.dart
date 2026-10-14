import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/analytics/product_analytics.dart';
import 'package:edupulse/core/analytics/product_events.dart';
import 'package:edupulse/core/utils/storage_service.dart';

/// Unit test cho bộ ghi sự kiện sản phẩm (đặc tả mục 9.1).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('mặc định tắt → không ghi sự kiện nào', () {
    ProductAnalytics.instance.track(ProductEvents.todayPlanViewed);
    expect(ProductAnalytics.instance.recent(), isEmpty);
    expect(ProductAnalytics.instance.enabled, isFalse);
  });

  test('khi bật → ghi sự kiện hợp lệ', () {
    ProductAnalytics.instance.setEnabled(true);
    ProductAnalytics.instance.track(ProductEvents.onboardingCompleted);

    final recent = ProductAnalytics.instance.recent();
    expect(recent.length, 1);
    expect(recent.single.name, ProductEvents.onboardingCompleted);
  });

  test('tên sự kiện không hợp lệ bị bỏ qua', () {
    ProductAnalytics.instance.setEnabled(true);
    ProductAnalytics.instance.track('event_la');
    expect(ProductAnalytics.instance.recent(), isEmpty);
  });

  test('thuộc tính không cho phép bị loại, giá trị dài bị cắt', () {
    ProductAnalytics.instance.setEnabled(true);
    ProductAnalytics.instance.track(
      ProductEvents.focusSessionCompleted,
      props: {
        'minutes': '25',
        'note': 'nội dung học tập nhạy cảm', // phải bị loại
        'result': 'a' * 100, // phải bị cắt còn 40
      },
    );

    final e = ProductAnalytics.instance.recent().single;
    expect(e.props.containsKey('note'), isFalse);
    expect(e.props['minutes'], '25');
    expect(e.props['result']!.length, 40);
  });

  test('không ghi sự kiện khi chưa đồng ý', () {
    ProductAnalytics.instance.track(ProductEvents.syncSucceeded);
    expect(ProductAnalytics.instance.recent(), isEmpty);
    expect(ProductAnalytics.instance.enabled, isFalse);
  });

  test('tắt đồng ý → xóa bộ đệm', () {
    ProductAnalytics.instance.setEnabled(true);
    ProductAnalytics.instance.track(ProductEvents.onboardingCompleted);
    expect(ProductAnalytics.instance.recent(), isNotEmpty);

    ProductAnalytics.instance.setEnabled(false);
    expect(ProductAnalytics.instance.recent(), isEmpty);
  });

  test('tên sự kiện lạ không được ghi kể cả khi đã bật', () {
    ProductAnalytics.instance.setEnabled(true);
    ProductAnalytics.instance.track('unknown_event');
    expect(ProductAnalytics.instance.recent(), isEmpty);
  });
}
