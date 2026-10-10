import 'dart:convert';

import '../ai/weekly_report.dart';

/// Mã mời mà HỌC SINH đọc cho ba mẹ nhập để liên kết tài khoản.
class FamilyInvite {
  const FamilyInvite({required this.code, this.expiresAt});

  /// 8 chữ số, chỉ có MỘT mã hiệu lực tại một thời điểm.
  final String code;

  /// Hết hạn thì mã không dùng được nữa (server cũng chặn, không chỉ UI).
  final DateTime? expiresAt;

  /// Mã còn dùng được không (chưa hết hạn).
  bool isUsableAt(DateTime now) =>
      expiresAt == null || expiresAt!.isAfter(now);

  static FamilyInvite? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final code = '${raw['code'] ?? ''}'.trim();
    if (code.isEmpty) return null;
    final expires = (raw['expiresAt'] as num?)?.toInt();
    return FamilyInvite(
      code: code,
      expiresAt: expires == null || expires <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expires),
    );
  }
}

/// Một người trong gia đình: ở phía học sinh là ba/mẹ, ở phía phụ huynh là con.
class FamilyMember {
  const FamilyMember({
    required this.linkId,
    required this.userId,
    required this.name,
    this.linkedAt,
    this.latestReportAt,
    this.liveAt,
    this.parentLabel,
    this.notifyOn = true,
    this.liveSummary = const {},
    this.liveCheckin,
  });

  /// Id liên kết — cần để ngắt liên kết.
  final String linkId;
  final String userId;
  final String name;
  final DateTime? linkedAt;

  /// Báo cáo gần nhất con đã gửi (chỉ có ở phía phụ huynh; null = chưa gửi
  /// bao giờ). Dùng để nói đúng "con chưa gửi báo cáo" thay vì hiện bảng rỗng.
  final DateTime? latestReportAt;

  /// Mốc con cập nhật "trạng thái trực tiếp" gần nhất (chỉ có ở phía phụ
  /// huynh). Null = con chưa có bản trực tiếp nào.
  final DateTime? liveAt;

  /// Tên riêng ba mẹ đặt cho con (chỉ có ở phía phụ huynh). Null = chưa đặt,
  /// dùng tên thật. Khi có, server đã trả về [name] là nhãn này.
  final String? parentLabel;

  /// Ba mẹ có muốn nhận thông báo khi con cập nhật? (mặc định có).
  final bool notifyOn;

  /// Vài con số nhanh từ bản trực tiếp (chỉ có ở phía phụ huynh): key → giá trị
  /// đã format sẵn (ví dụ `mock_score`: "Toán: 8.5/10"). Rỗng khi chưa có.
  final Map<String, String> liveSummary;

  /// Lời nhắn gần nhất con gửi kèm (chỉ có ở phía phụ huynh). Null = không có.
  final String? liveCheckin;

  bool get hasReport => latestReportAt != null;

  /// Con đang có bản cập nhật trực tiếp để xem.
  bool get isLive => liveAt != null;

  static FamilyMember? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final linkId = '${raw['linkId'] ?? ''}'.trim();
    final userId = '${raw['userId'] ?? ''}'.trim();
    if (linkId.isEmpty || userId.isEmpty) return null;
    int? millis(Object? v) {
      final n = (v as num?)?.toInt() ?? 0;
      return n > 0 ? n : null;
    }

    Map<String, String> readSummary(Object? v) {
      if (v is! Map) return const {};
      final out = <String, String>{};
      v.forEach((key, value) {
        if (value == null) return;
        final s = '$value'.trim();
        if (s.isNotEmpty) out['$key'] = s;
      });
      return out;
    }

    final linkedAt = millis(raw['linkedAt']);
    final latest = millis(raw['latestReportAt']);
    final live = millis(raw['liveAt']);
    final label = '${raw['parentLabel'] ?? ''}'.trim();
    final rawCheckin = raw['liveCheckin'];
    final checkin = rawCheckin == null ? '' : '$rawCheckin'.trim();
    return FamilyMember(
      linkId: linkId,
      userId: userId,
      name: ('${raw['name'] ?? ''}'.trim().isEmpty)
          ? 'Thành viên'
          : '${raw['name']}'.trim(),
      linkedAt:
          linkedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(linkedAt),
      latestReportAt:
          latest == null ? null : DateTime.fromMillisecondsSinceEpoch(latest),
      liveAt: live == null ? null : DateTime.fromMillisecondsSinceEpoch(live),
      parentLabel: label.isEmpty ? null : label,
      notifyOn: raw['notifyOn'] != false,
      liveSummary: readSummary(raw['liveSummary']),
      liveCheckin: checkin.isEmpty ? null : checkin,
    );
  }
}

/// Trạng thái "Cửa sổ tin cậy" của tài khoản đang đăng nhập.
class FamilyState {
  const FamilyState({
    this.invite,
    this.parents = const [],
    this.children = const [],
    this.topic,
  });

  /// Mã mời đang chờ (chỉ học sinh có).
  final FamilyInvite? invite;

  /// Ba/mẹ đã liên kết (góc nhìn học sinh).
  final List<FamilyMember> parents;

  /// Các con đã liên kết (góc nhìn phụ huynh).
  final List<FamilyMember> children;

