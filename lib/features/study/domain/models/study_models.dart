import 'dart:convert';
import 'dart:typed_data';

class StudyLog {
  final String id;
  final DateTime date;
  final String subject;
  final double hours;
  final String? note;

  StudyLog({
    required this.id,
    required this.date,
    required this.subject,
    required this.hours,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'subject': subject,
        'hours': hours,
        'note': note,
      };

  factory StudyLog.fromJson(Map<String, dynamic> j) => StudyLog(
        id: j['id'],
        date: DateTime.parse(j['date']),
        subject: j['subject'] ?? '',
        hours: (j['hours'] as num).toDouble(),
        note: j['note'],
      );

  String toJsonString() => jsonEncode(toJson());
  factory StudyLog.fromJsonString(String s) => StudyLog.fromJson(jsonDecode(s));
}

/// A local-first study note. Notes intentionally stay independent from a task
/// so they remain available even when a task is completed or removed.
class StudyNote {
  final String id;
  String title;
  String body;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<String> tags;

  /// Task-linked (mục 14) — ghi chú gắn với một nhiệm vụ cụ thể.
  final String? taskId;

  /// Subject-linked — môn của ghi chú (tự điền khi chọn task).
  final String? subject;

  /// Study-session-linked — ghi chú chụp lại sau một phiên focus.
  final String? sessionId;

  /// 1 ảnh đính kèm (base64, đã chặn > ~250KB trước khi lưu — prefs
  /// không phải kho file; giới hạn để không phình localStorage).
  final String? imageBase64;

  StudyNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.taskId,
    this.subject,
    this.sessionId,
    this.imageBase64,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'tags': tags,
        'taskId': taskId,
        'subject': subject,
        'sessionId': sessionId,
        'imageBase64': imageBase64,
      };

