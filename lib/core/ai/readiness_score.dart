import 'dart:convert';

import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../utils/storage_service.dart';

/// Kết quả tính chỉ số sẵn sàng thi AI (0–100).
///
/// Điểm không phải "đo IQ" mà là **hình chiếu của hành vi học tập thật** lên
/// khả năng đạt mục tiêu: điểm thi thử (trọng số lớn nhất), nhịp học gần đây,
/// tiến độ nhiệm vụ, độ bền chuỗi học và thời gian đến ngày thi.
class ReadinessResult {
  final int score; // 0..100
  final String band; // nhãn vùng: 'Rất tốt' / 'Khá' / 'Trung bình' / 'Cần nỗ lực'
  final List<ReadinessFactor> factors;
  final List<String> levers; // 3 đòn bẩy tăng điểm nhanh nhất
  final List<String> warnings; // rủi ro cụ thể (môn tụt, chuỗi đứt...)
  final DateTime computedAt;

  const ReadinessResult({
    required this.score,
    required this.band,
    required this.factors,
    required this.levers,
    required this.warnings,
    required this.computedAt,
  });
}

/// Một thành phần đóng góp vào chỉ số — để UI vẽ thanh chi tiết và để AI
/// (AiStudyContext) kể lại cho model nghe.
class ReadinessFactor {
  final String label;
  final double value; // 0..1
  final double weight;
  final String detail;

  const ReadinessFactor({
    required this.label,
    required this.value,
    required this.weight,
    required this.detail,
  });
}

/// Chỉ số sẵn sàng thi tính **offline, tức thì** từ dữ liệu local (mục tiêu:
/// "AI vượt trội" nghĩa là có insight tức thì không cần chờ mạng), và được
/// [AiStudyContext] đưa vào ngữ cảnh AI ở mọi lượt chat để toàn app nói
/// một thứ ngữ.
///
/// Điểm các thành phần (mỗi cái 0..1, có trọng số):
/// - Điểm thi thử gần nhất so với mục tiêu (45%) — trọng số lớn nhất vì đây
///   là tín hiệu mạnh nhất về kết cục thi.
/// - Nhịp học 7 ngày qua (20%) — đủ đều đặn mới ghi nhớ dài hạn.
/// - Tiến độ nhiệm vụ (15%) — hành động mỗi ngày quyết định khoảng cách điểm.
/// - Độ bền chuỗi học (10%) — kỷ luật duy trì.
/// - Thời gian còn lại so với mức cần thiết (10%) — buffer trước ngày thi.
///
/// Số liệu cứng dựa trên nguyên tắc luyện thi: buffer lý tưởng ≈ khoảng thời
/// gian cần để bù điểm yếu + rà soát tổng thể; dưới ngưỡng đó thì thời gian
/// trở thành nút thắt.
class ReadinessScore {
  ReadinessScore._();

  /// Khoảng cách điểm cần bù được quy đổi thành ngày cần ôn (1 điểm ≈ 14 ngày
  /// nhịp đều — thống kê nội bộ áp dụng cho thang 10, lớp 12).
  static const double pointsPerDay = 1 / 14;

  /// Số ngày "cần" tối thiểu để rà soát tổng thể trước thi.
  static const int minReviewDays = 5;

