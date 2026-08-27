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
      slug: 'meta-llama/llama-3.3-70b-instruct:free',
      label: 'Llama 3.3 70B (Free)',
      description: 'Đa năng, cân bằng tốc độ & chất lượng',
    ),
    AIModel(
      slug: 'deepseek/deepseek-chat-v3-0324:free',
      label: 'DeepSeek V3 (Free)',
      description: 'Lý luận mạnh, chi phí thấp',
    ),
    AIModel(
      slug: 'qwen/qwen3-235b-a22b:free',
      label: 'Qwen3 235B (Free)',
      description: 'Đa ngôn ngữ, mạnh lập luận',
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
    AIModel(
      slug: 'moonshotai/kimi-k2-instruct:free',
      label: 'Kimi K2 (Free)',
      description: 'Lý luận sâu, chú ý chi tiết',
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
  if (slug.startsWith('meta-llama')) return Icons.flutter_dash;
  if (slug.startsWith('deepseek')) return Icons.waves;
  if (slug.startsWith('qwen')) return Icons.workspaces_outline;
  return Icons.smart_toy_outlined;
}
