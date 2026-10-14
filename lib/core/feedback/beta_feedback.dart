import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/storage_service.dart';

/// Nhóm phản hồi beta (đặc tả mục 10 — "kênh feedback trong app").
///
/// Giữ ít nhóm để học sinh chọn nhanh, không phải phân vân phân loại.
enum BetaFeedbackCategory {
  bug('bug', 'Lỗi / hỏng'),
  idea('idea', 'Ý tưởng'),
  confusing('confusing', 'Khó hiểu'),
  other('other', 'Khác');

  const BetaFeedbackCategory(this.id, this.label);

  final String id;
  final String label;

  static BetaFeedbackCategory fromId(String? id) {
    for (final c in BetaFeedbackCategory.values) {
      if (c.id == id) return c;
    }
    return BetaFeedbackCategory.other;
  }
}

/// Một mẩu phản hồi beta, lưu **cục bộ** trên thiết bị.
///
/// Không tự gửi đi đâu: học sinh chủ động sao chép/chia sẻ nếu muốn. Tránh thu
/// thập dữ liệu học tập hay định danh ngoài những gì người dùng tự gõ.
@immutable
class BetaFeedbackEntry {
  final String id;
  final BetaFeedbackCategory category;
  final String message;
  final String contact;
  final DateTime at;

  const BetaFeedbackEntry({
    required this.id,
    required this.category,
    required this.message,
    this.contact = '',
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'c': category.id,
        'm': message,
        if (contact.isNotEmpty) 'k': contact,
        't': at.toIso8601String(),
      };

  static BetaFeedbackEntry? fromJsonString(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final message = '${j['m'] ?? ''}'.trim();
      if (message.isEmpty) return null;
      return BetaFeedbackEntry(
        id: '${j['id'] ?? ''}',
        category: BetaFeedbackCategory.fromId(j['c'] as String?),
        message: message,
        contact: '${j['k'] ?? ''}'.trim(),
        at: DateTime.tryParse('${j['t']}') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Kho phản hồi beta cục bộ (đặc tả mục 10).
///
/// Nguyên tắc giống [ProductAnalytics]: local-first, tối thiểu quyền riêng tư,
/// chỉ người dùng quyết định chia sẻ. Vòng đệm giới hạn để không phình prefs.
class BetaFeedbackService {
  BetaFeedbackService._();

  static final BetaFeedbackService instance = BetaFeedbackService._();

  static const String _key = 'beta_feedback';
  static const int _maxEntries = 100;
  static const int _maxMessage = 2000;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Lưu một phản hồi mới. Trả về `true` nếu phản hồi hợp lệ (nội dung không rỗng).
  bool submit(
    BetaFeedbackCategory category,
    String message, {
    String contact = '',
  }) {
    final text = message.trim();
    if (text.isEmpty) return false;

    final entry = BetaFeedbackEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: category,
      message:
          text.length > _maxMessage ? text.substring(0, _maxMessage) : text,
      contact: contact.trim(),
      at: DateTime.now(),
    );

    final list = _read();
    list.add(entry);
    while (list.length > _maxEntries) {
      list.removeAt(0);
    }
    _write(list);
    revision.value++;
    return true;
  }

  /// Các phản hồi đã lưu (cũ nhất ở đầu).
  List<BetaFeedbackEntry> recent() => _read();

  int get count => _read().length;

  void clear() {
    StorageService.setStringList(_key, const []);
    revision.value++;
  }

  /// Xuất toàn bộ phản hồi thành văn bản để người dùng tự sao chép/chia sẻ.
  String exportText() {
    final list = _read();
    if (list.isEmpty) return '';
    final buffer = StringBuffer('Phản hồi EduPulse (${list.length})\n');
    for (final e in list) {
      buffer
        ..writeln('---')
        ..writeln('[${e.category.label}] ${_formatDate(e.at)}');
      if (e.contact.isNotEmpty) buffer.writeln('Liên hệ: ${e.contact}');
      buffer.writeln(e.message);
    }
    return buffer.toString().trim();
  }

  List<BetaFeedbackEntry> _read() {
    final raw = StorageService.getStringList(_key) ?? const [];
    return raw
        .map(BetaFeedbackEntry.fromJsonString)
        .whereType<BetaFeedbackEntry>()
        .toList();
  }

  void _write(List<BetaFeedbackEntry> list) {
    StorageService.setStringList(
      _key,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}
