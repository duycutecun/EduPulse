import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../core/utils/now_context.dart';

/// Service gọi model qua OpenRouter (chuẩn OpenAI-compatible).
///
/// Dùng một API key duy nhất của chủ app (đã nhúng trong `config.dart`).
/// OpenRouter tự động định tuyến & failover khi provider hết quota, nên
/// không cần tự code xoay vòng nhiều key cho các model `:free`.
class OpenRouterService {
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _persona =
      'Bạn là AI Coach của EduPulse — trợ lý học tập & chuyên gia luyện thi hàng đầu cho sĩ tử Việt Nam (THPTQG, ĐGNL TSA, HSA, HSG). '
      'Khi học sinh gửi ảnh đề bài (Toán, Lý, Hóa, Sinh, Văn, Tiếng Anh): '
      '1. Đọc và nhận diện chính xác đề bài. '
      '2. Tóm tắt các giả thiết và yêu cầu. '
      '3. Trình bày phương pháp tư duy & lời giải chi tiết từng bước. '
      '4. Nêu các lưu ý / bẫy trắc nghiệm thường gặp. '
      'Đôi khi câu hỏi sẽ kèm một khối "THAM KHẢO TỪ WEB" từ Wikipedia. '
      'Hãy cân nhắc thông tin đó nếu liên quan và hữu ích để trả lời chính xác, phong phú hơn; '
      'nếu không liên quan thì bỏ qua và trả lời theo kiến thức vốn có. '
      'Trả lời chuẩn sư phạm, thân thiện, khích lệ tinh thần học sinh. '
      'Trả lời bằng tiếng Việt.\n\n'
      'QUAN TRỌNG — KHI BẠN KHUYÊN HỌC SINH LÀM GÕ ĐÓ CỤ THỂ (luyện quiz, '
      'bắt đầu phiên focus, lưu công thức vào ghi chú, thêm nhiệm vụ...), '
      'hãy chèn khối hành động ở CUỐI câu trả lời để học sinh bấm thực thi '
      'ngay trong app:\n'
      '<<<ACTIONS>>>\n'
      '- label: <nút hiển thị, ≤ 30 ký tự> | type: quiz | subject: <môn> | topic: <chủ đề>\n'
      '- label: <...> | type: focus | subject: <môn> | minutes: <25/30/45>\n'
      '- label: <...> | type: note | title: <tên ghi chú> | subject: <môn>\n'
      '- label: <...> | type: task | title: <tên nhiệm vụ> | subject: <môn> | minutes: <số> | priority: <high/medium/low>\n'
      '<<<END>>>\n'
      'Quy tắc: chỉ chèn khi thật sự hữu ích (1-3 dòng, không bắt buộc mỗi '
      'câu trả lời); KHÔNG chèn khi học sinh chỉ hỏi khái niệm/kiểm tra; '
      'giữ nguyên định dạng key: value như mẫu; type chỉ nhận quiz/focus/note/task.';

  /// Hướng dẫn cách dùng khối ngữ cảnh học tập (mục 10.2) — điều này biến AI
  /// từ khung chat chung chung thành trợ lý biết rõ tình huống học sinh.
  static const String _contextGuide = 'Bạn được cấp ngữ cảnh học tập thật của '
      'học sinh này ở từng lượt (kỳ thi sắp tới, tiến độ nhiệm vụ, chuỗi học, '
      'thời gian học theo môn, điểm thi thử, ghi chú). '
      'Hãy dùng nó để trả lời đúng cho người này: '
      '1. Nói tới tình huống thật của học sinh (ví dụ "bạn còn 12 ngày thi '
      'THPTQG mà điểm Hóa đang thấp nhất") thay vì lời khuyên chung chung. '
      '2. Khi học sinh hỏi chung ("nên học gì", "làm sao định kỳ thi"), chủ '
      'động dựa vào ngữ cảnh để đề xuất kế hoạch khớp kỳ thi, thời gian còn '
      'lại và môn đang yếu của học sinh. '
      '3. Nếu ngữ cảnh mâu thuẫn với điều học sinh nói, tin lời học sinh và '
      'nói rõ bạn đang thấy gì trong dữ liệu. '
      '4. Không kể lại nguyên văn khối ngữ cảnh, và đừng hỏi lại những gì đã '
      'có trong đó.';

