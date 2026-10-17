import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../utils/auth_service.dart';
import 'openrouter_service.dart';
import 'proxy_error.dart';

/// Service gọi Groq — AI chính của EduPulse (free, nhanh nhất).
///
/// Groq là provider mặc định cho câu hỏi chỉ-text (first-token ~0.35s với
/// `openai/gpt-oss-20b`). KHÔNG dùng cho đọc ảnh: model free của Groq không
/// nhận image input — ảnh vẫn đi đường Gemini (decided, xem `ai_router.dart`).
///
/// Cơ chế giống `OpenRouterService` nhưng KHÔNG có đường gọi thẳng (BYOK):
/// key `GROQ_API_KEY` chỉ nằm phía server trên proxy `/api/groq`
/// (như `/api/gemini`), nên mọi nền tảng (web/native) đều qua proxy. Hạn mức
/// free của Groq (~30 RPM, ~1000 req/ngày, ~8K tokens/phút) khiến
/// `max_tokens` mặc định khiêm tốn hơn OpenRouter.
class GroqService {
  /// Model mặc định — nhanh nhất (first-token ~0.35s), đủ cho chat/quiz.
  static const String defaultModel = 'openai/gpt-oss-20b';

  /// Model mạnh hơn khi cần lý luận dài: vẫn free trên Groq.
  static const String strongModel = 'openai/gpt-oss-120b';

  /// Prefix slug trong `AIModel.definitions` để `AiRouter` biết rẽ nhánh.
  /// Slug full dạng `groq/openai/gpt-oss-20b` → gửi `openai/gpt-oss-20b`.
  static const String slugPrefix = 'groq/';

  /// Nhãn "groq/" trong slug? (dùng chung cho UI icon + định tuyến).
  static bool isGroqSlug(String slug) => slug.startsWith(slugPrefix);

  /// Bỏ prefix để có model id thật gửi lên Groq API.
  static String nativeModel(String slug) {
    final s =
        slug.startsWith(slugPrefix) ? slug.substring(slugPrefix.length) : slug;
    return s.isEmpty ? defaultModel : s;
  }

  /// Header xác thực Supabase cho proxy cùng origin — rỗng khi chưa đăng nhập.
  ///
  /// Proxy (`api/_guard.js`) xác thực token khi có để tính hạn mức theo `uid`;
  /// người dùng ẩn danh vẫn gọi được (chỉ bị giới hạn theo IP).
  static Future<Map<String, String>> _proxyAuth() async {
    final token = await AuthService.idToken();
    return token == null || token.isEmpty
        ? const {}
        : {'Authorization': 'Bearer $token'};
  }

  /// Body chuẩn gửi lên proxy — messages đã được dựng bởi
  /// [OpenRouterService.buildMessages] (dùng chung persona + ngữ cảnh học
  /// tập, không nhân bản logic ở đây).
  static Map<String, dynamic> _payload(
    String model,
    List<Map<String, dynamic>> messages, {
    required bool stream,
  }) =>
      {
        'model': model,
        'messages': messages,
        'temperature': 0.6,
        // Groq free tính TPM (~8K) CẢ trên max_tokens — modest, xem api/_groq_logic.js.
        'max_tokens': 1200,
        if (stream) 'stream': true,
      };

  static Stream<String> chatStream({
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async* {
    final body = _payload(model, messages, stream: true);
    try {
      final request = http.Request(
        'POST',
        AppConfig.apiBase().resolve('/api/groq'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        ...await _proxyAuth(),
      });
      request.body = jsonEncode(body);

      final response =
          await request.send().timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        final bodyText = await response.stream.bytesToString();
        yield _errorMessage(response.statusCode, bodyText);
        return;
      }

      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) {
              buffer += delta;
              yield delta;
            }
          } catch (_) {
            // Skip malformed SSE lines
          }
        }
      }

      if (buffer.isEmpty) {
        yield 'AI không trả lời được nội dung này. Vui lòng thử lại.';
      }
    } catch (e) {
      yield '❌ Lỗi kết nối: $e';
    }
  }

  static Future<String> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      final resp = await http
          .post(
            AppConfig.apiBase().resolve('/api/groq'),
            headers: {
              'Content-Type': 'application/json',
              ...await _proxyAuth(),
            },
            body: jsonEncode(_payload(model, messages, stream: false)),
          )
          .timeout(const Duration(seconds: 45));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content is String && content.isNotEmpty) {
          return content;
        }
        return 'AI không trả lời được nội dung này. Vui lòng thử lại.';
      }
      return _errorMessage(resp.statusCode, resp.body);
    } catch (e) {
      // Timeout/mạng đứt — AiRouter coi mọi chuỗi '❌' là thất bại và tự thử
      // model kế tiếp (fallback, mục M3.4).
      return '❌ Lỗi kết nối Groq: $e';
    }
  }

  /// Thông báo lỗi tiếng Việt theo format của `OpenRouterService`.
  ///
  /// Groq trả các mã giống chuẩn OpenAI: 401/403 (auth), 429 (rate limit —
  /// gồm cả "quá tải"), 5xx (lỗi phía Groq). Sau thông báo này `AiRouter`
  /// tự fallback sang model khác/Gemini nên người dùng hiếm khi nhìn thấy.
  static String _errorMessage(int statusCode, String body) {
    final detail = ProxyError.detail(body);
    switch (statusCode) {
      case 401:
      case 403:
        return '❌ Lỗi xác thực: Groq API Key không hợp lệ. Vui lòng liên hệ chủ app.';
      case 429:
        return '❌ Groq đang quá tải hoặc hết lượt trong phút này. '
            'Đang tự chuyển sang AI khác…';
      case >= 500 && <= 504:
        return ProxyError.serverBusy(status: statusCode, detail: detail);
      case 400:
        return detail == null
            ? '❌ Yêu cầu không hợp lệ với Groq. Vui lòng thử lại.'
            : '❌ Yêu cầu không hợp lệ với Groq: $detail';
      default:
        return detail == null
            ? '❌ Lỗi $statusCode: Không thể kết nối AI Coach.'
            : '❌ Lỗi $statusCode: $detail';
    }
  }
}
