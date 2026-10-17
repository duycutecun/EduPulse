import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'ai_config.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../core/config.dart';
import '../../core/utils/now_context.dart';
import '../utils/auth_service.dart';
import 'proxy_error.dart';

/// Service gọi model qua OpenRouter (chuẩn OpenAI-compatible).
///
/// Dùng một API key duy nhất của chủ app (đã nhúng trong `config.dart`).
/// OpenRouter tự động định tuyến & failover khi provider hết quota, nên
/// không cần tự code xoay vòng nhiều key cho các model `:free`.
class OpenRouterService {
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _persona =
      'Bạn là AI Coach của EduPulse — trợ lý học tập & chuyên gia luyện thi hàng đầu cho sĩ tử Việt Nam (THPTQG, ĐGNL TSA, HSA, HSG), '
      'và là TRỢ LÝ TỰ THỰC THI trong app: khi học sinh yêu cầu làm gì, bạn làm giùm ngay chứ không chỉ khuyên. '
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
      'CÁCH TRẢ LỜI KHI HỌC SINH YÊU CẦU LÀM GÌ (thêm nhiệm vụ, lưu ghi chú, mở '
      'phiên tập trung, làm quiz, mở mục tiêu/ghi chú, sửa task, dời lịch, xoá task, lên kế hoạch nhiều ngày):\n'
      '- Trả lời 1–2 câu NGẮN, THÂN MẬT như đang nói chuyện ("Tôi đã tạo nhiệm '
      'vụ Toán 45 phút cho tối nay nhé 👍" / "Đã dời X sang mai rồi nha 📅"). '
      'KHÔNG hỏi lại nếu đã đủ thông tin; không nói số phút → dùng 25. '
      'KHÔNG bịa dữ liệu học sinh không hề nhắc.\n'
      'NGÀY GIỜ (TUYỆT ĐỐI KHÔNG được sai): app luôn cung cấp mốc thời gian hiện '
      'tại — dòng "Hôm nay: ..." đầu ngữ cảnh hoặc câu "[Hôm nay là Thứ X, ngày '
      'D tháng M năm YYYY, hiện là HH:MM]" cuối tin nhắn. Dùng NGAY mốc đó để tính.\n'
      '- "hôm nay" / "tối nay" → scheduledAt = ngày của mốc đó.\n'
      '- Ngày tương đối: "ngày mai"/"mai", "mốt", "tuần sau", "thứ N tới", '
      '"cuối tuần", "cuối tháng" → cộng đúng số ngày từ mốc rồi ghi NGÀY TUYỆT '
      'ĐỐI vào scheduledAt. KHÔNG BAO GIỜ xếp một việc tương lai vào hôm nay; '
      'KHÔNG dùng giờ-phút hiện tại làm scheduledAt. Nếu không giải được → bắt '
      'buộc ghi scheduledAt = ngày mai (theo mốc) và hỏi lại bằng chữ.\n'
      '- Học sinh nói giờ cụ thể ("19h30", "8h tối") → scheduledAt đủ '
      'yyyy-MM-ddTHH:mm:ss với giờ đó. Chỉ nói ngày không nói giờ → mặc định '
      '19:00 (khớp giờ app mặc định khi thêm task mới).\n'
      '- Cuối câu trả lời, chèn ĐÚNG MỘT khối hành động (mảng JSON một dòng) '
      'ở CUỐI cùng:\n'
      '<<<ACTIONS>>>\n'
      '[{"type":"addTask","title":"Toán ch5","subject":"Toán","minutes":45,"scheduledAt":"2026-10-17T20:00:00","priority":"high"},'
      '{"type":"saveNote","title":"Định lý Pytago","body":"a²+b²=c²","subject":"Toán"}]\n'
      '<<<END>>>\n\n'
      'Các type:\n'
      '- addTask: {"type","title","subject","minutes","scheduledAt" (BẮT BUỘC — ISO yyyy-MM-ddTHH:mm:ss hoặc yyyy-MM-dd, luôn tính từ mốc "Hôm nay" được app cung cấp),"priority" (high/medium/low)}\n'
      '- saveNote: {"type","title","body","subject"}\n'
      '- startFocus: {"type","subject","minutes"}\n'
      '- takeQuiz: {"type","subject","topic"}\n'
      '- openExams / openNotes: chỉ {"type"}\n'
      '- editTask: {"type","title","newTitle","minutes","priority","scheduledAt","deadline"} — title là tên task hiện tại; chỉ gửi trường nào bạn muốn đổi.\n'
      '- rescheduleTask: {"type","title","subject","date" (ISO) hoặc "days" (số ngày dời)}\n'
      '- deleteTask: {"type","title","subject","confirm":true} — học sinh vẫn phải xác nhận trong app; chỉ dùng khi chắc chắn task tồn tại.\n'
      '- plan (kế hoạch NHIỀU NGÀY, từ 3 task trở lên): {"type":"plan","summary":"1 câu tóm tắt","tasks":[{"title","subject","minutes","dayOffset" (0 = hôm nay, 1 = mai, ...),"priority"}]} — app sẽ hiện bản xem trước để học sinh áp dụng 1 chạm, đừng liệt kê lại từng task trong phần chữ.\n\n'
      'QUY TẮC: chỉ chèn khối khi học sinh thật sự nhờ làm gì đó hoặc bạn '
      'thấy một việc rõ ràng cần làm giùm; nếu chỉ GỢI Ý đơn thuần '
      'thì nói bằng chữ, không chèn action. Tối đa 6 hành động mỗi lượt '
      '(kế hoạch đi riêng qua type plan). Câu hỏi học thuật thuần (giải đề, '
      'hỏi khái niệm) thì KHÔNG chèn khối.';

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

