import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/ai/openrouter_service.dart';

/// HTTP 429 có HAI nghĩa hoàn toàn khác nhau, và app đã gộp chung khiến
/// người dùng thử lại mãi mà không bao giờ được.
///
/// Payload dưới đây là **nguyên bản** OpenRouter trả về (đã lấy từ
/// production), không phải dữ liệu bịa.
void main() {
  /// Đúng payload lỗi 429 thật của OpenRouter cho hạn mức model miễn phí.
  String dailyBody() => jsonEncode({
        'error': {
          'message': 'Rate limit exceeded: free-models-per-day. Add 10 credits '
              'to unlock 1000 free model requests per day',
          'code': 429,
          'metadata': {
            'headers': {
              'X-RateLimit-Limit': '50',
              'X-RateLimit-Remaining': '0',
              'X-RateLimit-Reset': '1791158400000',
            },
            'limit_source': 'openrouter_free_tier_daily',
          },
        },
      });

  group('429 hạn mức NGÀY — không phải lỗi chờ được', () {
    test('không được bảo người dùng chờ vài phút', () {
      final msg = OpenRouterService.rateLimitMessage(dailyBody());

      expect(msg, contains('50 lượt/ngày'),
          reason: 'phải nói rõ đã hết lượt cả ngày');
      expect(msg.toLowerCase(), isNot(contains('một phút')),
          reason: 'chờ 1 phút VÔ ÍCH với hạn mức ngày — đây chính là lỗi '
              'khiến người dùng thử lại mãi mà không bao giờ được');
      expect(msg.toLowerCase(), isNot(contains('1–2 phút')));
    });

    test('phải chỉ ra lối thoát thật sự dùng được', () {
      final msg = OpenRouterService.rateLimitMessage(dailyBody());

      expect(msg, contains('model trả phí'),
          reason: 'đổi sang model trả phí là cách duy nhất dùng được ngay');
      expect(msg, contains('1000 lượt/ngày'));
    });

    test('hiện giờ reset đọc từ X-RateLimit-Reset', () {
      final msg = OpenRouterService.rateLimitMessage(dailyBody());

      // 1791158400000 ms → 2026-10-06 16:00 UTC → 23:00 giờ VN.
      expect(msg, contains('hồi lại'));
      expect(msg, matches(RegExp(r'\d{2}:\d{2} ngày mai')),
          reason: 'phải nói đúng giờ hồi lại thay vì mơ hồ');
    });
  });

  group('429 ngắn hạn — lần này chờ được', () {
    test('báo chờ vài phút, KHÔNG nói hết lượt cả ngày', () {
      final msg = OpenRouterService.rateLimitMessage(
        jsonEncode({
          'error': {'message': 'Rate limit exceeded', 'code': 429},
        }),
      );

      expect(msg, contains('một phút'));
      expect(msg, isNot(contains('50 lượt/ngày')),
          reason: 'quy trầm trùng sẽ dạy người dùng chờ vô ích');
    });
  });

  group('Body lỗi — không được làm sập cả luồng chat', () {
    test('body rỗng vẫn trả thông báo hợp lệ', () {
      final msg = OpenRouterService.rateLimitMessage('');
      expect(msg, isNotEmpty);
      expect(msg, startsWith('❌'));
    });

    test('body không phải JSON không gây ném lỗi', () {
      // Proxy lỗi / mạng đứt có thể trả HTML — không được để lỗi parse làm
      // hỏng luồng chat của người học.
      final msg = OpenRouterService.rateLimitMessage('<html>502</html>');
      expect(msg, startsWith('❌'));
    });

    test('body null vẫn an toàn', () {
      expect(OpenRouterService.rateLimitMessage(null), startsWith('❌'));
    });
  });
}
