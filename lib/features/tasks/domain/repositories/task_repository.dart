import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/ai/ai_refresh_service.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../study/domain/models/study_models.dart';
import '../models/task_attachment.dart';
import '../models/task_state.dart';

/// Trạng thái kết quả một thao tác ghi lên Task (BE-2.1).
enum TaskMutationStatus {
  /// Ghi thành công.
  ok,

  /// Bị từ chối (chuyển trạng thái không hợp lệ, task không còn tồn tại…).
  failed,

  /// Bị chặn vì đã có task giống hệt — **không ghi gì** (AI-2.1).
  duplicate,
}

/// Kết quả một thao tác ghi lên Task (BE-2.1).
///
/// Lý do cần kết quả rõ ràng thay vì `bool`: UI cần phân biệt
/// "bị từ chối vì chuyển trạng thái không hợp lệ" với "trùng task" với "lỗi lưu
/// trữ", và luôn hiển thị thông điệp hợp lý thay vì im lặng.
class TaskMutationResult {
  final TaskMutationStatus status;
  final TodayTask? task;
  final String? error;

  const TaskMutationResult({
    this.status = TaskMutationStatus.ok,
    this.task,
    this.error,
  });

  const TaskMutationResult.success(this.task)
      : status = TaskMutationStatus.ok,
        error = null;

  const TaskMutationResult.failure(String this.error)
      : status = TaskMutationStatus.failed,
        task = null;

  bool get success => status == TaskMutationStatus.ok;
  bool get failed => status != TaskMutationStatus.ok;
  bool get isDuplicate => status == TaskMutationStatus.duplicate;

  /// Thông điệp nên hiện cho người dùng (có thể null nếu thành công).
  String? get message => error;
}

/// Repository quản lý Task — **Single Source of Truth** (BE-0.2, BE-2.1).
///
/// Nguyên tắc bất di bất dịch:
/// 1. Mọi ghi đều đi qua [TaskRepository]; UI không tự gọi StorageService cho task.
/// 2. Offline-first: ghi local thành công **trước**, cloud sync là bước sau và
///    không được làm hỏng thao tác local.
/// 3. `id` và `createdAt` bất biến trong vòng đời; `updatedAt` luôn được đóng dấu.
/// 4. Chuyển trạng thái đi qua [TaskStateMachine]; chuyển sai trả về lỗi,
///    tuyệt đối không ghi dữ liệu sai.
class TaskRepository {
  static final TaskRepository instance = TaskRepository._();
  TaskRepository._();

  /// Bản số thứ tự ghi — UI listen để refresh khi task thay đổi.
  /// Tách khỏi dữ liệu để tránh rebuild khi chưa có thay đổi thực.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Timer? _syncDebounce;

  // ─── Read ────────────────────────────────────────────────────────────────

  /// Toàn bộ nhiệm vụ, giữ nguyên thứ tự đã lưu.
  List<TodayTask> getAllTasks() {
    final ids = StorageService.getTodayTaskIds();
    final list = <TodayTask>[];
    for (final id in ids) {
      final task = getTaskById(id);
      if (task != null) list.add(task);
    }
    return list;
  }

  /// Lấy nhiệm vụ theo ID. Trả `null` nếu không tồn tại hoặc JSON hỏng.
  TodayTask? getTaskById(String id) {
    final json = StorageService.getTodayTaskJson(id);
    if (json == null) return null;
    try {
      return TodayTask.fromJsonString(json);
    } catch (e) {
      debugPrint('[TaskRepository] Corrupt task $id: $e');
      return null;
    }
  }

  /// Nhiệm vụ thuộc ngày [day] (mặc định hôm nay).
  ///
  /// Quy tắc lọc duy nhất của cả app — tránh tồn tại hai bộ lọc "hôm nay"
  /// khác nhau như ở bản v1:
  /// 1. `scheduledAt` nằm trong ngày → thuộc ngày.
  /// 2. Không có `scheduledAt`: task quá hạn chưa xong vẫn thuộc ngày hôm nay
  ///    (học sinh vẫn cần thấy nó), còn lại coi như "việc chưa lên lịch" của hôm nay.
  /// 3. Task đã hoàn thành/hủy không kéo theo vào ngày mới.
  List<TodayTask> getTasksForDay([DateTime? day]) {
    final now = DateTime.now();
    final target = DateTime(
      (day ?? now).year,
      (day ?? now).month,
      (day ?? now).day,
    );
    final isToday = target.year == now.year &&
        target.month == now.month &&
        target.day == now.day;

    return getAllTasks()
        .where((task) => _belongsToDay(task, target, isToday))
        .toList();
  }

