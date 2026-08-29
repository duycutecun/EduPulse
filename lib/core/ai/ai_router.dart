import 'dart:typed_data';
import '../../features/study/domain/models/study_models.dart';
import '../config.dart';
import '../utils/gemini_service.dart';
import '../utils/web_search_service.dart';
import 'ai_models.dart';
import 'openrouter_service.dart';

/// Định tuyến request chat của AI Coach đến service phù hợp theo model.
///
/// - Các model có slug bắt đầu bằng `gemini/` gọi trực tiếp Gemini API bằng
///   key chủ app cấu hình trong `AppConfig.geminiApiKey`.
/// - Mọi model khác chạy qua OpenRouter (một key duy nhất của app + failover).
class AiRouter {
  static Future<String> chat({
    required AIModel model,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    bool searchWeb = true,
  }) async {
    // Kiểm tra model hỗ trợ ảnh.
    if (imageBytes != null && imageBytes.isNotEmpty && !model.supportsVision) {
      return '❌ Model "${model.label}" không hỗ trợ đọc ảnh. Hãy chọn model có gắn nhãn "đọc ảnh" (GPT-4o mini, Gemini Flash).';
    }

    // Tự động tra cứu web để AI có thêm thông tin tham khảo.
    // Không chạy khi kèm ảnh (câu hỏi liên quan nội dung ảnh).
    String? webContext;
    if (searchWeb && (imageBytes == null || imageBytes.isEmpty)) {
      try {
        final lookup = await WebSearchService.lookup(userMessage);
        webContext = lookup?.toPromptBlock();
      } catch (_) {
        webContext = null;
      }
    }

    if (model.slug.startsWith('gemini/')) {
      return GeminiService.chat(
        apiKey: AppConfig.geminiApiKey,
        history: history,
        userMessage: userMessage,
        imageBytes: imageBytes,
        mimeType: mimeType,
        webContext: webContext,
      );
    }

    return OpenRouterService.chat(
      model: model.slug,
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mimeType: mimeType,
      webContext: webContext,
    );
  }
}
