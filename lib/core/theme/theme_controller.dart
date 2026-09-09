import 'package:flutter/material.dart';
import '../utils/storage_service.dart';

/// Quản lý chế độ giao diện (sáng/tối/theo hệ thống) với persistence.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(_load());

  static ThemeMode _load() {
    switch (StorageService.getThemeMode()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static void set(ThemeMode m) {
    StorageService.setThemeMode(m.name);
    mode.value = m;
  }
}