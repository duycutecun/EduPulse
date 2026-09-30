import 'dart:convert';
import '../utils/storage_service.dart';

/// Phản hồi của người dùng về một câu trả lời AI (đặc tả mục 10.10).
///
/// Nguyên tắc: feedback là **dữ liệu của người dùng** — lưu local-first,
/// chỉ dùng để cải thiện đề xuất sau này, không tự gửi đi đâu cả.
class AiFeedback {
  final String messageId;

  /// 'up' | 'down'
  final String kind;

  /// Lý do khi 👎 — một trong các giá trị spec: sai_kien_thuc,
  /// khong_hieu_cau_hoi, giai_thich_kho_hieu, nguon_khong_dang_tin,
  /// qua_dai, qua_ngan, khac. Null khi 👍 hoặc không chọn.
  final String? reason;

  /// Thời điểm phản hồi.
  final DateTime createdAt;

  const AiFeedback({
    required this.messageId,
    required this.kind,
    this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'kind': kind,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AiFeedback.fromJson(Map<String, dynamic> j) => AiFeedback(
        messageId: j['messageId'] ?? '',
        kind: j['kind'] ?? 'up',
        reason: j['reason'],
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );

  String toJsonString() => jsonEncode(toJson());
  factory AiFeedback.fromJsonString(String s) =>
      AiFeedback.fromJson(jsonDecode(s));
}

/// Nhãn tiếng Việt hiển thị cho các lý do 👎 (đặc tả mục 10.10).
const List<(String, String)> kAiFeedbackReasons = [
  ('sai_kien_thuc', 'Sai kiến thức'),
  ('khong_hieu_cau_hoi', 'Không hiểu câu hỏi'),
  ('giai_thich_kho_hieu', 'Giải thích khó hiểu'),
  ('nguon_khong_dang_tin', 'Nguồn không đáng tin'),
  ('qua_dai', 'Quá dài'),
  ('qua_ngan', 'Quá ngắn'),
  ('khac', 'Khác'),
];

/// Store feedback local — pattern JSON per-id như StorageService,
/// nhưng tách riêng để đỡ phình StorageService.
class AiFeedbackStore {
  static const String _idsKey = 'ai_feedback_ids';

  static List<String> _ids() =>
      StorageService.prefs.getStringList(_idsKey) ?? [];

  /// Lưu feedback (ghi đè nếu đã có cho cùng message).
  static void put(AiFeedback feedback) {
    StorageService.setString('ai_feedback_${feedback.messageId}',
        feedback.toJsonString());
    final ids = _ids();
    if (!ids.contains(feedback.messageId)) {
      StorageService.prefs.setStringList(_idsKey,
          [...ids, feedback.messageId]);
    }
  }

  static AiFeedback? get(String messageId) {
    final json =
        StorageService.getString('ai_feedback_$messageId');
    if (json == null) return null;
    try {
      return AiFeedback.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  /// Danh sách feedback của các câu trả lời AI bị 👎 — đầu vào cho
  /// việc điều chỉnh prompt/deckug sau này.
  static List<AiFeedback> allDownvotes() {
    final out = <AiFeedback>[];
    for (final id in _ids()) {
      final f = get(id);
      if (f != null && f.kind == 'down') out.add(f);
    }
    return out;
  }
}
