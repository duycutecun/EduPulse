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

class TodayTask {
  final String id;
  String title;
  bool isDone;
  final String subject;
  final String priority; // 'high', 'medium', 'low'
  final int estimateMinutes;

  TodayTask({
    required this.id,
    required this.title,
    this.isDone = false,
    this.subject = 'Toán',
    this.priority = 'medium',
    this.estimateMinutes = 45,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'subject': subject,
    'priority': priority,
    'estimateMinutes': estimateMinutes,
  };

  factory TodayTask.fromJson(Map<String, dynamic> j) => TodayTask(
    id: j['id'],
    title: j['title'],
    isDone: j['isDone'] ?? false,
    subject: j['subject'] ?? 'Toán',
    priority: j['priority'] ?? 'medium',
    estimateMinutes: j['estimateMinutes'] ?? 45,
  );

  String toJsonString() => jsonEncode(toJson());
  factory TodayTask.fromJsonString(String s) =>
      TodayTask.fromJson(jsonDecode(s));
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  bool isLoading;
  final Uint8List? imageBytes;
  final String? imageName;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.imageBytes,
    this.imageName,
  });
}

class CommunityUser {
  final int rank;
  final String name;
  String target;
  final int streak;
  final double weeklyHours;
  final String emoji;
  final String badge;
  int cheers;
  bool hasCheered;

  CommunityUser({
    required this.rank,
    required this.name,
    required this.target,
    required this.streak,
    required this.weeklyHours,
    required this.emoji,
    required this.badge,
    this.cheers = 0,
    this.hasCheered = false,
  });
}
