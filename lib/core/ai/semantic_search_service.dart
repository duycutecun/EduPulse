import 'dart:convert';
import '../utils/storage_service.dart';

class SearchResult {
  final String type;
  final String title;
  final String snippet;
  final double score;

  SearchResult(this.type, this.title, this.snippet, this.score);
}

class SemanticSearchService {
  static List<SearchResult> search(String query) {
    if (query.trim().isEmpty) return [];

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    results.addAll(_searchTasks(lowerQuery));
    results.addAll(_searchNotes(lowerQuery));
    results.addAll(_searchSessions(lowerQuery));

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(10).toList();
  }

  static List<SearchResult> _searchTasks(String query) {
    final results = <SearchResult>[];
    final ids = StorageService.getTodayTaskIds();

    for (final id in ids) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;

      try {
        final task = _parseTask(raw);
        final score = _computeScore(query, [
          task['title'] ?? '',
          task['subject'] ?? '',
          task['topic'] ?? '',
          task['note'] ?? '',
        ]);

        if (score > 0.1) {
          results.add(SearchResult(
            'task',
            task['title'] ?? '',
            '${task['subject'] ?? ''} · ${task['status'] ?? ''}',
            score,
          ));
        }
      } catch (_) {}
    }
    return results;
  }

  static List<SearchResult> _searchNotes(String query) {
    final results = <SearchResult>[];
    final ids = StorageService.getStudyNoteIds();

    for (final id in ids) {
      final raw = StorageService.getStudyNoteJson(id);
      if (raw == null) continue;

      try {
        final note = _parseJson(raw);
        final score = _computeScore(query, [
          note['title'] ?? '',
          note['body'] ?? '',
          note['subject'] ?? '',
          (note['tags'] as List?)?.join(' ') ?? '',
        ]);

        if (score > 0.1) {
          results.add(SearchResult(
            'note',
            note['title'] ?? '',
            (note['body'] ?? '').toString().substring(0, 50),
            score,
          ));
        }
      } catch (_) {}
    }
    return results;
  }

  static List<SearchResult> _searchSessions(String query) {
    final results = <SearchResult>[];
    final ids = StorageService.getStudySessionIds();

    for (final id in ids) {
      final raw = StorageService.getStudySessionJson(id);
      if (raw == null) continue;

      try {
        final session = _parseJson(raw);
        final score = _computeScore(query, [
          session['subject'] ?? '',
          session['reflectionNote'] ?? '',
        ]);

        if (score > 0.1) {
          results.add(SearchResult(
            'session',
            'Phiên học ${session['subject'] ?? ''}',
            '${session['actualMinutes'] ?? 0} phút',
            score,
          ));
        }
      } catch (_) {}
    }
    return results;
  }

  static double _computeScore(String query, List<String> fields) {
    final queryTerms = query.split(RegExp(r'\s+'));
    var score = 0.0;

    for (final field in fields) {
      final lowerField = field.toLowerCase();
      for (final term in queryTerms) {
        if (term.length < 2) continue;
        if (lowerField.contains(term)) {
          score += 1.0 / queryTerms.length;
        }
      }
    }

    return score.clamp(0.0, 1.0);
  }

  static Map<String, dynamic> _parseTask(String raw) {
    return _parseJson(raw);
  }

  static Map<String, dynamic> _parseJson(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
