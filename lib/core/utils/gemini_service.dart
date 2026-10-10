import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../../features/study/domain/models/study_models.dart';
import 'now_context.dart';
import '../ai/openrouter_service.dart';
import '../ai/proxy_error.dart';

class GeminiService {
  /// Model đang dùng. Nằm ở một chỗ duy nhất để `url` + payload proxy + tài
  /// liệu luôn khớp nhau khi Gemini đổi tên model.
  static const String model = 'gemini-3.7-flash';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  /// Đang chạy trên nền web (browser) — gọi proxy cùng origin `/api/gemini`,
  /// key giữ phía server (không lộ trong client).
  static bool get _onWeb {
    try {
      return Uri.base.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Persona của AI Coach — gửi qua `systemInstruction`, KHÔNG nhét vào
  /// `contents` (xem [buildContents] để hiểu vì sao).
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

  /// Hướng dẫn dùng khối ngữ cảnh học tập — điều biến AI Coach từ khung chat
  /// chung chung thành trợ lý biết rõ tình huống của học sinh.
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

  /// Dựng `systemInstruction` gửi lên Gemini: persona + (nếu có) ngữ cảnh học
  /// tập thật của học sinh.
  ///
  /// Vì sao persona/ngữ cảnh KHÔNG nằm trong `contents` nữa: Gemini 3.x
  /// (3.6/3.7/3.8 Flash) siết luật xoay lượt của `generateContent` — `contents`
  /// bắt buộc luân phiên `user` ↔ `model`, không được kết thúc bằng lượt
  /// `model`, và không nhận "prefilled model turn" (lượt `model` do client tự
  /// bịa ra). Cách cũ nhét persona (user) + ngữ cảnh (user) + câu hỏi (user)
  /// thành nhiều lượt `user` liền nhau ⇒ mọi request Gemini bị 400 và bị báo
  /// nhầm thành "API Key không hợp lệ". `systemInstruction` áp dụng cho toàn
  /// request và không tham gia chuỗi lượt, nên vừa đúng chuẩn vừa giữ nguyên
  /// nội dung.
  @visibleForTesting
  static String buildSystemInstruction({String? studyContext}) {
    final ctx = studyContext?.trim();
    if (ctx == null || ctx.isEmpty) return _persona;
    return '$_persona\n\n$_contextGuide\n\n'
        '--- NGỮ CẢNH HỌC TẬP HIỆN TẠI ---\n$ctx';
  }

  /// Dựng payload `contents` gửi lên Gemini.
  ///
  /// Tách riêng khỏi [chat] để test được việc payload có thật sự hợp lệ với
  /// Gemini 3.x hay không (luân phiên vai trò, kết thúc bằng `user`) mà không
  /// cần gọi mạng thật.
  @visibleForTesting
  static List<Map<String, dynamic>> buildContents({
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
  }) {
    final contents = <Map<String, dynamic>>[];

    /// Thêm một lượt; tự gộp vào lượt trước nếu cùng vai trò.
    ///
    /// Gộp thay vì để hai lượt `user` liền nhau: Gemini 3.x trả 400 cho
    /// request không luân phiên (`user` → `user`). Lượt rỗng cũng bị bỏ vì
    /// Gemini coi là lỗi xác thực dữ liệu.
    void addTurn(String role, List<Map<String, dynamic>> parts) {
      if (parts.isEmpty) return;
      if (contents.isNotEmpty && contents.last['role'] == role) {
        (contents.last['parts'] as List).addAll(parts);
        return;
      }
      contents.add({'role': role, 'parts': parts});
    }

    for (final msg in history.where((m) => !m.isLoading)) {
      final parts = <Map<String, dynamic>>[];
      if (msg.imageBytes != null && msg.imageBytes!.isNotEmpty) {
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(msg.imageBytes!),
          }
        });
      }
      if (msg.text.trim().isNotEmpty) {
        parts.add({'text': msg.text});
      }
      addTurn(msg.isUser ? 'user' : 'model', parts);
    }

    final currentParts = <Map<String, dynamic>>[];
    if (imageBytes != null && imageBytes.isNotEmpty) {
      currentParts.add({
        'inline_data': {
          'mime_type': mimeType ?? 'image/jpeg',
          'data': base64Encode(imageBytes),
        }
      });
    }
    final baseText = userMessage.trim().isEmpty && imageBytes != null
        ? 'Hãy đọc và giải chi tiết bài tập trong bức ảnh này giúp tôi.'
        : userMessage;
    // Luôn cho AI biết ngày/tháng/thứ hiện tại.
    final dateCtx = '\n\n[${NowContext.build()}]';
    final combined = webContext != null && webContext.isNotEmpty
        ? '$baseText\n\n$webContext$dateCtx'
        : '$baseText$dateCtx';
    currentParts.add({'text': combined});

    // Lượt cuối LUÔN là `user` — request kết thúc bằng `model` bị Gemini 3.x
    // từ chối thẳng.
    addTurn('user', currentParts);

