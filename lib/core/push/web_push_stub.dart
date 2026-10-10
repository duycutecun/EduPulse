/// Bản "rỗng" cho nền tảng KHÔNG phải web (iOS/Android native): Web Push chỉ
/// chạy trên trình duyệt/PWA, nên ở native mọi thao tác là no-op.
class WebPushService {
  static bool get isSupported => false;

  /// Chưa đăng ký được (native) → luôn null.
  static Future<String?> subscribe(String vapidPublicKey) async => null;

  static Future<void> unsubscribe() async {}

  /// Không có subscription nào đang hoạt động ở native.
  static String? currentSubscription() => null;
}
