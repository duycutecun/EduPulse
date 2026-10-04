/// Đồng hồ đếm ngược neo theo mốc thời gian thật (FE-3.2).
///
/// Vấn đề: `Timer.periodic` **trừ 1 mỗi giây**, nên nó đếm số lần tick chứ không
/// đếm thời gian đã trôi. Khi app bị vùi (Android tiêu hệu tiền), tick bị hệ
/// điều hành giữ lại rồi thả ra dồn một lúc, hoặc bị bỏ hẳn. Kết quả là học
/// sinh ngồi học 25 phút mà đồng hồ chỉ trừ được 8 phút — mất thời gian học
/// thật, đúng thứ mục tiêu "Không bao giờ bị mất thời gian học" cấm.
///
/// Cách sửa: giữ một mốc thời gian, mọi lần hỏi đều **tính ra** từ
/// `DateTime.now()` thay vì trừ dần. Timer chỉ còn vai trò đẩy giao diện cập
/// nhật, không còn là nguồn thời gian.
///
/// Nhận `now` qua tham số ở mọi hàm thay vì gọi `DateTime.now()` bên trong để
/// test được: một đồng hồ chỉ chạy được với đồng hồ thật thì cũng chỉ kiểm chứng
/// được bằng cách chờ thật.
class FocusClock {
  /// Tổng thời lượng một vòng, tính bằng giây.
  final int totalSeconds;

  /// Số giây còn lại **tại thời điểm neo gần nhất**.
  int _remainingAtAnchor;

  /// Mốc thời gian đang chạy; `null` khi đã tạm dừng.
  DateTime? _anchorAt;

  /// Lần bấm bắt đầu đầu tiên của vòng — dùng làm `startedAt` của phiên học.
  DateTime? _startedAt;

  /// Thời điểm bấm bắt đầu gần nhất (kể cả sau khi tạm dừng/tiếp tục).
  DateTime? _lastStartedAt;

  /// Tổng giây đã học được tính đến lần neo gần nhất, chưa gồm phần đang chạy.
  int _elapsedAtAnchor = 0;

  FocusClock({required this.totalSeconds})
      : _remainingAtAnchor = totalSeconds < 0 ? 0 : totalSeconds {
    if (totalSeconds < 0) {
      throw ArgumentError.value(totalSeconds, 'totalSeconds', 'phải ≥ 0');
    }
  }

  /// Đồng hồ đang chạy hay không.
  bool get isRunning => _anchorAt != null;

  /// Vòng đã từng được bấm bắt đầu chưa.
  bool get hasStarted => _startedAt != null;

