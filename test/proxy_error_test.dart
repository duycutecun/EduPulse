import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/ai/proxy_error.dart';

/// Proxy serverless trả 500 kèm `{"error":"<KEY> not configured"}` khi thiếu
/// biến môi trường. Client phải nói đúng đây là lỗi cấu hình phía máy chủ,
/// không phải "máy chủ nghẽn" — nếu không người dùng sẽ chờ vô ích.
void main() {
  group('ProxyError.detail', () {
    test('đọc được error từ JSON của proxy', () {
      expect(
        ProxyError.detail('{"error":"GEMINI_API_KEY not configured"}'),
        'GEMINI_API_KEY not configured',
      );
    });

    test('body không phải JSON (ví dụ HTML của dev server) → null', () {
      expect(ProxyError.detail('<html>404 Not Found</html>'), isNull);
    });

    test('JSON không có trường error → null', () {
      expect(ProxyError.detail('{"ok":true}'), isNull);
    });

    test('error rỗng → null', () {
      expect(ProxyError.detail('{"error":"   "}'), isNull);
    });
  });

  group('ProxyError.serverBusy', () {
    test('thiếu key → báo lỗi cấu hình, KHÔNG phải nghẽn', () {
      final msg = ProxyError.serverBusy(
        status: 500,
        detail: 'GEMINI_API_KEY not configured',
      );
      expect(msg, contains('chưa được cấu hình'));
      expect(msg, isNot(contains('nghẽn')));
      expect(msg, contains('GEMINI_API_KEY not configured'));
    });

    test('5xx khác → giữ thông điệp nghẽn kèm chi tiết', () {
      final msg = ProxyError.serverBusy(status: 502, detail: 'fetch failed');
      expect(msg, contains('nghẽn tạm thời'));
      expect(msg, contains('HTTP 502'));
      expect(msg, contains('fetch failed'));
    });

    test('không có chi tiết → không thêm dòng Chi tiết', () {
      final msg = ProxyError.serverBusy(status: 503, detail: null);
      expect(msg, contains('nghẽn tạm thời'));
      expect(msg, isNot(contains('Chi tiết')));
    });
  });
}
