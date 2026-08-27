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

class EduPulseApp extends StatefulWidget {
  const EduPulseApp({super.key});

  @override
  State<EduPulseApp> createState() => _EduPulseAppState();
}

class _EduPulseAppState extends State<EduPulseApp> {
  String _mode = 'system';

  @override
  void initState() {
    super.initState();
    _mode = StorageService.getThemeMode();
  }

  ThemeMode get _themeMode {
    switch (_mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void _setThemeMode(String mode) {
    // Resolve the target dark/light BEFORE the rebuild so every widget that
    // reads a theme-dependent AppColors.* getter in the very first frame of
    // the switch already sees the correct value (fixes the "two taps" lag
    // where only the background changed on the first press).
    AppColors.darkFallback = _resolvesDark(mode);
    setState(() {
      _mode = mode;
      StorageService.setThemeMode(mode);
    });
  }

  bool _resolvesDark(String mode) {
    switch (mode) {
      case 'light':
        return false;
      case 'dark':
        return true;
      default:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      themeAnimationDuration: Duration.zero,
      home: _BrightnessSyncer(
        child: MainShellScreen(
          onThemeModeChanged: _setThemeMode,
          themeMode: _mode,
        ),
      ),
    );
  }
}

// Keeps AppColors._darkFallback in sync with the resolved theme.
// This is used by widgets that can't easily receive a BuildContext
// (e.g. static color helpers called outside build).
class _BrightnessSyncer extends StatelessWidget {
  final Widget child;
  const _BrightnessSyncer({required this.child});

  @override
  Widget build(BuildContext context) {
    AppColors.darkFallback = Theme.of(context).brightness == Brightness.dark;
    return child;
  }
}

