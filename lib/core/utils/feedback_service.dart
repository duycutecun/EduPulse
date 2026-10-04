import 'package:flutter/services.dart';

import 'storage_service.dart';

/// Cổng duy nhất cho rung và âm thanh của ứng dụng.
///
/// Đặc tả 5.14 liệt kê trong Cài đặt hai mục **Rung** và **Âm thanh**, và
/// FE-6.6 yêu cầu "Sound can be disabled". Trước đây `HapticFeedback` được gọi
/// rải rác ở 29 chỗ và tiếng kêu chỉ gắn với mascot — không có đường nào để tắt.
///
/// Vì vậy mọi lời gọi phải đi qua đây: một chỗ quyết định, một chỗ tắt.
/// Đổi cài đặt có hiệu lực ngay với các lần tương tác sau, không cần mở lại app.
class FeedbackService {
  /// Tắt cả hai khi người dùng bật "Giảm chuyển động" trong Tôi.
  static const String hapticsKey = 'haptics_enabled';
  static const String soundKey = 'sound_enabled';

  static bool get hapticsEnabled => StorageService.getBool(hapticsKey) ?? true;

  static bool get soundEnabled => StorageService.getBool(soundKey) ?? true;

  static void setHaptics(bool value) =>
      StorageService.setBool(hapticsKey, value);

  static void setSound(bool value) => StorageService.setBool(soundKey, value);

  static Future<void> light() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> selection() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> medium() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Hành động phá huỷ / không dễ lấy lại (xoá nhiệm vụ): rung nặng để người
  /// dùng nhận ra ngay cả khi không nhìn màn hình.
  static Future<void> heavy() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  static Future<void> vibrate() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.vibrate();
  }

  /// Hoàn tất phiên học: rung nhẹ + tiếng "pop" nếu người dùng cho phép.
  static Future<void> celebrate() async {
    await medium();
    if (!soundEnabled) return;
    await SystemSound.play(SystemSoundType.click);
  }
}
