import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../features/study/domain/models/study_models.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  static Future<String> chat({
    required String apiKey,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    if (apiKey.isEmpty) {
      return 'Bạn chưa nhập Gemini API Key. Vào **Tài khoản → Cài đặt → Gemini API Key** để cấu hình AI Coach.';
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
    currentParts.add({'text': textContent});

    contents.add({
      'role': 'user',
      'parts': currentParts,
    });

    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': contents,
              'generationConfig': {
                'temperature': 0.6,
                'maxOutputTokens': 2048,
              }
            }),
          )
          .timeout(const Duration(seconds: 35));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
            'AI không trả lời được nội dung này. Vui lòng thử lại.';
      } else if (resp.statusCode == 400) {
        return '❌ API Key không hợp lệ hoặc dữ liệu ảnh quá lớn. Vui lòng kiểm tra lại trong phần Tài khoản.';
      } else {
        return '❌ Lỗi ${resp.statusCode}: Không thể kết nối đến AI Coach. Kiểm tra mạng và thử lại.';
      }
    } catch (e) {
      return '❌ Lỗi kết nối: $e\n\nHãy kiểm tra kết nối mạng hoặc dung lượng ảnh và thử lại.';
    }
  }
}
