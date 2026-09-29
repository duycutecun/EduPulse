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

  static final ValueNotifier<double> fontScale =
      ValueNotifier<double>(_normal);

  /// Gọi một lần sau `StorageService.init()` trước `runApp`.
  static void load() {
    fontScale.value = _stored;
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
}
