import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../features/study/domain/repositories/study_session_repository.dart';
import '../utils/storage_service.dart';

class PredictionResult {
  final double predictedScore;
  final double targetScore;
  final double gap;
  final String assessment;
  final List<String> recommendations;

  PredictionResult({
    required this.predictedScore,
    required this.targetScore,
    required this.gap,
    required this.assessment,
    required this.recommendations,
  });
}

class PredictiveEngine {
  static PredictionResult? predict({DateTime? now}) {
    final t = now ?? DateTime.now();
    final exams = _readExams();
    if (exams.isEmpty) return null;

    final primaryId = StorageService.getPrimaryExamId();
    ExamModel? main;
    if (primaryId != null) {
      for (final e in exams) {
        if (e.id == primaryId) {
          main = e;
          break;
        }
      }
    }
    main ??= _nearest(exams, t);
    if (main == null) return null;

    final target = main.targetScore ?? 8.0;
    final daysLeft = main.dateTime.difference(t).inDays;
    if (daysLeft < 0) return null;

    final sessions = StudySessionRepository.instance.getAll();
    final recentSessions = sessions
        .where((s) => t.difference(s.completedAt).inDays <= 14)
        .toList();

    final recentMinutes =
        recentSessions.fold<int>(0, (a, s) => a + s.actualMinutes);
    final dailyAvg = recentMinutes / 14.0;

    final scores = _readMockScores();
    final bySubject = <String, List<double>>{};
    for (final s in scores) {
      bySubject.putIfAbsent(s.subject, () => []).add(s.score);
    }
    final subjectAverages = bySubject.entries
        .map((e) =>
            MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final currentAvg = subjectAverages.isEmpty
        ? 5.0
        : subjectAverages.map((e) => e.value).reduce((a, b) => a + b) /
            subjectAverages.length;

    final paceFactor = (dailyAvg / 60.0).clamp(0.5, 1.5);
    final daysFactor = (daysLeft / 30.0).clamp(0.3, 1.0);
    final predicted =
        (currentAvg * 0.6 + (currentAvg * paceFactor * daysFactor) * 0.4)
            .clamp(0.0, 10.0);

    final gap = target - predicted;
    final assessment = gap <= 0
        ? 'Đang đúng hướng'
        : gap <= 1.0
            ? 'Cần thêm chút nỗ lực'
            : 'Cần tăng cường học tập';

    final recommendations = <String>[];
    if (gap > 0) {
      final extraMinutes = (gap * 30).round();
      recommendations.add('Tăng $extraMinutes phút/ngày để đạt mục tiêu');
    }
    if (subjectAverages.isNotEmpty &&
        subjectAverages.first.value < target - 1.0) {
      recommendations.add(
          'Ưu tiên ôn ${subjectAverages.first.key} (TB ${subjectAverages.first.value.toStringAsFixed(1)})');
    }
    if (dailyAvg < 45) {
      recommendations.add('Duy trì tối thiểu 45 phút/ngày');
    }
    if (recommendations.isEmpty) {
      recommendations.add('Duy trì nhịp học hiện tại');
    }

    return PredictionResult(
      predictedScore: double.parse(predicted.toStringAsFixed(1)),
      targetScore: target,
      gap: double.parse(gap.toStringAsFixed(1)),
      assessment: assessment,
      recommendations: recommendations,
    );
  }

  static List<ExamModel> _readExams() {
    final ids = StorageService.getExamIds();
    final out = <ExamModel>[];
    for (final id in ids) {
      final raw = StorageService.getExamJson(id);
      if (raw == null) continue;
      try {
        out.add(ExamModel.fromJsonString(raw));
      } catch (_) {}
    }
    return out;
  }

  static ExamModel? _nearest(List<ExamModel> exams, DateTime now) {
    ExamModel? upcoming;
    var upcomingGap = 1 << 62;
    ExamModel? any;
    var anyGap = 1 << 62;
    for (final e in exams) {
      final gap = e.dateTime.difference(now).abs().inMinutes;
      if (any == null || gap < anyGap) {
        any = e;
        anyGap = gap;
      }
      if (e.dateTime.isAfter(now) && gap < upcomingGap) {
        upcoming = e;
        upcomingGap = gap;
      }
    }
    return upcoming ?? any;
  }

  static List<MockScore> _readMockScores() {
    final ids = StorageService.getMockScoreIds();
    final out = <MockScore>[];
    for (final id in ids) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        out.add(MockScore.fromJsonString(raw));
      } catch (_) {}
    }
    return out;
  }
}
