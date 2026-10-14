/// Tên sự kiện sản phẩm tối thiểu (đặc tả mục 9.1).
///
/// Chỉ là **sự kiện sản phẩm**, tuyệt đối không chứa nội dung học tập, câu hỏi,
/// ghi chú hay chat thô. Dùng hằng chuỗi để tránh gõ sai và để test/đối chiếu.
class ProductEvents {
  ProductEvents._();

  static const onboardingCompleted = 'onboarding_completed';
  static const todayPlanViewed = 'today_plan_viewed';
  static const priorityTaskStarted = 'priority_task_started';
  static const priorityTaskCompleted = 'priority_task_completed';
  static const taskRescheduled = 'task_rescheduled';
  static const focusSessionStarted = 'focus_session_started';
  static const focusSessionCompleted = 'focus_session_completed';
  static const focusSessionAbandoned = 'focus_session_abandoned';
  static const aiActionRequested = 'ai_action_requested';
  static const aiActionApplied = 'ai_action_applied';
  static const aiActionFailed = 'ai_action_failed';
  static const syncSucceeded = 'sync_succeeded';
  static const syncFailed = 'sync_failed';
  static const conflictResolved = 'conflict_resolved';

  /// Tập tên hợp lệ — dùng để chặn ghi sự kiện lạ (phòng gõ sai/telemetry lén).
  static const all = <String>{
    onboardingCompleted,
    todayPlanViewed,
    priorityTaskStarted,
    priorityTaskCompleted,
    taskRescheduled,
    focusSessionStarted,
    focusSessionCompleted,
    focusSessionAbandoned,
    aiActionRequested,
    aiActionApplied,
    aiActionFailed,
    syncSucceeded,
    syncFailed,
    conflictResolved,
  };
}
