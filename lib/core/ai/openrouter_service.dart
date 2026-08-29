import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../features/study/domain/models/study_models.dart';

/// Service gọi model qua OpenRouter (chuẩn OpenAI-compatible).
///
/// Dùng một API key duy nhất của chủ app (đã nhúng trong `config.dart`).
/// OpenRouter tự động định tuyến & failover khi provider hết quota, nên
/// không cần tự code xoay vòng nhiều key cho các model `:free`.
class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
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
      'Trả lời bằng tiếng Việt.';

  static Future<String> chat({
    required String model,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
  }) async {
    if (AppConfig.openRouterApiKey.isEmpty) {
      return '❌ Chưa cấu hình OpenRouter API Key (thiếu biến môi trường OPENROUTER_API_KEY khi build).';
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _persona},
    ];

    for (final msg in history.where((m) => !m.isLoading)) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': _buildContent(msg.imageBytes, msg.text),
      });
    }

    final resolved = _resolveText(userMessage, imageBytes);
    final finalText = webContext != null && webContext.isNotEmpty
        ? '$resolved\n\n$webContext'
        : resolved;
    final currentContent = _buildContent(imageBytes, finalText);
    messages.add({'role': 'user', 'content': currentContent});

    try {
      final resp = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
              'HTTP-Referer': 'https://edu-pulse-five.vercel.app',
              'X-Title': 'EduPulse',
            },
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
        return '❌ Model này đã hết lượt miễn phí (quota exceeded). Hãy chọn model khác trong danh sách hoặc thử lại sau ít phút.';
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        return '❌ Lỗi xác thực: OpenRouter API Key không hợp lệ. Vui lòng liên hệ chủ app.';
      } else if (resp.statusCode == 400) {
        return '❌ Yêu cầu không hợp lệ (dữ liệu ảnh quá lớn hoặc model không hỗ trợ ảnh). Vui lòng thử lại.';
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

  static String _resolveText(String userMessage, Uint8List? imageBytes) {
    if (userMessage.trim().isNotEmpty) return userMessage;
    if (imageBytes != null) {
      return 'Hãy đọc và giải chi tiết bài tập trong bức ảnh này giúp tôi.';
    }
    return userMessage;
  }
}
