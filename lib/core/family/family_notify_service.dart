import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../notifications/notification_service.dart';
import '../utils/storage_service.dart';
import 'family_models.dart';

/// Báo cho ba mẹ khi con vừa cập nhật tiến độ.
///
/// Đây là thông báo **cục bộ**: app của ba mẹ tự bắn ra khi nhận được tín hiệu
/// Realtime (hoặc khi tới nhịp hỏi định kỳ) — không cần server đẩy, không thêm
/// dữ liệu nào lên cloud, và nội dung thông báo cũng chỉ là \"con vừa chia sẻ\",
/// không kèm số liệu học tập.
///
/// Đổi lại, nó chỉ nổ khi app ba mẹ **còn sống** (đang mở hoặc vừa xuống nền).
/// Muốn báo cả khi app đã bị tắt hẳn thì phải có FCM (cần service account —
/// hiện bị org policy chặn), nên chưa làm.
///
/// Chống trùng: mỗi con chỉ báo MỘT lần cho mỗi mốc cập nhật mới, và **lần đầu
/// tiên thấy một con thì chỉ ghi nhớ** — mở app lên không bị dội một tràng
/// thông báo cho những gì đã xảy ra từ lâu.
class FamilyNotifyService {
  FamilyNotifyService._();

  /// Công tắc của ba mẹ (mặc định tắt — không tự xin quyền thông báo).
  static const String enabledKey = 'family_notify_enabled';

  /// Mốc đã báo gần nhất của từng con: `{userId: epochMillis}`.
  static const String seenKey = 'family_notify_seen';

  /// Test thay được để quan sát thông báo mà không cần plugin nền tảng.
  @visibleForTesting
  static Future<bool> Function({required String title, required String body})?
      debugShow;

  static bool get enabled => StorageService.getBool(enabledKey) ?? false;

  /// Bật/tắt. Bật thì XIN QUYỀN đúng lúc này (iOS: bị từ chối một lần là không
  /// hỏi lại được, nên chỉ hỏi khi người dùng thật sự muốn).
  ///
  /// Trả về false khi máy chặn rõ ràng hoặc nền tảng không hỗ trợ thông báo.
  static Future<bool> setEnabled(bool value) async {
    if (!value) {
      StorageService.setBool(enabledKey, false);
      return true;
    }
    if (!NotificationService.isSupported) return false;
    final granted = await NotificationService.requestPermission();
    // Android < 13 không có quyền runtime ⇒ plugin trả null, coi như được phép.
    final ok = granted != false;
    StorageService.setBool(enabledKey, ok);
    return ok;
  }

  /// Đọc trạng thái gia đình vừa lấy về, báo cho ba mẹ những mốc MỚI.
  ///
  /// Gọi ở MỌI lần đọc trạng thái (tín hiệu Realtime lẫn nhịp hỏi định kỳ) —
  /// nhờ vậy thông báo không phụ thuộc việc tín hiệu có tới hay không.
  static Future<void> handleState(FamilyState state) async {
    if (!enabled || state.children.isEmpty) return;

    final raw = StorageService.getString(seenKey);
    final firstRun = raw == null || raw.isEmpty;
    final seen = _decode(raw);

    var changed = false;
    for (final child in state.children) {
      final live = child.liveAt?.millisecondsSinceEpoch ?? 0;
      final report = child.latestReportAt?.millisecondsSinceEpoch ?? 0;
      final latest = live > report ? live : report;
      if (latest <= 0) continue;

      final known = seen[child.userId] ?? 0;
      if (latest <= known) continue;

      seen[child.userId] = latest;
      changed = true;
      // Lần đầu thấy con: ghi nhớ rồi thôi, không thông báo.
      if (firstRun) continue;
      await _notify(child, isLive: live >= report);
    }

    if (changed) StorageService.setString(seenKey, jsonEncode(seen));
  }

  static Future<void> _notify(FamilyMember child, {required bool isLive}) async {
    final show = debugShow ?? NotificationService.showNow;
    try {
      await show(
        title: 'Con vừa cập nhật tiến độ',
        body: isLive
            ? '${child.name} vừa chia sẻ cập nhật mới — mở Cửa sổ tin cậy để xem.'
            : '${child.name} vừa gửi báo cáo tuần mới.',
      );
    } catch (_) {
      // Thông báo là việc tốt-nhất: hỏng thì màn ba mẹ vẫn tự cập nhật.
    }
  }

  static Map<String, int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    } catch (_) {
      return {};
    }
  }
}
