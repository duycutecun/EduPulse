import '../../features/study/domain/models/study_models.dart';
import 'ai_models.dart';
import 'ai_context.dart';
import 'ai_memory_service.dart';
import 'ai_response_cache.dart';
import 'predictive_engine.dart';
import 'early_warning_service.dart';
import 'cross_subject_analyzer.dart';
import 'model_selector.dart';
import 'context_optimizer.dart';

class AiBrain {
  static String buildEnhancedContext({
    required AiContextLevel level,
    TodayTask? task,
    int? availableMinutes,
    DateTime? now,
  }) {
    final context = AiStudyContext.buildFor(
      level,
      task: task,
      availableMinutes: availableMinutes,
      now: now,
    );

    final memoryPrompt = AiMemoryService.buildMemoryPrompt();
    if (memoryPrompt.isEmpty) return context;

    final combined = '$memoryPrompt\n\n$context';
    return ContextOptimizer.optimize(combined, level);
  }

  static PredictionResult? getPrediction({DateTime? now}) {
    return PredictiveEngine.predict(now: now);
  }

  static List<Warning> getWarnings({DateTime? now}) {
    return EarlyWarningService.check(now: now);
  }

  static List<CorrelationResult> getCorrelations({DateTime? now}) {
    return CrossSubjectAnalyzer.analyze(now: now);
  }

  static AIModel selectModel({
    required bool hasImage,
    required String message,
    AIModel? userPreferred,
  }) {
    return ModelSelector.select(
      hasImage: hasImage,
      needsReasoning: ModelSelector.needsReasoning(message),
      isSimpleQuery: ModelSelector.isSimpleQuery(message),
      userPreferred: userPreferred,
    );
  }

  static String? getCachedResponse(String query) {
    return AiResponseCache.get(query);
  }

  static void cacheResponse(String query, String response) {
    AiResponseCache.put(query, response);
  }

  static void invalidateCache() {
    AiResponseCache.invalidateOnDataChange();
  }

  static void recordConversation(String userMessage, String aiResponse) {
    AiMemoryService.appendToSummary(userMessage, aiResponse);
  }

  static void clearMemory() {
    AiMemoryService.clear();
  }
}
