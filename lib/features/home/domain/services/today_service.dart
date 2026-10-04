import 'package:flutter/material.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../../../tasks/domain/models/task_state.dart';
import '../../../tasks/domain/repositories/task_repository.dart';

/// Thống kê tóm tắt học tập trong ngày (Daily Summary) theo đặc tả FE-1.4 & BE-1.2.
class DailySummary {
  final int totalTasks;
  final int completedTasks;
  final int studyMinutes;
  final int remainingTasks;

  const DailySummary({
    required this.totalTasks,
    required this.completedTasks,
    required this.studyMinutes,
    required this.remainingTasks,
  });

  double get completionRate =>
      totalTasks == 0 ? 0.0 : (completedTasks / totalTasks).clamp(0.0, 1.0);

  String get studyDurationFormatted {
    final hours = studyMinutes ~/ 60;
    final minutes = studyMinutes % 60;
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}m' : ''}';
    }
    return '${minutes}m';
  }

  String get summaryText =>
      '$completedTasks/$totalTasks nhiệm vụ · $studyDurationFormatted học';
}

/// Service truy vấn và tổng hợp dữ liệu màn hình "Hôm Nay" (BE-1.1, BE-1.2, FE-1.3).
class TodayService {
  /// Lấy danh sách nhiệm vụ hôm nay đã được sắp xếp chuẩn theo FE-1.3:
  /// 1. Task đang làm (active session)
  /// 2. Task quá hạn (overdue) hoặc mức ưu tiên cao (high priority)
  /// 3. Task theo lịch bình thường
  /// 4. Task đã hoàn thành (xếp ở cuối)
  ///
  /// **Lọc "hôm nay" thuộc về [TaskRepository.getTasksForDay]** — bản v1 hàm này
  /// tự đọc toàn bộ storage và không lọc ngày, khiến task của ngày mai và task
  /// quá hạn từ tuần trước cũng hiện ở màn Hôm nay. Nay chỉ còn phần **sắp xếp**.
  static List<TodayTask> getTodayTasksSorted({String? activeTaskId}) {
    final tasks =
        List<TodayTask>.from(TaskRepository.instance.getTasksForDay());
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);

    // Task đã xong hôm nay vẫn phải hiện để thấy tiến độ → lấy lại nhóm
    // terminal của ngày hôm nay (repository cố tình loại terminal khỏi kết quả).
    tasks.addAll(_completedToday());

    tasks.sort((a, b) {
      // 1. Task hoàn thành luôn xuống cuối
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1;
      }

      // 2. Task đang học (active session) ưu tiên cao nhất
      if (activeTaskId != null) {
        if (a.id == activeTaskId && b.id != activeTaskId) return -1;
        if (b.id == activeTaskId && a.id != activeTaskId) return 1;
      }

      // 3. Quá hạn
      final aOverdue =
          a.deadline != null && DateUtils.dateOnly(a.deadline!).isBefore(today);
      final bOverdue =
          b.deadline != null && DateUtils.dateOnly(b.deadline!).isBefore(today);
      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }

      // 4. Mức độ ưu tiên (high -> medium -> low)
      final pA = _priorityWeight(a.priority);
      final pB = _priorityWeight(b.priority);
      if (pA != pB) {
        return pB.compareTo(pA);
      }

      // 5. Giờ hẹn lịch (scheduledAt)
      if (a.scheduledAt != null && b.scheduledAt != null) {
        return a.scheduledAt!.compareTo(b.scheduledAt!);
      }
      if (a.scheduledAt != null) return -1;
      if (b.scheduledAt != null) return 1;

      return 0;
    });

    return tasks;
  }

  static int _priorityWeight(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }

  /// Task đã hoàn thành **trong ngày hôm nay** — repository cố tình loại task
  /// terminal khỏi danh sách ngày, nhưng màn Hôm nay cần chúng để hiển thị
  /// tiến độ "x/y". Giữ đúng ngày, không kéo task hoàn thành của ngày khác vào.
  static List<TodayTask> _completedToday() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    return TaskRepository.instance.getAllTasks().where((task) {
      final status = TaskStatus.fromString(task.status);
      if (!status.isTerminal) return false;
      final stamp = task.updatedAt ?? task.scheduledAt ?? task.createdAt;
      if (stamp == null) return false;
      return DateUtils.dateOnly(stamp) == today;
    }).toList();
  }

  /// Tính toán tổng thời gian học thực tế trong ngày hôm nay từ Study Sessions (BE-1.2).
  static int getTodayStudyMinutes() =>
      StudySessionRepository.instance.minutesOn(DateTime.now());

  /// Tổng hợp số liệu ngày (Daily Summary) đầy đủ (BE-1.2, FE-1.4).
  static DailySummary getDailySummary() {
    final tasks = getTodayTasksSorted();
    final total = tasks.length;
    final completed = tasks.where((t) => t.isDone).length;
    final remaining = total - completed;
    final studyMinutes = getTodayStudyMinutes();

    return DailySummary(
      totalTasks: total,
      completedTasks: completed,
      studyMinutes: studyMinutes,
      remainingTasks: remaining,
    );
  }
}
