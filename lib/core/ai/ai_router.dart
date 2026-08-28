import 'dart:typed_data';
import '../../features/study/domain/models/study_models.dart';
import '../utils/gemini_service.dart';
import '../utils/storage_service.dart';
import 'ai_models.dart';
import 'openrouter_service.dart';

/// Định tuyến request chat của AI Coach đến service phù hợp theo model.
///
/// - Các model có slug bắt đầu bằng `gemini/` gọi trực tiếp Gemini API bằng
///   key người dùng nhập (Tài khoản → Gemini API Key).
/// - Mọi model khác chạy qua OpenRouter (một key duy nhất của app + failover).
class AiRouter {
  static Future<String> chat({
    required AIModel model,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    // Kiểm tra model hỗ trợ ảnh.
    if (imageBytes != null && imageBytes.isNotEmpty && !model.supportsVision) {
      return '❌ Model "${model.label}" không hỗ trợ đọc ảnh. Hãy chọn model có gắn nhãn "đọc ảnh" (GPT-4o mini, Gemini Flash).';
    }

    if (model.slug.startsWith('gemini/')) {
      return GeminiService.chat(
        apiKey: StorageService.getGeminiApiKey(),
        history: history,
        userMessage: userMessage,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
    }

    return OpenRouterService.chat(
      model: model.slug,
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mimeType: mimeType,
    );
  }
}
