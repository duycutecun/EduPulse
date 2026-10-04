import 'ai_models.dart';

class ModelSelector {
  static AIModel select({
    required bool hasImage,
    required bool needsReasoning,
    required bool isSimpleQuery,
    AIModel? userPreferred,
  }) {
    if (userPreferred != null) {
      if (hasImage && !userPreferred.supportsVision) {
        return _bestVisionModel();
      }
      return userPreferred;
    }

    if (hasImage) {
      return _bestVisionModel();
    }

    if (needsReasoning) {
      return _bestReasoningModel();
    }

    if (isSimpleQuery) {
      return _fastestModel();
    }

    return _balancedModel();
  }

  static AIModel _bestVisionModel() {
    for (final m in AIModel.definitions) {
      if (m.supportsVision && m.slug.contains('inkling')) return m;
    }
    for (final m in AIModel.definitions) {
      if (m.supportsVision) return m;
    }
    return AIModel.definitions.first;
  }

  static AIModel _bestReasoningModel() {
    for (final m in AIModel.definitions) {
      if (m.slug.contains('nemotron-3-ultra')) return m;
    }
    for (final m in AIModel.definitions) {
      if (m.slug.contains('nemotron')) return m;
    }
    return AIModel.definitions.first;
  }

  static AIModel _fastestModel() {
    for (final m in AIModel.definitions) {
      if (m.slug.contains('lightning')) return m;
    }
    for (final m in AIModel.definitions) {
      if (m.slug.contains('mini') || m.slug.contains('small')) return m;
    }
    return AIModel.definitions.first;
  }

  static AIModel _balancedModel() {
    for (final m in AIModel.definitions) {
      if (m.slug.contains('nemotron-3-super')) return m;
    }
    return AIModel.definitions.first;
  }

  static bool isSimpleQuery(String message) {
    final lower = message.toLowerCase();
    if (lower.length < 20) return true;
    if (lower.contains('?') && lower.length < 50) return true;
    final simplePatterns = [
      'là gì',
      'nghĩa là',
      'công thức',
      'định nghĩa',
      'ví dụ',
    ];
    return simplePatterns.any((p) => lower.contains(p));
  }

  static bool needsReasoning(String message) {
    final lower = message.toLowerCase();
    final reasoningPatterns = [
      'giải',
      'tính',
      'chứng minh',
      'so sánh',
      'phân tích',
      'tại sao',
      'như thế nào',
      'lập kế hoạch',
    ];
    return reasoningPatterns.any((p) => lower.contains(p));
  }
}
