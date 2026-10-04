import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'focus_clock.dart';

/// Phiên học **đang chạy**, ghi xuống storage để khôi phục sau khi app bị hệ
/// điều hành kill (BE-3.2).
///
/// Vì sao cần: `FocusClock` chỉ sống trong bộ nhớ. Khi Android giết tiến trình
/// (người dùng vuốt app, hết RAM, hệ thống buộc dừng), toàn bộ vòng đang chạy
/// biến mất — học sinh mất đúng phần thời gian đã học, và không có gì để hỏi
/// họ "bạn có muốn tiếp tục không".
///
/// Đây là **ảnh chụp trạng thái**, không phải lịch sử: khi vòng kết thúc thì xoá
/// đi, chỉ [StudySession] mới là dữ liệu lâu dài.
class ActiveStudySession {
  /// Vòng đã bỏ dở quá lâu thì không hỏi nữa — hỏi lại phiên từ 8 tiếng trước
  /// chỉ gây phiền.
  ///
  /// Hết hạn không phải để quên dữ liệu: khoản thời gian đó vẫn được tính vào
  /// [elapsedMinutesAt] và ghi thành phiên `cancelled` nếu người dùng đồng ý;
  /// chỉ là câu hỏi "tiếp tục phiên học tối qua" thì vô nghĩa.
  static const Duration expiry = Duration(hours: 6);

  final String taskId;
  final String? taskTitle;
  final String subject;

  /// Tổng thời lượng vòng, tính bằng giây.
  final int totalSeconds;

  /// Số giây còn lại tại [anchorAt].
  final int remainingAtAnchor;

  /// Mốc thời gian đang chạy; `null` nghĩa là vòng đang tạm dừng.
  final DateTime? anchorAt;

  /// Mốc bấm bắt đầu thật của vòng.
  final DateTime startedAt;

  /// Vòng thứ mấy trong phiên (dùng cho nhãn "Phiên N").
  final int round;

  /// Đang trong giờ nghỉ hay giờ tập trung.
  final bool isBreak;

  ActiveStudySession({
    required this.taskId,
    this.taskTitle,
    required this.subject,
    required this.totalSeconds,
    required this.remainingAtAnchor,
    required this.anchorAt,
    required this.startedAt,
    this.round = 1,
    this.isBreak = false,
  });

  /// Chụp trạng thái hiện tại của [clock] để lưu xuống storage.
  factory ActiveStudySession.fromClock({
    required FocusClock clock,
    required String taskId,
    String? taskTitle,
    required String subject,
    int round = 1,
    bool isBreak = false,
  }) =>
      ActiveStudySession(
        taskId: taskId,
        taskTitle: taskTitle,
        subject: subject,
        totalSeconds: clock.totalSeconds,
        remainingAtAnchor: clock.remainingSecondsAtAnchor,
        anchorAt: clock.anchorAt,
        startedAt: clock.startedAt ?? DateTime.now(),
        round: round,
        isBreak: isBreak,
      );

  /// Số giây còn lại tại [now] — kể cả phần đã trôi qua lúc app không mở.
  int remainingAt(DateTime now) {
    final anchor = anchorAt;
    if (anchor == null) return remainingAtAnchor;
    final remaining = remainingAtAnchor - now.difference(anchor).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  /// Số giây đã học tích luỹ tại [now], không vượt quá tổng thời lượng.
  ///
  /// Suy ra từ phần còn lại thay vì lưu riêng: `đã học + còn lại = tổng` là bất
  /// biến của một vòng, lưu thêm hai con số độc lập thì chỉ chờ chúng lệch nhau.
  int elapsedSecondsAt(DateTime now) => totalSeconds - remainingAt(now);

  /// Phút đã học (làm tròn), dùng để ghi phiên `cancelled` khi người dùng
  /// chọn "Kết thúc phiên" thay vì tiếp tục.
  int elapsedMinutesAt(DateTime now) => (elapsedSecondsAt(now) / 60).round();

  /// Vòng đã trôi qua [expiry] chưa — quá hạn thì không hỏi nữa.
  bool isExpiredAt(DateTime now) {
    final anchor = anchorAt;
    // Vòng đã tạm dừng không có mốc đang chạy; dùng mốc bắt đầu làm chuẩn để
    // phiên treo cả đêm cũng không bị hỏi lại mãi.
    final reference = anchor ?? startedAt;
    return now.difference(reference) >= expiry;
  }

  /// Dựng lại đồng hồ đã ngừng, sẵn sàng tiếp tục từ đúng số giây còn lại.
  ///
  /// Vòng còn "thời gian sống" thì neo lại vào [now]: người dùng không bấm bắt đầu
  /// ngay, nên thời gian từ lúc app mở tới lúc bấm không thuộc phiên học.
  FocusClock restoreClock({DateTime? now}) {
    final at = now ?? DateTime.now();
    final restored = FocusClock.restore(
      totalSeconds: totalSeconds,
      remainingSeconds: remainingAt(at),
      startedAt: startedAt,
      // Vòng đang tạm dừng phải khôi phục thành tạm dừng; còn vòng quá hạn thì
      // giữ dừng thay vì chạy vô ích về 0 ngay.
      running: anchorAt != null && !isExpiredAt(at),
      now: at,
    );
    return restored;
  }

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'taskTitle': taskTitle,
        'subject': subject,
        'totalSeconds': totalSeconds,
        'remainingAtAnchor': remainingAtAnchor,
        'anchorAt': anchorAt?.toIso8601String(),
        'startedAt': startedAt.toIso8601String(),
        'round': round,
        'isBreak': isBreak,
      };

  String toJsonString() => jsonEncode(toJson());

  factory ActiveStudySession.fromJson(Map<String, dynamic> json) =>
      ActiveStudySession(
        taskId: json['taskId'] ?? '',
        taskTitle: json['taskTitle'],
        subject: json['subject'] ?? '',
        totalSeconds: json['totalSeconds'] ?? 0,
        remainingAtAnchor: json['remainingAtAnchor'] ?? 0,
        anchorAt: DateTime.tryParse(json['anchorAt'] ?? ''),
        startedAt:
            DateTime.tryParse(json['startedAt'] ?? '') ?? DateTime.now(),
        round: json['round'] ?? 1,
        isBreak: json['isBreak'] ?? false,
      );

  factory ActiveStudySession.fromJsonString(String value) =>
      ActiveStudySession.fromJson(jsonDecode(value) as Map<String, dynamic>);

  /// Đọc ảnh chụp từ chuỗi; JSON hỏng → `null` (không làm hỏng cả màn hình).
  static ActiveStudySession? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final session = ActiveStudySession.fromJsonString(value);
      if (session.totalSeconds <= 0) return null;
      return session;
    } catch (e) {
      debugPrint('[ActiveStudySession] Corrupt snapshot: $e');
      return null;
    }
  }

  @override
  String toString() =>
      'ActiveStudySession($subject, ${remainingAt(DateTime.now())}s left, '
      'round $round, break=$isBreak)';
}