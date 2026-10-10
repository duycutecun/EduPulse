import 'package:flutter/material.dart';
import 'core/ai/free_models_catalog.dart';
import 'core/ai/ai_insights.dart';
import 'core/family/live_progress_service.dart';
import 'core/ai/ai_refresh_service.dart';
import 'core/migration/data_migration.dart';
import 'core/notifications/adaptive_policy.dart';
import 'core/notifications/notification_service.dart';
import 'core/pwa/pwa_service.dart';
import 'core/sync/backup_service.dart';
import 'core/sync/sync_state.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/appearance_service.dart';
import 'core/utils/auth_service.dart';
import 'core/utils/storage_service.dart';
import 'core/utils/supabase_service.dart';
import 'core/widget/home_widget_service.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/auth/presentation/screens/reset_password_screen.dart';
import 'features/study/domain/models/study_models.dart';
import 'app/account_role_gate.dart';
import 'app/main_shell.dart';
import 'app/app_navigator_key.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PwaService.init();
  // Storage bắt buộc phải sẵn sàng trước khi các màn hình đọc dữ liệu.
  await StorageService.init();
  // Migration dữ liệu (mục 42): auto backup → migrate → rollback nếu lỗi.
  // Chạy sớm trước mọi màn hình đọc data, log MigrationReport ra console.
  logMigration(DataMigration.run(DataMigration.defaultSteps()));
  // Font scale adaptive (đặc tả mục 20) đọc trước runApp để frame đầu đã đúng.
  AppearanceService.load();
  runApp(const EduPulseApp());

  // Firebase (auth) + Supabase (data) + notification không chặn frame đầu
  // tiên: khởi tạo ngay sau khi UI render xong để app mở nhanh hơn.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await AuthService.init();
    await SupabaseService.init();
    await NotificationService.init();
    // Làm mới danh sách model AI miễn phí (OpenRouter) ở nền — cache 24h.
    FreeModelsCatalog.ensureLoaded();
    // AI tự phân tích tiến độ và đẩy gợi ý lên Home. Gọi ở đây (một lần mỗi
    // lần mở app) thay vì trong card, để không phát sinh request khi dựng
    // widget và không gọi model khi cache còn hạn (TTL 6h). Kết quả được
    // ghi cache, card ở Home chỉ đọc nên mở app vẫn tức thì.
    AiInsights.load();
    // Khi đã online, đẩy dữ liệu local lên cloud ngay sau khi kết nối sẵn sàng.
    // Qua SyncStateService để mọi UI (banner, sidebar, tab Tôi) phản ánh
    // trạng thái Syncing → Synced (đặc tả mục 19).
    SyncStateService.updateConnectivity(isOnline: PwaService.isOnline);
    if (PwaService.isOnline && SupabaseService.isConfigured) {
      SyncStateService.syncInBackground();
    }
    // Sync nền định kỳ 15 phút khi còn online.
    SyncStateService.startAutoSync();
    // Sao lưu toàn diện + đồng bộ gần như thời gian thực giữa mọi thiết bị.
    // Chạy sau `AuthService.init()` vì danh tính liên kết dữ liệu giữa các máy
    // chính là Firebase UID — chưa đăng nhập thì mỗi máy một tài khoản riêng.
    // Lần chạy đầu sẽ kéo bản sao lưu gần nhất về nếu cloud đã có (đúng yêu
    // cầu "mở app luôn thấy bản mới nhất"), rồi bắt đầu hỏi/lưu định kỳ.
    BackupService.start();
    // "Cập nhật trực tiếp" cho gia đình: khi con bật công tắc, app tự dựng lại
    // báo cáo theo đúng mục con chia sẻ và đẩy lên mỗi khi số liệu đổi — ba mẹ
    // mở app là thấy tiến độ mới nhất, không phải chờ con bấm gửi.
    LiveProgressService.start();

    // Ghi nhận người dùng đã mở app (phục vụ tần suất nhắc thích ứng) và
    // đặt lại lịch nhắc/digest theo hành vi gần nhất (đặc tả mục 16).
    AdaptivePolicy.recordOpened();
    AdaptivePolicy.syncReminders(
      reminderEnabled: StorageService.getBool('reminder_enabled') ?? false,
      reminderHour: StorageService.getInt('reminder_hour') ?? 19,
      reminderMinute: StorageService.getInt('reminder_minute') ?? 30,
      tasks: StorageService.getTodayTaskIds()
          .map((id) => StorageService.getTodayTaskJson(id))
          .whereType<String>()
          .map((json) {
            try {
              return TodayTask.fromJsonString(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<TodayTask>()
          .toList(),
      sessions: const [],
      primaryExam: null,
    );

    // Chu trình AI khép kín: mở app là dữ liệu mới nhất được AI nhìn thấy —
    // bản tin/gợi ý tính lại nền (guard test/native-key tự chặn nếu không có
    // kênh gọi), flashcard đến hạn được dời lời nhắc 18:00.
    AiRefreshService.refreshNow();
    AdaptivePolicy.syncFlashcardReminder();
    // Widget màn hình chính (Giai đoạn 2): đồng bộ dữ liệu mới nhất để
    // widget hiển thị đúng ngay khi app được mở.
    HomeWidgetService.sync();
  });
}

/// App luôn ở chế độ sáng (Duolingo-style), không hỗ trợ dark mode.
class EduPulseApp extends StatelessWidget {
  const EduPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // High contrast (mục 21): đổi theme toàn app theo cài đặt.
    return ValueListenableBuilder<bool>(
      valueListenable: AppearanceService.highContrast,
      builder: (context, highContrast, _) => MaterialApp(
        title: 'EduPulse',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: AppTheme.lightWithContrast(highContrast),
        builder: (context, child) {
          // Font size adaptive toàn app (đặc tả mục 20): nhân với system
          // textScaler để tôn trọng cài đặt hệ điều hành.
          //
          // Lưu ý: `MaterialApp.builder` cung cấp `child` (Navigator) và
          // MediaQuery của MaterialApp nằm TRÊN builder, nên phải:
          //  1) đọc MediaQuery bằng `maybeOf` (context ở đây chưa chắc có),
          //  2) LUÔN trả về `child` — nếu thay bằng SizedBox.shrink() khi
          //     child null thì app không vẽ được gì (màn hình trắng).
          final media = MediaQuery.maybeOf(context);
          final systemScale =
              media == null ? 1.0 : media.textScaler.scale(16) / 16;
          return ValueListenableBuilder<double>(
            valueListenable: AppearanceService.fontScale,
            builder: (context, _, builtChild) {
              final Widget content =
                  builtChild ?? child ?? const SizedBox.shrink();
              return MediaQuery(
                data: (media ?? const MediaQueryData()).copyWith(
                  textScaler: TextScaler.linear(
                    systemScale * AppearanceService.fontScale.value,
                  ),
                ),
                child: content,
              );
            },
          );
        },
        home: _buildHome(),
      ),
    );
  }

  /// Màn hình khởi đầu:
  /// - Nếu URL có `oobCode` + `mode=resetPassword` (bấm link reset từ email)
  ///   → mở màn đặt mật khẩu mới.
  /// - Nếu URL là deep link `task/<id>` → xử lý mở chi tiết task.
  /// - Ngược lại: onboarding (lần đầu) hoặc [AccountRoleGate] — nơi quyết
  ///   định app học sinh hay màn phụ huynh theo vai trò tài khoản.
  Widget _buildHome() {
    final params = Uri.base.queryParameters;
    final oobCode = params['oobCode'];
    final mode = params['mode'];
    if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
      return ResetPasswordScreen(
        oobCode: oobCode,
        email: params['email'] ?? '',
      );
    }

    // Deep link task:
    final path = Uri.base.path;
    if (path.startsWith('/task/')) {
      final taskId = path.substring('/task/'.length);
      // Khởi động MainShell trước, sau đó mở chi tiết task.
      // Chúng tôi cần truyền taskId vào MainShell để xử lý khi app ready.
      return MainShellScreen(deepLinkTaskId: taskId);
    }

    return StorageService.isOnboardingDone()
        ? const AccountRoleGate()
        : const OnboardingScreen();
  }
}
