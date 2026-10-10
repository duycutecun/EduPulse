import '../../../core/constants/subject_catalog.dart';
import '../../../core/share/share_text.dart';
import '../../../core/utils/storage_service.dart';
import '../../exams/domain/exam_repository.dart';
import '../../progress/domain/progress_engine.dart';
import '../../study/domain/repositories/study_session_repository.dart';
import '../../tasks/domain/repositories/task_repository.dart';

/// Số liệu tuần để vẽ "ảnh thành tựu" và kể lại trong vài dòng chữ.
///
/// Tách khỏi widget để **kiểm thử được**: mọi con số ở đây đến từ
/// [ProgressEngine] (nguồn số liệu duy nhất của app) chứ không tự cộng tay ở UI
/// — nếu không, ảnh chia sẻ và màn Tiến độ sẽ nói hai con số khác nhau.
class AchievementData {
  const AchievementData({
    required this.studentName,
    required this.weekStart,
    required this.weekEnd,
    required this.weekMinutes,
    required this.completionPercent,
    required this.streakDays,
    required this.activeDays,
    required this.tasksCompleted,
    required this.tasksTotal,
    this.topSubject,
    this.topSubjectMinutes,
    this.examName,
    this.daysToExam,
  });

  final String studentName;
  final DateTime weekStart;
  final DateTime weekEnd;

  /// Phút focus cả tuần (không tính nhiệm vụ — chỉ thời gian ngồi học thật).
  final int weekMinutes;

  final int completionPercent;
  final int streakDays;

  /// Số ngày trong tuần có ít nhất một phiên focus.
  final int activeDays;

  final int tasksCompleted;
  final int tasksTotal;

  /// Môn học nhiều nhất trong tuần (null nếu tuần chưa có phiên nào).
  final String? topSubject;
  final int? topSubjectMinutes;

  final String? examName;
  final int? daysToExam;

  double get weekHours => weekMinutes / 60.0;

  /// Dòng chữ lớn trên ảnh — phải tích cực và KHÔNG dùng chuỗi ngày làm vũ khí
  /// so sánh (cùng giọng với [WeeklyReport]: kể chuyện tuần, không chấm điểm).
  String get headline {
    if (weekMinutes <= 0) {
      return 'Tuần này mình đã hoàn thành $tasksCompleted nhiệm vụ học tập.';
    }
    final hours = weekHours.toStringAsFixed(1);
    if (activeDays <= 1) {
      return 'Tuần này mình đã học $hours giờ và bắt đầu lại nhịp học.';
    }
    return 'Tuần này mình đã học $hours giờ trong $activeDays ngày.';
  }

  /// Nhãn ngắn gọn của tuần, vd "Tuần 6/10 – 12/10".
  String get weekLabel {
    String d(DateTime x) => '${x.day}/${x.month}';
    return 'Tuần ${d(weekStart)} – ${d(weekEnd)}';
  }

  /// Dựng số liệu từ dữ liệu local. Trả về null khi tuần chưa có gì để khoe
  /// (không phút học, không nhiệm vụ xong) — UI sẽ nói thật thay vì phát hành
  /// một tấm ảnh toàn số 0.
  static AchievementData? build({DateTime? now}) {
    final t = now ?? DateTime.now();
    final snapshot = ProgressEngine.snapshot(
      StudySessionRepository.instance.getAll(),
      TaskRepository.instance.getAllTasks(),
      t,
    );
    final week = snapshot.week;

    if (week.totalMinutes <= 0 && week.tasksCompleted <= 0) return null;

    final activeDays = week.dailyMinutes.where((m) => m > 0).length;

    // Môn nhiều thời gian nhất — bỏ qua môn 0 phút để không khoe "Toán 0 phút".
    SubjectProgress? top;
    for (final s in snapshot.subjects) {
      if (s.minutes <= 0) continue;
      if (top == null || s.minutes > top.minutes) top = s;
    }

    final exam = ExamRepository.instance.primaryExam;
    final daysLeft = exam?.daysLeftAt(t);

    final name = StorageService.getUserName().trim();
    return AchievementData(
      studentName: name.isEmpty ? 'Sĩ tử EduPulse' : name,
      weekStart: week.weekStart,
      weekEnd: week.weekStart.add(const Duration(days: 6)),
      weekMinutes: week.totalMinutes,
      completionPercent: (week.completionRate * 100).round().clamp(0, 100),
      streakDays: StorageService.getStreak(),
      activeDays: activeDays,
      tasksCompleted: week.tasksCompleted,
      tasksTotal: week.tasksTotal,
      topSubject: top?.subject,
      topSubjectMinutes: top?.minutes,
      examName: exam?.name,
      daysToExam: daysLeft != null && daysLeft >= 0 ? daysLeft : null,
    );
  }
}

/// Các dòng số liệu hiển thị trên ảnh — tách riêng để đếm/kiểm tra bằng test
/// mà không phải đọc cây widget.
class AchievementStat {
  const AchievementStat(this.emoji, this.label, this.value);

  final String emoji;
  final String label;
  final String value;
}

/// Danh sách số liệu cho ảnh, theo thứ tự hiển thị. Chỉ đưa vào những dòng có
/// dữ liệu thật (không hiện "0 phút" hay "0%").
List<AchievementStat> achievementStats(AchievementData data) {
  final stats = <AchievementStat>[];

  if (data.weekMinutes > 0) {
    stats.add(AchievementStat(
      '⏱️',
      'Thời gian tập trung',
      data.weekMinutes >= 60
          ? '${data.weekHours.toStringAsFixed(1)} giờ'
          : '${data.weekMinutes} phút',
    ));
  }
  if (data.tasksTotal > 0) {
    stats.add(AchievementStat(
      '✅',
      'Nhiệm vụ hoàn thành',
      '${data.tasksCompleted}/${data.tasksTotal} (${data.completionPercent}%)',
    ));
  }
  if (data.streakDays > 0) {
    stats.add(AchievementStat(
      '🔥',
      'Chuỗi ngày học',
      '${data.streakDays} ngày liên tiếp',
    ));
  }
  if (data.topSubject != null && (data.topSubjectMinutes ?? 0) > 0) {
    stats.add(AchievementStat(
      '📚',
      'Môn đầu tư nhiều nhất',
      '${AppSubjects.displayName(data.topSubject!)} · ${data.topSubjectMinutes} phút',
    ));
  }
  if (data.examName != null && data.daysToExam != null) {
    stats.add(AchievementStat(
      '🎯',
      'Kỳ thi mục tiêu',
      '${data.examName} — còn ${data.daysToExam} ngày',
    ));
  }
  return stats;
}

/// Chữ kèm ảnh khi chia sẻ: một câu + link app, để người nhận biết ảnh này đến
/// từ EduPulse ngay cả khi họ chỉ đọc phần chữ.
String achievementShareText(AchievementData data) {
  return [
    'Thành tựu học tập của mình trong tuần này 🎉',
    data.headline,
    'Mình đang dùng EduPulse để giữ nhịp học mỗi ngày.',
    ShareText.appLink,
  ].join('\n');
}
