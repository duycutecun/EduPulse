import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../ai/flashcard_service.dart';
import '../ai/ai_daily_briefing.dart';
import '../utils/storage_service.dart';
import 'notification_service.dart';

/// Chính sách thông báo thích ứng (đặc tả mục 16).
///
/// Nguyên tắc áp dụng:
/// - **AI/app tự điều chỉnh tần suất**: nếu người dùng liên tục không mở
///   app sau nhắc → nhắc thưa dần (1 → 2 → 3 → 7 ngày), không bỏ hoàn toàn.
/// - **Daily digest được hỗ trợ**: gói tóm tắt 1 lần/ngày thay vì nhiều
///   notification rải rác.
/// - **Trong Focus**: chặn notification không quan trọng; deadline/exam
///   khẩn cấp được bypass.
/// - **Không dùng streak làm cơ chế ép** (mục 44): ngôn ngữ nhẹ nhàng.
class AdaptivePolicy {
  AdaptivePolicy._();

  // ------------------------------------------------------------------
  // Hành vi người dùng
  // ------------------------------------------------------------------

  /// Ghi nhận người dùng đã mở app hôm nay (gọi khi app khởi động).
  static void recordOpened() {
    final d = DateTime.now();
    StorageService.setString('notif_last_open', _dateKey(d));
  }

  static String? _lastOpenDate() => StorageService.getString('notif_last_open');

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Số ngày liên tiếp người dùng không mở app (tính tới hôm qua).
  /// Người dùng mở app mỗi ngày → 0.
  static int missedDays(DateTime now) {
    final last = _lastOpenDate();
    if (last == null) return 0;
    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return 0;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final gap = yesterday
        .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
        .inDays;
    return gap > 0 ? gap : 0;
  }

  // ------------------------------------------------------------------
  // Tần suất thích ứng
  // ------------------------------------------------------------------

  /// Khoảng cách ngày giữa các lần nhắc, dựa trên việc người dùng có
  /// phản hồi (mở app) sau nhắc hay không:
  /// - Mở thường xuyên (missed ≤ 1) → mỗi ngày.
  /// - Bỏ qua 2–3 ngày → mỗi 2 ngày.
  /// - Bỏ qua 4–6 ngày → mỗi 3 ngày.
  /// - Bỏ qua ≥ 7 ngày → mỗi tuần (không biến mất hẳn).
  static int reminderIntervalDays(DateTime now) {
    final missed = missedDays(now);
    if (missed <= 1) return 1;
    if (missed <= 3) return 2;
    if (missed <= 6) return 3;
    return 7;
  }

  // ------------------------------------------------------------------
  // Focus blocking (mục 16: trong Focus chặn notification không quan trọng)
  // ------------------------------------------------------------------

  static bool get inFocusSession =>
      StorageService.getBool('notif_in_focus') ?? false;

  static void setInFocus(bool value) {
    StorageService.setBool('notif_in_focus', value);
    if (!NotificationService.isSupported) return;
    if (value) {
      // Tạm dừng nhắc thường trong phiên Focus.
      NotificationService.cancelId(NotificationService.reminderId);
      NotificationService.cancelId(NotificationService.digestId);
    }
    // Khi thoát Focus, [syncReminders] sẽ đặt lại lịch phù hợp.
  }

  /// Deadline/exam khẩn cấp được bypass — luôn cho phép gửi.
  static bool shouldNotifyNow({
    required bool isUrgent,
    bool? inFocus,
  }) {
    if (isUrgent) return true;
    return !(inFocus ?? inFocusSession);
  }

  // ------------------------------------------------------------------
  // Daily digest (mục 16: Daily summary)
  // ------------------------------------------------------------------

  /// Lên lịch digest lúc [hour]:[minute] kế tiếp với nội dung mới nhất.
  /// Gọi khi mở app — nội dung luôn cập nhật, không stale.
  static Future<void> scheduleDigest({
    required List<TodayTask> tasks,
    required List<StudySession> sessions,
    required ExamModel? primaryExam,
    int hour = 20,
    int minute = 30,
  }) async {
    if (!NotificationService.isSupported) return;
    if (!(StorageService.getBool('notif_digest_enabled') ?? false)) return;

    // Ưu tiên lời dẫn từ bản tin AI hôm nay (cache theo ngày, không tốn
    // quota thêm) — digest trở thành "giọng nói" của chu trình AI ở ngoài
    // app. Bản tin chưa có thì buildDigest tự dùng nội dung quy tắc cũ.
    String? briefingGreeting;
    try {
      final b = await AiDailyBriefing.load();
      final g = b.greeting.trim();
      if (g.isNotEmpty) briefingGreeting = g;
    } catch (_) {}

    final digest = buildDigest(
      tasks: tasks,
      sessions: sessions,
      primaryExam: primaryExam,
      now: DateTime.now(),
      briefingGreeting: briefingGreeting,
    );
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    await NotificationService.scheduleAt(
      id: NotificationService.digestId,
      when: when,
      title: digest.title,
      body: digest.body,
    );
  }