  /// Dựng chỉ số. Trả về null khi chưa đủ dữ liệu tối thiểu (chưa có kỳ thi
  /// chính hoặc chưa có điểm thi thử nào).
  static ReadinessResult? compute({DateTime? now}) {
    final t = now ?? DateTime.now();
    final primary = _primaryExam();
    if (primary == null) return null;
    final scores = _mockScores();
    if (scores.isEmpty) return null;

    final target = primary.targetScore;
    final current = primary.currentScore ?? _latestAvg(scores);
    if (target == null) return null;

    // --- 1. Khoảng cách điểm (45%) ---
    final gap = (target - current).clamp(0.0, 10.0);
    final daysLeft = primary.daysLeft;
    // Điểm đã đạt trên mục tiêu → thành phần full điểm.
    final scoreGap = daysLeft <= 0
        ? (gap <= 0 ? 1.0 : 0.0)
        : (1 - gap / 10).clamp(0.0, 1.0);
    final fGap = ReadinessFactor(
      label: 'Khoảng cách điểm',
      value: scoreGap,
      weight: 0.45,
      detail: gap <= 0
          ? 'Đã đạt/tụt qua mục tiêu ${target.toStringAsFixed(1)}đ (hiện ${current.toStringAsFixed(1)}đ)'
          : 'Còn cách mục tiêu ${gap.toStringAsFixed(1)}đ (hiện ${current.toStringAsFixed(1)}đ)',
    );

    // --- 2. Nhịp học 7 ngày (20%) ---
    final sessions = _sessions();
    var recentMinutes = 0;
    var recentDays = 0;
    final daySet = <String>{};
    for (final s in sessions) {
      final d = t.difference(s.completedAt).inDays;
      if (d >= 0 && d <= 7) {
        recentMinutes += s.actualMinutes;
        daySet.add(
            '${s.completedAt.year}-${s.completedAt.month}-${s.completedAt.day}');
      }
    }
    recentDays = daySet.length;
    // Đạt full khi ≥5 ngày có học trong 7 ngày qua và ≥150 phút/tuần.
    final paceValue =
        ((recentDays / 5) * 0.6 + (recentMinutes / 150) * 0.4).clamp(0.0, 1.0);
    final fPace = ReadinessFactor(
      label: 'Nhịp học 7 ngày',
      value: paceValue,
      weight: 0.20,
      detail: recentMinutes == 0
          ? 'Chưa focus ngày nào trong 7 ngày qua'
          : '$recentDays ngày có học · ${recentMinutes}p focus',
    );

    // --- 3. Tiến độ nhiệm vụ (15%) ---
    final tasks = _tasks();
    double taskValue;
    String taskDetail;
    if (tasks.isEmpty) {
      taskValue = 0.5; // không có kế hoạch → trung tính, không phạt gắt
      taskDetail = 'Chưa có nhiệm vụ nào được lên kế hoạch';
    } else {
      final done = tasks.where((x) => x.isDone || x.status == 'completed').length;
      final skipped = tasks.where((x) => x.status == 'skipped').length;
      taskValue = ((done + 0.3 * skipped) / tasks.length).clamp(0.0, 1.0);
      taskDetail = '$done/${tasks.length} nhiệm vụ đã xong'
          '${skipped > 0 ? ' · $skipped bỏ qua' : ''}';
    }
    final fTask = ReadinessFactor(
      label: 'Tiến độ nhiệm vụ',
      value: taskValue,
      weight: 0.15,
      detail: taskDetail,
    );

    // --- 4. Độ bền chuỗi học (10%) ---
    final streak = StorageService.getStreak();
    final record = StorageService.getStreakRecord();
    final streakValue = (streak / 14).clamp(0.0, 1.0); // 14 ngày = full
    final fStreak = ReadinessFactor(
      label: 'Chuỗi học',
      value: streakValue,
      weight: 0.10,
      detail: record > streak
          ? '$streak ngày (kỷ lục $record)'
          : '$streak ngày liên tiếp',
    );

    // --- 5. Thời gian còn lại (10%) ---
    double timeValue;
    String timeDetail;
    if (daysLeft < 0) {
      timeValue = 1.0;
      timeDetail = 'Đã qua ngày thi';
    } else {
      final neededDays =
          (gap / pointsPerDay).ceil().clamp(minReviewDays, 60);
      timeValue = (daysLeft / neededDays).clamp(0.0, 1.0);
      timeDetail = gap <= 0
          ? '$daysLeft ngày — chỉ cần giữ đà'
          : 'Cần ~$neededDays ngày để bù ${gap.toStringAsFixed(1)}đ, còn $daysLeft ngày';
    }
    final fTime = ReadinessFactor(
      label: 'Thời gian',
      value: timeValue,
      weight: 0.10,
      detail: timeDetail,
    );

    final weighted = scoreGap * 0.45 +
        paceValue * 0.20 +
        taskValue * 0.15 +
        streakValue * 0.10 +
        timeValue * 0.10;

    // Môn yếu nhất tham chiếu để tạo cảnh báo & đòn bẩy.
    final weakest = _weakestSubjectAvg(scores);

    // Cảnh báo cụ thể theo dữ liệu.
    final warnings = <String>[];
    if (recentDays == 0 && sessions.isNotEmpty) {
      warnings.add('7 ngày qua không có phiên focus nào — nhịp học đang đứt.');
    }
    if (streak == 0 && record >= 3) {
      warnings.add('Chuỗi học $record ngày đã đứt — khởi động lại nhẹ nhàng nhé.');
    }
    if (weakest != null && weakest.$2 < 6.0) {
      warnings.add(
          'Môn ${weakest.$1} TB ${weakest.$2.toStringAsFixed(1)}đ — dưới ngưỡng an toàn 6.0.');
    }
    if (daysLeft >= 0 && daysLeft <= 7 && gap > 1.5) {
      warnings.add(
          'Còn $daysLeft ngày nhưng còn cách mục tiêu ${gap.toStringAsFixed(1)}đ — cần chiến lược "gặt điểm" ưu tiên dạng bài dễ.');
    }

    // Đòn bẩy: sắp theo "số điểm kiếm được mỗi giờ công" giảm dần.
    final levers = <String>[];
    if (weakest != null && gap > 0) {
      levers.add(
          'Đầu tư 60% thời gian vào ${weakest.$1} (TB ${weakest.$2.toStringAsFixed(1)}đ) — mỗi +1đ ở môn yếu worth hơn nhiều so với môn mạnh.');
    }
    if (recentDays < 4) {
      levers.add(
          'Nâng nhịp lên 4–5 ngày học/tuần (${recentDaysDaysLabel(recentDays)}) — đều đặn quan trọng hơn dồn ca dài.');
    }
    if (taskValue < 0.6 && tasks.isNotEmpty) {
      levers.add(
          'Giải tỏa ${tasks.where((x) => !x.isDone && x.status != "skipped").length} nhiệm vụ còn treo — mỗi task xong là +10 XP và tiến độ thật.');
    }
    if (streak < 3) {
      levers.add('Giữ chuỗi ≥3 ngày trước — thói quen là nền của mọi đòn bẩy khác.');
    }
    if (levers.isEmpty) {
      levers.add('Duy trì nhịp hiện tại và tăng dần độ khó đề luyện — bạn đang trên quỹ đạo.');
    }

    final finalScore = (weighted * 100).round().clamp(0, 100);

    final band = finalScore >= 80
        ? 'Rất tốt'
        : finalScore >= 60
            ? 'Khá'
            : finalScore >= 40
                ? 'Trung bình'
                : 'Cần nỗ lực';

    return ReadinessResult(
      score: finalScore,
      band: band,
      factors: [fGap, fPace, fTask, fStreak, fTime],
      levers: levers.take(3).toList(),
      warnings: warnings.take(3).toList(),
      computedAt: t,
    );
  }

