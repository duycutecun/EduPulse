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
    setState(() {
      _mode = mode;
      StorageService.setThemeMode(mode);
    });
  }

  void _syncBrightness(Brightness brightness) {
    AppColors.currentBrightness = brightness;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        _syncBrightness(brightness);
        return child!;
      },
      home: MainShellScreen(
        onThemeModeChanged: _setThemeMode,
        themeMode: _mode,
      ),
    );
  }
}
