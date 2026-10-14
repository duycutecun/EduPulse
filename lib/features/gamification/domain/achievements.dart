import '../../study/domain/models/study_models.dart';

/// Thống kê "chất liệu" để xét huy hiệu — nguồn dữ liệu toàn cục bộ, không có
/// gì gửi đi (P0-4: không telemetry học tập).
class AchievementStats {
  final List<MockScore> scores;
  final List<StudySession> sessions;
  final int streak;
  final int streakRecord;
  final int notesCount;
  final int tasksCompletedToday;
  final int tasksTotalToday;

  const AchievementStats({
    required this.scores,
    required this.sessions,
    required this.streak,
    required this.streakRecord,
    required this.notesCount,
    required this.tasksCompletedToday,
    required this.tasksTotalToday,
  });

  int get totalMinutes => sessions.fold(0, (sum, s) => sum + s.actualMinutes);

  bool get allTasksToday =>
      tasksTotalToday > 0 && tasksCompletedToday >= tasksTotalToday;

  /// Đã hoàn thành phiên học đầu tiên.
  bool get hasFirstSession => sessions.isNotEmpty;
}

/// Một huy hiệu thành tích (P2 — gamification).
///
/// Tiêu chí nhằm động viên hành vi *bền vững* (học đều, ghi chép, ôn lại) thay
/// vì thúc ép cày điểm: không có huy hiệu nào thưởng "điểm cao mà không học".
class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(AchievementStats) isUnlocked;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.isUnlocked,
  });
}

/// Danh bạ huy hiệu — thứ tự quyết định thứ tự hiển thị.
final List<Achievement> kAchievements = [
  Achievement(
    id: 'first_session',
    emoji: '👣',
    title: 'Bước chân đầu',
    description: 'Hoàn thành phiên học đầu tiên.',
    isUnlocked: (s) => s.hasFirstSession,
  ),
  Achievement(
    id: 'ten_hours',
    emoji: '⏱️',
    title: '10 giờ đồng hồ',
    description: 'Tích luỹ 10 giờ học tập.',
    isUnlocked: (s) => s.totalMinutes >= 600,
  ),
  Achievement(
    id: 'deep_focus',
    emoji: '🧘',
    title: 'Tâm trí sâu',
    description: 'Một phiên ≥25 phút với độ tập trung cao.',
    isUnlocked: (s) => s.sessions
        .any((x) => x.actualMinutes >= 25 && x.focus != null && x.focus! >= 4),
  ),
  Achievement(
    id: 'first_score',
    emoji: '📝',
    title: 'Cú mở màn',
    description: 'Có điểm thi thử đầu tiên.',
    isUnlocked: (s) => s.scores.isNotEmpty,
  ),
  Achievement(
    id: 'score_8',
    emoji: '🎯',
    title: 'Phá mốc 8 điểm',
    description: 'Đạt từ 8 điểm trong một lần thi thử.',
    isUnlocked: (s) => s.scores.any((x) => x.score >= 8),
  ),
  Achievement(
    id: 'ten_scores',
    emoji: '🧮',
    title: 'Một tá đề',
    description: '10 lần thi thử.',
    isUnlocked: (s) => s.scores.length >= 10,
  ),
  Achievement(
    id: 'streak_3',
    emoji: '🔥',
    title: 'Khởi động liền mạch',
    description: 'Học 3 ngày liên tiếp.',
    isUnlocked: (s) => s.streak >= 3,
  ),
  Achievement(
    id: 'streak_7',
    emoji: '⚡',
    title: 'Một tuần rực lửa',
    description: 'Học 7 ngày liên tiếp.',
    isUnlocked: (s) => s.streak >= 7,
  ),
  Achievement(
    id: 'streak_record',
    emoji: '🏆',
    title: 'Xô đổ kỷ lục',
    description: 'Kỷ lục chuỗi ngày đạt 10.',
    isUnlocked: (s) => s.streakRecord >= 10,
  ),
  Achievement(
    id: 'all_today',
    emoji: '✅',
    title: 'Trọn vẹn một ngày',
    description: 'Hoàn thành toàn bộ nhiệm vụ trong ngày.',
    isUnlocked: (s) => s.allTasksToday,
  ),
  Achievement(
    id: 'notes_5',
    emoji: '📒',
    title: 'Kho ghi chú nhỏ',
    description: 'Lưu 5 ghi chú.',
    isUnlocked: (s) => s.notesCount >= 5,
  ),
  Achievement(
    id: 'early_bird',
    emoji: '🐦',
    title: 'Chim nhiếp ảnh sớm',
    description: 'Có phiên học bắt đầu trước 7 giờ sáng.',
    isUnlocked: (s) =>
        s.sessions.any((x) => x.startedAt != null && x.startedAt!.hour < 7),
  ),
];

/// Huy hiệu đã đạt theo [stats] — sắp giữ nguyên thứ tự danh bạ.
List<Achievement> unlockedFor(AchievementStats stats) =>
    kAchievements.where((a) => a.isUnlocked(stats)).toList();

/// Một dòng trạng thái trong lưới huy hiệu.
class AchievementState {
  final Achievement achievement;
  final bool unlocked;

  const AchievementState(this.achievement, this.unlocked);
}

/// Xét toàn bộ danh bạ để UI render trạng thái khoá/mở.
List<AchievementState> evaluateAchievements(AchievementStats stats) =>
    kAchievements.map((a) => AchievementState(a, a.isUnlocked(stats))).toList();
