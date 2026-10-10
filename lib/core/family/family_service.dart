import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:realtime_client/realtime_client.dart';

import '../ai/weekly_report.dart';
import '../utils/auth_service.dart';
import '../utils/supabase_service.dart';
import 'family_models.dart';

/// Lỗi nghiệp vụ do SERVER trả về (vd "Mã mời đã được dùng rồi", "Không tạo
/// được mã mời.") — khác với `null` mà `_post` trả về khi mạng/đăng nhập.
class FamilyActionException implements Exception {
  const FamilyActionException(this.message);

  final String message;

  @override
  String toString() => 'FamilyActionException: $message';
}

/// Cầu nối tới `/api/family.js` — "Cửa sổ tin cậy" giữa học sinh và phụ huynh.
///
/// Vì sao đi qua API chứ không gọi thẳng Supabase: app đăng nhập bằng FIREBASE
/// còn RLS của Supabase so với `auth.uid()` (Supabase Auth), nên client không
/// đọc/ghi được gì. Server xác thực Firebase ID token rồi tự kiểm quyền —
/// xem `api/family.js`.
///
/// Quy tắc chung của service:
/// - Chưa đăng nhập ⇒ mọi thao tác trả về null/false kèm thông báo "cần đăng
///   nhập", không ném lỗi ra UI.
/// - Mất mạng ⇒ thao tác ĐỌC trả null (UI giữ dữ liệu cũ), thao tác GHI trả
///   false kèm thông báo thử lại — không bao giờ báo thành công giả.
class FamilyService {
  FamilyService._();

  /// Bản deploy cùng origin (web/PWA) hoặc host đang phục vụ app.
  static Uri _endpoint() => Uri.base.resolve('/api/family');

  static bool get isLoggedIn => AuthService.isLoggedIn;

  /// Ghi nhớ trạng thái gần nhất để UI mở ra là thấy ngay, không nháy trắng
  /// trong lúc chờ mạng (dữ liệu này không nhạy cảm: chỉ là tên + mốc liên kết
  /// của chính tài khoản đang đăng nhập).
  static FamilyState? _cachedState;

  static FamilyState? get cachedState => _cachedState;

  @visibleForTesting
  static void debugSetCache(FamilyState? state) => _cachedState = state;

  // ─── HỌC SINH ──────────────────────────────────────────────────────────────

  /// Tạo (hoặc thay) mã mời. Mã cũ mất hiệu lực ngay khi mã mới được tạo.
  ///
  /// Ném [FamilyActionException] kèm thông báo cụ thể khi server chối (thay vì
  /// gộp vào `null` như lỗi mạng) — để UI báo cho học sinh đúng lý do thay vì
  /// nói chung chung "kiểm tra mạng".
  static Future<FamilyInvite?> createInvite({String? studentName}) async {
    final body = await _post({
      'action': 'invite',
      if (studentName != null) 'studentName': studentName,
    });
    if (body == null) return null;
    if (body['ok'] != true) {
      throw FamilyActionException(
        '${body['error'] ?? 'Không tạo được mã mời.'}',
      );
    }
    return FamilyInvite.fromJson({
      'code': body['code'],
      'expiresAt': body['expiresAt'],
    });
  }

  /// Gửi báo cáo tuần cho gia đình.
  ///
  /// Trả về số phụ huynh đã nhận (0 = chưa ai liên kết, vẫn lưu lại để sau khi
  /// liên kết là ba mẹ đọc được ngay), hoặc null khi gửi thất bại.
  static Future<int?> shareReport(
    WeeklyReportData report, {
    String? studentName,
  }) async {
    final body = await _post({
      'action': 'share_report',
      'studentName': studentName,
      'payload': report.toJson(),
    });
    if (body == null || body['ok'] != true) return null;
    return (body['sentTo'] as num?)?.toInt() ?? 0;
  }

  /// Cập nhật "trạng thái trực tiếp" cho ba mẹ — bản mới nhất, không phải
  /// lịch sử. App của con tự gọi khi [LiveProgressService] thấy số liệu đổi.
  /// Trả về false khi chưa đăng nhập / mất mạng (lần sau đẩy lại).
  static Future<bool> publishLive(
    WeeklyReportData report, {
    String? studentName,
  }) async {
    final body = await _post({
      'action': 'share_live',
      'studentName': studentName,
      'payload': report.toJson(),
    });
    return body != null && body['ok'] == true;
  }

