import 'package:flutter/material.dart';

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
  static const List<AIModel> definitions = [
    AIModel(
      slug: 'openrouter/free',
      label: 'Auto (Free)',
      description: 'Tự chọn model miễn phí tốt nhất',
    ),
    AIModel(
      slug: 'minimax/minimax-m3:free',
      label: 'MiniMax M3 (Free)',
      description: 'Đa năng, hỗ trợ đa ngôn ngữ',
    ),
    AIModel(
      slug: 'nvidia/nemotron-3-ultra-550b-a55b:free',
      label: 'Nemotron Ultra (Free)',
      description: '550B参数, lý luận mạnh',
    ),
    AIModel(
      slug: 'z-ai/glm-5.2:free',
      label: 'GLM 5.2 (Free)',
      description: 'Zhipu AI, đa năng',
    ),
    AIModel(
      slug: 'openai/gpt-4o-mini',
      label: 'GPT-4o mini',
      description: 'OpenAI · nhanh, hỗ trợ đọc ảnh',
      supportsVision: true,
    ),
    AIModel(
      slug: 'google/gemini-flash-1.5',
      label: 'Gemini Flash',
      description: 'Google · hỗ trợ đọc ảnh',
      supportsVision: true,
    ),
  ];

  /// Model mặc định khi chưa chọn.
  static AIModel get defaultModel => definitions.first;

  /// Tìm model theo slug; trả về mặc định nếu không thấy.
  static AIModel fromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return defaultModel;
    return definitions.firstWhere(
      (m) => m.slug == slug,
      orElse: () => defaultModel,
    );
  }
}

/// Nhận diện logo/icon hiển thị cho từng model.
IconData aiModelIcon(String slug) {
  if (slug.startsWith('openai')) return Icons.bolt;
  if (slug.startsWith('google')) return Icons.auto_awesome;
  if (slug.startsWith('minimax')) return Icons.psychology;
  if (slug.startsWith('nvidia')) return Icons.memory;
  if (slug.startsWith('z-ai')) return Icons.smart_toy_outlined;
  if (slug.startsWith('openrouter')) return Icons.auto_fix_high;
  return Icons.smart_toy_outlined;
}