  /// Đang chạy trên nền web (browser) — không gọi OpenRouter trực tiếp (CORS),
  /// dùng proxy serverless cùng origin `/api/openrouter`.
  static bool get _onWeb {
    try {
      return Uri.base.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Dựng payload messages gửi lên OpenRouter.
  ///
  /// Tách riêng khỏi [chat] để test được thứ tự & nội dung các message mà
  /// không cần gọi mạng thật.
  @visibleForTesting
  static List<Map<String, dynamic>> buildMessages({
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? webContext,
    String? studyContext,
  }) {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _persona},
    ];

    // Ngữ cảnh học tập thật của học sinh (kỳ thi, nhiệm vụ, điểm, ghi chú…)
    // đặt ngay sau persona để model luôn thấy trước khi đọc lịch sử chat.
    // Rỗng khi người dùng tắt quyền đọc dữ liệu hoặc app chưa có dữ liệu.
    final ctx = studyContext?.trim();
    if (ctx != null && ctx.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': '$_contextGuide\n\n--- NGỮ CẢNH HỌC TẬP HIỆN TẠI ---\n$ctx',
      });
    }

    for (final msg in history.where((m) => !m.isLoading)) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': _buildContent(msg.imageBytes, msg.text),
      });
    }

    final resolved = _resolveText(userMessage, imageBytes);
    // Luôn cho AI biết ngày/tháng/thứ hiện tại.
    final dateCtx = '\n\n[${NowContext.build()}]';
    final finalText = webContext != null && webContext.isNotEmpty
        ? '$resolved\n\n$webContext$dateCtx'
        : '$resolved$dateCtx';
    final currentContent = _buildContent(imageBytes, finalText);
    messages.add({'role': 'user', 'content': currentContent});
    return messages;
  }

  static Stream<String> chatStream({
    required String model,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
    String? studyContext,
  }) async* {
    final onWeb = _onWeb;
    if (!onWeb && AppConfig.openRouterApiKey.isEmpty) {
      yield '❌ Chưa cấu hình OpenRouter API Key.';
      return;
    }

    final messages = buildMessages(
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      webContext: webContext,
      studyContext: studyContext,
    );

    try {
      final uri =
          onWeb ? Uri.base.resolve('/api/openrouter') : Uri.parse(_baseUrl);
      final headers = onWeb
          ? {'Content-Type': 'application/json'}
          : {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
              'HTTP-Referer': 'https://edu-pulse-five.vercel.app',
              'X-Title': 'EduPulse',
            };

      final request = http.Request('POST', uri);
      request.headers.addAll(headers);
      request.body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.6,
        'max_tokens': 2048,
        'stream': true,
      });

      final response =
          await request.send().timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        yield '❌ Lỗi ${response.statusCode}: Không thể kết nối AI.';
        return;
      }

      final buffer = StringBuffer();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) {
              buffer.write(delta);
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
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
    String? studyContext,
  }) async {
    // Trên desktop/mobile (không CORS) cần key build-time; trên web key do
    // proxy `/api/openrouter` giữ phía server.
    final onWeb = _onWeb;
    if (!onWeb && AppConfig.openRouterApiKey.isEmpty) {
      return '❌ Chưa cấu hình OpenRouter API Key (thiếu biến môi trường OPENROUTER_API_KEY khi build).';
    }

    final messages = buildMessages(
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      webContext: webContext,
      studyContext: studyContext,
    );

    try {
      final uri =
          onWeb ? Uri.base.resolve('/api/openrouter') : Uri.parse(_baseUrl);
      final headers = onWeb
          ? {'Content-Type': 'application/json'}
          : {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
              'HTTP-Referer': 'https://edu-pulse-five.vercel.app',
              'X-Title': 'EduPulse',
            };
      final resp = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.6,
              'max_tokens': 2048,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content is String && content.isNotEmpty) {
          return content;
        }
        return 'AI không trả lời được nội dung này. Vui lòng thử lại.';
      } else if (resp.statusCode == 429) {
        return rateLimitMessage(resp.body);
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        return '❌ Lỗi xác thực: OpenRouter API Key không hợp lệ. Vui lòng liên hệ chủ app.';
      } else if (resp.statusCode == 400) {
        return '❌ Yêu cầu không hợp lệ (dữ liệu ảnh quá lớn hoặc model không hỗ trợ ảnh). Vui lòng thử lại.';
      } else if (resp.statusCode == 413) {
        return '❌ Ảnh/đoạn chat gửi quá lớn bị máy chủ từ chối. Hãy chọn ảnh nhỏ hơn hoặc xóa bớt ảnh cũ trong hội thoại.';
      } else if (onWeb &&
          (resp.statusCode == 500 ||
              resp.statusCode == 502 ||
              resp.statusCode == 503 ||
              resp.statusCode == 504)) {
        return '❌ Máy chủ AI đang nghẽn tạm thời (HTTP ${resp.statusCode}). Chờ vài giây rồi thử lại.';
      } else {
        return '❌ Lỗi ${resp.statusCode}: Không thể kết nối đến AI Coach. Kiểm tra mạng và thử lại.';
      }
    } catch (e) {
      return '❌ Lỗi kết nối: $e\n\nHãy kiểm tra kết nối mạng hoặc dung lượng ảnh và thử lại.';
    }
  }

  static Object _buildContent(Uint8List? imageBytes, String text) {
    // Nếu có ảnh, tạo content dạng mảng part (chuẩn OpenAI vision).
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return [
        {'type': 'text', 'text': text},
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}'
          },
        },
      ];
    }
    return text;
  }

  /// Thông báo cho HTTP 429 — **phân biệt hai nguyên nhân rất khác nhau**.
  ///
  /// Trước đây mọi 429 đều bị gộp thành “chờ 1–2 phút”. Nhưng OpenRouter có
  /// hai loại giới hạn rất khác:
  ///  - **ngắn hạn**: gửi quá nhanh → chờ vài chục giây là dùng lại được.
  ///  - **theo ngày** (`free-models-per-day`): hết lượt cả ngày — chờ 1–2 phút
  ///    **vô ích**, phải chờ tới giờ reset hoặc đổi model.
  ///
  /// Nói sai khiến người dùng thử lại mãi mà không bao giờ được — nên đọc
  /// `error.code` và `X-RateLimit-Reset` mà OpenRouter gửi kèm.
  static String rateLimitMessage(String? body) {
    var isDaily = false;
    DateTime? resetAt;

    if (body != null && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        final error = decoded is Map ? decoded['error'] : null;
        final code = error is Map ? error['code']?.toString() : null;
        final message = error is Map ? error['message']?.toString() : null;
        isDaily = (code ?? '').contains('free-models-per-day') ||
            (message ?? '').contains('free-models-per-day') ||
            (message ?? '').contains('per day');

        final meta = error is Map ? error['metadata'] : null;
        final headers = meta is Map ? meta['headers'] : null;
        final millis =
            int.tryParse('${headers is Map ? headers['X-RateLimit-Reset'] : null}');
        if (millis != null) {
          resetAt = DateTime.fromMillisecondsSinceEpoch(millis);
        }
      } catch (_) {
        // Body không phải JSON (proxy lỗi, mạng đứt) → rơi về thông báo chung.
      }
    }

    if (!isDaily) {
      return '❌ Gửi hơi nhanh (HTTP 429). Chờ khoảng một phút rồi thử lại, '
          'hoặc đổi sang model khác trong danh sách.';
    }

    final until = resetAt == null
        ? 'ngày mai'
        : 'tới ${_hhmm(resetAt.toLocal())} ngày mai';
    return '❌ Đã hết lượt model miễn phí hôm nay (50 lượt/ngày), hồi lại '
        '$until.\n\n'
        'Chờ không giải quyết được — hãy đổi sang model trả phí trong danh sách, '
        'hoặc nạp thêm tiền vào OpenRouter để có 1000 lượt/ngày.';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _resolveText(String userMessage, Uint8List? imageBytes) {
    if (userMessage.trim().isNotEmpty) return userMessage;
    if (imageBytes != null) {
      return 'Hãy đọc và giải chi tiết bài tập trong bức ảnh này giúp tôi.';
    }
    return userMessage;
  }
}
