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
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!isSupported || _initialized) return;

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
  }

  /// Lên lịch nhắc học lặp lại mỗi ngày vào [hour]:[minute].
  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
  }) async {
    if (!isSupported) return;
    await init();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
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
      id: 1001,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      title: 'EduPulse — Giờ học của bạn đã đến! 📚',
      body: 'Duy trì streak 🔥 — 25 phút hôm nay là cả một thói quen lớn!',
    );
  }

  /// Hủy lịch nhắc đã đặt (nếu có).
  static Future<void> cancel() async {
    if (!isSupported) return;
    await _plugin.cancel(id: 1001);
  }
}