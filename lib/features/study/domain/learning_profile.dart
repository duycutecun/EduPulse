import 'models/study_models.dart';

/// Learning Profile — inferred preferences (đặc tả mục 17 & 37).
///
/// AI có thể học: best study time, preferred session length, subject
/// difficulty, focus/avoidance patterns, learning efficiency. Nhưng:
/// - **Chỉ cập nhật khi có đủ dữ liệu** (mục 37): trả `null` thay vì đoán.
/// - **User có thể sửa inference** (mục 17): profile cho phép override
///   thủ công — giá trị user tự đặt luôn thắng giá trị suy luận.
/// - **Hypothesis ≠ fact** (mục 36): kết luận môn "tránh" phải kèm mức
///   độ tin và được diễn đạt nhẹ nhàng.
///
/// Tất cả hàm là pure function để kiểm thử độc lập.

const int kMinSessionsForInference = 5;

/// Mức độ tin của một suy luận — hiển thị cho user để phân biệt
/// fact/inference (mục 10.7).
enum Confidence { low, medium, high }

String confidenceLabel(Confidence c) {
  switch (c) {
    case Confidence.low:
      return 'Suy đoán ban đầu';
    case Confidence.medium:
      return 'Khá chắc chắn';
    case Confidence.high:
      return 'Rõ ràng từ dữ liệu';
  }
}

// ---------------------------------------------------------------------------
// Khung giờ học tốt nhất
// ---------------------------------------------------------------------------

/// Giờ dạng thập phân (ví dụ 19.5 = 19:30). Quy về khung giờ.
String _timeBucket(double hour) {
  if (hour >= 5 && hour < 11) return 'Sáng (5h–11h)';
  if (hour >= 11 && hour < 17) return 'Chiều (11h–17h)';
  if (hour >= 17 && hour < 23) return 'Tối (17h–23h)';
  return 'Đêm khuya (23h–5h)';
}

String? inferBestStudyTime(List<StudySession> sessions) {
  final buckets = <String, List<int>>{};
  for (final s in sessions) {
    if (s.focus == null) continue;
    final bucket =
        _timeBucket(s.completedAt.hour + s.completedAt.minute / 60.0);
    (buckets[bucket] ??= []).add(s.focus!);
  }

  String? best;
  double bestAvg = 0;
  double secondAvg = 0;
  for (final entry in buckets.entries) {
    if (entry.value.length < 3) continue;
    final avg = entry.value.fold(0, (a, b) => a + b) / entry.value.length;
    if (avg > bestAvg) {
      secondAvg = bestAvg;
      bestAvg = avg;
      best = entry.key;
    } else if (avg > secondAvg) {
      secondAvg = avg;
    }
  }

  if (best == null || bestAvg - secondAvg < 0.5) return null;
  return best;
}

// ---------------------------------------------------------------------------
// Độ dài phiên ưa thích
// ---------------------------------------------------------------------------

