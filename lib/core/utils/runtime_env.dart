import 'runtime_env_io.dart'
    if (dart.library.js_interop) 'runtime_env_web.dart' as impl;

/// Nhận biết môi trường chạy — hiện dùng để TẮT gọi mạng AI trong `flutter test`
/// (test phải chạy thuần local, không phụ thuộc backend).
class RuntimeEnv {
  RuntimeEnv._();

  /// Đang chạy bên trong `flutter test` trên VM. Trên web luôn `false`
  /// (web test vốn đã bật AI qua proxy, giống hành vi khi chạy thật).
  static bool get isFlutterTest => impl.isFlutterTest;
}