  /// Quy tắc "task này thuộc ngày nào" — **một nơi duy nhất**.
  ///
  /// Tách riêng vì [findDuplicate] cần bản "còn task đã hoàn thành trong ngày"
  /// (xem giải thích ở đó); nếu mỗi chỗ tự viết lại bộ lọc thì sớm muộn chúng
  /// cũng lệch nhau.
  static bool _belongsToDay(TodayTask task, DateTime target, bool isToday) {
    final status = TaskStatus.fromString(task.status);
    if (status.isTerminal) return false;

    if (task.scheduledAt != null) {
      final d = task.scheduledAt!;
      return d.year == target.year &&
          d.month == target.month &&
          d.day == target.day;
    }

    if (task.deadline != null) {
      final d = task.deadline!;
      final deadlineDay = DateTime(d.year, d.month, d.day);
      if (deadlineDay == target) return true;
      // Quá hạn: chỉ hiện ở hôm nay để không biến ngày mới thành "đống nợ".
      return isToday && deadlineDay.isBefore(target);
    }

    // Không lịch, không hạn → nhiệm vụ "chưa xếp lịch", hiện ở hôm nay.
    return isToday;
  }

  /// Task thuộc ngày [day] **kể cả đã hoàn thành** — chỉ dùng cho chống trùng.
  bool _scheduledInDay(TodayTask task, DateTime? day) {
    final at = task.scheduledAt ?? task.deadline;
    if (at == null) return day == null;
    final target =
        day == null ? DateTime.now() : DateTime(day.year, day.month, day.day);
    final a = DateTime(at.year, at.month, at.day);
    return a == target;
  }

  // ─── Write ───────────────────────────────────────────────────────────────

  /// Tạo nhiệm vụ mới. Nếu `id` đã tồn tại thì coi như update (idempotent).
  Future<TaskMutationResult> createTask(TodayTask task) async {
    final existing = getTaskById(task.id);
    if (existing != null) return updateTask(task);

    task.createdAt ??= DateTime.now();
    _persist(task, registerId: true);
    return TaskMutationResult.success(task);
  }

  /// Tìm task **trùng nội dung**: cùng tên (không phân biệt hoa/thường, bỏ
  /// dấu, emoji) + cùng môn đã chuẩn hoá + cùng ngày học.
  ///
  /// Dùng cho AI-2.1: AI hay gợi ý "ôn lại Toán 19h" nhiều lần trong ngày, nếu
  /// không có chốt chặn thì người dùng sẽ có 3–4 task giống hệt nhau.
  TodayTask? findDuplicate({
    required String title,
    required String subject,
    DateTime? scheduledAt,
    String? ignoreId,
  }) {
    final key = _dupKey(title, subject);
    if (key == null) return null;

    // Duyệt **toàn bộ** task chứ không dùng getTasksForDay(): task đã hoàn
    // thành hôm nay không xuất hiện trong danh sách hôm nay, nhưng nếu AI gợi
    // ý lại đúng việc vừa xong thì người dùng vẫn phải làm lại — đúng là
    // trùng. Nên chỉ lọc theo **ngày lên lịch**, không lọc theo trạng thái.
    for (final task in getAllTasks()) {
      if (ignoreId != null && task.id == ignoreId) continue;
      if (_dupKey(task.title, task.subject) != key) continue;
      if (!_scheduledInDay(task, scheduledAt)) continue;
      return task;
    }
    return null;
  }

  /// Tạo task nhưng **chặn trùng** — dùng cho mọi thao tác của AI.
  ///
  /// Trả về `duplicate = true` kèm task đã có; không ghi gì cả.
  Future<TaskMutationResult> createTaskIfMissing(TodayTask task) async {
    final duplicate = findDuplicate(
      title: task.title,
      subject: task.subject,
      scheduledAt: task.scheduledAt,
    );
    if (duplicate != null) {
      return TaskMutationResult(
        status: TaskMutationStatus.duplicate,
        task: duplicate,
        error: 'Bạn đã có nhiệm vụ "${duplicate.title}" trong kế hoạch rồi',
      );
    }
    return createTask(task);
  }