  /// Số giây còn lại tại thời điểm [now].
  ///
  /// Khi đang chạy: trừ đúng số giây đã trôi qua, không phụ thuộc tick.
  int remainingAt(DateTime now) {
    final anchor = _anchorAt;
    if (anchor == null) return _remainingAtAnchor;
    final elapsed = now.difference(anchor).inSeconds;
    final remaining = _remainingAtAnchor - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// Số giây đã học tích luỹ tại [now].
  int elapsedAt(DateTime now) {
    final anchor = _anchorAt;
    if (anchor == null) return _elapsedAtAnchor;
    return totalSeconds - remainingAt(now);
  }

  /// Điểm bắt đầu thật của phiên (lần bấm đầu tiên), `null` nếu chưa bấm bao giờ.
  DateTime? get startedAt => _startedAt;

  /// Mốc thời gian đang chạy, `null` khi đã tạm dừng.
  DateTime? get anchorAt => _anchorAt;

  /// Số giây còn lại tại mốc neo (không tính phần đã trôi từ mốc tới giờ).
  int get remainingSecondsAtAnchor => _remainingAtAnchor;

  /// Dựng đồng hồ từ trạng thái đã lưu (BE-3.2).
  ///
  /// Giữ `startedAt` của phiên gốc: nếu dựng lại rồi coi đó là lần bấm đầu
  /// tiên, mốc bắt đầu sẽ trôi theo mỗi lần app bị kill — và `StudySession`
  /// ghi ra sẽ không bao giờ khớp với lúc người dùng thực sự bắt đầu.
  factory FocusClock.restore({
    required int totalSeconds,
    required int remainingSeconds,
    DateTime? startedAt,
    bool running = false,
    DateTime? now,
  }) {
    if (totalSeconds < 0) {
      throw ArgumentError.value(totalSeconds, 'totalSeconds', 'phải ≥ 0');
    }
    final clock = FocusClock(totalSeconds: totalSeconds);
    final remaining = remainingSeconds < 0
        ? 0
        : (remainingSeconds > totalSeconds ? totalSeconds : remainingSeconds);
    clock._remainingAtAnchor = remaining;
    // Phần đã học suy ra từ phần còn lại, không nhận tham số riêng: hai con số
    // độc lập dễ lệch nhau và sinh ra vòng "25 phút nhưng đã học 30 phút".
    clock._elapsedAtAnchor = totalSeconds - remaining;
    clock._startedAt = startedAt;
    clock._lastStartedAt = startedAt;
    if (running) clock._anchorAt = now ?? DateTime.now();
    return clock;
  }

  /// Bắt đầu (hoặc tiếp tục sau khi tạm dừng) chạy từ [now].
  ///
  /// Nếu đã chạy thì gọi lại là không-op: đồng hồ không được "reset âm thầm"
  /// giữa chừng vì một lời gọi lặp.
  void start(DateTime now) {
    if (_anchorAt != null) return;
    _anchorAt = now;
    _startedAt ??= now;
    _lastStartedAt = now;
  }

  /// Tạm dừng tại [now], giữ nguyên số giây còn lại.
  ///
  /// Phần thời gian đã chạy được cộng vào tổng đã học trước khi bỏ neo — nếu
  /// không, tạm dừng 5 phút rồi tiếp tục sẽ mất 5 phút đó khỏi `elapsedAt`.
  void pause(DateTime now) {
    final anchor = _anchorAt;
    if (anchor == null) return;
    _elapsedAtAnchor = elapsedAt(now);
    _remainingAtAnchor = remainingAt(now);
    _anchorAt = null;
  }

  /// Đặt lại vòng về [totalSeconds] và dừng, dùng khi đổi cài đặt Pomodoro.
  void reset() {
    _anchorAt = null;
    _remainingAtAnchor = totalSeconds;
    _elapsedAtAnchor = 0;
    _startedAt = null;
    _lastStartedAt = null;
  }

  /// Đổi tổng thời lượng, giữ trạng thái chạy/dừng.
  ///
  /// `totalSeconds` là `final` nên phải tạo đồng hồ mới; thao tác này giữ đúng
  /// số giây đã học để đổi cài đặt giữa chừng không nuốt mất tiến độ.
  FocusClock withTotal(int totalSeconds) {
    if (totalSeconds < 0) {
      throw ArgumentError.value(totalSeconds, 'totalSeconds', 'phải ≥ 0');
    }
    final next = FocusClock(totalSeconds: totalSeconds);
    next._anchorAt = _anchorAt;
    next._remainingAtAnchor = remainingAt(DateTime.now());
    next._startedAt = _startedAt;
    next._lastStartedAt = _lastStartedAt;
    next._elapsedAtAnchor = elapsedAt(DateTime.now());
    // Vòng mới dài hơn thì phần chênh về hướng "học thêm" coi như chưa học;
    // ngắn hơn thì giữ số đã học, phần dư chuyển thành phần chưa học.
    if (next._elapsedAtAnchor > totalSeconds) {
      next._elapsedAtAnchor = totalSeconds;
      next._remainingAtAnchor = 0;
    } else {
      next._remainingAtAnchor = totalSeconds - next._elapsedAtAnchor;
    }
    return next;
  }

  /// Định dạng `mm:ss` (hoặc `h:mm:ss` khi vượt 1 giờ).
  String formatSeconds(int seconds) {
    final value = seconds < 0 ? 0 : seconds;
    final h = value ~/ 3600;
    final m = (value % 3600) ~/ 60;
    final s = value % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}