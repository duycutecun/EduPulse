import 'dart:math';
import '../../features/study/domain/models/study_models.dart';
import '../../features/study/domain/repositories/study_session_repository.dart';

class CorrelationResult {
  final String subjectA;
  final String subjectB;
  final double correlation;
  final String insight;

  CorrelationResult(
      this.subjectA, this.subjectB, this.correlation, this.insight);
}

class CrossSubjectAnalyzer {
  static List<CorrelationResult> analyze({DateTime? now}) {
    final t = now ?? DateTime.now();
    final sessions = StudySessionRepository.instance.getAll();
    if (sessions.length < 5) return [];

    final bySubject = <String, List<StudySession>>{};
    for (final s in sessions) {
      final key = s.subject.isEmpty ? 'khác' : s.subject;
      bySubject.putIfAbsent(key, () => []).add(s);
    }

    if (bySubject.length < 2) return [];

    final subjects = bySubject.keys.toList();
    final results = <CorrelationResult>[];

    for (var i = 0; i < subjects.length; i++) {
      for (var j = i + 1; j < subjects.length; j++) {
        final a = subjects[i];
        final b = subjects[j];
        final corr = _computeCorrelation(bySubject[a]!, bySubject[b]!, t);
        if (corr.abs() > 0.3) {
          final insight = corr > 0
              ? '$a và $b có xu hướng cùng tiến bộ'
              : '$a tiến bộ thường kém khi $b được ưu tiên';
          results.add(CorrelationResult(a, b, corr, insight));
        }
      }
    }

    return results;
  }

  static double _computeCorrelation(
    List<StudySession> a,
    List<StudySession> b,
    DateTime now,
  ) {
    final aByDay = _groupByDay(a, now);
    final bByDay = _groupByDay(b, now);

    final days = aByDay.keys.toSet().intersection(bByDay.keys.toSet());
    if (days.length < 3) return 0.0;

    final aValues = days.map((d) => aByDay[d]!).toList();
    final bValues = days.map((d) => bByDay[d]!).toList();

    final aMean = aValues.reduce((x, y) => x + y) / aValues.length;
    final bMean = bValues.reduce((x, y) => x + y) / bValues.length;

    var numerator = 0.0;
    var aVar = 0.0;
    var bVar = 0.0;

    for (var i = 0; i < days.length; i++) {
      final aDiff = aValues[i] - aMean;
      final bDiff = bValues[i] - bMean;
      numerator += aDiff * bDiff;
      aVar += aDiff * aDiff;
      bVar += bDiff * bDiff;
    }

    final denominator = sqrt(aVar * bVar);
    if (denominator == 0) return 0.0;
    return numerator / denominator;
  }

  static Map<int, double> _groupByDay(
      List<StudySession> sessions, DateTime now) {
    final map = <int, double>{};
    for (final s in sessions) {
      final day = now.difference(s.completedAt).inDays;
      map[day] = (map[day] ?? 0) + s.actualMinutes.toDouble();
    }
    return map;
  }

  static List<String> getPrerequisites(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('vật lý') || lower.contains('lý')) {
      return ['Toán'];
    }
    if (lower.contains('hóa')) {
      return ['Toán', 'Vật lý'];
    }
    if (lower.contains('sinh')) {
      return ['Hóa học'];
    }
    return [];
  }
}
