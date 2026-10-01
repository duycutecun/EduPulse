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
  factory StudyLog.fromJsonString(String s) =>
      StudyLog.fromJson(jsonDecode(s));
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
  final String subject;
  final String? topic;
  final String priority; // 'high', 'medium', 'low'
  final int estimateMinutes;
  DateTime? deadline;
  DateTime? scheduledAt;
  final String? note;
  final String? goalId;
  final List<String> subtasks;
  final String? recurrence;
  String status; // 'todo', 'completed', 'skipped'
  String? skipReason;
  int rescheduleCount;

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
  };

  factory TodayTask.fromJson(Map<String, dynamic> j) => TodayTask(
    id: j['id'],
    title: j['title'],
    isDone: j['isDone'] ?? false,
    subject: j['subject'] ?? 'Toán',
    topic: j['topic'],
    priority: j['priority'] ?? 'medium',
    estimateMinutes: j['estimateMinutes'] ?? 45,
    deadline: j['deadline'] == null ? null : DateTime.tryParse(j['deadline']),
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
  );

  String toJsonString() => jsonEncode(toJson());
  factory TodayTask.fromJsonString(String s) =>
      TodayTask.fromJson(jsonDecode(s));
}

/// A completed focus period. Kept separately from the lightweight daily log so
/// task history can later power task-level analytics and AI recommendations.
class StudySession {
  final String id;
  final DateTime completedAt;
  final String? taskId;
  final String subject;
  final int plannedMinutes;
  final int actualMinutes;
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
    this.mood,
    this.focus,
    this.difficulty,
    this.understanding,
    this.effectiveness,
    this.reflectionNote,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'completedAt': completedAt.toIso8601String(),
        'taskId': taskId,
        'subject': subject,
        'plannedMinutes': plannedMinutes,
        'actualMinutes': actualMinutes,
        'mood': mood,
        'focus': focus,
        'difficulty': difficulty,
        'understanding': understanding,
        'effectiveness': effectiveness,
        'reflectionNote': reflectionNote,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] ?? '',
        completedAt: DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
        taskId: json['taskId'],
        subject: json['subject'] ?? '',
        plannedMinutes: json['plannedMinutes'] ?? 0,
        actualMinutes: json['actualMinutes'] ?? 0,
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
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'imageName': imageName,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] ?? '',
    text: j['text'] ?? '',
    isUser: j['isUser'] ?? false,
    timestamp: j['timestamp'] != null
        ? DateTime.tryParse(j['timestamp']) ?? DateTime.now()
        : DateTime.now(),
    imageName: j['imageName'],
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
