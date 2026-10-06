import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Dịch vụ nhắc học hằng ngày (local notification, không cần server).
///
/// Chỉ hoạt động trên Android/iOS native — trên web/PWA đây là no-op (UI
/// nên ẩn tính năng khi [isSupported] == false).
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Nền tảng có hỗ trợ local notification hay không (mobile native).
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!isSupported || _initialized) return;

    try {
      tz.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);

      // Android 13+ cần runtime permission riêng.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
    } catch (_) {
      // Gracefully handle in tests or platform environments where plugin isn't bound.
    }
  }

  /// Xin quyền gửi thông báo ở thời điểm **người dùng thật sự muốn** (bật
  /// switch Nhắc học / Digest / Gửi thử), không xin lúc cài đặt.
  ///
  /// Trên iOS quyền thông báo **một khi bị từ chối là không hỏi lại**: xin
  /// sớm lúc mở app rồi bị từ chối nghĩa là nhắc học vĩnh viễn không hoạt
  /// động. Vì vậy [init] cố tình để `requestAlertPermission: false` và chỉ
  /// hỏi đúng lúc người dùng bật tính năng.
  ///
  /// Trả về `true` khi quyền đã được cấp, `false` khi máy chặn rõ ràng,
  /// và `null` khi nền tảng không cần quyền runtime (Android < 13) — caller
  /// phải coi `null` là **được phép**, nếu không sẽ tắt mất nhắc học trên máy
  /// Android cũ.
  static Future<bool?> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (!_initialized) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        // Android < 13: không có quyền runtime → plugin trả null.
        return await android?.requestNotificationsPermission();
      }
    } catch (_) {
      // Nền tảng không bind plugin (test) → không xác định được quyền.
    }
    return null;
  }

  /// Quyền thông báo hiện tại (iOS/Android 13+). `null` = không kiểm tra được.
  static Future<bool?> permissionGranted() async {
    if (!isSupported || !_initialized) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final status = await ios?.checkPermissions();
        return status?.isEnabled;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled();
      }
    } catch (_) {}
    return null;
  }

  /// Hiển thị ngay một thông báo — dùng cho nút "Gửi thử" ở tab Tôi, để
  /// người dùng biết chắc tiếng Việt + icon hiện đúng trên máy mình thay vì
  /// phải chờ tới giờ nhắc thật.
  static Future<bool> showNow({
    required String title,
    required String body,
    int id = 1099,
  }) async {
    if (!isSupported) return false;
    await init();
    if (!_initialized) return false;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_study_reminder',
          'Nhắc học hằng ngày',
          channelDescription: 'Nhắc nhở duy trì thói quen học mỗi ngày',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Id lịch nhắc học hằng ngày.
  static const int reminderId = 1001;

  /// Id daily digest (tóm tắt cuối ngày).
  static const int digestId = 1002;

  /// Id nhắc ôn flashcard đến hạn (SM-2).
  static const int flashcardReminderId = 1003;

  /// Lên lịch nhắc học lặp lại mỗi ngày vào [hour]:[minute].
  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
  }) async {
    if (!isSupported) return;
    await init();
    if (!_initialized) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_study_reminder',
        'Nhắc học hằng ngày',
        channelDescription: 'Nhắc nhở duy trì thói quen học mỗi ngày',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: reminderId,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      title: 'EduPulse — Giờ học của bạn đã đến! 📚',
      body: 'Duy trì streak 🔥 — 25 phút hôm nay là cả một thói quen lớn!',
    );
  }

  /// Lên lịch một-shot vào [when] (DateTime cục bộ).
  static Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!isSupported) return;
    await init();
    if (!_initialized) return;

    final scheduled = tz.TZDateTime.from(when, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'digest_and_spaced',
        'Tóm tắt và nhắc giãn cách',
        channelDescription: 'Tóm tắt cuối ngày và nhắc theo tần suất thích ứng',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  /// Hủy một notification theo id.
  static Future<void> cancelId(int id) async {
    if (!isSupported || !_initialized) return;
    await _plugin.cancel(id: id);
  }

  /// Hủy lịch nhắc đã đặt (nếu có).
  static Future<void> cancel() async {
    if (!isSupported || !_initialized) return;
    await _plugin.cancel(id: 1001);
  }
}
