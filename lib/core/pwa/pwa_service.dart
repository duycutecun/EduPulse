import 'pwa_service_io.dart' if (dart.library.js_interop) 'pwa_service_web.dart'
    as impl;
import 'package:flutter/foundation.dart';

/// Dịch vụ hỗ trợ cài đặt PWA (web) — cài ứng dụng trên Android/Chrome
/// hoặc hướng dẫn "Add to Home Screen" trên iOS.
///
/// Trên native (iOS/Android app thật) các hàm đều trả về trạng thái không
/// installable để UI không hiện banner cài đặt.
class PwaService {
  PwaService._();

  /// Khởi tạo (bắt đầu lắng nghe sự kiện installable trên web).
  static void init() => impl.init();

  /// App có thể cài đặt qua native prompt (Chrome/Android) hay không.
  static bool get isInstallable => impl.isInstallable;

  /// Đang chạy trên iOS (Safari) hay không — để hiện hướng dẫn Add to Home Screen.
  static bool get isIosSafari => impl.isIosSafari;

  /// Đang chạy trên nền tảng web hay không.
  static bool get isWeb => impl.isWeb;

  /// Notifier báo khi trạng thái installable thay đổi (để UI hiện banner).
  static ValueNotifier<bool> get installableStream => impl.installableNotifier;

  /// Gọi native install prompt (Android/Chrome). Trả về true nếu prompt đã được gọi.
  static Future<bool> install() => impl.install();
}
