import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/storage_service.dart';
import '../privacy/share_audit_log.dart';
import 'product_events.dart';

/// Một sự kiện sản phẩm đã ẩn danh (không PII, không nội dung học tập).
@immutable
class ProductEvent {
  final String name;
  final DateTime at;
  final Map<String, String> props;

  const ProductEvent({
    required this.name,
    required this.at,
    this.props = const {},
  });

  Map<String, dynamic> toJson() => {
        'n': name,
        't': at.toIso8601String(),
        if (props.isNotEmpty) 'p': props,
      };

  static ProductEvent? fromJsonString(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final props = <String, String>{};
      final p = j['p'];
      if (p is Map) {
        p.forEach((k, v) => props['$k'] = '$v');
      }
      return ProductEvent(
        name: j['n'] as String,
        at: DateTime.tryParse('${j['t']}') ?? DateTime.now(),
        props: props,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Bộ ghi sự kiện sản phẩm **cục bộ, tối thiểu quyền riêng tư** (đặc tả mục 9).
///
/// Nguyên tắc:
/// - **Opt-in**: chỉ ghi khi người dùng đã đồng ý (`analytics_consent`), mặc
///   định tắt. Không tự bật.
/// - **Ẩn danh**: chỉ tên sự kiện + thời điểm + vài thuộc tính đã cho phép;
///   không có nội dung học tập, không định danh thiết bị/người dùng.
/// - **Local-only**: ghi vào SharedPreferences (vòng đệm giới hạn); không tự
///   gửi đi đâu. Việc đẩy lên backend (nếu có) phải là lát cắt riêng có consent
///   và đã pseudonym hoá.
class ProductAnalytics {
  ProductAnalytics._();

  static final ProductAnalytics instance = ProductAnalytics._();

  static const String consentKey = 'analytics_consent';
  static const String _bufferKey = 'product_events';
  static const int _maxBuffer = 200;

  /// Chỉ các thuộc tính phi-nội-dung này được phép lưu.
  static const Set<String> _allowedPropKeys = {
    'count',
    'minutes',
    'source',
    'result',
    'reason',
    'kind',
  };

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get enabled => StorageService.getBool('analytics_consent') ?? false;

  void setEnabled(bool value) {
    StorageService.setBool('analytics_consent', value);
    if (!value) clear();
    ShareAuditLog.log(
      ShareAuditKinds.analyticsConsent,
      value ? 'bật' : 'tắt',
    );
    revision.value++;
  }

  /// Ghi một sự kiện. Không làm gì nếu chưa đồng ý hoặc tên không hợp lệ.
  void track(String event, {Map<String, String>? props}) {
    if (!enabled) return;
    if (!ProductEvents.all.contains(event)) return;

    final safe = <String, String>{};
    props?.forEach((k, v) {
      if (!_allowedPropKeys.contains(k)) return;
      final s = v.trim();
      if (s.isEmpty) return;
      safe[k] = s.length > 40 ? s.substring(0, 40) : s;
    });

    final e = ProductEvent(name: event, at: DateTime.now(), props: safe);
    final list = _read();
    list.add(e);
    // Vòng đệm giới hạn — bỏ sự kiện cũ nhất, giữ bộ nhớ nhỏ.
    while (list.length > _maxBuffer) {
      list.removeAt(0);
    }
    _write(list);
    revision.value++;
  }

  /// Các sự kiện gần đây (mới nhất ở cuối).
  List<ProductEvent> recent() => _read();

  void clear() {
    StorageService.setStringList(_bufferKey, const []);
    revision.value++;
  }

  List<ProductEvent> _read() {
    final raw = StorageService.getStringList(_bufferKey) ?? const [];
    return raw
        .map(ProductEvent.fromJsonString)
        .whereType<ProductEvent>()
        .toList();
  }

  void _write(List<ProductEvent> list) {
    StorageService.setStringList(
      _bufferKey,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
