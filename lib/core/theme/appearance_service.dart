import 'package:flutter/foundation.dart';

import '../utils/storage_service.dart';

/// Appearance (đặc tả mục 20 — Accessibility & Appearance):
///
/// - **Font size adaptive**: 3 mức S/M/L áp qua `textScaler` toàn app —
///   tôn trọng both cài đặt user và hệ điều hành (scale nhân với system
///   scale hiện có, không ghi đè).
/// - Dark mode: app chủ động khóa light (Duolingo-style) — palette tối
///   chưa đủ chuẩn production, nên không fake switch.
/// - Giảm chuyển động đã có ở tab Tôi (mục 20 Reduced motion).
///
/// Service dùng ValueNotifier để MaterialApp rebuild khi user đổi mức.
class AppearanceService {
  AppearanceService._();

  static const double _small = 0.9;
  static const double _normal = 1.0;
  static const double _large = 1.15;

  static final ValueNotifier<double> fontScale = ValueNotifier<double>(_normal);

  /// Gọi một lần sau `StorageService.init()` trước `runApp`.
  static void load() {
    fontScale.value = _stored;
    _loadHighContrast();
  }

  static double get _stored {
    switch (StorageService.getString('appearance_font_scale')) {
      case 'small':
        return _small;
      case 'large':
        return _large;
      default:
        return _normal;
    }
  }

  static String get fontScaleKey {
    if (fontScale.value <= _small + 0.01) return 'small';
    if (fontScale.value >= _large - 0.01) return 'large';
    return 'normal';
  }

  static void setFontScale(double scale) {
    fontScale.value = scale.clamp(0.8, 1.4);
    // Lưu key tương ứng (hoặc giá trị số nếu trong tương lai có slider).
    switch (fontScale.value) {
      case _small:
        StorageService.setString('appearance_font_scale', 'small');
      case _large:
        StorageService.setString('appearance_font_scale', 'large');
      default:
        StorageService.setString('appearance_font_scale', 'normal');
    }
  }

  /// Đặt mức theo key UI: 'small' | 'normal' | 'large'.
  static void setFontScaleByKey(String key) {
    switch (key) {
      case 'small':
        setFontScale(_small);
      case 'large':
        setFontScale(_large);
      default:
        setFontScale(_normal);
    }
  }

  // ── High contrast (mục 21 — Accessibility) ─────────────────────────
  // Tăng độ tương phản viền/chữ: viền đậm hơn, chữ phụ tối hơn.
  // Không đổi palette brand — chỉ tăng contrast của tầng phụ trợ.
  static final ValueNotifier<bool> highContrast = ValueNotifier(false);

  static bool get storedHighContrast =>
      StorageService.getBool('appearance_high_contrast') ?? false;

  static void setHighContrast(bool v) {
    highContrast.value = v;
    StorageService.setBool('appearance_high_contrast', v);
  }

  /// Gọi trong load() để khôi phục cài đặt trước runApp.
  static void _loadHighContrast() {
    highContrast.value = storedHighContrast;
  }
}
