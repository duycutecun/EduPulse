import 'dart:convert';
import '../utils/storage_service.dart';

class AdaptiveQuizEngine {
  static const String _key = 'adaptive_quiz_performance_v1';

  static int getDifficultyForTopic(String topic) {
    final data = _loadData();
    final key = _hash(topic);
    return data[key] as int? ?? 3;
  }

  static void recordAnswer(String topic, bool correct) {
    final data = _loadData();
    final key = _hash(topic);
    final current = data[key] as int? ?? 3;

    if (correct) {
      data[key] = (current + 1).clamp(1, 5);
    } else {
      data[key] = (current - 1).clamp(1, 5);
    }
    _saveData(data);
  }

  static List<String> getWeakTopics() {
    final data = _loadData();
    final weak = <String>[];
    for (final entry in data.entries) {
      if (entry.value is int && (entry.value as int) <= 2) {
        weak.add(entry.key);
      }
    }
    return weak;
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

  static void _saveData(Map<String, dynamic> data) {
    StorageService.setString(_key, jsonEncode(data));
  }

  static String _hash(String input) {
    return input.hashCode.toString();
  }

  static void reset() => StorageService.removeString(_key);
}
