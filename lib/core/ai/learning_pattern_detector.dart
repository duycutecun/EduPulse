import '../../features/study/domain/models/study_models.dart';

/// Một tín hiệu học tập được rút ra hoàn toàn trên thiết bị.
///
/// Chỉ sử dụng phiên focus và các điểm tự đánh giá mà học sinh đã chủ động
/// lưu. Đây là gợi ý, không phải kết luận về sức khỏe hay năng lực.
class LearningPattern {
  const LearningPattern({required this.summary, required this.suggestion});

  final String summary;
  final String suggestion;
}

/// Phát hiện các thói quen có thể hành động được mà không cần gọi mô hình AI.
/// Kết quả được đưa vào [AiStudyContext] để AI Coach nhất quán với Home và
/// Pomodoro, kể cả khi thiết bị đang offline.
class LearningPatternDetector {
  LearningPatternDetector._();

  static List<LearningPattern> detect(
    Iterable<StudySession> sessions, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final recent = sessions
        .where((s) => reference.difference(s.completedAt).inDays >= 0)
        .where((s) => reference.difference(s.completedAt).inDays <= 28)
        .toList();
    if (recent.length < 3) return const [];

    final patterns = <LearningPattern>[];
    final byHour = <int, List<StudySession>>{};
    for (final session in recent) {
      byHour.putIfAbsent(session.completedAt.hour, () => []).add(session);
    }
    final viableHours =
        byHour.entries.where((entry) => entry.value.length >= 2);
    if (viableHours.isNotEmpty) {
      final best = viableHours
          .reduce((a, b) => _quality(a.value) >= _quality(b.value) ? a : b);
      final end = (best.key + 2) % 24;
      patterns.add(LearningPattern(
        summary:
            'Bạn thường học hiệu quả hơn vào ${_hour(best.key)}–${_hour(end)}.',
        suggestion: 'Ưu tiên xếp phiên khó vào khung giờ này.',
      ));
    }

    final rated = recent.where((s) => s.focus != null).toList();
    if (rated.length >= 3) {
      final averageFocus =
          rated.map((s) => s.focus!).reduce((a, b) => a + b) / rated.length;
      final averagePlan =
          rated.map((s) => s.plannedMinutes).reduce((a, b) => a + b) /
              rated.length;
      if (averageFocus <= 2.5 && averagePlan >= 40) {
        patterns.add(const LearningPattern(
          summary: 'Các phiên dài gần đây có mức tập trung tự đánh giá thấp.',
          suggestion:
              'Thử Pomodoro 25 phút, nghỉ ngắn rồi mới bắt đầu lượt tiếp theo.',
        ));
      }
    }
    return patterns;
  }

  static double _quality(List<StudySession> sessions) {
    final scored = sessions
        .where((s) => s.focus != null || s.effectiveness != null)
        .toList();
    if (scored.isEmpty) return sessions.length.toDouble();
    final ratings =
        scored.map((s) => ((s.focus ?? 3) + (s.effectiveness ?? 3)) / 2);
    return ratings.reduce((a, b) => a + b) / scored.length;
  }

  static String _hour(int hour) => '${hour.toString().padLeft(2, '0')}:00';
}