  /// Khoá trùng: tên + môn chuẩn hoá. Trả null nếu dữ liệu quá rỗng để so.
  static String? _dupKey(String title, String subject) {
    final t = _foldKey(title);
    if (t.isEmpty) return null;
    return '${AppSubjects.normalize(subject).toLowerCase()}|$t';
  }

  /// Bỏ dấu + bỏ dấu câu + gộp khoảng trắng. Dùng chung bộ bỏ dấu của danh
  /// mục môn để "Ôn hàm số" và "on HAM SO" là một.
  static String _foldKey(String value) => AppSubjects.foldDiacritics(value)
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Cập nhật nhiệm vụ. Giữ nguyên `id` và `createdAt` của bản ghi cũ.
  Future<TaskMutationResult> updateTask(TodayTask updated) async {
    final existing = getTaskById(updated.id);
    if (existing == null) {
      return const TaskMutationResult.failure('Nhiệm vụ không còn tồn tại');
    }
    updated.createdAt ??= existing.createdAt;
    _persist(updated);
    return TaskMutationResult.success(updated);
  }

  /// Bật/tắt hoàn thành — qua state machine.
  Future<TaskMutationResult> toggleTaskDone(String id) async {
    final task = getTaskById(id);
    if (task == null) {
      return const TaskMutationResult.failure('Không tìm thấy nhiệm vụ');
    }

    final current = TaskStatus.fromString(task.status);
    final target = task.isDone ? TaskStatus.scheduled : TaskStatus.completed;

    if (!TaskStateMachine.canTransition(current, target)) {
      return TaskMutationResult.failure(
        'Không thể đổi trạng thái từ "${TaskStateMachine.getStatusLabel(current)}" '
        'sang "${TaskStateMachine.getStatusLabel(target)}"',
      );
    }

    task.isDone = target == TaskStatus.completed;
    task.status = target.value;
    if (target == TaskStatus.completed) {
      task.skipReason = null;
    }
    _persist(task);
    return TaskMutationResult.success(task);
  }

  /// Đặt trạng thái nhiệm vụ (BE-2.2). Trạng thái không hợp lệ → không ghi.
  Future<TaskMutationResult> setTaskStatus(
    String id,
    TaskStatus newStatus, {
    String? reason,
  }) async {
    final task = getTaskById(id);
    if (task == null) {
      return const TaskMutationResult.failure('Không tìm thấy nhiệm vụ');
    }

    final current = TaskStatus.fromString(task.status);
    if (!TaskStateMachine.canTransition(current, newStatus)) {
      return TaskMutationResult.failure(
        'Không thể chuyển "${TaskStateMachine.getStatusLabel(current)}" '
        '→ "${TaskStateMachine.getStatusLabel(newStatus)}"',
      );
    }

    task.status = newStatus.value;
    task.isDone = newStatus == TaskStatus.completed;
    task.skipReason = reason;
    _persist(task);
    return TaskMutationResult.success(task);
  }

  /// Bỏ qua nhiệm vụ hôm nay kèm lý do (nút "Bỏ qua" trên TaskCard).
  Future<TaskMutationResult> skipTask(String id, {String? reason}) =>
      setTaskStatus(id, TaskStatus.notCompleted, reason: reason);

  /// Dời lịch nhiệm vụ — **cập nhật task hiện tại, không tạo bản sao** (FE-2.4).
  ///
  /// Task đã hoàn thành không được dời (chặn từ state machine) để không phá
  /// lịch sử học tập. `rescheduleCount` tăng để AI có thể gợi ý chia nhỏ.
  Future<TaskMutationResult> rescheduleTask(
    String id,
    DateTime newDate, {
    String? reason,
  }) async {
    final task = getTaskById(id);
    if (task == null) {
      return const TaskMutationResult.failure('Không tìm thấy nhiệm vụ');
    }

    final current = TaskStatus.fromString(task.status);
    // Task hoàn thành/bỏ qua chuyển sang "đã dời" là bất hợp lệ.
    if (current.isTerminal) {
      return TaskMutationResult.failure(
        'Nhiệm vụ đã ${TaskStateMachine.getStatusLabel(current).toLowerCase()} '
        '— không thể dời lịch',
      );
    }

    // Giữ giờ đã hẹn nếu có, chỉ đổi ngày.
    final base = task.scheduledAt ?? newDate;
    task.scheduledAt = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      base.hour,
      base.minute,
    );
    task.rescheduleCount += 1;
    // Dời xong nhiệm vụ sẵn sàng làm ở ngày mới.
    task.status = TaskStatus.scheduled.value;
    task.isDone = false;
    task.skipReason = null;
    if (reason != null && reason.isNotEmpty) task.skipReason = reason;