  /// Tạo nội dung tóm tắt cuối ngày: task còn lại, phút focus hôm nay,
  /// đếm ngược kỳ thi. Nhẹ nhàng, không tạo áp lực (Principle 5 Calm).
  static ({String title, String body}) buildDigest({
    required List<TodayTask> tasks,
    required List<StudySession> sessions,
    required ExamModel? primaryExam,
    required DateTime now,
    String? briefingGreeting,
  }) {
    final today = _dateKey(now);
    final remaining = tasks
        .where((t) =>
            !(t.scheduledAt != null && _dateKey(t.scheduledAt!) != today) &&
            !t.isDone &&
            t.status != 'skipped')
        .toList();
    final minutesToday = sessions
        .where((s) => _dateKey(s.completedAt) == today)
        .fold(0, (sum, s) => sum + s.actualMinutes);

    final title = remaining.isEmpty
        ? 'Hôm nay bạn đã xong hết kế hoạch 🎉'
        : 'Tóm tắt hôm nay — còn ${remaining.length} nhiệm vụ';

    final parts = <String>[
      if (briefingGreeting != null && briefingGreeting.trim().isNotEmpty)
        _short(briefingGreeting.trim(), 90),
      if (minutesToday > 0) 'Focus $minutesToday phút',
      if (remaining.isNotEmpty)
        'Còn lại: ${remaining.take(2).map((t) => t.title).join(', ')}'
            '${remaining.length > 2 ? ' +${remaining.length - 2}' : ''}',
      if (primaryExam != null &&
          primaryExam.dateTime.difference(now).inDays >= 0)
        '${primaryExam.name} còn ${primaryExam.dateTime.difference(now).inDays} ngày',
    ];

    return (
      title: title,
      body: parts.isEmpty ? 'Nghỉ ngơi tốt nhé!' : parts.join(' • ')
    );
  }

  // ------------------------------------------------------------------
  // Đồng bộ toàn bộ lịch nhắc theo policy
  // ------------------------------------------------------------------

  /// Đặt lại nhắc hằng ngày/theo khoảng và digest. Gọi khi mở app và khi
  /// thoát Focus. Không làm gì trên web (NotificationService tự no-op).
  static Future<void> syncReminders({
    required bool reminderEnabled,
    required int reminderHour,
    required int reminderMinute,
    required List<TodayTask> tasks,
    required List<StudySession> sessions,
    required ExamModel? primaryExam,
  }) async {
    if (!NotificationService.isSupported) return;
    if (inFocusSession) return; // đang Focus — đừng đặt lại, tránh đánh thức.

    final now = DateTime.now();
    final interval = reminderIntervalDays(now);

    if (!reminderEnabled) {
      await NotificationService.cancelId(NotificationService.reminderId);
    } else if (interval == 1) {
      await NotificationService.scheduleDaily(
        hour: reminderHour,
        minute: reminderMinute,
      );
    } else {
      // Nhắc thưa hơn: một-shot vào lần kế tiếp đúng giờ ưa thích.
      var when =
          DateTime(now.year, now.month, now.day, reminderHour, reminderMinute);
      while (!when.isAfter(now) || when.difference(now).inDays < interval - 1) {
        when = when.add(const Duration(days: 1));
      }
      await NotificationService.scheduleAt(
        id: NotificationService.reminderId,
        when: when,
        title: 'EduPulse — Hôm nay bạn cần làm gì? 📚',
        body: 'Mở EduPulse để xem kế hoạch và bắt đầu một phiên học nhé.',
      );
    }

    await scheduleDigest(
      tasks: tasks,
      sessions: sessions,
      primaryExam: primaryExam,
    );

    // Nhắc ôn flashcard đến hạn (SM-2) — mảnh nhắc cuối của chu trình
    // "học → AI chấm lịch → quay lại đúng lúc". Chỉ lên lịch khi có thẻ
    // đến hạn để không làm phiền khi lịch trống.
    await syncFlashcardReminder();
  }

  // ------------------------------------------------------------------
  // Nhắc flashcard SM-2 (spaced repetition)
  // ------------------------------------------------------------------

  /// Lên lịch (hoặc dời) lời nhắc "có N thẻ đến hạn" vào 18:00 hôm nay nếu
  /// còn thẻ; không có thẻ thì huỷ. No-op trên nền không hỗ trợ notification.
  /// Gọi khi sync lịch mở app và mỗi khi học sinh vừa ôn xong một buổi
  /// (lịch SM-2 thay đổi).
  static Future<void> syncFlashcardReminder() async {
    if (!NotificationService.isSupported) return;

    final due = FlashcardService.dueCards();
    if (due.isEmpty) {
      await NotificationService.cancelId(
          NotificationService.flashcardReminderId);
      return;
    }

    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, 18);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    await NotificationService.scheduleAt(
      id: NotificationService.flashcardReminderId,
      when: when,
      title: due.length == 1
          ? '1 thẻ flashcard đến hạn ôn 🃏'
          : '${due.length} thẻ flashcard đến hạn ôn 🃏',
      body: due.length == 1
          ? 'Vài phút với "${_short(due.first.front)}" là xong — nhớ lâu hơn hẳn.'
          : 'Ưu tiên: ${_short(due.first.front)} — ôn ít mỗi ngày, nhớ lâu về sau.',
    );
  }

  static String _short(String s, [int max = 60]) {
    final t = s.replaceAll('\n', ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max).trimRight()}…';
  }
}
