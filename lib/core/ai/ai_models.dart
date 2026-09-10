import 'package:flutter/material.dart';

import 'free_models_catalog.dart';

/// Định nghĩa model AI có sẵn trong AI Coach.
///
/// Hiện tại tất cả model đều chạy qua OpenRouter (một API key duy nhất,
/// tự động failover khi một provider hết quota). Các model có hậu tố `:free`
/// là các variant miễn phí do OpenRouter định tuyến.
class AIModel {
  /// Slug model dùng trong request OpenRouter (vd: `meta-llama/llama-3.3-70b`).
  final String slug;

  /// Tên hiển thị cho người dùng.
  final String label;

  /// Mô tả ngắn.
  final String description;

  /// Model có hỗ trợ đọc ảnh (vision) hay không.
  final bool supportsVision;

  const AIModel({
    required this.slug,
    required this.label,
    required this.description,
    this.supportsVision = false,
  });

  /// Danh sách model có sẵn để người dùng chọn (mặc định lên đầu).
  ///
  /// Cập nhật 09/2026 theo danh sách model miễn phí của OpenRouter
  /// (https://openrouter.ai/collections/free-models).
  static const List<AIModel> definitions = [
    AIModel(
      slug: 'openrouter/free',
      label: 'Auto (Free)',
      description: 'Tự chọn model miễn phí tốt nhất',
    ),
    AIModel(
      slug: 'nvidia/nemotron-3-ultra-550b-a55b:free',
      label: 'Nemotron 3 Ultra (Free)',
      description: 'NVIDIA · 550B, lý luận mạnh',
    ),
    AIModel(
      slug: 'thinkingmachines/inkling:free',
      label: 'Inkling (Free)',
      description: 'Thinking Machines · đọc ảnh & audio',
      supportsVision: true,
    ),
    AIModel(
      slug: 'thinkingmachines/inkling-small:free',
      label: 'Inkling Small (Free)',
      description: 'Thinking Machines · nhẹ, đọc ảnh & audio',
      supportsVision: true,
    ),
    AIModel(
      slug: 'dots-studio/dots-3-note-preview:free',
      label: 'Dots3 Note (Free)',
      description: 'Dots Studio · đọc ảnh, ngữ cảnh 512K',
      supportsVision: true,
    ),
    AIModel(
      slug: 'google/gemma-4-31b-it:free',
      label: 'Gemma 4 31B (Free)',
      description: 'Google · đọc ảnh, ngữ cảnh 262K',
      supportsVision: true,
    ),
    AIModel(
      slug: 'google/gemma-4-26b-a4b-it:free',
      label: 'Gemma 4 26B A4B (Free)',
      description: 'Google · MoE nhẹ, đọc ảnh',
      supportsVision: true,
    ),
    AIModel(
      slug: 'nex-agi/nex-n2.5-pro:free',
      label: 'Nex N2.5 Pro (Free)',
      description: 'Nex AGI · agentic, đọc ảnh',
      supportsVision: true,
    ),
    AIModel(
      slug: 'nvidia/nemotron-3-super-120b-a12b:free',
      label: 'Nemotron 3 Super (Free)',
      description: 'NVIDIA · 120B cân bằng tốc độ',
    ),
    AIModel(
      slug: 'poolside/laguna-s-2.1:free',
      label: 'Laguna S 2.1 (Free)',
      description: 'Poolside · chuyên lập trình',
    ),
    AIModel(
      slug: 'cohere/north-mini-code:free',
      label: 'North Mini Code (Free)',
      description: 'Cohere · code nhanh',
    ),
    AIModel(
      slug: 'nvidia/nemotron-3.5-lightning:free',
      label: 'Nemotron 3.5 Lightning (Free)',
      description: 'NVIDIA · siêu nhanh, ngữ cảnh 1M',
    ),
    AIModel(
      slug: 'gemini/gemini-3.7-flash',
      label: 'Gemini 3.7 Flash (Key)',
      description: 'Google · dùng trực tiếp key của bạn, đọc ảnh',
      supportsVision: true,
    ),
  ];

  /// Model mặc định khi chưa chọn.
  static AIModel get defaultModel => definitions.first;

  /// Tìm model theo slug trong danh sách runtime (nếu có) hoặc danh sách tĩnh;
  /// trả về mặc định nếu không thấy ở cả hai.
  static AIModel fromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return defaultModel;
    final runtime = runtimeDefinitions;
    final fromRuntime =
        runtime?.where((m) => m.slug == slug).toList() ?? const <AIModel>[];
    if (fromRuntime.isNotEmpty) return fromRuntime.first;
    return definitions.firstWhere(
      (m) => m.slug == slug,
      orElse: () => defaultModel,
    );
  }

  /// Danh sách model runtime do FreeModelsCatalog nạp (cache/mạng).
  /// Null khi chưa nạp — UI nên dùng cái này nếu có, không thì dùng [definitions].
  static List<AIModel>? get runtimeDefinitions =>
      FreeModelsCatalog.runtimeModels.value;

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      slug: json['slug'] as String? ?? '',
      label: json['label'] as String? ?? json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      supportsVision: json['supportsVision'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'label': label,
        'description': description,
        'supportsVision': supportsVision,
      };
}

/// Nhận diện logo/icon hiển thị cho từng model.
IconData aiModelIcon(String slug) {
  if (slug.startsWith('openai')) return Icons.bolt_rounded;
  if (slug.startsWith('google') || slug.startsWith('gemini')) return Icons.auto_awesome_rounded;
  if (slug.startsWith('nvidia')) return Icons.memory_rounded;
  if (slug.startsWith('thinkingmachines')) return Icons.psychology_alt_rounded;
  if (slug.startsWith('dots-studio')) return Icons.grain_rounded;
  if (slug.startsWith('nex-agi')) return Icons.hub_rounded;
  if (slug.startsWith('poolside')) return Icons.code_rounded;
  if (slug.startsWith('cohere')) return Icons.terminal_rounded;
  if (slug.startsWith('minimax')) return Icons.psychology_rounded;
  if (slug.startsWith('z-ai')) return Icons.smart_toy_rounded;
  if (slug.startsWith('openrouter')) return Icons.route_rounded;
  return Icons.smart_toy_rounded;
}
