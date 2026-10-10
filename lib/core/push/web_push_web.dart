import 'dart:async';
import 'dart:js_interop';

/// Cầu nối JS `window.__edupulsePush` (khai báo trong `web/index.html`).
extension type _PushApi(JSObject _) implements JSObject {
  external bool isSupported();
  external JSString? getSubscriptionJson();
  external void subscribe(JSString vapidKey);
  external void unsubscribe();
}

@JS('__edupulsePush')
external _PushApi? get _pushApi;

/// Web Push trên nền tảng web/PWA.
///
/// Toàn bộ phần "khó" của trình duyệt (đăng ký Service Worker, xin quyền, gọi
/// `pushManager.subscribe`) nằm ở cầu nối JS trong `web/index.html`. Ở đây chỉ
/// gọi vào cầu nối đó và trả kết quả về Dart.
class WebPushService {
  static const Duration _pollStep = Duration(milliseconds: 500);
  static const int _pollTries = 40; // ~20 giây, đủ để người dùng bấm "Cho phép".

  static bool get isSupported => _pushApi?.isSupported() ?? false;

  /// Đăng ký nhận thông báo đẩy. Trả về chuỗi JSON subscription khi thành công
  /// (để gửi lên server), null khi bị từ chối/hết thời gian/không hỗ trợ.
  static Future<String?> subscribe(String vapidPublicKey) async {
    final api = _pushApi;
    if (api == null) return null;
    api.subscribe(vapidPublicKey.toJS);
    for (var i = 0; i < _pollTries; i++) {
      await Future<void>.delayed(_pollStep);
      final json = currentSubscription();
      if (json != null) return json;
    }
    return null;
  }

  static Future<void> unsubscribe() async {
    _pushApi?.unsubscribe();
  }

  static String? currentSubscription() {
    final value = _pushApi?.getSubscriptionJson();
    return value?.toDart;
  }
}
