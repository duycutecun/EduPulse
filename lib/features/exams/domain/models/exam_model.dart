import 'dart:convert';

enum ExamType { preset, custom }

/// Giai đoạn của kỳ thi theo đặc tả (mục 39–40):
/// - [normal]: thi còn xa (> 7 ngày)
/// - [revision]: 7 ngày trước thi — ưu tiên ôn trọng tâm, giảm task không cần thiết
/// - [examDay]: trong ngày thi — hiển thị thông tin thi + checklist, ít task
/// - [postExam]: sau giờ thi — chờ kết quả / nhận xét, giữ lịch sử
enum ExamPhase { normal, revision, examDay, postExam }

class ExamModel {
  final String id;
  final String name;
  final DateTime dateTime;
  final ExamType type;
  final String? description;
  final String emoji;
  final double? currentScore;
  final double? targetScore;

  ExamModel({
    required this.id,
    required this.name,
    required this.dateTime,
    this.type = ExamType.preset,
    this.description,
    this.emoji = '🎯',
    this.currentScore,
    this.targetScore,
  });

  Duration get remaining => dateTime.difference(DateTime.now());
  bool get isPast => dateTime.isBefore(DateTime.now());

  int get daysLeft => remaining.inDays;

  /// true nếu đã qua thời điểm kết thúc của ngày thi (23:59:59 ngày thi).
  bool get isExamDayOver {
    final endOfDay = DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);
    return DateTime.now().isAfter(endOfDay);
  }

  /// true nếu hôm nay là ngày thi.
  bool get isExamDay =>
      !isExamDayOver &&
      DateTime.now().year == dateTime.year &&
      DateTime.now().month == dateTime.month &&
      DateTime.now().day == dateTime.day;

  /// true nếu còn ≤ 7 ngày (và chưa tới/qua ngày thi) — Revision mode.
  bool get isRevisionPeriod {
    if (isExamDay || isExamDayOver) return false;
    final days = daysLeft;
    // Còn dưới 1 ngày nhưng chưa sang ngày thi vẫn tính revision.
    return days <= 7;
  }

  /// Giai đoạn hiện tại của kỳ thi — quyết định UX Home.
  ExamPhase get examPhase {
    if (isExamDayOver) return ExamPhase.postExam;
    if (isExamDay) return ExamPhase.examDay;
    if (isRevisionPeriod) return ExamPhase.revision;
    return ExamPhase.normal;
  }

  /// Kết quả dự kiến sau thi khi đã có điểm mục tiêu và điểm hiện tại.
  /// null khi chưa đủ dữ liệu để kết luận (chưa có target hoặc current).
  bool? get postExamResult {
    final target = targetScore;
    final actual = currentScore;
    if (target == null || actual == null) return null;
    return actual >= target;
  }

  /// Bản sao với điểm hiện tại khác (dùng trong kiểm thử/lưu điểm sau thi).
  ExamModel copyWithCurrent(double? currentScore) => ExamModel(
        id: id,
        name: name,
        dateTime: dateTime,
        type: type,
        description: description,
        emoji: emoji,
        currentScore: currentScore,
        targetScore: targetScore,
      );

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
    'currentScore': currentScore,
    'targetScore': targetScore,
  };

  factory ExamModel.fromJson(Map<String, dynamic> j) => ExamModel(
    id: j['id'],
    name: j['name'],
    dateTime: DateTime.parse(j['dateTime']),
    type: ExamType.values[j['type'] ?? 1],
    description: j['description'],
    emoji: j['emoji'] ?? '🎯',
    currentScore: (j['currentScore'] as num?)?.toDouble(),
    targetScore: (j['targetScore'] as num?)?.toDouble(),
  );

  String toJsonString() => jsonEncode(toJson());
  factory ExamModel.fromJsonString(String s) =>
      ExamModel.fromJson(jsonDecode(s));
}