/// Độ dài phiên người dùng thực sự hoàn thành nhiều nhất (mode), trả về
/// phút — chỉ khi có đủ mẫu và có một mode vượt trội.
int? inferPreferredSessionMinutes(List<StudySession> sessions) {
  if (sessions.length < kMinSessionsForInference) return null;
  final counts = <int, int>{};
  for (final s in sessions) {
    final bucket = (s.actualMinutes / 15).floor() * 15;
    counts[bucket] = (counts[bucket] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.length >= 2 && sorted[0].value < sorted[1].value * 2) {
    return null; // không rõ ràng — không kết luận.
  }
  return sorted.first.key;
}

// ---------------------------------------------------------------------------
// Độ khó môn & môn đang tránh
// ---------------------------------------------------------------------------

class SubjectProfile {
  final String subject;

  /// Điểm difficulty trung bình (1 dễ – 5 khó); null nếu < 3 phản hồi.
  final double? avgDifficulty;

  /// Số task của môn này đã bị bỏ qua.
  final int skippedCount;

  /// Số task của môn này đã hoàn thành.
  final int completedCount;

  const SubjectProfile({
    required this.subject,
    required this.avgDifficulty,
    required this.skippedCount,
    required this.completedCount,
  });

  /// Môn "đang tránh": bỏ qua nhiều hơn hẳn hoàn thành (≥ 2 lần skip và
  /// skip gấp đôi done). Đây là **hypothesis** — UI phải hiển thị như
  /// giả thuyết kèm lý do có thể (mục 36).
  bool get isAvoided => skippedCount >= 2 && skippedCount >= completedCount * 2;

  /// Môn khó theo dữ liệu — chỉ khi có đủ phản hồi và difficulty > 3.5.
  bool get isHard => avgDifficulty != null && avgDifficulty! > 3.5;
}

Map<String, SubjectProfile> inferSubjectProfiles({
  required List<StudySession> sessions,
  required List<TodayTask> tasks,
}) {
  final diffs = <String, List<int>>{};
  for (final s in sessions) {
    if (s.difficulty == null) continue;
    (diffs[s.subject] ??= []).add(s.difficulty!);
  }

  final skipped = <String, int>{};
  final completed = <String, int>{};
  for (final t in tasks) {
    if (t.isDone) {
      completed[t.subject] = (completed[t.subject] ?? 0) + 1;
    } else if (t.status == 'skipped') {
      skipped[t.subject] = (skipped[t.subject] ?? 0) + 1;
    }
  }

  final subjects = <String>{
    ...diffs.keys,
    ...skipped.keys,
    ...completed.keys,
  };

  final result = <String, SubjectProfile>{};
  for (final subject in subjects) {
    final list = diffs[subject] ?? const [];
    result[subject] = SubjectProfile(
      subject: subject,
      avgDifficulty:
          list.length < 3 ? null : list.fold(0, (a, b) => a + b) / list.length,
      skippedCount: skipped[subject] ?? 0,
      completedCount: completed[subject] ?? 0,
    );
  }
  return result;
}

// ---------------------------------------------------------------------------
// Model hồ sơ cho UI
// ---------------------------------------------------------------------------

/// Một dòng trong Hồ sơ học tập.
class LearningTrait {
  final String label;
  final String value;

  /// Căn cứ dữ liệu — hiển thị để minh bạch (mục 10.7 Evidence).
  final String evidence;

  final Confidence confidence;

  /// true nếu đây là giá trị user tự đặt (override) — không bị AI ghi đè.
  final bool isUserOverride;

  const LearningTrait({
    required this.label,
    required this.value,
    required this.evidence,
    required this.confidence,
    this.isUserOverride = false,
  });
}

/// Tổng hợp hồ sơ học tập, ưu tiên override của user.
///
/// [overrides] là các giá trị user đã sửa (key: 'best_time',
/// 'session_minutes'). Giá trị user tự đặt luôn hiển thị với nhãn
/// "Bạn tự chỉnh" và không bị suy luận ghi đè.
List<LearningTrait> buildLearningProfile({
  required List<StudySession> sessions,
  required List<TodayTask> tasks,
  required Map<String, String> overrides,
}) {
  final traits = <LearningTrait>[];

  // --- Best study time ---
  final bestTimeOverride = overrides['best_time'];
  if (bestTimeOverride != null && bestTimeOverride.isNotEmpty) {
    traits.add(LearningTrait(
      label: 'Thời gian học hiệu quả',
      value: bestTimeOverride,
      evidence: 'Bạn tự chỉnh — AI không thay đổi giá trị này.',
      confidence: Confidence.high,
      isUserOverride: true,
    ));
  } else {
    final inferred = inferBestStudyTime(sessions);
    if (inferred != null) {
      traits.add(LearningTrait(
        label: 'Thời gian học hiệu quả',
        value: inferred,
        evidence: 'Từ các phiên có chấm focus theo khung giờ.',
        confidence: Confidence.medium,
      ));
    }
  }

  // --- Preferred session length ---
  final sessionOverride = overrides['session_minutes'];
  if (sessionOverride != null && sessionOverride.isNotEmpty) {
    traits.add(LearningTrait(
      label: 'Độ dài phiên phù hợp',
      value: '$sessionOverride phút',
      evidence: 'Bạn tự chỉnh — AI không thay đổi giá trị này.',
      confidence: Confidence.high,
      isUserOverride: true,
    ));
  } else {
    final inferredMinutes = inferPreferredSessionMinutes(sessions);
    if (inferredMinutes != null) {
      traits.add(LearningTrait(
        label: 'Độ dài phiên phù hợp',
        value: '$inferredMinutes phút',
        evidence: 'Độ dài phiên bạn hoàn thành nhiều nhất (bội 15 phút).',
        confidence: Confidence.medium,
      ));
    }
  }

  // --- Subject profiles: môn khó / môn đang tránh ---
  final profiles = inferSubjectProfiles(sessions: sessions, tasks: tasks);
  final hardSubjects = profiles.values.where((p) => p.isHard).toList();
  if (hardSubjects.isNotEmpty) {
    traits.add(LearningTrait(
      label: 'Môn đang khó với bạn',
      value: hardSubjects.map((p) => p.subject).join(', '),
      evidence: 'Difficulty trung bình > 3.5/5 từ ít nhất 3 phiên phản hồi.',
      confidence: Confidence.medium,
    ));
  }
  final avoided = profiles.values.where((p) => p.isAvoided).toList();
  if (avoided.isNotEmpty) {
    traits.add(LearningTrait(
      label: 'Môn có vẻ đang bị trì hoãn',
      value: avoided.map((p) => p.subject).join(', '),
      evidence:
          'Bỏ qua nhiều hơn hoàn thành. Có thể do thiếu tài liệu, động lực hoặc bài quá khó — bạn biết rõ nhất.',
      confidence: Confidence.low,
    ));
  }

  return traits;
}