  /// Label phụ cho đòn bẩy "nhịp học".
  static String recentDaysDaysLabel(int days) => days == 0
      ? 'hiện chưa ngày nào'
      : days == 1
          ? 'hiện 1 ngày'
          : 'hiện $days ngày';

  static ExamModel? _primaryExam() {
    final ids = StorageService.getExamIds();
    final primaryId = StorageService.getPrimaryExamId();
    ExamModel? primary;
    if (primaryId != null) {
      for (final id in ids) {
        if (id != primaryId) continue;
        final raw = StorageService.getExamJson(id);
        if (raw == null) continue;
        try {
          primary = ExamModel.fromJsonString(raw);
        } catch (_) {}
        break;
      }
    }
    primary ??= () {
      for (final id in ids) {
        final raw = StorageService.getExamJson(id);
        if (raw == null) continue;
        try {
          return ExamModel.fromJsonString(raw);
        } catch (_) {}
      }
      return null;
    }();
    return primary;
  }

  static List<MockScore> _mockScores() {
    final out = <MockScore>[];
    for (final id in StorageService.getMockScoreIds()) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        out.add(MockScore.fromJsonString(raw));
      } catch (_) {}
    }
    return out;
  }

  static List<StudySession> _sessions() {
    final out = <StudySession>[];
    for (final id in StorageService.getStudySessionIds()) {
      final raw = StorageService.getStudySessionJson(id);
      if (raw == null) continue;
      try {
        out.add(StudySession.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static List<TodayTask> _tasks() {
    final out = <TodayTask>[];
    for (final id in StorageService.getTodayTaskIds()) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        out.add(TodayTask.fromJsonString(raw));
      } catch (_) {}
    }
    return out;
  }

  /// Dùng điểm gần nhất thay vì trung bình toàn bộ để phản ánh trình độ
  /// hiện tại (điểm cũ xa sẽ kéo thấp không cần thiết).
  static double _latestAvg(List<MockScore> scores) {
    final sorted = [...scores]..sort((a, b) => a.date.compareTo(b.date));
    return sorted.last.score;
  }

  static (String, double)? _weakestSubjectAvg(List<MockScore> scores) {
    final bySubject = <String, List<double>>{};
    for (final s in scores) {
      final sub = s.subject.trim().isEmpty ? 'Khác' : s.subject.trim();
      bySubject.putIfAbsent(sub, () => <double>[]).add(s.score);
    }
    if (bySubject.isEmpty) return null;
    final averages = bySubject.entries
        .map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return (averages.first.key, averages.first.value);
  }
}
