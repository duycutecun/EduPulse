import 'dart:typed_data';
import '../../features/study/domain/models/study_models.dart';
import 'ai_config.dart';
import '../utils/gemini_service.dart';
import '../utils/web_search_service.dart';
import 'ai_models.dart';
import 'ai_context.dart';
import 'groq_service.dart';
import 'openrouter_service.dart';

/// Định tuyến request chat của AI Coach đến service phù hợp theo model.
///
/// - Model có slug bắt đầu bằng `groq/` chạy qua proxy `/api/groq` (Groq —
///   AI MẶC ĐỊNH, free & nhanh nhất; key `GROQ_API_KEY` phía server).
/// - Model có slug bắt đầu bằng `gemini/` gọi trực tiếp Gemini API bằng
///   key chủ app cấu hình trong `AiConfig.geminiApiKey` — và là bắt buộc khi
///   đọc ảnh (Groq free không nhận image input).
/// - Các model khác chạy qua OpenRouter (một key duy nhất + failover).
///
/// Trên web, tất cả đều qua proxy serverless cùng origin (`/api/groq`,
/// `/api/openrouter`, `/api/gemini`) để không lộ key trong bundle client.
///
/// # Auto + Failover
/// - Câu hỏi kèm ảnh luôn ưu tiên Gemini trước (đọc ảnh thuộc Gemini —
///   decided; Groq không nhận ảnh), còn câu hỏi chỉ-text ưu tiên Groq.
/// - Mọi request được thử theo danh sách model ứng viên: nếu model hỏng
///   (429 hết hạn mức, 5xx, timeout, mạng...) thì tự động chuyển sang model
///   kế tiếp (Groq → OpenRouter → Gemini) để luôn có câu trả lời
///   ("fallback ≥99%", đặc tả M3.4). MỖI model chỉ thử MỘT lần, tối đa
///   [_maxAttempts] ứng viên — không vòng lặp vô hạn cho đến khi AI nào đó
///   trả lời.
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

  static Stream<String> chatStream({
    required AIModel model,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    bool searchWeb = true,
    AiContextLevel contextLevel = AiContextLevel.full,
    TodayTask? contextTask,
    int? availableMinutes,
  }) async* {
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;

    if (hasImage && imageBytes.length > 3 * 1024 * 1024 && _onWeb) {
      yield '❌ Ảnh quá lớn (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB). '
          'Máy chủ web giới hạn ~4MB — hãy chọn ảnh nhỏ hơn hoặc nén ảnh trước khi gửi.';
      return;
    }

    String? webContext;
    lastWebSource = null;
    if (searchWeb && !hasImage) {
      try {
        final lookup = await WebSearchService.lookup(userMessage,
            tavilyApiKey: AiConfig.tavilyApiKey);
        webContext = lookup?.toPromptBlock();
        lastWebSource = lookup;
      } catch (_) {
        webContext = null;
      }
    }

    final candidates = _candidates(model, hasImage);

    String? studyContext;
    try {
      studyContext = AiStudyContext.buildFor(
        contextLevel,
        task: contextTask,
        availableMinutes: availableMinutes,
      );
    } catch (_) {
      studyContext = null;
    }

    String? lastError;
    var tried = 0;
    for (final m in candidates) {
      if (hasImage && !m.supportsVision) continue;
      tried += 1;
      if (tried > _maxAttempts) break;

      var fullResponse = '';
      var hasError = false;

      await for (final chunk in _callStream(
        m,
        history: history,
        userMessage: userMessage,
        imageBytes: imageBytes,
        mimeType: mimeType,
        webContext: webContext,
        studyContext: studyContext,
      )) {
        if (chunk.startsWith('❌')) {
          lastError = chunk;
          hasError = true;
          break;
        }
        fullResponse += chunk;
        yield chunk;
      }

      if (!hasError && fullResponse.isNotEmpty) return;
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (hasImage && candidates.every((m) => !m.supportsVision)) {
      yield '❌ Không có model nào trong danh sách hỗ trợ đọc ảnh.';
      return;
    }
    yield lastError ??
        '❌ Các model AI đều đang lỗi. Chờ vài giây rồi thử lại nhé.';
  }

  static Future<String> chat({
    required AIModel model,
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    bool searchWeb = true,
    AiContextLevel contextLevel = AiContextLevel.full,
    TodayTask? contextTask,
    int? availableMinutes,
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
        final lookup = await WebSearchService.lookup(userMessage,
            tavilyApiKey: AiConfig.tavilyApiKey);
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

    // Ngữ cảnh học tập của học sinh (mục 10.2): kỳ thi, nhiệm vụ, chuỗi học,
    // thời gian học, điểm thi thử, ghi chú. Đây là thứ biến AI Coach từ khung
    // chat rời rạc thành trợ lý thật sự của app. Dựng lại mỗi lượt để AI luôn
    // nắm tình trạng mới nhất, và bọc try/catch vì hỏng context tuyệt đối
    // không được làm sập chat.
    String? studyContext;
    try {
      studyContext = AiStudyContext.buildFor(
        contextLevel,
        task: contextTask,
        availableMinutes: availableMinutes,
      );
    } catch (_) {
      studyContext = null;
    }

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
        studyContext: studyContext,
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

    // Groq luôn có mặt (AI mặc định từ 10/2026): catalog runtime cache lại từ
    // phiên cũ có thể chưa chứa model mới — nạp trực tiếp từ definitions tĩnh.
    for (final m in AIModel.definitions) {
      if (m.slug.startsWith('groq/')) add(m);
    }

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
    // Chặn thời gian chờ tổng: tối đa [_maxAttempts] lượt thử (mỗi model một
    // lần — không vòng lặp/vòng đệ quy vô hạn). Nhưng luôn GIỮ một slot cho
    // Gemini: đó là phương án dự phòng chắc chắn ("fallback ≥99%", M3.4) —
    // nếu Gemini bị cắt khỏi danh sách thì fallback sẽ dừng ở model khác.
    if (list.length > _maxAttempts) {
      if (!list.take(_maxAttempts).any((m) => m.slug.startsWith('gemini/'))) {
        final trimmed = list.sublist(0, _maxAttempts - 1);
        trimmed.add(
          list.firstWhere((m) => m.slug.startsWith('gemini/')),
        );
        return trimmed;
      }
      return list.sublist(0, _maxAttempts);
    }
    return list;
  }

  /// Thứ tự ưu tiên model tốt đã biết theo ngữ cảnh câu hỏi.
  ///
  /// Text: Groq dẫn đầu (nhanh nhất, free) — nếu Groq quá tải thì
  /// OpenRouter bù, cuối cùng Gemini. Ảnh: Gemini dẫn đầu (decided —
  /// Groq free không nhận image input, đọc ảnh là nhiệm vụ của Gemini).
  static List<String> _preferredOrder(bool hasImage) {
    if (hasImage) {
      return const [
        'gemini/gemini-3.7-flash',
        'thinkingmachines/inkling:free',
        'google/gemma-4-31b-it:free',
        'dots-studio/dots-3-note-preview:free',
        'google/gemma-4-26b-a4b-it:free',
        'nex-agi/nex-n2.5-pro:free',
        'thinkingmachines/inkling-small:free',
      ];
    }
    return const [
      'groq/openai/gpt-oss-20b',
      'groq/openai/gpt-oss-120b',
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

  static Stream<String> _callStream(
    AIModel m, {
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
    String? studyContext,
  }) async* {
    if (m.slug.startsWith('gemini/')) {
      final response = await GeminiService.chat(
        apiKey: AiConfig.geminiApiKey,
        history: history,
        userMessage: userMessage,
        imageBytes: imageBytes,
        mimeType: mimeType,
        webContext: webContext,
        studyContext: studyContext,
      );
      yield response;
      return;
    }
    if (GroqService.isGroqSlug(m.slug)) {
      // Groq KHÔNG nhận ảnh (free) — nhánh này chỉ chạy cho câu hỏi text;
      // list ứng viên đã lọc trước (mỗi model vision chỉ khi không có ảnh).
      // Bỏ các tin nhắn CŨ có ảnh đính kèm khỏi history: gửi kèm image part
      // là Groq 400, còn nội dung ảnh thuộc Gemini ở lượt trước đó.
      final messages = OpenRouterService.buildMessages(
        history: history.where((msg) => msg.imageBytes == null).toList(),
        userMessage: userMessage,
        webContext: webContext,
        studyContext: studyContext,
      );
      yield* GroqService.chatStream(
        model: GroqService.nativeModel(m.slug),
        messages: messages,
      );
      return;
    }
    yield* OpenRouterService.chatStream(
      model: m.slug,
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mimeType: mimeType,
      webContext: webContext,
      studyContext: studyContext,
    );
  }

  static Future<String> _call(
    AIModel m, {
    required List<ChatMessage> history,
    required String userMessage,
    Uint8List? imageBytes,
    String? mimeType,
    String? webContext,
    String? studyContext,
  }) {
    if (m.slug.startsWith('gemini/')) {
      return GeminiService.chat(
        apiKey: AiConfig.geminiApiKey,
        history: history,
        userMessage: userMessage,
        imageBytes: imageBytes,
        mimeType: mimeType,
        webContext: webContext,
        studyContext: studyContext,
      );
    }
    if (GroqService.isGroqSlug(m.slug)) {
      // Groq KHÔNG nhận ảnh (free): chain chỉ-text → ảnh luôn đi Gemini.
      // Bỏ tin nhắn cũ có ảnh khỏi history (reason ở _callStream).
      final messages = OpenRouterService.buildMessages(
        history: history.where((msg) => msg.imageBytes == null).toList(),
        userMessage: userMessage,
        webContext: webContext,
        studyContext: studyContext,
      );
      return GroqService.chat(
        model: GroqService.nativeModel(m.slug),
        messages: messages,
      );
    }
    return OpenRouterService.chat(
      model: m.slug,
      history: history,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mimeType: mimeType,
      webContext: webContext,
      studyContext: studyContext,
    );
  }
}
