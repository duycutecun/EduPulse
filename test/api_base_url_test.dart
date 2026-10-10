import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/config.dart';

/// Bảo vệ lỗi tái diễn quan trọng nhất cho bản IPA/APK:
/// Trên iOS/Android, `Uri.base` là URI file:// của app — resolve('/api/family')
/// thành `file:///api/family` → mạng vỡ → "không tạo được mã mời".
/// `AppConfig.apiBase()` phải trả về host production trên native.
void main() {
  test('AppConfig.apiBaseUrl trỏ đúng bản deploy production', () {
    expect(AppConfig.apiBaseUrl, 'https://edu-pulse-five-gamma.vercel.app');
  });

  test('apiBase() trên native resolve đúng endpoint /api/family', () {
    // Trong test (VM) kIsWeb = false → chính là nhánh native.
    final uri = AppConfig.apiBase().resolve('/api/family');
    expect(uri.scheme, 'https');
    expect(uri.host, 'edu-pulse-five-gamma.vercel.app');
    expect(uri.path, '/api/family');
    expect(uri.toString(), 'https://edu-pulse-five-gamma.vercel.app/api/family');
  });

  test('apiBase() resolve /api/backup thành URL https hợp lệ', () {
    final uri = AppConfig.apiBase().resolve('/api/backup');
    expect(uri.hasScheme, true);
    expect(uri.host.isNotEmpty, true);
    expect(uri.toString().startsWith('file:'), false);
  });
}