  /// Con TẮT cập nhật trực tiếp ⇒ xoá hẳn bản đang chia sẻ. Ba mẹ không còn
  /// thấy bản cũ sót lại — đây là phần "thu hồi" của giao kèo.
  static Future<bool> clearLive() async {
    final body = await _post({'action': 'share_live', 'enabled': false});
    return body != null && body['ok'] == true;
  }

  // ─── CẢ HAI VAI ────────────────────────────────────────────────────────────

  /// Đọc trạng thái gia đình của tài khoản đang đăng nhập.
  static Future<FamilyState?> fetchState() async {
    final body = await _post({'action': 'my_family'});
    if (body == null || body['ok'] != true) return null;
    final state = FamilyState.fromJson(body);
    _cachedState = state;
    // Server trả kèm kênh Realtime của tài khoản này — nghe để biết con vừa
    // cập nhật mà kéo ngay. Hỏng kênh thì chu kỳ hỏi định kỳ vẫn là nguồn đúng.
    _learnTopic(state.topic);
    return state;
  }

  /// Ngắt một liên kết (cả hai phía đều gọi được — server kiểm tra thành viên).
  static Future<FamilyActionResult> unlink(
    String linkId, {
    required bool asParent,
  }) async {
    final body = await _post({'action': 'unlink', 'linkId': linkId});
    if (body == null) {
      return const FamilyActionResult(
        ok: false,
        message: 'Không ngắt được lúc này — kiểm tra mạng rồi thử lại.',
      );
    }
    if (body['ok'] != true) {
      return FamilyActionResult(
        ok: false,
        message: '${body['error'] ?? 'Không ngắt được liên kết.'}',
      );
    }
    await fetchState();
    return FamilyActionResult(
      ok: true,
      message: asParent
          ? 'Đã ngắt liên kết. Bạn sẽ không nhận báo cáo mới của con.'
          : 'Đã ngắt liên kết. Ba mẹ không xem được báo cáo nữa.',
    );
  }

  // ─── PHỤ HUYNH ─────────────────────────────────────────────────────────────

  /// Nhập mã mời để liên kết với tài khoản của con.
  static Future<FamilyActionResult> redeem(
    String code, {
    String? parentName,
  }) async {
    final clean = code.trim();
    if (clean.length != 8) {
      return const FamilyActionResult(
        ok: false,
        message: 'Mã mời gồm 8 chữ số — nhập lại giúp mình nhé.',
      );
    }
    final body = await _post({
      'action': 'redeem',
      'code': clean,
      if (parentName != null) 'parentName': parentName,
    });
    if (body == null) {
      return const FamilyActionResult(
        ok: false,
        message: 'Không liên kết được lúc này — kiểm tra mạng rồi thử lại.',
      );
    }
    if (body['ok'] != true) {
      return FamilyActionResult(
        ok: false,
        message: '${body['error'] ?? 'Mã mời không đúng.'}',
      );
    }
    await fetchState();
    final name = '${body['studentName'] ?? ''}'.trim();
    return FamilyActionResult(
      ok: true,
      studentName: name.isEmpty ? null : name,
      message: body['alreadyLinked'] == true
          ? 'Tài khoản này đã liên kết rồi.'
          : 'Đã liên kết${name.isEmpty ? '' : ' với $name'} 💚',
    );
  }

  /// Test có thể thay nguồn này để dựng màn ba mẹ mà không cần mạng.
  @visibleForTesting
  static Future<ChildProgress?> Function(String studentUserId, int since)?
      debugProgressFetcher;

  /// Đọc tiến độ của con: trạng thái trực tiếp (nếu con bật) + báo cáo tuần.
  ///
  /// [since] (epoch ms) > 0 ⇒ chỉ lấy phần MỚI hơn mốc đó (vòng hỏi định kỳ và
  /// tín hiệu Realtime không cần tải lại cả trang). Trả về null khi lỗi mạng;
  /// [ChildProgress] rỗng khi con chưa chia sẻ gì.
  static Future<ChildProgress?> fetchChildProgress(
    String studentUserId, {
    int since = 0,
  }) async {
    final hook = debugProgressFetcher;
    if (hook != null) return hook(studentUserId, since);

    final body = await _post({
      'action': 'child_reports',
      'studentUserId': studentUserId,
      if (since > 0) 'since': since,
    });
    if (body == null || body['ok'] != true) return null;
    return ChildProgress.fromJson(body);
  }

