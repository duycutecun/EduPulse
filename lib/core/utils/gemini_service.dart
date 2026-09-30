import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../../features/study/domain/models/study_models.dart';
import 'now_context.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.7-flash:generateContent';

  /// Đang chạy trên nền web (browser) — gọi proxy cùng origin `/api/gemini`,
  /// key giữ phía server (không lộ trong client).
  static bool get _onWeb {
    try {
      return Uri.base.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Dựng payload `contents` gửi lên Gemini.
  ///
  /// Tách riêng khỏi [chat] để test được việc ngữ cảnh học tập có thực sự
  /// nằm trong payload hay không, mà không cần gọi mạng thật.
  @visibleForTesting
  static List<Map<String, dynamic>> buildContents({
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
    String? studyContext,
  }) {
    final contents = <Map<String, dynamic>>[];

    // System instruction persona prompt
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text': 'Bạn là AI Coach của EduPulse — trợ lý học tập & chuyên gia luyện thi hàng đầu cho sĩ tử Việt Nam (THPTQG, ĐGNL TSA, HSA, HSG). '
              'Khi học sinh gửi ảnh đề bài (Toán, Lý, Hóa, Sinh, Văn, Tiếng Anh): '
              '1. Đọc và nhận diện chính xác đề bài. '
              '2. Tóm tắt các giả thiết và yêu cầu. '
              '3. Trình bày phương pháp tư duy & lời giải chi tiết từng bước. '
              '4. Nêu các lưu ý / bẫy trắc nghiệm thường gặp. '
              'Đôi khi câu hỏi sẽ kèm một khối "THAM KHẢO TỪ WEB" từ Wikipedia. '
              'Hãy cân nhắc thông tin đó nếu liên quan và hữu ích để trả lời chính xác, phong phú hơn; '
              'nếu không liên quan thì bỏ qua và trả lời theo kiến thức vốn có. '
              'Trả lời chuẩn sư phạm, thân thiện, khích lệ tinh thần học sinh.'
        }
      ]
    });
    contents.add({
      'role': 'model',
      'parts': [
        {
          'text':
              'Chào bạn! Tôi là AI Coach của EduPulse, sẵn sàng đồng hành giải đề thi, hướng dẫn phương pháp giải và tối ưu điểm số cùng bạn!'
        }
      ]
    });

    // Ngữ cảnh học tập thật của học sinh — đặt ngay sau lời chào, trước lịch
    // sử chat, để mọi câu trả lời đều dựa trên tình huống thực tế.
    final ctx = studyContext?.trim();
    if (ctx != null && ctx.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': 'Đây là ngữ cảnh học tập hiện tại của tôi trên EduPulse. '
                'Hãy nhớ và dùng nó để tư vấn cụ thể cho đúng tôi: nói tới tình '
                'huống thật (kỳ thi, còn bao nhiêu ngày, môn đang yếu, nhiệm vụ '
                'chưa làm) thay vì lời khuyên chung chung; khi tôi hỏi chung thì '
                'chủ động dựa vào đây để đề xuất kế hoạch; đừng kể lại nguyên '
                'văn khối này và đừng hỏi lại những gì đã có trong đó.\n\n'
                '--- NGỮ CẢNH HỌC TẬP HIỆN TẠI ---\n$ctx'
          }
        ]
      });
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
      if (msg.text.isNotEmpty) {
        parts.add({'text': msg.text});
      }
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': parts,
      });
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

    contents.add({
      'role': 'user',
      'parts': currentParts,
    });

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
      studyContext: studyContext,
    );

    try {
      // Gọi 1 request duy nhất. Không gửi google_search grounding vì key
      // miễn phí không hỗ trợ (400/403) và làm tốn gấp đôi quota; app vẫn có
      // web search riêng (Tavily) chèn webContext vào prompt khi cần.
      final onWeb = _onWeb;
      final resp = await _post(contents, apiKey, onWeb: onWeb);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] ??
            'AI không trả lời được nội dung này. Vui lòng thử lại.';
        return text;
      } else if (resp.statusCode == 429) {
        return '❌ Đang bị giới hạn tần suất (HTTP 429): gửi quá nhanh hoặc key hết quota. Chờ 1–2 phút rồi thử lại.';
      } else if (resp.statusCode == 400) {
        return '❌ API Key không hợp lệ hoặc yêu cầu không hợp lệ. Vui lòng kiểm tra lại trong phần Tài khoản.';
      } else if (resp.statusCode == 403) {
        return '❌ Quyền bị từ chối: key Gemini cần bật Google Search (billing) hoặc key không hợp lệ. Vui lòng kiểm tra lại.';
      } else if (resp.statusCode == 413) {
        return '❌ Ảnh gửi quá lớn bị máy chủ từ chối. Hãy chọn ảnh nhỏ hơn.';
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

  static Future<http.Response> _post(
    List<Map<String, dynamic>> contents,
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
            if (onWeb) 'model': 'gemini-3.7-flash',
            'contents': contents,
            'generationConfig': {
              'temperature': 0.6,
              'maxOutputTokens': 2048,
            }
          }),
        )
        .timeout(const Duration(seconds: 40));
  }
}
