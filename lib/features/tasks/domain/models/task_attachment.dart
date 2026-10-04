/// Tài liệu đính kèm của một nhiệm vụ (FE-2.2).
///
/// **Giới hạn thật, không giả vờ:** `shared_preferences` không phải kho
/// tệp. Một ảnh vượt [maxBytes] sẽ làm toàn bộ prefs nặng lên và ghi đè
/// chậm dần trên Android. Vì vậy app chỉ nhận ảnh tĩnh ≤ 250KB — cùng hạn
/// mức mà màn Ghi chú đang áp dụng — và nói rõ với người dùng khi vượt.
///
/// Quét tài liệu / đính kèm nhiều tệp cần OCR và kho tệp thật, đã được
/// loại khỏi phạm vi có chủ ý (CHECKLIST mục 14) thay vì làm vỏ rồi gọi
/// là xong.
library;

class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.base64,
    required this.addedAt,
  });

  final String id;
  final String name;
  final int sizeBytes;

  /// Dữ liệu ảnh đã mã hoá base64 (không có tiền tố `data:`).
  final String base64;
  final DateTime addedAt;

  /// Hạn mức một tệp đính kèm.
  static const int maxBytes = 250 * 1024;

  /// Số tệp tối đa cho một nhiệm vụ — giữ prefs ở mức an toàn.
  static const int maxCount = 3;

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Tài liệu').toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      base64: (json['base64'] ?? '').toString(),
      addedAt: DateTime.tryParse((json['addedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeBytes': sizeBytes,
        'base64': base64,
        'addedAt': addedAt.toIso8601String(),
      };

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = (sizeBytes / 1024).toStringAsFixed(0);
    return '$kb KB';
  }
}
