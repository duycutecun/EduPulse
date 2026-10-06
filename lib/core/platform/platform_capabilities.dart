import 'package:flutter/foundation.dart';

/// Những tính năng **chỉ bản app cài trên máy (native) mới có**, không có
/// trên web/PWA.
///
/// Đây là nguồn sự thật duy nhất cho câu hỏi "app khác web ở điểm nào": UI
/// (thẻ Tôi → Trải nghiệm riêng trên app) và logic đều đọc từ đây, nên không
/// có chuyện một màn hình hứa có thông báo còn màn hình khác nói không.
///
/// Mọi tính năng trong danh sách này đã CÓ code thật trong app:
/// - [systemShare]  → `ShareService` (share sheet hệ thống + copy fallback).
/// - [notifications] → `NotificationService` + `AdaptivePolicy` (local, offline).
/// - [homeWidget]    → `HomeWidgetService` + `EdupulseWidgetProvider` (Android).
/// - [haptics]       → `FeedbackService` (rung/âm thanh).
enum NativeFeature {
  /// Chia sẻ ra ngoài app: mở bảng chia sẻ của hệ điều hành.
  systemShare,

  /// Nhắc học / tóm tắt cuối ngày / nhắc flashcard — chạy offline, không server.
  notifications,

  /// Widget trên màn hình chính: đếm ngược kỳ thi + nhiệm vụ hôm nay.
  homeWidget,

  /// Rung + âm thanh phản hồi khi tương tác.
  haptics,
}

/// Mức độ có mặt của một [NativeFeature] trên một nền tảng.
enum FeatureAvailability {
  /// Chạy đầy đủ trên nền tảng này.
  available,

  /// Không có bản native, nhưng vẫn có đường thay thế trên web (Web Share
  /// API, clipboard…).
  webFallback,

  /// Nền tảng này không có tính năng (web/PWA không có rung, không có widget).
  unavailable,

  /// Chưa làm trên nền tảng này (iOS chưa có widget — cần WidgetKit target).
  comingSoon,
}

/// Ma trận khả dụng native vs web.
///
/// Logic thuần nằm ở [availabilityFor] (nhận cờ nền tảng) để **kiểm thử được**
/// cho cả 3 nền tảng trên một máy CI duy nhất; các getter bên dưới chỉ là
/// cách gọi tiện dụng cho UI.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIosApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Đang chạy app cài trên máy (Android/iOS), không phải web/PWA.
  static bool get isNativeApp => isAndroidApp || isIosApp;

  /// Tên nền tảng hiện tại cho UI: "Ứng dụng iOS", "Ứng dụng Android", "Web".
  static String get platformLabel {
    if (kIsWeb) return 'Web / PWA';
    if (isIosApp) return 'Ứng dụng iOS';
    if (isAndroidApp) return 'Ứng dụng Android';
    return 'Máy tính';
  }

  /// Ma trận khả dụng — thuần, không phụ thuộc trạng thái runtime.
  static FeatureAvailability availabilityFor(
    NativeFeature feature, {
    required bool isWeb,
    required bool isAndroid,
    required bool isIos,
  }) {
    final nativeMobile = isAndroid || isIos;

    switch (feature) {
      case NativeFeature.systemShare:
        // Web vẫn chia sẻ được (Web Share API, fallback clipboard) nhưng
        // không phải bảng chia sẻ hệ thống như trên app.
        return isWeb ? FeatureAvailability.webFallback : FeatureAvailability.available;

      case NativeFeature.notifications:
        // PWA có thể có notification, nhưng app này cố tình không làm: lịch
        // nhắc nằm hoàn toàn on-device để chạy được khi offline.
        return nativeMobile
            ? FeatureAvailability.available
            : FeatureAvailability.unavailable;

      case NativeFeature.homeWidget:
        if (isAndroid) return FeatureAvailability.available;
        if (isIos) return FeatureAvailability.comingSoon;
        return FeatureAvailability.unavailable;

      case NativeFeature.haptics:
        return nativeMobile
            ? FeatureAvailability.available
            : FeatureAvailability.unavailable;
    }
  }

  /// Khả dụng của [feature] trên nền tảng đang chạy.
  static FeatureAvailability availability(NativeFeature feature) =>
      availabilityFor(
        feature,
        isWeb: isWeb,
        isAndroid: isAndroidApp,
        isIos: isIosApp,
      );

  /// Tính năng này có chạy được trên máy hiện tại hay không.
  static bool supports(NativeFeature feature) =>
      availability(feature) == FeatureAvailability.available;

  /// Các tính năng có ích hơn hẳn khi dùng app thay vì web.
  static List<NativeFeature> get nativeOnlyFeatures => NativeFeature.values;

  /// Web thay thế [feature] bằng gì — dùng để giải thích ngắn gọn trong UI.
  static String webAlternative(NativeFeature feature) {
    switch (feature) {
      case NativeFeature.systemShare:
        return 'Web dùng Web Share API của trình duyệt; nếu không có thì sao chép vào clipboard.';
      case NativeFeature.notifications:
        return 'Web không có nhắc học offline — chỉ có thể nhắc khi bạn đang mở tab.';
      case NativeFeature.homeWidget:
        return 'Web không có widget; phải mở trình duyệt mới thấy đếm ngược.';
      case NativeFeature.haptics:
        return 'Web không rung được — phản hồi chỉ bằng hình ảnh.';
    }
  }
}
