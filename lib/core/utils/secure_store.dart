import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Bọc [FlutterSecureStorage] để lưu khoá bí mật (BYOK AI) trong kho an toàn
/// của nền tảng (iOS Keychain / Android Keystore / DPAPI-Windows / WebCrypto
/// trên web) thay vì SharedPreferences dạng plaintext (đặc tả mục 8, dòng 211).
///
/// Mọi lỗi đều được nuốt và trả về an toàn: trên nền tảng thiếu plugin (ví dụ
/// khi chạy `flutter test`) thao tác ghi trả `false` để lớp gọi tự quyết định
/// phương án dự phòng; đọc trả `null`. Nhờ vậy app không bao giờ vỡ chỉ vì kho
/// an toàn không sẵn sàng.
class SecureStore {
  SecureStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  /// Ghi [value] vào kho an toàn. Chuỗi rỗng nghĩa là xoá. Trả `true` nếu
  /// thành công, `false` nếu nền tảng không hỗ trợ (lớp gọi nên dự phòng).
  static Future<bool> write(String key, String value) async {
    try {
      if (value.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Bỏ qua: không có gì để xoá hoặc nền tảng không hỗ trợ.
    }
  }

  static Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (_) {
      return false;
    }
  }
}
