import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../features/study/domain/models/study_models.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.7-flash:generateContent';

  static Future<String> chat({
    required String apiKey,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
  }) async {
    if (apiKey.isEmpty) {
      return 'Gemini API Key chưa được cấu hình. Chủ app cần đặt key trong AppConfig (biến GEMINI_API_KEY) rồi build lại.';
    }

    final contents = <Map<String, dynamic>>[];
    
    // System instruction persona prompt
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text':
              'Bạn là AI Coach của EduPulse — trợ lý học tập & chuyên gia luyện thi hàng đầu cho sĩ tử Việt Nam (THPTQG, ĐGNL TSA, HSA, HSG). '
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
    final textContent = userMessage.trim().isEmpty && imageBytes != null
        ? 'Hãy đọc và giải chi tiết bài tập trong bức ảnh này giúp tôi.'
        : userMessage;
    currentParts.add({
      'text': webContext != null && webContext.isNotEmpty
          ? '$textContent\n\n$webContext'
          : textContent,
    });

    contents.add({
      'role': 'user',
      'parts': currentParts,
    });

    try {
      // Bật Google Search grounding (dữ liệu thời gian thực). Chỉ chạy khi
      // câu hỏi KHÔNG kèm ảnh — grounding + ảnh có thể xung đột.
      final tryGrounding = imageBytes == null || imageBytes.isEmpty;
      var resp = await _post(contents, apiKey, useGrounding: tryGrounding);

      // Nếu key không hỗ trợ grounding (403/400 vì thiếu billing), thử lại
      // không grounding để không làm hỏng chat (fallback webContext/Wikipedia).
      if (!tryGrounding ||
          resp.statusCode == 403 ||
          (resp.statusCode == 400 &&
              (resp.body.contains('billing') ||
                  resp.body.contains('grounding') ||
                  resp.body.contains('permission')))) {
        if (tryGrounding) {
          resp = await _post(contents, apiKey, useGrounding: false);
        }
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
            'AI không trả lời được nội dung này. Vui lòng thử lại.';

        // Gom nguồn Google Search (groundingMetadata.groundingChunks).
        final sources = <String>[];
        try {
          final meta = data['candidates']?[0]?['groundingMetadata'];
          final chunks = meta?['groundingChunks'] as List? ?? [];
          for (final chunk in chunks) {
            final web = chunk?['web'];
            if (web != null) {
              final title = (web['title'] as String?)?.trim() ?? '';
              final uri = (web['uri'] as String?)?.trim() ?? '';
              if (uri.isNotEmpty) {
                sources.add(title.isNotEmpty ? '$title ($uri)' : uri);
              }
            }
          }
        } catch (_) {}

        var out = text;
        if (sources.isNotEmpty) {
          out = '$out\n\n🔍 Tra cứu web thời gian thực (Google):';
          for (final s in sources.take(5)) {
            out = '$out\n• $s';
          }
        }
        return out;
      } else if (resp.statusCode == 400) {
        return '❌ API Key không hợp lệ hoặc yêu cầu không hợp lệ. Vui lòng kiểm tra lại trong phần Tài khoản.';
      } else if (resp.statusCode == 403) {
        return '❌ Quyền bị từ chối: key Gemini cần bật Google Search (billing) hoặc key không hợp lệ. Vui lòng kiểm tra lại.';
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
    required bool useGrounding,
  }) {
    return http
        .post(
          Uri.parse('$_baseUrl?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': contents,
            if (useGrounding)
              'tools': [
                {'google_search': {}},
              ],
            'generationConfig': {
              'temperature': 0.6,
              'maxOutputTokens': 2048,
            }
          }),
        )
        .timeout(const Duration(seconds: 40));
  }
}