  /// Kênh Realtime của chính tài khoản này do server sinh (không đoán được).
  /// Nghe kênh này để biết "con vừa cập nhật" mà kéo ngay, thay vì chờ hết
  /// chu kỳ hỏi định kỳ. Null khi server chưa trả về.
  final String? topic;

  bool get hasLinkedParents => parents.isNotEmpty;
  bool get hasLinkedChildren => children.isNotEmpty;

  static const FamilyState empty = FamilyState();

  static FamilyState fromJson(Object? raw) {
    if (raw is! Map) return empty;
    List<FamilyMember> read(String key) {
      final list = raw[key];
      if (list is! List) return const [];
      return list
          .map(FamilyMember.fromJson)
          .whereType<FamilyMember>()
          .toList(growable: false);
    }

    final topic = '${raw['topic'] ?? ''}'.trim();
    return FamilyState(
      invite: FamilyInvite.fromJson(raw['invite']),
      parents: read('parents'),
      children: read('children'),
      topic: topic.isEmpty ? null : topic,
    );
  }
}

/// Một báo cáo tuần con đã gửi cho gia đình.
class SharedReport {
  const SharedReport({
    required this.id,
    required this.studentName,
    required this.createdAt,
    required this.report,
  });

  final String id;
  final String studentName;
  final DateTime createdAt;

  /// Báo cáo đã dựng. Null khi payload hỏng/không có mục nào — khi đó UI nói
  /// thật là không đọc được, không vẽ bảng trống.
  final WeeklyReportData? report;

  static SharedReport? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = '${raw['id'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    final at = (raw['createdAt'] as num?)?.toInt() ?? 0;
    return SharedReport(
      id: id,
      studentName: ('${raw['studentName'] ?? ''}'.trim().isEmpty)
          ? 'Con'
          : '${raw['studentName']}'.trim(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(at),
      report: WeeklyReportData.fromJson(_decodePayload(raw['payload'])),
    );
  }

  /// Payload có thể tới dưới dạng Map (Supabase jsonb) hoặc String (nếu ai đó
  /// đẩy lên dạng chuỗi) — chấp nhận cả hai để không mất dữ liệu.
  static Object? _decodePayload(Object? raw) {
    if (raw is String) {
      if (raw.isEmpty) return null;
      try {
        return jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
    return raw;
  }
}

/// Tiến độ của con mà ba mẹ đọc được — một gói gồm cả hai nguồn:
///
/// - [live]: bản "trạng thái trực tiếp" con đang chia sẻ, app của con tự đẩy
///   mỗi khi số liệu đổi. Null khi con CHƯA bật (hoặc vừa tắt) — khi đó ba mẹ
///   vẫn thấy báo cáo tuần con tự tay gửi, chỉ là không cập nhật liên tục.
/// - [reports]: báo cáo tuần con tự tay bấm gửi. Khi hỏi kèm mốc `since`, đây
///   chỉ là phần MỚI hơn mốc đã biết — người gọi tự ghép vào danh sách đang có.
///
/// Cả hai đều là nội dung do con chọn chia sẻ; không có dữ liệu thô nào ở đây.
class ChildProgress {
  const ChildProgress({this.live, this.reports = const [], this.serverTime});

  final SharedReport? live;
  final List<SharedReport> reports;

  /// Giờ server lúc trả lời — dùng làm mốc cho lần hỏi sau.
  final DateTime? serverTime;

  /// Không có gì mới (chỉ có nghĩa khi hỏi kèm `since`).
  bool get isEmpty => live == null && reports.isEmpty;

  static ChildProgress? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final reports = <SharedReport>[];
    final list = raw['reports'];
    if (list is List) {
      for (final entry in list) {
        final report = SharedReport.fromJson(entry);
        if (report != null) reports.add(report);
      }
    }

    final serverAt = _millis(raw['serverTime']);
    return ChildProgress(
      live: _readLive(raw['live']),
      reports: reports,
      serverTime:
          serverAt == null ? null : DateTime.fromMillisecondsSinceEpoch(serverAt),
    );
  }

  /// "Trạng thái trực tiếp" → cùng kiểu [SharedReport] với báo cáo tuần, để
  /// màn ba mẹ vẽ bằng đúng một đoạn UI. Không có payload đọc được thì bỏ
  /// luôn (thà nói "đang chờ cập nhật" còn hơn hiện thẻ rỗng).
  static SharedReport? _readLive(Object? raw) {
    if (raw is! Map) return null;
    final payload = SharedReport._decodePayload(raw['payload']);
    final decoded = WeeklyReportData.fromJson(payload);
    if (decoded == null) return null;
    final at = _millis(raw['updatedAt']) ?? 0;
    final name = '${raw['studentName'] ?? ''}'.trim();
    return SharedReport(
      id: 'live',
      studentName: name.isEmpty ? 'Con' : name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(at),
      report: decoded,
    );
  }

  static int? _millis(Object? v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n > 0 ? n : null;
  }
}

/// Kết quả một thao tác có thể thất bại vì lý do nghiệp vụ (mã sai, hết hạn…).
class FamilyActionResult {
  const FamilyActionResult({
    required this.ok,
    required this.message,
    this.studentName,
  });

  final bool ok;
  final String message;

  /// Tên con/học sinh vừa liên kết — để chào đúng người.
  final String? studentName;
}