  // ─── REALTIME: "con vừa cập nhật" ──────────────────────────────────────────

  /// Báo có tín hiệu mới. Màn ba mẹ lắng nghe rồi kéo lại ngay thay vì chờ
  /// hết chu kỳ hỏi định kỳ. Giá trị = mốc thời gian server báo.
  static final ValueNotifier<int> liveSignal = ValueNotifier<int>(0);

  static RealtimeChannel? _channel;
  static String? _topic;
  static bool _subscribed = false;
  static int _signalAt = 0;

  /// Đang nghe kênh Realtime? (Chỉ để hiển thị/log — mọi thứ vẫn chạy nếu không.)
  static bool get isLive => _subscribed;

  /// Tín hiệu `at` này có mới hơn cái đã biết không?
  ///
  /// Bỏ qua tín hiệu trùng/cũ: cùng một lần cập nhật có thể bắn cho nhiều máy,
  /// và tín hiệu đến muộn không được kéo thêm một lần vô ích.
  @visibleForTesting
  static bool shouldPullOnSignal(int at) => at > _signalAt;

  /// Nhận kênh Realtime của mình rồi bắt đầu nghe.
  ///
  /// Kênh do server sinh từ hash(uid + service_role_key) nên không đoán được;
  /// đổi tài khoản là đổi kênh và phải bỏ kênh cũ, nếu không máy này còn nghe
  /// kênh của tài khoản trước.
  static void _learnTopic(String? topic) {
    if (topic == null || topic.isEmpty) return;
    if (topic != _topic) {
      _stopChannel();
      _topic = topic;
      _signalAt = 0;
    }
    _startChannel();
  }

  /// **Có thể thất bại mà không sao** — đây chỉ là đường tắt cho độ trễ; màn
  /// ba mẹ vẫn hỏi định kỳ nên không mất gì, chỉ chậm hơn vài chục giây.
  static void _startChannel() {
    final topic = _topic;
    final client = SupabaseService.client;
    if (topic == null || topic.isEmpty || client == null || _subscribed) return;
    try {
      _channel = client.realtime
          .channel(topic)
          .onBroadcast(
            event: 'family',
            callback: (payload) {
              final at =
                  ((payload['payload']?['at'] ?? payload['at'] ?? 0) as num)
                      .toInt();
              if (at > 0 && !shouldPullOnSignal(at)) return;
              if (at > 0) _signalAt = at;
              liveSignal.value = at > 0 ? at : DateTime.now().millisecondsSinceEpoch;
            },
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              _subscribed = true;
            } else if (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.timedOut) {
              // Đường tắt hỏng — hỏi định kỳ lo phần còn lại. Không tự hẹn thử
              // lại: sẽ thành vòng lặp vô tận khi mạng tắt.
              _subscribed = false;
              debugPrint('[FamilyService] Realtime ngắt ($status) — dùng poll.');
            }
            if (error != null) {
              debugPrint('[FamilyService] Realtime lỗi: $error');
            }
          });
    } catch (e) {
      _subscribed = false;
      debugPrint('[FamilyService] Không bật được Realtime: $e');
    }
  }

  static void _stopChannel() {
    final channel = _channel;
    _channel = null;
    _subscribed = false;
    if (channel == null) return;
    try {
      SupabaseService.client?.removeChannel(channel);
    } catch (_) {
      // Dọn dẹp là việc tốt-nhất; giữ kênh cũ cũng không hại.
    }
  }

  /// Ngắt kênh Realtime (dọn khi đăng xuất).
  static void stopLive() {
    _stopChannel();
    _topic = null;
    _signalAt = 0;
  }

  // ─── GỌI API ───────────────────────────────────────────────────────────────

  /// POST một hành động lên `/api/family`. Trả null khi chưa đăng nhập, mất
  /// mạng, hoặc phản hồi không đọc được — người gọi phân biệt null với
  /// `{ok:false}` (lỗi nghiệp vụ có thông báo cụ thể từ server).
  static Future<Map<String, dynamic>?> _post(
      Map<String, dynamic> body) async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    String? token;
    try {
      token = await user.getIdToken();
    } catch (_) {
      return null;
    }
    if (token == null || token.isEmpty) return null;

    try {
      final resp = await http
          .post(
            _endpoint(),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'idToken': token, ...body}),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      debugPrint('[FamilyService] Phản hồi lạ: ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('[FamilyService] Lỗi kết nối: $e');
      return null;
    }
  }
}
