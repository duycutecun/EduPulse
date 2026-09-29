import 'package:flutter/material.dart';
import 'core/ai/free_models_catalog.dart';
import 'core/notifications/notification_service.dart';
import 'core/pwa/pwa_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/auth_service.dart';
import 'core/utils/storage_service.dart';
import 'core/utils/supabase_service.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/auth/presentation/screens/reset_password_screen.dart';
import 'app/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PwaService.init();
  // Storage bắt buộc phải sẵn sàng trước khi các màn hình đọc dữ liệu.
  await StorageService.init();
  runApp(const EduPulseApp());

  // Firebase (auth) + Supabase (data) + notification không chặn frame đầu
  // tiên: khởi tạo ngay sau khi UI render xong để app mở nhanh hơn.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await AuthService.init();
    await SupabaseService.init();
    await NotificationService.init();
    // Làm mới danh sách model AI miễn phí (OpenRouter) ở nền — cache 24h.
    FreeModelsCatalog.ensureLoaded();
    // Khi đã online, đẩy dữ liệu local lên cloud ngay sau khi kết nối sẵn sàng.
    if (PwaService.isOnline && SupabaseService.isConfigured) {
      SupabaseService.syncAll();
    }
  });
}

/// App luôn ở chế độ sáng (Duolingo-style), không hỗ trợ dark mode.
class EduPulseApp extends StatelessWidget {
  const EduPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _buildHome(),
    );
  }

  /// Màn hình khởi đầu:
  /// - Nếu URL có `oobCode` + `mode=resetPassword` (bấm link reset từ email)
  ///   → mở màn đặt mật khẩu mới.
  /// - Ngược lại: onboarding (lần đầu) hoặc MainShell.
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
    return StorageService.isOnboardingDone()
        ? const MainShellScreen()
        : const OnboardingScreen();
  }
}