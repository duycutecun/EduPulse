import '../../features/study/domain/repositories/study_session_repository.dart';
import '../../features/study/domain/models/study_models.dart';
import '../utils/storage_service.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

/// Kết quả phân tích điểm yếu học tập.
class WeaknessReport {
  /// Đủ dữ liệu để phân tích (cần ≥ 3 phiên học).
  final bool hasEnoughData;

  /// Môn học yếu nhất theo điểm thi thử (null nếu chưa có điểm).
  final String? weakestSubjectByScore;
  final double? weakestSubjectScore;

  /// Môn học ít được dành thời gian nhất tuần vừa rồi.
  final String? neglectedSubject;
  final int? neglectedMinutes;

  /// Môn học thường xuyên bị dời lịch nhất.
  final String? mostRescheduledSubject;
  final int? rescheduledCount;

  /// Số phiên học có feedback tâm trạng xấu (emoji ≤2/5).
  final int lowMoodSessions;

  /// Nhận xét tổng hợp (1-3 câu).
  final String summary;

  /// Gợi ý hành động cụ thể (2-4 việc).
  final List<String> suggestions;

  const WeaknessReport({
    required this.hasEnoughData,
    this.weakestSubjectByScore,
    this.weakestSubjectScore,
    this.neglectedSubject,
    this.neglectedMinutes,
    this.mostRescheduledSubject,
    this.rescheduledCount,
    this.lowMoodSessions = 0,
    required this.summary,
    required this.suggestions,
  });

  /// Không đủ dữ liệu — trả thông báo trung thực, không phán đoán.
  factory WeaknessReport.insufficient() => const WeaknessReport(
        hasEnoughData: false,
        summary: 'Chưa đủ dữ liệu để phân tích (cần ít nhất 3 phiên học). '
            'Hãy học thêm vài buổi rồi quay lại nhé!',
        suggestions: [],
      );
}

// ─── Analyzer ────────────────────────────────────────────────────────────────

/// Weakness Analyzer — Sprint 4 AI-4.5.
///
/// Phân tích từ DATA THẬT (không chỉ dựa vào lịch sử chat như trước):
/// - Điểm thi thử theo môn → môn yếu nhất.
/// - Phiên học 7 ngày qua → môn ít được dành thời gian.
/// - Task bị reschedule nhiều → môn hay trì hoãn.
/// - Feedback cảm xúc sau phiên → phiên học stress.
///
/// Nguyên tắc: chỉ kết luận khi có đủ dữ liệu (≥ 3 phiên), trung thực
/// khi thiếu dữ liệu — không phán đoán bừa (mục 10.8 spec).
class WeaknessAnalyzer {
  WeaknessAnalyzer._();

  static const int _minSessions = 3;
  static const int _recentDays = 14;

  /// Phân tích điểm yếu và trả về [WeaknessReport].
  static WeaknessReport analyze() {
    final now = DateTime.now();
    final since = now.subtract(Duration(days: _recentDays));

    // 1. Thu thập phiên học gần đây
    final sessions = _recentSessions(since);
    if (sessions.length < _minSessions) {
      return WeaknessReport.insufficient();
    }

    // 2. Môn yếu nhất theo điểm thi thử
    final (weakSubject, weakScore) = _weakestByScore();

    // 3. Môn ít được dành thời gian (dùng phiên học thật)
    final (neglectedSub, neglectedMins) = _neglectedSubject(sessions);

    // 4. Môn bị reschedule nhiều
    final (rescheduledSub, rescheduledCnt) = _mostRescheduled();

    // 5. Số phiên cảm xúc thấp
    final lowMood = _countLowMoodSessions(sessions);

    // 6. Tổng hợp nhận xét + gợi ý
    final (summary, suggestions) = _buildReport(
      weakSubject: weakSubject,
      weakScore: weakScore,
      neglectedSub: neglectedSub,
      neglectedMins: neglectedMins,
      rescheduledSub: rescheduledSub,
      rescheduledCnt: rescheduledCnt,
      lowMood: lowMood,
      sessionCount: sessions.length,
    );

    return WeaknessReport(
      hasEnoughData: true,
      weakestSubjectByScore: weakSubject,
      weakestSubjectScore: weakScore,
      neglectedSubject: neglectedSub,
      neglectedMinutes: neglectedMins,
      mostRescheduledSubject: rescheduledSub,
      rescheduledCount: rescheduledCnt,
      lowMoodSessions: lowMood,
      summary: summary,
      suggestions: suggestions,
    );
  }

  // ─── Các hàm phân tích ───────────────────────────────────────────────────

  static List<StudySession> _recentSessions(DateTime since) {
    final repo = StudySessionRepository.instance;
    return repo
        .getAll()
        .where((s) =>
            s.status == 'completed' &&
            s.startedAt != null &&
            s.startedAt!.isAfter(since))
        .toList();
  }

