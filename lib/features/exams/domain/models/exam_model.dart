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

  /// Điểm mục tiêu theo từng môn — đặc tả 5.13 (`Toán 9.0 / Lý 9.0 / Hóa 9.0`)
  /// và BE-5.2 (`Support: subjects, target`).
  ///
  /// Khoá là tên môn đã chuẩn hoá qua [AppSubjects.normalize] khi ghi; đọc thì
  /// chấp nhận cả khoá thô để dữ liệu cũ không bị mất.
  final Map<String, double> subjectTargets;

  /// Danh sách môn của kỳ thi (đặc tả 5.13) — suy ra từ [subjectTargets] và
  /// các task đã gắn kỳ thi này, nên không cần thêm một trường phải nhập tay.
  final List<String> subjects;

  /// Lúc sửa lần cuối — dùng để **phát hiện xung đột** giữa máy này và cloud.
  ///
  /// Cố ý NULLABLE: dữ liệu tạo trước khi có trường này không có mốc thời
  /// gian. `null` được hiểu là “không rõ” — xem [ExamRepository.mergeFromCloud]
  /// để biết quy tắc xử lý, không đoán bừa.
  final DateTime? updatedAt;

  ExamModel({
    required this.id,
    required this.name,
    required this.dateTime,
    this.type = ExamType.preset,
    this.description,
    this.emoji = '🎯',
    this.currentScore,
    this.targetScore,
    Map<String, double> subjectTargets = const {},
    List<String>? subjects,
    this.updatedAt,
  })  : subjectTargets = subjectTargets,
        // Không bắt học sinh khai báo môn hai lần: đặt mục tiêu cho môn nào
        // là môn đó có mặt trong kỳ thi (đặc tả 5.13).
        subjects = subjects == null || subjects.isEmpty
            ? subjectTargets.keys.toList()
            : subjects;

  Duration get remaining => remainingAt(DateTime.now());
  bool get isPast => isPastAt(DateTime.now());

  int get daysLeft => daysLeftAt(DateTime.now());

  // ─── Realtime (BE-5.2) ────────────────────────────────────────────────────
  //
  // Các getter trên đọc `DateTime.now()` trực tiếp — tiện cho UI nhưng không
  // kiểm thử được việc đếm ngược "theo thời gian thực". Bộ hàm `...At(now)`
  // dưới đây tách mốc thời gian ra tham số để test chuyển giao ngày thi chính
  // xác, và để widget đếm ngược tự truyền mốc của nó.

  Duration remainingAt(DateTime now) => dateTime.difference(now);

  bool isPastAt(DateTime now) => dateTime.isBefore(now);

  /// Số ngày còn lại tính tại [now].
  int daysLeftAt(DateTime now) => remainingAt(now).inDays;

  /// true nếu đã qua 23:59:59 ngày thi tính tại [now].
  bool isExamDayOverAt(DateTime now) {
    final endOfDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);
    return now.isAfter(endOfDay);
  }

  /// true nếu [now] là ngày thi.
  bool isExamDayAt(DateTime now) =>
      !isExamDayOverAt(now) &&
      now.year == dateTime.year &&
      now.month == dateTime.month &&
      now.day == dateTime.day;

  /// Giai đoạn tại [now] — bản thuần của [examPhase].
  ExamPhase phaseAt(DateTime now) {
    if (isExamDayOverAt(now)) return ExamPhase.postExam;
    if (isExamDayAt(now)) return ExamPhase.examDay;
    final days = daysLeftAt(now);
    if (days <= 7) return ExamPhase.revision;
    return ExamPhase.normal;
  }

  /// true nếu đã qua thời điểm kết thúc của ngày thi (23:59:59 ngày thi).
  bool get isExamDayOver {
    final endOfDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);
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
        subjectTargets: subjectTargets,
        subjects: subjects,
      );

  /// Bản sao với điểm mục tiêu tổng / theo môn khác (dùng khi sửa kỳ thi).
  ExamModel copyWith({
    double? targetScore,
    Map<String, double>? subjectTargets,
  }) =>
      ExamModel(
        id: id,
        name: name,
        dateTime: dateTime,
        type: type,
        description: description,
        emoji: emoji,
        currentScore: currentScore,
        targetScore: targetScore ?? this.targetScore,
        subjectTargets: subjectTargets ?? this.subjectTargets,
        subjects: subjects,
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
        'subjectTargets': subjectTargets,
        'subjects': subjects,
        'updatedAt': updatedAt?.toIso8601String(),
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
        subjectTargets: ((j['subjectTargets'] as Map?) ?? {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
        subjects: ((j['subjects'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.tryParse(j['updatedAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  /// Bản sao có mốc sửa mới — repository dùng khi lưu để đóng dấu “phiên bản
  /// này thuộc máy này”. `copyWith` chung không cần: trường duy nhất cần đổi
  /// là `updatedAt`, gói riêng cho rõ ý nghĩa.
  ExamModel copyWithUpdatedAt(DateTime at) => ExamModel(
        id: id,
        name: name,
        dateTime: dateTime,
        type: type,
        description: description,
        emoji: emoji,
        currentScore: currentScore,
        targetScore: targetScore,
        subjectTargets: subjectTargets,
        subjects: subjects,
        updatedAt: at,
      );
  factory ExamModel.fromJsonString(String s) =>
      ExamModel.fromJson(jsonDecode(s));
}
