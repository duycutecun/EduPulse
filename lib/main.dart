import 'package:flutter/material.dart';
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
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = StorageService.isDarkMode();
  }

  void _toggleTheme() {
    setState(() {
      _isDark = StorageService.isDarkMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPulse — Trợ lý Sĩ tử & Đếm ngược Kỳ thi',
      debugShowCheckedModeBanner: false,
      theme: _isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: MainShellScreen(
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
