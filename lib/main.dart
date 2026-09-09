import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/notifications/notification_service.dart';
import 'core/pwa/pwa_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/storage_service.dart';
import 'core/utils/supabase_service.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'app/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PwaService.init();
  await StorageService.init();
  await SupabaseService.init();
  await NotificationService.init();
  runApp(const EduPulseApp());
}

class EduPulseApp extends StatelessWidget {
  const EduPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'EduPulse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: _BrightnessSyncer(
            child: StorageService.isOnboardingDone()
                ? const MainShellScreen()
                : const OnboardingScreen(),
          ),
        );
      },
    );
  }
}

// Đồng bộ AppColors.darkFallback với brightness thực tế để các getter màu
// (bgPage, cardWhite, textPrimary...) trả đúng bảng màu sáng/tối.
class _BrightnessSyncer extends StatelessWidget {
  final Widget child;
  const _BrightnessSyncer({required this.child});

  @override
  Widget build(BuildContext context) {
    AppColors.darkFallback = AppColors.isDark(context);
    return child;
  }
}