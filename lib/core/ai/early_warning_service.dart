import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../features/study/domain/repositories/study_session_repository.dart';
import '../utils/storage_service.dart';

class Warning {
  final String type;
  final String message;
  final String action;

  Warning(this.type, this.message, this.action);
}

class EarlyWarningService {
  static List<Warning> check({DateTime? now}) {
    final t = now ?? DateTime.now();
    final warnings = <Warning>[];

    warnings.addAll(_checkNeglectedSubjects(t));
    warnings.addAll(_checkScoreTrend(t));
    warnings.addAll(_checkExamCountdown(t));
    warnings.addAll(_checkBurnout(t));
    warnings.addAll(_checkStreakRisk(t));

    return warnings;
  }

  static List<Warning> _checkNeglectedSubjects(DateTime now) {
    final warnings = <Warning>[];
    final sessions = StudySessionRepository.instance.getAll();
    if (sessions.isEmpty) return warnings;

    final bySubject = <String, DateTime>{};
    for (final s in sessions) {
      final key = s.subject.isEmpty ? 'khác' : s.subject;
      final existing = bySubject[key];
      if (existing == null || s.completedAt.isAfter(existing)) {
        bySubject[key] = s.completedAt;
      }
    }

    for (final entry in bySubject.entries) {
      final daysSince = now.difference(entry.value).inDays;
      if (daysSince >= 5) {
        warnings.add(Warning(
          'neglected',
          '$daysSince ngày chưa học ${entry.key}',
          'Tạo task ôn ${entry.key} ngay hôm nay',
        ));
      }
    }
    return warnings;
  }

  static List<Warning> _checkScoreTrend(DateTime now) {
    final warnings = <Warning>[];
    final scores = _readMockScores();
    if (scores.length < 2) return warnings;

    scores.sort((a, b) => a.date.compareTo(b.date));
    final latest = scores[scores.length - 1];
    final prev = scores[scores.length - 2];

    if (latest.subject == prev.subject) {
      final delta = latest.score - prev.score;
      if (delta <= -1.0) {
        warnings.add(Warning(
          'score_drop',
          '${latest.subject}: ${prev.score.toStringAsFixed(1)} → ${latest.score.toStringAsFixed(1)} (giảm ${(-delta).toStringAsFixed(1)})',
          'Xem lại các câu sai bài thi gần nhất',
        ));
      }
    }
    return warnings;
  }

  static List<Warning> _checkExamCountdown(DateTime now) {
    final warnings = <Warning>[];
    final exams = _readExams();
    if (exams.isEmpty) return warnings;

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
    main ??= exams.first;
    final daysLeft = main.dateTime.difference(now).inDays;

    if (daysLeft >= 0 && daysLeft <= 7) {
      warnings.add(Warning(
        'exam_close',
        'Còn $daysLeft ngày thi ${main.name}',
        'Tập trung ôn các chương trọng số cao',
      ));
    } else if (daysLeft > 7 && daysLeft <= 14) {
      warnings.add(Warning(
        'exam_approaching',
        'Còn $daysLeft ngày thi ${main.name}',
        'Bắt đầu tổng ôn toàn diện',
      ));
    }
    return warnings;
  }

  static List<Warning> _checkBurnout(DateTime now) {
    final warnings = <Warning>[];
    final sessions = StudySessionRepository.instance.getAll();
    if (sessions.length < 3) return warnings;

    final recent = sessions
        .where((s) => now.difference(s.completedAt).inDays <= 7)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    if (recent.length >= 3) {
      final lowFocus = recent.take(3).where((s) => (s.focus ?? 3) <= 2).length;
      if (lowFocus >= 2) {
        warnings.add(Warning(
          'burnout_risk',
          '3 phiên gần nhất đều tập trung thấp',
          'Nghỉ ngơi 1 ngày rồi quay lại',
        ));
      }
    }
    return warnings;
  }

  static List<Warning> _checkStreakRisk(DateTime now) {
    final warnings = <Warning>[];
    final streak = StorageService.getStreak();
    if (streak <= 0) return warnings;

    final lastStudy = StorageService.getString('last_study_date');
    if (lastStudy == null) return warnings;

    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));

    if (lastStudy == yesterday && now.hour >= 16) {
      warnings.add(Warning(
        'streak_risk',
        'Chuỗi $streak ngày sắp đứt nếu hôm nay chưa học',
        'Học 15 phút bất kỳ môn nào để giữ chuỗi',
      ));
    }
    return warnings;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
