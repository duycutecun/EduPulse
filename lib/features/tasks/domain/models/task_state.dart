/// Trạng thái của một nhiệm vụ theo đặc tả Sprint 2 (BE-0.2, BE-2.2).
///
/// `value` là chuỗi lưu trữ thực tế (backward-compatible với dữ liệu v1:
/// v1 dùng `todo` / `completed` / `skipped`).
enum TaskStatus {
  scheduled('todo'),
  started('started'),
  completed('completed'),
  notCompleted('skipped'),
  rescheduled('rescheduled');

  final String value;
  const TaskStatus(this.value);

  /// Nhãn tiếng Việt hiển thị cho người dùng.
  String get label => TaskStateMachine.getStatusLabel(this);

  /// Task đã kết thúc vòng đời (không còn mở khỏi đây ngoài thao tác mở lại).
  bool get isTerminal =>
      this == TaskStatus.completed || this == TaskStatus.notCompleted;

  static TaskStatus fromString(String? val) {
    if (val == null) return TaskStatus.scheduled;
    switch (val.toLowerCase()) {
      case 'started':
      case 'in_progress':
        return TaskStatus.started;
      case 'completed':
      case 'done':
        return TaskStatus.completed;
      case 'skipped':
      case 'not_completed':
      case 'failed':
        return TaskStatus.notCompleted;
      case 'rescheduled':
        return TaskStatus.rescheduled;
      case 'todo':
      case 'scheduled':
      default:
        return TaskStatus.scheduled;
    }
  }
}

/// Máy trạng thái quản lý các bước chuyển trạng thái hợp lệ của Nhiệm vụ.
///
/// Vòng đời chuẩn (đặc tả UX/UI §6):
///
/// ```text
/// scheduled → started → completed
///      ↓          ↓
///      └────→ notCompleted → rescheduled → scheduled
/// ```
///
/// Quy tắc bất biến:
/// - `completed` chỉ mở lại được về `scheduled` (bỏ tick hoàn thành).
/// - Task đã `completed` **không** được `reschedule` — tránh phá vỡ lịch sử.
/// - `started` không được nhảy thẳng `rescheduled` phải qua `notCompleted`.
class TaskStateMachine {
  const TaskStateMachine._();

  static const Map<TaskStatus, Set<TaskStatus>> _allowed = {
    TaskStatus.scheduled: {
      TaskStatus.started,
      TaskStatus.completed,
      TaskStatus.notCompleted,
      TaskStatus.rescheduled,
    },
    TaskStatus.started: {
      TaskStatus.completed,
      TaskStatus.notCompleted,
      TaskStatus.scheduled,
    },
    TaskStatus.completed: {
      TaskStatus.scheduled,
    },
    TaskStatus.notCompleted: {
      TaskStatus.scheduled,
      TaskStatus.rescheduled,
      TaskStatus.started,
    },
    TaskStatus.rescheduled: {
      TaskStatus.scheduled,
      TaskStatus.started,
    },
  };

  /// Kiểm tra việc chuyển từ [currentStatus] sang [newStatus] có hợp lệ không.
  static bool canTransition(TaskStatus currentStatus, TaskStatus newStatus) {
    if (currentStatus == newStatus) return true;
    return _allowed[currentStatus]!.contains(newStatus);
  }

  /// Thử chuyển trạng thái; trả về trạng thái mới nếu hợp lệ, `null` nếu không.
  static TaskStatus? tryTransition(
    TaskStatus currentStatus,
    TaskStatus newStatus,
  ) {
    return canTransition(currentStatus, newStatus) ? newStatus : null;
  }

  /// Trả về nhãn tiếng Việt mô tả trạng thái.
  static String getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.scheduled:
        return 'Chưa làm';
      case TaskStatus.started:
        return 'Đang học';
      case TaskStatus.completed:
        return 'Đã hoàn thành';
      case TaskStatus.notCompleted:
        return 'Đã bỏ qua';
      case TaskStatus.rescheduled:
        return 'Đã dời lịch';
    }
  }
}
