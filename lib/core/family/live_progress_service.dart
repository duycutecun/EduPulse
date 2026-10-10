import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ai/weekly_report.dart';
import '../pwa/pwa_service.dart';
import '../utils/auth_service.dart';
import '../utils/storage_service.dart';
import 'family_service.dart';

/// "Cập nhật trực tiếp": giữ bản tiến độ mới nhất của học sinh cho ba mẹ.
///
/// VẤN ĐỀ: báo cáo tuần chỉ lên cloud khi con tự bấm "Gửi cho gia đình", nên
/// ba mẹ mở app thấy số liệu cũ mấy ngày dù con vẫn học đều.
///
/// CÁCH LÀM: con BẬT công tắc ⇒ app tự dựng lại báo cáo theo đúng những mục con
/// đã chọn chia sẻ, và đẩy lên khi nội dung THẬT SỰ đổi (so "vân tay" nội dung,
/// bỏ qua mốc thời gian nên không đẩy trùng). Không có gì để đẩy mới thôi.
///
/// GIAO KÈO VẪN NGUYÊN:
/// - Mặc định TẮT. Con bật thì mới có chuyện gì để ba mẹ theo dõi.
/// - Chỉ những mục con bật trong "Cửa sổ tin cậy" vào payload; tắt hết mục
///   thì không đẩy gì cả.
/// - Con tắt công tắc ⇒ xoá hẳn bản trực tiếp, ba mẹ hết thấy ngay.
/// - Chỉ chạy khi con ĐÃ đăng nhập và ĐÃ liên kết với ít nhất một phụ huynh.
///
/// HỎNG THÌ IM LẶNG: mất mạng hay đẩy lỗi chỉ là bỏ lỡ một nhịp — lần kiểm tra
/// sau tự đẩy lại (vân tay chỉ được ghi khi server đã nhận).
class LiveProgressService {
  LiveProgressService._();

  /// Công tắc của học sinh (mặc định tắt — không tự ý theo dõi ai).
  static const String _enabledKey = 'family_live_share';

  /// Vân tay nội dung lần cuối ĐÃ đẩy thành công, để không gửi lại y hệt.
  static const String _fingerprintKey = 'family_live_fingerprint';

  /// Nhịp kiểm tra. 30 giây là đủ "gần như tức thì" cho ba mẹ mà vẫn nhẹ
  /// mạng: mỗi nhịp chỉ dựng báo cáo từ dữ liệu local và gửi khi có đổi.
  static const Duration checkInterval = Duration(seconds: 30);

  static Timer? _timer;
  static StreamSubscription<Object?>? _authSubscription;
  static bool _inFlight = false;

  /// Con đang bật cập nhật trực tiếp?
  static bool get enabled => StorageService.getBool(_enabledKey) ?? false;

  /// Chạy nền (timer đã bật). Không phụ thuộc đăng nhập — đăng nhập sau vẫn kịp.
  static bool get isRunning => _timer != null;

  /// Bắt đầu kiểm tra định kỳ. Gọi một lần sau khi khởi động app.
  ///
  /// An toàn khi gọi lại nhiều lần: timer cũ bị huỷ trước.
  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(checkInterval, (_) => unawaited(checkNow()));
    // Vừa đăng nhập xong ⇒ cập nhật ngay, không bắt ba mẹ chờ hết nhịp.
    _authSubscription ??= AuthService.authStateChanges?.listen((_) {
      unawaited(checkNow(force: true));
    });
    unawaited(checkNow());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _authSubscription?.cancel();
    _authSubscription = null;
  }

  /// Bật/tắt công tắc. Trả về true khi trạng thái mong muốn đã lên tới server.
  ///
  /// Tắt: xoá bản trực tiếp (con thu hồi ngay cả phần đã chia sẻ). Bật: đẩy
  /// ngay một bản để ba mẹ thấy tức thì, rồi các nhịp sau tự cập nhật.
  static Future<bool> setEnabled(bool value) async {
    StorageService.setBool(_enabledKey, value);
    if (!value) {
      // Quên vân tay đi: bật lại phải đẩy một bản mới, không được coi là "đã gửi".
      StorageService.removeString(_fingerprintKey);
      if (!AuthService.isLoggedIn) return true;
      return FamilyService.clearLive();
    }
    return checkNow(force: true);
  }

  /// Dựng báo cáo hiện tại (đúng những mục con chọn) rồi đẩy nếu nội dung đổi.
  ///
  /// Trả về true khi không còn gì phải đẩy (đã đồng bộ hoặc không có gì để
  /// chia sẻ) — false khi chưa lên được cloud, lần sau sẽ thử lại.
  static Future<bool> checkNow({bool force = false}) async {
    if (_inFlight) return true;
    if (!enabled || !AuthService.isLoggedIn) return true;
    if (!PwaService.isOnline) return false;

    // Chưa biết gia đình thì hỏi một lần; chưa liên kết ai thì chưa cần đẩy.
    var state = FamilyService.cachedState;
    state ??= await FamilyService.fetchState();
    if (state == null) return false;
    if (!state.hasLinkedParents) return true;

    final choices =
        WeeklyReport.savedChoices() ?? WeeklyReport.defaultChoices;
    final report = WeeklyReport.build(enabled: choices);
    if (report == null) return true; // con tắt hết mục — không có gì để chia sẻ

    final fingerprint = fingerprintOf(report);
    if (!force && fingerprint == StorageService.getString(_fingerprintKey)) {
      return true;
    }

    _inFlight = true;
    try {
      final ok = await FamilyService.publishLive(
        report,
        studentName: StorageService.getUserName(),
      );
      // Chỉ ghi vân tay khi server đã nhận: đẩy lỗi thì nhịp sau gửi lại.
      if (ok) StorageService.setString(_fingerprintKey, fingerprint);
      return ok;
    } finally {
      _inFlight = false;
    }
  }

  /// Vân tay NỘI DUNG của báo cáo (bỏ `generatedAt`/mốc tuần).
  ///
  /// Báo cáo dựng lại lúc nào cũng có `generatedAt` mới, nên so cả JSON sẽ
  /// đẩy lại vô ích mỗi 30 giây. Chỉ khi câu chữ hay con số đổi mới đáng gửi.
  @visibleForTesting
  static String fingerprintOf(WeeklyReportData report) {
    final buffer = StringBuffer(report.headline);
    for (final item in report.items) {
      buffer
        ..write('|')
        ..write(item.key)
        ..write(':')
        ..write(item.title)
        ..write('=')
        ..write(item.value);
      if (item.detail != null) buffer..write('~')..write(item.detail);
    }
    return buffer.toString();
  }
}