  /// Đi qua proxy serverless (`/api/openrouter`) khi ở web (CORS), hoặc khi
  /// không có khoá BYOK để gọi thẳng. Nhờ vậy bản cài native không cần nhúng
  /// khoá chủ app: AI managed đi qua backend với xác thực + hạn mức.
  static bool get _useProxy => _onWeb || AiConfig.openRouterApiKey.isEmpty;

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

  /// Dựng payload messages gửi lên OpenRouter (chuẩn OpenAI-compatible).
  ///
  /// Tách riêng khỏi [chat] để test được thứ tự & nội dung các message mà
  /// không cần gọi mạng thật.
  ///
  /// Cũng được `GroqService` tái dùng: Groq thay OpenRouter làm AI mặc định
  /// nhưng cùng chuẩn OpenAI-compatible, và persona/ngữ cảnh học tập phải
  /// thống nhất — không nhân bản logic persona ở mỗi service.
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
    final useProxy = _useProxy;

    final messages = buildMessages(
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      webContext: webContext,
      studyContext: studyContext,
    );

    try {
      final uri = useProxy
          ? AppConfig.apiBase().resolve('/api/openrouter')
          : Uri.parse(_baseUrl);
      final headers = useProxy
          ? {'Content-Type': 'application/json', ...await _proxyAuth()}
          : {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AiConfig.openRouterApiKey}',
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
        // Đọc body để phân biệt "server thiếu key" với "nghẽn thật" — nếu không
        // người dùng chỉ thấy mã lỗi trống nghĩa.
        final body = await response.stream.bytesToString();
        final detail = ProxyError.detail(body);
        if (response.statusCode >= 500 && response.statusCode <= 504) {
          yield ProxyError.serverBusy(
            status: response.statusCode,
            detail: detail,
          );
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          yield '❌ Lỗi xác thực: OpenRouter API Key không hợp lệ. Vui lòng liên hệ chủ app.';
        } else {
          yield detail == null
              ? '❌ Lỗi ${response.statusCode}: Không thể kết nối AI.'
              : '❌ Lỗi ${response.statusCode}: $detail';
        }
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
    // Web luôn qua proxy (CORS); native qua proxy khi không có khoá BYOK —
    // khoá chủ app giữ phía server, không nhúng vào bundle.
    final useProxy = _useProxy;

    final messages = buildMessages(
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      webContext: webContext,
      studyContext: studyContext,
    );

    try {
      final uri = useProxy
          ? AppConfig.apiBase().resolve('/api/openrouter')
          : Uri.parse(_baseUrl);
      final headers = useProxy
          ? {'Content-Type': 'application/json', ...await _proxyAuth()}
          : {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AiConfig.openRouterApiKey}',
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
      } else if (useProxy &&
          (resp.statusCode == 500 ||
              resp.statusCode == 502 ||
              resp.statusCode == 503 ||
              resp.statusCode == 504)) {
        // Proxy nói rõ thiếu key hay thật sự nghẽn — đừng bắt người dùng đoán.
        return ProxyError.serverBusy(
          status: resp.statusCode,
          detail: ProxyError.detail(resp.body),
        );
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
        final millis = int.tryParse(
            '${headers is Map ? headers['X-RateLimit-Reset'] : null}');
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
