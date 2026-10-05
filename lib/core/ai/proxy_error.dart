import 'dart:convert';

/// Đọc lỗi JSON mà proxy serverless (`/api/gemini`, `/api/openrouter`) trả về.
///
/// Vì sao cần: proxy trả **HTTP 500 kèm `{"error": "... not configured"}`** khi
/// server thiếu biến môi trường. Nếu client chỉ nhìn mã trạng thái thì mọi lỗi
/// 5xx đều bị báo thành "máy chủ đang nghẽn" — người dùng sẽ chờ vô ích thay vì
/// biết rằng chủ app phải cấu hình API key.
class ProxyError {
  ProxyError._();

  /// Trích trường `error` trong body JSON; `null` nếu body không phải JSON hợp
  /// lệ hoặc không có `error` dạng chuỗi.
  static String? detail(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['error'] is String) {
        final e = (data['error'] as String).trim();
        return e.isEmpty ? null : e;
      }
    } catch (_) {
      // Proxy có thể trả HTML (ví dụ 404 của dev server) — coi như không có chi
      // tiết, không nuốt lỗi thật vì phía gọi vẫn dùng mã trạng thái.
    }
    return null;
  }

  /// Tin nhắn cho lỗi 5xx của proxy.
  ///
  /// - Thiếu key (`... not configured`) → nói thẳng là lỗi cấu hình phía máy
  ///   chủ, kèm chi tiết để chủ app biết cần đặt biến nào.
  /// - Còn lại → giữ nguyên thông điệp "nghẽn tạm thời", kèm chi tiết nếu có.
  static String serverBusy({
    required int status,
    required String? detail,
  }) {
    if (detail != null && detail.toLowerCase().contains('not configured')) {
      return '❌ AI Coach chưa được cấu hình trên máy chủ (thiếu API key). '
          'Chủ app cần thêm biến môi trường trên Vercel rồi deploy lại.\n'
          'Chi tiết: $detail';
    }
    final suffix =
        (detail == null || detail.isEmpty) ? '' : '\nChi tiết: $detail';
    return '❌ Máy chủ AI đang nghẽn tạm thời (HTTP $status). '
        'Chờ vài giây rồi thử lại.$suffix';
  }
}
