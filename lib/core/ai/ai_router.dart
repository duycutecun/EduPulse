import 'dart:typed_data';
import '../../features/study/domain/models/study_models.dart';
import 'ai_models.dart';
import 'openrouter_service.dart';

/// Định tuyến request chat của AI Coach đến service phù hợp theo model.
///
/// Hiện tại mọi model (cả Google/OpenAI) đều chạy qua OpenRouter để tận dụng
/// một key duy nhất + auto-failover sẵn có.
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

    return OpenRouterService.chat(
      model: model.slug,
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mimeType: mimeType,
    );
  }
}
