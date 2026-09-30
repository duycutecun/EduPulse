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
///
/// Trên web, cả hai đều đi qua proxy serverless cùng origin (`/api/openrouter`,
/// `/api/gemini`) vì OpenRouter chặn CORS và tránh lộ key trong bundle client.
///
/// # Auto + Failover
/// - Model "Auto (Free)" (`openrouter/free`) được định tuyến *thông minh*:
///   câu hỏi kèm ảnh ưu tiên model đọc ảnh tốt nhất, câu hỏi chỉ text ưu tiên
///   model lý luận/fast nhất.
/// - Mọi request được thử theo danh sách model ứng viên: nếu model hỏng
///   (429 hết quota, 5xx, 400, mạng...) thì tự động chuyển sang model kế tiếp
///   để luôn có câu trả lời ("AI này lỗi, AI kia bù vào").
class AiRouter {
  static bool get _onWeb {
    try {
      return Uri.base.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Số model ứng viên tối đa thử failover (giới hạn để không kéo dài thời
  /// gian chờ khi nhiều model cùng lỗi).
  static const int _maxAttempts = 6;

  /// Nguồn web dùng cho câu trả lời GẦN NHẤT (mục 10.9 — AI citations).
  /// UI đọc để hiển thị source card; null khi câu hỏi không tra web.
  static WebLookup? lastWebSource;

  static Future<String> chat({
    required AIModel model,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    bool searchWeb = true,
  }) async {
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;

    // Proxy serverless (web) giữ giới hạn body ~4MB — chặn sớm ở client.
    if (hasImage && imageBytes.length > 3 * 1024 * 1024 && _onWeb) {
      return '❌ Ảnh quá lớn (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB). '
          'Máy chủ web giới hạn ~4MB — hãy chọn ảnh nhỏ hơn hoặc nén ảnh trước khi gửi.';
    }

    // Tự động tra cứu web để AI có thêm thông tin tham khảo.
    String? webContext;
    lastWebSource = null;
    if (searchWeb && !hasImage) {
      try {
        final lookup =
            await WebSearchService.lookup(userMessage, tavilyApiKey: AppConfig.tavilyApiKey);
        webContext = lookup?.toPromptBlock();
        // Ghi nguồn để UI hiển thị source card (ưu tiên nguồn
        // authoritative — Wikipedia/Tavily được service chọn sẵn).
        lastWebSource = lookup;
      } catch (_) {
        webContext = null;
      }
    }

    // Danh sách model ứng viên được sắp xếp hợp lý (xem _candidates).
    final candidates = _candidates(model, hasImage);

    String? lastError;
    var tried = 0;
    for (final m in candidates) {
      // Kèm ảnh: bỏ qua model không hỗ trợ đọc ảnh (chọn AI hợp lý).
      if (hasImage && !m.supportsVision) continue;
      tried += 1;
      if (tried > _maxAttempts) break;

      final result = await _call(
        m,
        history: history,
        userMessage: userMessage,
        imageBytes: imageBytes,
        mimeType: mimeType,
        webContext: webContext,
      );

      if (_isOk(result)) return result;
      lastError = result;
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (hasImage && candidates.every((m) => !m.supportsVision)) {
      return '❌ Không có model nào trong danh sách hỗ trợ đọc ảnh. '
          'Hãy chọn model có nhãn "đọc ảnh" trong bộ chọn model.';
    }
    return lastError ??
        '❌ Các model AI đều đang lỗi. Chờ vài giây rồi thử lại nhé.';
  }

  /// Chọn & sắp xếp hợp lý danh sách model ứng viên:
  /// 1. Model người dùng đang chọn (nếu phù hợp với loại câu hỏi).
  /// 2. Các model "đã biết tốt" theo ngữ cảnh (ảnh → vision; text → lý luận).
  /// 3. Các model còn lại trong catalog runtime.
  /// 4. Gemini (chạy bằng key riêng của app) làm phương án dự phòng ổn định.
  static List<AIModel> _candidates(AIModel selected, bool hasImage) {
    final base = AIModel.runtimeDefinitions ??
        (hasImage
            ? AIModel.definitions.where((m) => m.supportsVision).toList()
            : List<AIModel>.from(AIModel.definitions));

    final list = <AIModel>[];
    void add(AIModel m) {
      if (!list.any((e) => e.slug == m.slug)) list.add(m);
    }

    // Model đang chọn dẫn đầu trừ khi kèm ảnh mà model không đọc được ảnh
    // (khi đó nhảy thẳng tới model vision để chọn AI hợp lý).
    if (!(hasImage && !selected.supportsVision)) add(selected);

    for (final slug in _preferredOrder(hasImage)) {
      for (final m in base) {
        if (m.slug == slug) add(m);
      }
    }

    if (hasImage) {
      for (final m in base) {
        if (m.supportsVision) add(m);
      }
    } else {
      for (final m in base) {
        add(m);
      }
    }

    // Gemini luôn ở cuối danh sách làm phương án dự phòng chắc chắn.
    for (final m in AIModel.definitions) {
      if (m.slug.startsWith('gemini/')) add(m);
    }
    // Nếu kèm ảnh mà chưa có model vision nào → chèn ngầm Gemini.
    if (hasImage && list.every((m) => !m.supportsVision)) {
      for (final m in AIModel.definitions) {
        if (m.slug.startsWith('gemini/')) add(m);
      }
    }
    if (list.length > _maxAttempts) {
      return list.sublist(0, _maxAttempts);
    }
    return list;
  }

  /// Thứ tự ưu tiên model tốt đã biết theo ngữ cảnh câu hỏi.
  static List<String> _preferredOrder(bool hasImage) {
    if (hasImage) {
      return const [
        'thinkingmachines/inkling:free',
        'google/gemma-4-31b-it:free',
        'dots-studio/dots-3-note-preview:free',
        'google/gemma-4-26b-a4b-it:free',
        'nex-agi/nex-n2.5-pro:free',
        'thinkingmachines/inkling-small:free',
      ];
    }
    return const [
      'nvidia/nemotron-3-ultra-550b-a55b:free',
      'thinkingmachines/inkling:free',
      'google/gemma-4-31b-it:free',
      'nvidia/nemotron-3-super-120b-a12b:free',
      'nvidia/nemotron-3.5-lightning:free',
      'thinkingmachines/inkling-small:free',
    ];
  }

  /// Kết quả hợp lệ khi có nội dung thật, không phải chuỗi lỗi '❌...'.
  static bool _isOk(String result) {
    final t = result.trim();
    return t.isNotEmpty && !t.startsWith('❌');
  }

  static Future<String> _call(
    AIModel m, {
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
  }) {
    if (m.slug.startsWith('gemini/')) {
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
      model: m.slug,
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mimeType: mimeType,
      webContext: webContext,
    );
  }
}