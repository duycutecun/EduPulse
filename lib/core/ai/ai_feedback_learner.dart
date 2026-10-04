import 'dart:convert';
import '../utils/storage_service.dart';

class FeedbackPattern {
  final double likeRate;
  final int totalFeedback;
  final List<String> commonIssues;

  FeedbackPattern({
    required this.likeRate,
    required this.totalFeedback,
    required this.commonIssues,
  });
}

class AiFeedbackLearner {
  static const String _key = 'ai_feedback_patterns_v1';

  static FeedbackPattern? analyze() {
    final raw = StorageService.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final total = (data['total'] as num?)?.toInt() ?? 0;
      final likes = (data['likes'] as num?)?.toInt() ?? 0;
      final issues = (data['issues'] as List?)?.cast<String>() ?? [];

      return FeedbackPattern(
        likeRate: total > 0 ? likes / total : 0.5,
        totalFeedback: total,
        commonIssues: issues,
      );
    } catch (_) {
      return null;
    }
  }

  static void recordFeedback(String messageId, bool isLike, {String? reason}) {
    final data = _loadData();
    data['total'] = (data['total'] as int? ?? 0) + 1;
    if (isLike) {
      data['likes'] = (data['likes'] as int? ?? 0) + 1;
    }
    if (reason != null && reason.isNotEmpty) {
      final issues = (data['issues'] as List?)?.cast<String>() ?? [];
      issues.add(reason);
      if (issues.length > 10) issues.removeAt(0);
      data['issues'] = issues;
    }
    StorageService.setString(_key, jsonEncode(data));
  }

  static Map<String, dynamic> _loadData() {
    final raw = StorageService.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static int? getSuggestedMaxTokens() {
    final pattern = analyze();
    if (pattern == null) return null;
    if (pattern.likeRate < 0.3 && pattern.totalFeedback >= 5) {
      return 1024;
    }
    return null;
  }

  static void clear() => StorageService.removeString(_key);
}
