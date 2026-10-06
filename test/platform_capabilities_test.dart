import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/platform/platform_capabilities.dart';

/// Khoá lại ma trận "app khác web ở điểm nào" — thứ mà UI (tab Tôi) và các
/// service đều đọc để quyết định hiện/ẩn tính năng.
void main() {
  FeatureAvailability onAndroid(NativeFeature f) =>
      PlatformCapabilities.availabilityFor(
          f, isWeb: false, isAndroid: true, isIos: false);

  FeatureAvailability onIos(NativeFeature f) =>
      PlatformCapabilities.availabilityFor(
          f, isWeb: false, isAndroid: false, isIos: true);

  FeatureAvailability onWeb(NativeFeature f) =>
      PlatformCapabilities.availabilityFor(
          f, isWeb: true, isAndroid: false, isIos: false);

  group('Tính năng chỉ có trên app', () {
    test('chia sẻ: app mở bảng chia sẻ hệ thống, web chỉ có bản thay thế', () {
      expect(onAndroid(NativeFeature.systemShare), FeatureAvailability.available);
      expect(onIos(NativeFeature.systemShare), FeatureAvailability.available);
      expect(onWeb(NativeFeature.systemShare), FeatureAvailability.webFallback);
    });

    test('thông báo nhắc học: chỉ chạy trên app native', () {
      expect(onAndroid(NativeFeature.notifications), FeatureAvailability.available);
      expect(onIos(NativeFeature.notifications), FeatureAvailability.available);
      expect(onWeb(NativeFeature.notifications), FeatureAvailability.unavailable);
    });

    test('widget màn hình chính: Android có, iOS sắp có, web không có', () {
      expect(onAndroid(NativeFeature.homeWidget), FeatureAvailability.available);
      expect(onIos(NativeFeature.homeWidget), FeatureAvailability.comingSoon);
      expect(onWeb(NativeFeature.homeWidget), FeatureAvailability.unavailable);
    });

    test('rung phản hồi: chỉ có trên app native', () {
      expect(onAndroid(NativeFeature.haptics), FeatureAvailability.available);
      expect(onIos(NativeFeature.haptics), FeatureAvailability.available);
      expect(onWeb(NativeFeature.haptics), FeatureAvailability.unavailable);
    });
  });

  group('Hợp đồng cho UI', () {
    test('mọi tính năng đều có lời giải thích web thay thế bằng gì', () {
      for (final feature in PlatformCapabilities.nativeOnlyFeatures) {
        final text = PlatformCapabilities.webAlternative(feature);
        expect(text.trim(), isNotEmpty,
            reason: '$feature thiếu mô tả thay thế trên web');
      }
    });

    test('danh sách tính năng native phủ hết enum (không sót khi thêm mới)',
        () {
      expect(
        PlatformCapabilities.nativeOnlyFeatures.toSet(),
        NativeFeature.values.toSet(),
      );
    });

    test('supports() khớp với availability() trên nền tảng đang chạy', () {
      for (final feature in NativeFeature.values) {
        expect(
          PlatformCapabilities.supports(feature),
          PlatformCapabilities.availability(feature) ==
              FeatureAvailability.available,
        );
      }
    });

    test('trên Android: nhận đủ tính năng native', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(PlatformCapabilities.isWeb, isFalse);
      expect(PlatformCapabilities.isAndroidApp, isTrue);
      expect(PlatformCapabilities.isNativeApp, isTrue);
      expect(PlatformCapabilities.platformLabel, 'Ứng dụng Android');
      expect(PlatformCapabilities.supports(NativeFeature.notifications), isTrue);
      expect(PlatformCapabilities.supports(NativeFeature.homeWidget), isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    test('trên iOS: widget chưa có nhưng thông báo/chia sẻ/rung đã có', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(PlatformCapabilities.isIosApp, isTrue);
      expect(PlatformCapabilities.platformLabel, 'Ứng dụng iOS');
      expect(PlatformCapabilities.supports(NativeFeature.notifications), isTrue);
      expect(PlatformCapabilities.supports(NativeFeature.systemShare), isTrue);
      expect(PlatformCapabilities.supports(NativeFeature.haptics), isTrue);
      expect(
          PlatformCapabilities.supports(NativeFeature.homeWidget), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });

    test('trên máy tính: không phải app mobile nên không có nhắc học/widget',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      expect(PlatformCapabilities.isNativeApp, isFalse);
      expect(PlatformCapabilities.platformLabel, 'Máy tính');
      expect(PlatformCapabilities.supports(NativeFeature.notifications), isFalse);
      expect(PlatformCapabilities.supports(NativeFeature.homeWidget), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
