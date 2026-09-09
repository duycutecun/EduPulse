import 'dart:convert';

enum ExamType { preset, custom }

class ExamModel {
  final String id;
  final String name;
  final DateTime dateTime;
  final ExamType type;
  final String? description;
  final String emoji;

  ExamModel({
    required this.id,
    required this.name,
    required this.dateTime,
    this.type = ExamType.preset,
    this.description,
    this.emoji = '🎯',
  });

  Duration get remaining => dateTime.difference(DateTime.now());
  bool get isPast => dateTime.isBefore(DateTime.now());

  int get daysLeft => remaining.inDays;

  /// Color category based on days left
  String get urgencyLabel {
    if (isPast) return 'Đã qua';
    if (daysLeft < 30) return 'Sắp thi';
    if (daysLeft < 90) return 'Cần chuẩn bị';
    return 'Còn nhiều thời gian';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dateTime': dateTime.toIso8601String(),
    'type': type.index,
    'description': description,
    'emoji': emoji,
  };

  factory ExamModel.fromJson(Map<String, dynamic> j) => ExamModel(
    id: j['id'],
    name: j['name'],
    dateTime: DateTime.parse(j['dateTime']),
    type: ExamType.values[j['type'] ?? 1],
    description: j['description'],
    emoji: j['emoji'] ?? '🎯',
  );

  String toJsonString() => jsonEncode(toJson());
  factory ExamModel.fromJsonString(String s) =>
      ExamModel.fromJson(jsonDecode(s));
}
