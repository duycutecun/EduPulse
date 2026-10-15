import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/storage_service.dart';

/// Nhật ký CỤC BỘ những lần người dùng thay đổi quyền chia sẻ / đồng ý
/// (đặc tả mục 8, dòng 213: "cần có màn xem trước và nhật ký thay đổi quyền
/// chia sẻ").
///
/// VÌ SAO Ở LOCAL: đây là lịch sử minh bạch cho chính người dùng thấy mình đã
/// bật/tắt chia sẻ gì, lúc nào — không phải dữ liệu gửi lên cloud. Chỉ ghi
/// HÀNH ĐỘNG (loại quyền + bật/tắt), KHÔNG ghi nội dung học tập hay số liệu.
///
/// Cùng khuôn với [ProductAnalytics]/[BetaFeedbackService]: danh sách JSON bị
/// giới hạn số mục để không phình bộ nhớ, kèm `revision` để UI lắng nghe.
class ShareAuditEntry {
  const ShareAuditEntry({
    required this.atMs,
    required this.kind,
    required this.action,
    this.detail,
  });

  final int atMs;
  final String kind;
  final String action;
  final String? detail;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  Map<String, dynamic> toJson() => {
        'at': atMs,
        'kind': kind,
        'action': action,
        if (detail != null) 'detail': detail,
      };

  static ShareAuditEntry? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final kind = (map['kind'] ?? '').toString();
      final action = (map['action'] ?? '').toString();
      if (kind.isEmpty || action.isEmpty) return null;
      final detailRaw = (map['detail'] as String?)?.trim();
      return ShareAuditEntry(
        atMs: (map['at'] as num?)?.toInt() ?? 0,
        kind: kind,
        action: action,
        detail: (detailRaw == null || detailRaw.isEmpty) ? null : detailRaw,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Các loại quyền chia sẻ/đồng ý được ghi nhật ký.
class ShareAuditKinds {
  ShareAuditKinds._();

  static const String analyticsConsent = 'analytics_consent';
  static const String familyLive = 'family_live';
  static const String familyNotify = 'family_notify';
  static const String familyReport = 'family_report';
  static const String familyNotifyPref = 'family_notify_pref';
  static const String parentMode = 'parent_mode';
  static const String aiRead = 'ai_permission_read';
  static const String aiAnalyze = 'ai_permission_analyze';
  static const String aiAutoImage = 'ai_auto_read_image';

  static const Map<String, String> _labels = {
    analyticsConsent: 'Số liệu cải thiện trải nghiệm',
    familyLive: 'Cập nhật trực tiếp cho gia đình',
    familyNotify: 'Thông báo khi con cập nhật',
    familyReport: 'Gửi báo cáo tuần cho gia đình',
    familyNotifyPref: 'Nhận thông báo cho một con',
    parentMode: 'Chế độ phụ huynh',
    aiRead: 'AI đọc nhiệm vụ và phiên học',
    aiAnalyze: 'AI phân tích tiến độ',
    aiAutoImage: 'AI tự đọc ảnh đề bài',
  };

  /// Nhãn tiếng Việt để hiển thị; nếu không biết thì trả về chính `kind`.
  static String labelOf(String kind) => _labels[kind] ?? kind;

  static bool isKnown(String kind) => _labels.containsKey(kind);
}

/// Nhật ký thay đổi quyền chia sẻ (local-only).
class ShareAuditLog {
  ShareAuditLog._();

  static const String storageKey = 'share_audit_log_v1';

  /// Giữ tối đa 200 mốc gần nhất — đủ để người dùng rà lại lịch sử.
  static const int maxEntries = 200;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Ghi một mốc thay đổi quyền. Bỏ qua nếu `kind`/`action` rỗng.
  static void log(String kind, String action, {String? detail}) {
    final k = kind.trim();
    final a = action.trim();
    if (k.isEmpty || a.isEmpty) return;

    final entry = ShareAuditEntry(
      atMs: DateTime.now().millisecondsSinceEpoch,
      kind: k,
      action: a,
      detail: (detail == null || detail.trim().isEmpty) ? null : detail.trim(),
    );

    final list = _read();
    list.add(jsonEncode(entry.toJson()));
    while (list.length > maxEntries) {
      list.removeAt(0);
    }
    _write(list);
    revision.value++;
  }

  /// Các mốc gần nhất, mới nhất trước.
  static List<ShareAuditEntry> recent() {
    final list = _read();
    final entries = <ShareAuditEntry>[];
    for (final raw in list.reversed) {
      final e = ShareAuditEntry.tryParse(raw);
      if (e != null) entries.add(e);
    }
    return entries;
  }

  static int get count => recent().length;

  static void clear() {
    StorageService.setStringList(storageKey, const []);
    revision.value++;
  }

  /// Xuất văn bản thuần để người dùng sao chép/chia sẻ.
  static String exportText() {
    final buffer = StringBuffer()
      ..writeln('Nhật ký thay đổi quyền chia sẻ — EduPulse');
    final entries = recent();
    if (entries.isEmpty) {
      buffer.writeln('(chưa có mục nào)');
      return buffer.toString();
    }
    for (final e in entries) {
      final t = e.at;
      final stamp = '${t.day.toString().padLeft(2, '0')}/'
          '${t.month.toString().padLeft(2, '0')}/${t.year} '
          '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
      final label = ShareAuditKinds.labelOf(e.kind);
      final detail = e.detail == null ? '' : ' (${e.detail})';
      buffer.writeln('$stamp — $label: ${e.action}$detail');
    }
    return buffer.toString();
  }

  static List<String> _read() => StorageService.getStringList(storageKey) ?? [];

  static void _write(List<String> list) =>
      StorageService.setStringList(storageKey, list);
}