    return contents;
  }

  static Future<String> chat({
    required String apiKey,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
    String? studyContext,
  }) async {
    if (apiKey.isEmpty && !_onWeb) {
      return 'Gemini API Key chưa được cấu hình. Chủ app cần đặt key trong AppConfig (biến GEMINI_API_KEY) rồi build lại.';
    }

    final contents = buildContents(
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mimeType: mimeType,
      webContext: webContext,
    );
    final systemInstruction = buildSystemInstruction(studyContext: studyContext);

    try {
      // Gọi 1 request duy nhất. Không gửi google_search grounding vì key
      // miễn phí không hỗ trợ (400/403) và làm tốn gấp đôi quota; app vẫn có
      // web search riêng (Tavily) chèn webContext vào prompt khi cần.
      final onWeb = _onWeb;
      final resp =
          await _post(contents, systemInstruction, apiKey, onWeb: onWeb);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] ??
            'AI không trả lời được nội dung này. Vui lòng thử lại.';
        return text;
      } else if (resp.statusCode == 429) {
        // Dùng chung bộ phân loại với OpenRouter: 429 của Gemini CŨNG có thể
        // là hạn mức **theo ngày** — bảo người dùng “chờ 1–2 phút” khi đó là
        // bảo họ làm một việc vô ích. Cùng lỗi, cùng cách sửa.
        return OpenRouterService.rateLimitMessage(resp.body);
      } else if (resp.statusCode == 400) {
        // Kèm message thật của Google: trước đây mọi 400 đều bị báo thành
        // "API Key không hợp lệ", khiến lỗi định dạng payload (lượt không hợp
        // lệ) bị chẩn đoán sai và người dùng loay hoay đổi key vô ích.
        final detail = _apiErrorDetail(resp.body);
        return detail == null
            ? '❌ Gemini từ chối yêu cầu (HTTP 400). Kiểm tra lại nội dung câu hỏi hoặc API key trong phần Tài khoản.'
            : '❌ Gemini từ chối yêu cầu: $detail';
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        final detail = _apiErrorDetail(resp.body);
        return detail == null
            ? '❌ Không có quyền gọi Gemini: key sai, chưa bật Gemini API cho project, hoặc bị chặn vùng. Kiểm tra lại khoá trong phần Tài khoản.'
            : '❌ Không có quyền gọi Gemini: $detail';
      } else if (resp.statusCode == 404) {
        // Model bị đổi tên/ngừng hỗ trợ — nói thẳng thay vì lỗi chung chung.
        return '❌ Không tìm thấy model Gemini "$model" (HTTP 404). '
            'Model có thể đã bị đổi tên hoặc ngừng hỗ trợ — cập nhật lại model Gemini trong app.';
      } else if (resp.statusCode == 413) {
        return '❌ Ảnh gửi quá lớn bị máy chủ từ chối. Hãy chọn ảnh nhỏ hơn.';
      } else if (onWeb &&
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
        final detail = _apiErrorDetail(resp.body);
        return detail == null
            ? '❌ Lỗi ${resp.statusCode}: Không thể kết nối đến AI Coach. Kiểm tra mạng và thử lại.'
            : '❌ Lỗi ${resp.statusCode}: $detail';
      }
    } catch (e) {
      return '❌ Lỗi kết nối: $e\n\nHãy kiểm tra kết nối mạng hoặc dung lượng ảnh và thử lại.';
    }
  }

  /// Trích `message` trong body lỗi của Gemini.
  ///
  /// Gemini trả `{"error": {"code": 400, "message": "...", "status": "..."}}`,
  /// còn proxy của app trả `{"error": "..."}` dạng chuỗi — đọc được cả hai.
  static String? _apiErrorDetail(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final error = data['error'];
        if (error is String && error.trim().isNotEmpty) return error.trim();
        if (error is Map) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      }
    } catch (_) {
      // Body không phải JSON → không có chi tiết, phía gọi vẫn dùng mã lỗi.
    }
    return null;
  }

  static Future<http.Response> _post(
    List<Map<String, dynamic>> contents,
    String systemInstruction,
    String apiKey, {
    required bool onWeb,
  }) {
    final uri = onWeb
        ? Uri.base.resolve('/api/gemini')
        : Uri.parse('$_baseUrl?key=$apiKey');
    return http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            // Proxy `/api/gemini` nén model trên URL, key giữ phía server.
            if (onWeb) 'model': model,
            // Persona + ngữ cảnh học tập đi qua systemInstruction (xem
            // buildSystemInstruction) — không chiếm lượt trong `contents`.
            'systemInstruction': {
              'parts': [
                {'text': systemInstruction}
              ],
            },
            'contents': contents,
            'generationConfig': {
              // KHÔNG gửi temperature/top_p/top_k: Google đã bỏ các tham số
              // sampling này từ Gemini 3.x (3.7 Flash "strictly enforces") —
              // gửi vào là bị bỏ qua hoặc bị từ chối.
              'maxOutputTokens': 2048,
            }
          }),
        )
        .timeout(const Duration(seconds: 40));
  }
}
