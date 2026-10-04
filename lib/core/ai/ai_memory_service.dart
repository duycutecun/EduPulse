import '../utils/storage_service.dart';

class AiMemoryService {
  static const String _key = 'ai_memory_summary';
  static const int _maxChars = 5000;

  static String? getSummary() => StorageService.getString(_key);

  static void setSummary(String summary) {
    if (summary.length > _maxChars) {
      summary = '${summary.substring(0, _maxChars)}…';
    }
    StorageService.setString(_key, summary);
  }

  static void clear() => StorageService.removeString(_key);

  static String buildMemoryPrompt() {
    final summary = getSummary();
    if (summary == null || summary.isEmpty) return '';
    return '--- LỊCH SỬ TRÒ CHUYỆN TRƯỚC ---\n$summary\n--- HẾT LỊCH SỬ ---';
  }

  static void appendToSummary(String userMessage, String aiResponse) {
    final existing = getSummary() ?? '';
    final entry = 'User: $userMessage\nAI: $aiResponse';
    final updated = existing.isEmpty ? entry : '$existing\n\n$entry';
    setSummary(updated);
  }

  static Map<String, dynamic> toJson() => {
        'summary': getSummary() ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      };

  static void fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as String?;
    if (summary != null && summary.isNotEmpty) {
      setSummary(summary);
    }
  }
}