    _persist(task);
    return TaskMutationResult.success(task);
  }

  /// Xóa nhiệm vụ.
  ///
  /// Nhiệm vụ đã xóa được trả về trong [TaskMutationResult.task] kèm vị trí
  /// gốc để [restoreTask] hoàn tác trọn vẹn (FE-2.5). Tài liệu đính kèm đi
  /// theo task và được đính kèm vào [DeletedTaskRef.attachments] để Undo
  /// trả lại đúng như cũ.
  Future<DeletedTaskRef> deleteTask(String id) async {
    final task = getTaskById(id);
    if (task == null) {
      throw StateError('Không tìm thấy nhiệm vụ để xóa');
    }
    final ids = StorageService.getTodayTaskIds();
    final index = ids.indexOf(id);
    final attachments = listAttachments(id);
    StorageService.removeTodayTask(id);
    for (final attachment in attachments) {
      StorageService.removeTaskAttachment(id, attachment.id);
    }
    _afterMutation();
    return DeletedTaskRef(
      task: task,
      originalIndex: index < 0 ? null : index,
      attachments: attachments,
    );
  }

  /// Phục hồi nhiệm vụ vừa xóa — hỗ trợ Hoàn tác trong SnackBar (FE-2.5).
  ///
  /// Giữ nguyên `id`, vị trí trong danh sách và tài liệu đính kèm để hoàn tác
  /// không làm lịch lệch cũng không mất ảnh.
  Future<TaskMutationResult> restoreTask(DeletedTaskRef ref) async {
    final task = ref.task;
    final ids = StorageService.getTodayTaskIds();
    if (!ids.contains(task.id)) {
      final index = (ref.originalIndex ?? ids.length).clamp(0, ids.length);
      ids.insert(index, task.id);
      StorageService.setTodayTaskIds(ids);
    }
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    if (listAttachments(task.id).isEmpty && ref.attachments.isNotEmpty) {
      _restoreAttachments(task.id, ref.attachments);
    }
    _afterMutation();
    return TaskMutationResult.success(task);
  }

  // ---------------------------------------------------------------------
  // Tài liệu đính kèm (FE-2.2)
  // ---------------------------------------------------------------------

  /// Danh sách tài liệu của một nhiệm vụ, mới thêm trước.
  ///
  /// Tệp hỏng bị bỏ qua và log lại thay vì làm hỏng cả danh sách.
  List<TaskAttachment> listAttachments(String taskId) {
    final attachments = <TaskAttachment>[];
    for (final id in StorageService.getTaskAttachmentIds(taskId)) {
      final json = StorageService.getTaskAttachmentJson(taskId, id);
      if (json == null) continue;
      try {
        attachments.add(
          TaskAttachment.fromJson(jsonDecode(json) as Map<String, dynamic>),
        );
      } catch (e) {
        debugPrint('[TaskRepository] Corrupt attachment $taskId/$id: $e');
      }
    }
    attachments.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return attachments;
  }

  /// Gắn tài liệu lên nhiệm vụ.
  ///
  /// Chặn trước khi ghi ba lỗi thường gặp nhất: task không tồn tại, tệp quá
  /// [TaskAttachment.maxBytes], và đã đủ [TaskAttachment.maxCount] tệp —
  /// prefs không phải kho tệp, để phình thì cả app chậm.
  TaskMutationResult addAttachment(
    String taskId, {
    required String name,
    required List<int> bytes,
    DateTime? addedAt,
  }) {
    final task = getTaskById(taskId);
    if (task == null) {
      return const TaskMutationResult.failure('Không tìm thấy nhiệm vụ');
    }
    if (bytes.isEmpty) {
      return const TaskMutationResult.failure('Tệp rỗng — không thể gắn');
    }
    if (bytes.length > TaskAttachment.maxBytes) {
      final kb = (bytes.length / 1024).round();
      return TaskMutationResult.failure(
        'Tệp nặng ${kb}KB — vượt giới hạn '
        '${TaskAttachment.maxBytes ~/ 1024}KB. Hãy chọn ảnh nhẹ hơn.',
      );
    }
    final existing = listAttachments(taskId);
    if (existing.length >= TaskAttachment.maxCount) {
      return TaskMutationResult.failure(
        'Mỗi nhiệm vụ chỉ gắn tối đa ${TaskAttachment.maxCount} tài liệu. '
        'Hãy gỡ một tài liệu cũ trước.',
      );
    }

    final attachment = TaskAttachment(
      // Dùng bộ đếm như [_newId] chứ không dùng micro giây trần: hai lần gắn
      // liên tiếp có thể rơi vào cùng một micro-giây, và khi đó cùng một id sẽ
      // khiến tệp mới ghi đè tệp cũ — mất ảnh mà không có dấu vết.
      id: _newId(),
      name: name.trim().isEmpty ? 'Tài liệu' : name.trim(),
      sizeBytes: bytes.length,
      base64: base64Encode(bytes),
      addedAt: addedAt ?? DateTime.now(),
    );
    StorageService.setTaskAttachmentJson(
        taskId, attachment.id, _encodeAttachment(attachment));
    final ids = StorageService.getTaskAttachmentIds(taskId)..add(attachment.id);
    StorageService.setTaskAttachmentIds(taskId, ids);

    _afterMutation();
    return TaskMutationResult.success(task);
  }

  /// Gỡ một tài liệu đính kèm.
  TaskMutationResult removeAttachment(String taskId, String attachmentId) {
    final task = getTaskById(taskId);
    if (task == null) {
      return const TaskMutationResult.failure('Không tìm thấy nhiệm vụ');
    }
    StorageService.removeTaskAttachment(taskId, attachmentId);
    _afterMutation();
    return TaskMutationResult.success(task);
  }

  /// Gắn lại đúng tài liệu vừa gỡ (Undo) — giữ nguyên `id` và thời điểm thêm
  /// để sau này thứ tự hiển thị không bị đảo.
  TaskMutationResult restoreAttachment(
      String taskId, TaskAttachment attachment) {
    final task = getTaskById(taskId);
    if (task == null) {
      return const TaskMutationResult.failure('Không tìm thấy nhiệm vụ');
    }
    final ids = StorageService.getTaskAttachmentIds(taskId);
    if (!ids.contains(attachment.id)) ids.add(attachment.id);
    StorageService.setTaskAttachmentIds(taskId, ids);
    StorageService.setTaskAttachmentJson(
        taskId, attachment.id, _encodeAttachment(attachment));
    _afterMutation();
    return TaskMutationResult.success(task);
  }

  String _encodeAttachment(TaskAttachment attachment) =>
      jsonEncode(attachment.toJson());

  /// Đổi thứ tự hiển thị (FE-1.3 — nhịp học cá nhân gợi ý "môn khó lên trước").
  ///
  /// Chỉ ghi lại danh sách ID, **không sửa nội dung task**. Id không tồn tại bị
  /// bỏ qua; id đang lưu mà không có trong [orderedIds] được giữ lại cuối danh
  /// sách để không làm mất task.
  Future<TaskMutationResult> reorderTasks(List<String> orderedIds) async {
    final current = StorageService.getTodayTaskIds();
    final currentSet = current.toSet();

    final next = <String>[];
    final seen = <String>{};
    for (final id in orderedIds) {
      if (!currentSet.contains(id) || !seen.add(id)) continue;
      next.add(id);
    }
    // Giữ các task không được nhắc tới, theo thứ tự cũ.
    for (final id in current) {
      if (!seen.contains(id)) next.add(id);
    }

    if (_sameOrder(next, current)) {
      return TaskMutationResult.success(null);
    }
    StorageService.setTodayTaskIds(next);
    _afterMutation();
    return TaskMutationResult.success(null);
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Chia nhỏ một nhiệm vụ dài thành nhiều phần 25–30 phút (FE-2.1/FE-2.2).
  ///
  /// An toàn dữ liệu — thứ tự bắt buộc:
  /// 1. Ghi **hết** các phần con xuống storage và kiểm tra lại đã tồn tại.
  /// 2. Chỉ khi đủ số phần mới xóa task gốc.
  ///
  /// Nếu bước 1 hỏng ⇒ task gốc **giữ nguyên**, không mất gì.
  ///
  /// [parts] = số phần; mặc định suy ra từ thời lượng (~25 phút/phần),
  /// giới hạn 2–4 phần. Ghi chú chỉ nằm ở phần đầu để không lặp lại 4 lần.
  Future<TaskSplitResult> splitTask(
    String id, {
    int? parts,
    int targetMinutes = 25,
  }) async {
    final task = getTaskById(id);
    if (task == null) {
      return TaskSplitResult.failure('Không tìm thấy nhiệm vụ để chia nhỏ');
    }
    if (task.isDone) {
      return TaskSplitResult.failure(
          'Nhiệm vụ đã hoàn thành thì không cần chia nhỏ nữa');
    }

    final auto = (task.estimateMinutes / targetMinutes).ceil().clamp(2, 4);
    final count = (parts ?? auto).clamp(2, 4);
    if (task.estimateMinutes <= targetMinutes) {
      return TaskSplitResult.failure(
          'Nhiệm vụ này chỉ ${task.estimateMinutes} phút — đủ ngắn rồi');
    }

    // Chia đều, phần dư dồn vào các phần đầu ⇒ tổng không đổi.
    final base = task.estimateMinutes ~/ count;
    final extra = task.estimateMinutes % count;
    final minutes = <int>[
      for (var i = 0; i < count; i++) base + (i < extra ? 1 : 0),
    ];

    final children = <TodayTask>[];
    for (var i = 0; i < count; i++) {
      // Dựng trực tiếp thay vì copyWith: `copyWith(null)` giữ giá trị cũ nên
      // không xoá được ghi chú/khoảng trống của task gốc.
      children.add(TodayTask(
        id: _newId(),
        title: '${task.title} (${i + 1}/$count)',
        subject: task.subject,
        topic: task.topic,
        priority: task.priority,
        estimateMinutes: minutes[i],
        deadline: task.deadline,
        scheduledAt: task.scheduledAt,
        // Ghi chú chỉ nằm ở phần đầu để không lặp lại 4 lần.
        note: i == 0 ? task.note : null,
        goalId: task.goalId,
        subtasks: task.subtasks,
        recurrence: task.recurrence,
        status: TaskStatus.scheduled.value,
        isDone: false,
        rescheduleCount: 0,
      ));
    }

    // 1. Ghi trước toàn bộ phần con.
    for (final child in children) {
      _persist(child, registerId: true);
    }
    final written = children.every((c) => getTaskById(c.id) != null);
    if (!written) {
      for (final child in children) {
        if (getTaskById(child.id) != null) {
          StorageService.removeTodayTask(child.id);
        }
      }
      return TaskSplitResult.failure(
          'Không lưu được các phần nhỏ — nhiệm vụ cũ vẫn nguyên vẹn');
    }

    // 2. Đủ số phần mới xóa task gốc.
    final index = StorageService.getTodayTaskIds().indexOf(id);
    // Tài liệu đính kèm theo task cha: phần con là việc nhỏ hơn, không tự
    // mang tài liệu của cả bài. Giữ lại để hoàn tác không mất ảnh.
    final attachments = listAttachments(id);
    StorageService.removeTodayTask(id);
    for (final attachment in attachments) {
      StorageService.removeTaskAttachment(id, attachment.id);
    }
    _afterMutation();

    return TaskSplitResult(
      parts: children,
      originalTask: task,
      originalIndex: index < 0 ? null : index,
      originalAttachments: attachments,
    );
  }

  /// Hoàn tác một lần chia nhỏ: bỏ các phần con, trả task gốc về đúng chỗ.
  Future<TaskMutationResult> undoSplit(TaskSplitResult split) async {
    final original = split.originalTask;
    if (original == null) {
      return TaskMutationResult.failure('Không có dữ liệu để hoàn tác');
    }
    for (final child in split.parts) {
      if (getTaskById(child.id) != null) {
        StorageService.removeTodayTask(child.id);
      }
    }
    if (getTaskById(original.id) == null) {
      _persist(original, registerId: true);
      final ids = StorageService.getTodayTaskIds();
      final index = (split.originalIndex ?? 0).clamp(0, ids.length - 1);
      ids.remove(original.id);
      ids.insert(index, original.id);
      StorageService.setTodayTaskIds(ids);
    }
    if (listAttachments(original.id).isEmpty) {
      _restoreAttachments(original.id, split.originalAttachments);
    }
    _afterMutation();
    return TaskMutationResult.success(original);
  }

  /// Ghi lại danh sách tài liệu đính kèm đã gỡ (dùng chung cho Undo xóa và
  /// Undo chia nhỏ).
  void _restoreAttachments(String taskId, List<TaskAttachment> attachments) {
    if (attachments.isEmpty) return;
    for (final attachment in attachments) {
      StorageService.setTaskAttachmentJson(
          taskId, attachment.id, _encodeAttachment(attachment));
    }
    StorageService.setTaskAttachmentIds(
      taskId,
      StorageService.getTaskAttachmentIds(taskId)
        ..addAll(attachments.map((a) => a.id)),
    );
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
  static int _idCounter = 0;

  // ─── Internal ────────────────────────────────────────────────────────────

  /// Ghi xuống storage + đóng dấu thời gian + phát tín hiệu + hẹn sync.
  void _persist(TodayTask task, {bool registerId = false}) {
    final now = DateTime.now();
    task.createdAt ??= now;
    task.updatedAt = now;

    if (registerId) {
      final ids = StorageService.getTodayTaskIds();
      if (!ids.contains(task.id)) {
        ids.add(task.id);
        StorageService.setTodayTaskIds(ids);
      }
    }
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    _afterMutation();
  }

  /// Mọi thay đổi task đều đi qua đây: refresh UI + chu trình AI + sync cloud.
  void _afterMutation() {
    revision.value++;
    AiRefreshService.notifyDataChanged();
    _scheduleCloudSync();
  }

  /// Debounce 2s để thao tác liên tiếp (tick nhiều task) chỉ gọi cloud 1 lần.
  /// Offline thì bỏ qua — local đã an toàn, sync định kỳ của SyncStateService lo.
  void _scheduleCloudSync() {
    if (!SupabaseService.isConfigured || !PwaService.isOnline) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), _pushToCloud);
  }

  /// Đẩy lên cloud NGAY, bỏ qua debounce — xem [ExamRepository.flushNow].
  ///
  /// Đặt cùng chỗ với kỳ thi để hai nguồn dữ liệu chính luôn được đẩy đồng
  /// thời điểm; nếu một cái chờ mà một cái không, sẽ khó truy nguồn khi lệch.
  void flushNow() {
    _syncDebounce?.cancel();
    _syncDebounce = null;
    if (!SupabaseService.isConfigured || !PwaService.isOnline) return;
    unawaited(_pushToCloud());
  }

  Future<bool> _pushToCloud() async {
    try {
      final ok = await SupabaseService.syncTasks(getAllTasks());
      if (ok) SyncStateService.markSynced();
      return ok;
    } catch (e) {
      debugPrint('[TaskRepository] Cloud sync failed (offline-first): $e');
      return false;
    }
  }
}

