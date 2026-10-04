import '../utils/storage_service.dart';
import 'early_warning_service.dart';

class AiNotificationService {
  static const String _key = 'ai_notifications_enabled';

  static bool isEnabled() => StorageService.getBool(_key) ?? true;

  static void setEnabled(bool value) => StorageService.setBool(_key, value);

  static Future<void> showWarning(Warning warning) async {
    if (!isEnabled()) return;
    if (isQuietHour(DateTime.now())) return;
  }

  static Future<void> showStreakReminder(int streak) async {
    if (!isEnabled()) return;
    if (isQuietHour(DateTime.now())) return;
  }

  static Future<void> showExamReminder(String examName, int daysLeft) async {
    if (!isEnabled()) return;
    if (isQuietHour(DateTime.now())) return;
  }

  static bool isQuietHour(DateTime now) {
    return now.hour >= 22 || now.hour < 7;
  }
}