  factory StudyNote.fromJson(Map<String, dynamic> json) => StudyNote(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
        tags: (json['tags'] as List? ?? const [])
            .map((tag) => tag.toString())
            .toList(),
        // Field mới đều nullable — note cũ không có vẫn parse đúng
        // (tương thích ngược, không cần migration).
        taskId: json['taskId'] as String?,
        subject: json['subject'] as String?,
        sessionId: json['sessionId'] as String?,
        imageBase64: json['imageBase64'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
  factory StudyNote.fromJsonString(String value) =>
      StudyNote.fromJson(jsonDecode(value));
}

class TodayTask {
  final String id;
  String title;
  bool isDone;
  String subject;
  String? topic;
  String priority; // 'high', 'medium', 'low'
  int estimateMinutes;
  DateTime? deadline;
  DateTime? scheduledAt;
  String? note;
  String? goalId;
  List<String> subtasks;
  String? recurrence;
  String status; // 'todo', 'completed', 'skipped'
  String? skipReason;
  int rescheduleCount;

  /// Thời điểm tạo nhiệm vụ (BE-2.1). Nullable + fallback để dữ liệu v1
  /// (không có trường này) vẫn parse được mà không cần migration.
  DateTime? createdAt;

  /// Thời điểm sửa gần nhất. Được TaskRepository cập nhật mỗi lần ghi.
  DateTime? updatedAt;

  TodayTask({
    required this.id,
    required this.title,
    this.isDone = false,
    this.subject = 'Toán',
    this.topic,
    this.priority = 'medium',
    this.estimateMinutes = 45,
    this.deadline,
    this.scheduledAt,
    this.note,
    this.goalId,
    this.subtasks = const [],
    this.recurrence,
    this.status = 'todo',
    this.skipReason,
    this.rescheduleCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'subject': subject,
        'topic': topic,
        'priority': priority,
        'estimateMinutes': estimateMinutes,
        'deadline': deadline?.toIso8601String(),
        'scheduledAt': scheduledAt?.toIso8601String(),
        'note': note,
        'goalId': goalId,
        'subtasks': subtasks,
        'recurrence': recurrence,
        'status': status,
        'skipReason': skipReason,
        'rescheduleCount': rescheduleCount,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory TodayTask.fromJson(Map<String, dynamic> j) => TodayTask(
        id: j['id'],
        title: j['title'],
        isDone: j['isDone'] ?? false,
        subject: j['subject'] ?? 'Toán',
        topic: j['topic'],
        priority: j['priority'] ?? 'medium',
        estimateMinutes: j['estimateMinutes'] ?? 45,
        deadline:
            j['deadline'] == null ? null : DateTime.tryParse(j['deadline']),
        scheduledAt: j['scheduledAt'] == null
            ? null
            : DateTime.tryParse(j['scheduledAt']),
        note: j['note'],
        goalId: j['goalId'],
        subtasks: (j['subtasks'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        recurrence: j['recurrence'],
        status: j['status'] ?? ((j['isDone'] ?? false) ? 'completed' : 'todo'),
        skipReason: j['skipReason'],
        rescheduleCount: j['rescheduleCount'] ?? 0,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'].toString()),
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.tryParse(j['updatedAt'].toString()),
      );

  String toJsonString() => jsonEncode(toJson());
  factory TodayTask.fromJsonString(String s) =>
      TodayTask.fromJson(jsonDecode(s));

  /// Bản sao giữ nguyên `id` — dùng cho edit/reschedule để không phá vỡ
  /// định danh nhiệm vụ và lịch sử phiên học đã tham chiếu tới (BE-2.1).
  TodayTask copyWith({
    String? title,
    bool? isDone,
    String? subject,
    String? topic,
    String? priority,
    int? estimateMinutes,
    DateTime? deadline,
    DateTime? scheduledAt,
    String? note,
    String? goalId,
    List<String>? subtasks,
    String? recurrence,
    String? status,
    String? skipReason,
    int? rescheduleCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodayTask(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      priority: priority ?? this.priority,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      deadline: deadline ?? this.deadline,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      note: note ?? this.note,
      goalId: goalId ?? this.goalId,
      subtasks: subtasks ?? this.subtasks,
      recurrence: recurrence ?? this.recurrence,
      status: status ?? this.status,
      skipReason: skipReason ?? this.skipReason,
      rescheduleCount: rescheduleCount ?? this.rescheduleCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A completed focus period. Kept separately from the lightweight daily log so
/// task history can later power task-level analytics and AI recommendations.
///
/// BE-3.1: thêm `startedAt`/`endedAt`/`status`. Cả ba đều **nullable** nên phiên
/// cũ (chỉ có `completedAt`) vẫn đọc được nguyên vẹn, không cần migration.
class StudySession {
  /// Phiên chạy trọn vẹn.
  static const String statusCompleted = 'completed';

  /// Phiên bị dừng giữa chừng — vẫn tính thời gian đã học nhưng không đạt mục tiêu.
  static const String statusCancelled = 'cancelled';

  final String id;
  final DateTime completedAt;
  final String? taskId;
  final String subject;
  final int plannedMinutes;
  final int actualMinutes;

  /// Lúc bấm bắt đầu Focus. Phiên cũ không có → coi như bằng `completedAt`.
  final DateTime? startedAt;

  /// Lúc kết thúc phiên (thường trùng `completedAt`).
  final DateTime? endedAt;

  /// Xem [statusCompleted] / [statusCancelled]; phiên cũ mặc định
  /// [statusCompleted] vì trước đây chỉ ghi phiên hoàn thành.
  final String? status;

  int? mood;
  int? focus;
  int? difficulty;
  int? understanding;
  int? effectiveness;
  String? reflectionNote;

  StudySession({
    required this.id,
    required this.completedAt,
    this.taskId,
    required this.subject,
    required this.plannedMinutes,
    required this.actualMinutes,
    this.startedAt,
    this.endedAt,
    this.status,
    this.mood,
    this.focus,
    this.difficulty,
    this.understanding,
    this.effectiveness,
    this.reflectionNote,
  });

  /// Phiên có chạy trọn vẹn không.
  bool get isCompleted => (status ?? statusCompleted) == statusCompleted;

  /// Điểm phản hồi tổng hợp 1–5, **tính ra** từ các thang đánh giá chi tiết.
  ///
  /// Cố ý không lưu thêm một trường `feedbackRating`: hai nguồn sự thật cho
  /// cùng một câu hỏi là cách chắc chắn nhất để chúng lệch nhau.
  int? get feedbackRating {
    final values = <int>[
      if (mood != null) mood!,
      if (focus != null) focus!,
      if (difficulty != null) difficulty!,
      if (understanding != null) understanding!,
      if (effectiveness != null) effectiveness!,
    ];
    if (values.isEmpty) return null;
    final sum = values.fold<int>(0, (a, b) => a + b);
    return (sum / values.length).round();
  }

  /// Thời lượng thực tế tính từ mốc bắt đầu/kết thúc — hữu ích khi bản ghi
  /// cũ không có `actualMinutes` chính xác.
  Duration? get elapsed {
    final from = startedAt ?? completedAt;
    final to = endedAt ?? completedAt;
    final diff = to.difference(from);
    return diff.isNegative ? null : diff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'completedAt': completedAt.toIso8601String(),
        'taskId': taskId,
        'subject': subject,
        'plannedMinutes': plannedMinutes,
        'actualMinutes': actualMinutes,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'status': status,
        'mood': mood,
        'focus': focus,
        'difficulty': difficulty,
        'understanding': understanding,
        'effectiveness': effectiveness,
        'reflectionNote': reflectionNote,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] ?? '',
        completedAt:
            DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
        taskId: json['taskId'],
        subject: json['subject'] ?? '',
        plannedMinutes: json['plannedMinutes'] ?? 0,
        actualMinutes: json['actualMinutes'] ?? 0,
        startedAt: DateTime.tryParse(json['startedAt'] ?? ''),
        endedAt: DateTime.tryParse(json['endedAt'] ?? ''),
        status: json['status'],
        mood: json['mood'],
        focus: json['focus'],
        difficulty: json['difficulty'],
        understanding: json['understanding'],
        effectiveness: json['effectiveness'],
        reflectionNote: json['reflectionNote'],
      );

  String toJsonString() => jsonEncode(toJson());
  factory StudySession.fromJsonString(String value) =>
      StudySession.fromJson(jsonDecode(value));
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  bool isLoading;
  final Uint8List? imageBytes;
  final String? imageName;

  /// Nguồn web trích dẫn (mục 10.9 — AI citations): title + url.
  /// Không lưu vào JSON history (nguồn chỉ gắn với phiên hiện tại —
  /// lịch sử cũ không có nguồn thì không hiển thị gì, trung thực).
  String? sourceTitle;
  String? sourceUrl;

  /// Hành động AI đề xuất (chat biết HÀNH ĐỘNG): được parse từ khối
  /// `<<<ACTIONS>>>` trong câu trả lời. Không lưu vào JSON history — hành động
  /// chỉ gắn với phiên hiện tại, lịch sử cũ vẫn hiển thị text thuần.
  final List<dynamic> actions;

  /// Tin nhắn lỗi của AI (đặc tả 12 / 30): hiện kèm [Thử lại] và
  /// [Tiếp tục tự học] thay vì chỉ báo lỗi. `retryPrompt` giữ nguyên câu hỏi
  /// gốc để thử lại đúng ý người dùng.
  final bool isError;
  final String? retryPrompt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.imageBytes,
    this.imageName,
    this.sourceTitle,
    this.sourceUrl,
    this.actions = const [],
    this.isError = false,
    this.retryPrompt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'imageName': imageName,
        // Lỗi AI phải sống sót qua lịch sử: mở app lại vẫn thấy nút
        // "Thử lại" với đúng câu hỏi gốc (UX 12 / AI-30).
        'isError': isError,
        'retryPrompt': retryPrompt,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] ?? '',
        text: j['text'] ?? '',
        isUser: j['isUser'] ?? false,
        timestamp: j['timestamp'] != null
            ? DateTime.tryParse(j['timestamp']) ?? DateTime.now()
            : DateTime.now(),
        imageName: j['imageName'],
        isError: j['isError'] ?? false,
        retryPrompt: j['retryPrompt'],
      );
}

/// Một lần ghi điểm đề thi thử (theo môn, thang 10).
class MockScore {
  final String id;
  final DateTime date;
  final String subject;
  final double score; // 0..10
  final String? note;

  MockScore({
    required this.id,
    required this.date,
    required this.subject,
    required this.score,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'subject': subject,
        'score': score,
        'note': note,
      };

  factory MockScore.fromJson(Map<String, dynamic> j) => MockScore(
        id: j['id'],
        date: DateTime.parse(j['date']),
        subject: j['subject'] ?? '',
        score: (j['score'] as num).toDouble(),
        note: j['note'],
      );

  String toJsonString() => jsonEncode(toJson());
  factory MockScore.fromJsonString(String s) =>
      MockScore.fromJson(jsonDecode(s));
}

class CommunityUser {
  final int rank;
  final String name;
  String target;
  final int streak;
  final String emoji;

  CommunityUser({
    required this.rank,
    required this.name,
    required this.target,
    required this.streak,
    required this.emoji,
  });
}
