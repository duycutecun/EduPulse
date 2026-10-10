// Điểm truy cập Web Push dùng chung toàn app.
//
// Trên web/PWA dùng bản thật (gọi `window.__edupulsePush`); trên iOS/Android
// native dùng bản rỗng (no-op). Chọn bản theo nền tảng lúc biên dịch.
export 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart';
