import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/storage_service.dart';
import 'core/utils/supabase_service.dart';
import 'app/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await SupabaseService.init();
  runApp(const EduPulseApp());
}

class EduPulseApp extends StatelessWidget {
  const EduPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const _BrightnessSyncer(
        child: MainShellScreen(),
      ),
    );
  }
}

// Forces AppColors.darkFallback to false (app is light-mode only).
class _BrightnessSyncer extends StatelessWidget {
  final Widget child;
  const _BrightnessSyncer({required this.child});

  @override
  Widget build(BuildContext context) {
    AppColors.darkFallback = false;
    return child;
  }
}