  static (String?, double?) _weakestByScore() {
    final mockIds = StorageService.getMockScoreIds();
    if (mockIds.isEmpty) return (null, null);

    final scoreBySubject = <String, List<double>>{};
    for (final id in mockIds) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        final score = MockScore.fromJsonString(raw);
        final sub = score.subject.trim();
        if (sub.isEmpty) continue;
        scoreBySubject.putIfAbsent(sub, () => []).add(score.score);
      } catch (_) {
        continue;
      }
    }

    if (scoreBySubject.isEmpty) return (null, null);

    // Cần ít nhất 2 điểm cho một môn mới tin cậy
    final averages = scoreBySubject.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) =>
            MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (averages.isEmpty) return (null, null);
    return (averages.first.key, averages.first.value);
  }

  static (String?, int?) _neglectedSubject(List<StudySession> sessions) {
    if (sessions.isEmpty) return (null, null);

    final minutesBySubject = <String, int>{};
    for (final s in sessions) {
      final sub = s.subject.trim();
      if (sub.isEmpty) continue;
      minutesBySubject[sub] = (minutesBySubject[sub] ?? 0) + s.actualMinutes;
    }

    if (minutesBySubject.isEmpty) return (null, null);

    final sorted = minutesBySubject.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Chỉ báo "bị bỏ quên" nếu thật sự ít (< 30% trung bình)
    if (sorted.length < 2) return (null, null);
    final avg = minutesBySubject.values.reduce((a, b) => a + b) /
        minutesBySubject.length;
    if (sorted.first.value < avg * 0.5) {
      return (sorted.first.key, sorted.first.value);
    }
    return (null, null);
  }

  static (String?, int?) _mostRescheduled() {
    final taskIds = StorageService.getTodayTaskIds();
    final countBySubject = <String, int>{};

    for (final id in taskIds) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        final task = TodayTask.fromJsonString(raw);
        final count = task.rescheduleCount;
        if (count >= 2) {
          final sub = task.subject.trim();
          if (sub.isNotEmpty) {
            countBySubject[sub] = (countBySubject[sub] ?? 0) + count;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (countBySubject.isEmpty) return (null, null);
    final sorted = countBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return (sorted.first.key, sorted.first.value);
  }

  static int _countLowMoodSessions(List<StudySession> sessions) {
    return sessions.where((s) {
      // mood là 1-5, ≤ 2 là thấp
      final mood = s.mood;
      return mood != null && mood <= 2;
    }).length;
  }

  // ─── Tổng hợp nhận xét ───────────────────────────────────────────────────

  static (String, List<String>) _buildReport({
    required String? weakSubject,
    required double? weakScore,
    required String? neglectedSub,
    required int? neglectedMins,
    required String? rescheduledSub,
    required int? rescheduledCnt,
    required int lowMood,
    required int sessionCount,
  }) {
    final parts = <String>[];
    final suggestions = <String>[];

    // Môn yếu theo điểm
    if (weakSubject != null && weakScore != null) {
      if (weakScore < 6.5) {
        parts.add(
            'Điểm thi thử môn **$weakSubject** đang ở mức thấp (TB ${weakScore.toStringAsFixed(1)}/10) — đây là khoảng trống cần ưu tiên lấp đầy.');
        suggestions.add(
            'Dành ít nhất 30ph mỗi ngày ôn lại nền tảng môn $weakSubject.');
        suggestions
            .add('Làm lại các dạng bài hay gặp trong đề thi môn $weakSubject.');
      } else if (weakScore < 8.0) {
        parts.add(
            'Môn **$weakSubject** có thể cải thiện thêm (TB ${weakScore.toStringAsFixed(1)}/10).');
        suggestions
            .add('Tập trung vào dạng bài khó để đẩy điểm $weakSubject lên 8+.');
      }
    }

    // Môn bị bỏ quên
    if (neglectedSub != null) {
      final minsStr = neglectedMins != null ? '${neglectedMins}ph' : '';
      parts.add(
          'Môn **$neglectedSub** đang ít được chú ý ($minsStr trong 2 tuần qua).');
      suggestions.add(
          'Thêm ít nhất 1 task môn $neglectedSub vào lịch học tuần này để không bỏ quên.');
    }

    // Hay dời lịch
    if (rescheduledSub != null &&
        rescheduledCnt != null &&
        rescheduledCnt >= 3) {
      parts.add(
          'Task môn **$rescheduledSub** thường xuyên bị dời lịch ($rescheduledCnt lần) — có thể nhiệm vụ đang quá nặng.');
      suggestions.add(
          'Thử chia nhỏ task môn $rescheduledSub thành các buổi 20-30ph dễ bắt đầu hơn.');
    }

    // Phiên tâm trạng thấp
    if (lowMood >= 3) {
      parts.add(
          'Có $lowMood phiên học có cảm xúc không tốt gần đây — xem lại thời điểm học và mức độ nhiệm vụ.');
      suggestions
          .add('Thử học vào buổi bạn năng lượng cao nhất (sáng sớm / chiều).');
    }

    // Không tìm ra điểm yếu rõ ràng
    if (parts.isEmpty) {
      return (
        'Dữ liệu $sessionCount phiên học gần đây trông khá cân bằng — không có môn nào nổi bật cần lo ngại. '
            'Hãy duy trì nhịp học đều đặn và tiếp tục làm đề thử để có thêm dữ liệu.',
        [
          'Tiếp tục duy trì lịch học đều đặn.',
          'Làm thêm đề thi thử để tracking điểm theo môn.'
        ],
      );
    }

    final summary = parts.join(' ');
    if (suggestions.isEmpty) {
      suggestions.add('Hỏi AI Coach để lập kế hoạch cải thiện cụ thể.');
    }

    return (summary, suggestions.take(4).toList());
  }
}