/// Tham chiếu đủ để hoàn tác một lần xóa (FE-2.5 Undo).
///
/// Mang theo cả tài liệu đính kèm: xóa task phải dọn luôn ảnh (không để
/// base64 mồ côi nằm vĩnh viễn trong prefs), nhưng nếu Undo chỉ khôi phục
/// task thì người dùng mất tài liệu mà không hề được báo.
class DeletedTaskRef {
  final TodayTask task;
  final int? originalIndex;
  final List<TaskAttachment> attachments;

  const DeletedTaskRef({
    required this.task,
    this.originalIndex,
    this.attachments = const [],
  });
}

/// Kết quả chia nhỏ nhiệm vụ: các phần con + thông tin để hoàn tác.
class TaskSplitResult {
  final List<TodayTask> parts;
  final TodayTask? originalTask;
  final int? originalIndex;

  /// Tài liệu đính kèm của task cha, giữ lại để [TaskRepository.undoSplit]
  /// trả về đúng trạng thái trước khi chia nhỏ.
  final List<TaskAttachment> originalAttachments;
  final String? error;

  const TaskSplitResult({
    required this.parts,
    this.originalTask,
    this.originalIndex,
    this.originalAttachments = const [],
    this.error,
  });

  const TaskSplitResult.failure(String this.error)
      : parts = const [],
        originalTask = null,
        originalIndex = null,
        originalAttachments = const [];

  bool get success => error == null;
  bool get failed => error != null;
}
