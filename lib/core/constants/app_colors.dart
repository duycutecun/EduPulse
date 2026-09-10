import 'package:flutter/material.dart';

class AppColors {
  // Call isDark(context) inside build() to get the current brightness.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Được đồng bộ từ theme thực tế (xem _BrightnessSyncer / MeshBackground).
  static bool darkFallback = false;

  // ─── Brand & Functional Colors (same in light & dark) ────────────────
  /// Màu thương hiệu — indigo #3F3FF3 (theo template "elegant login" v0),
  /// dùng thống nhất cho nút chính, link, icon active, progress.
  static const Color primary = Color(0xFF3F3FF3);
  static const Color primaryDark = Color(0xFF3232C9);
  static const Color primarySoft = Color(0xFFECECFE);

  // Tên cũ giữ lại làm alias để không vỡ code ngoài (deprecated dần).
  static const Color green = primary;
  static const Color greenDark = primaryDark;
  static const Color greenLight = primarySoft;

  static const Color blue = Color(0xFF1CB0F6);
  static const Color blueDark = Color(0xFF1899D6);
  static const Color red = Color(0xFFFF4B4B);
  static const Color redDark = Color(0xFFEA2B2B);
  static const Color orange = Color(0xFFFF9600);
  static const Color orangeDark = Color(0xFFCC7A00);
  static const Color yellow = Color(0xFFFFC800);
  static const Color purple = Color(0xFF3F3FF3);

  // ─── Soft tinted backgrounds (for dimensional icon tiles & chips) ───────
  static const Color greenSoft = Color(0xFFD7FFB8);
  static const Color blueSoft = Color(0xFFDDF4FF);
  static const Color redSoft = Color(0xFFFFE3E3);
  static const Color orangeSoft = Color(0xFFFFEBC9);
  static const Color purpleSoft = Color(0xFFF3E4FF);
  static const Color yellowSoft = Color(0xFFFFF4C9);

  // ─── Theme-dependent Neutrals (palette public để AppTheme dùng explicit) ──
  static const Color bgPageLight = Color(0xFFF7F7F7);
  static const Color bgPageDark = Color(0xFF141414);

  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF222222);

  static const Color borderLight = Color(0xFFE5E5E5);
  static const Color borderDark = Color(0xFF3A3A3A);

  static const Color borderStrongLight = Color(0xFFD7D7D7);
  static const Color borderStrongDark = Color(0xFF4D4D4D);

  static const Color textPrimaryLight = Color(0xFF4B4B4B);
  static const Color textPrimaryDark = Color(0xFFEDEDED);

  static const Color textSecondaryLight = Color(0xFF777777);
  static const Color textSecondaryDark = Color(0xFFB5B5B5);

  static const Color textMutedLight = Color(0xFFAFAFAF);
  static const Color textMutedDark = Color(0xFF8C8C8C);

  static const Color dividerLight = Color(0xFFE5E5E5);
  static const Color dividerDark = Color(0xFF3A3A3A);

  static const Color tertiaryLight = Color(0xFFF0F0F0);
  static const Color tertiaryDark = Color(0xFF1E1E1E);

  // ─── Resolved getters (theo darkFallback) ───────────────────────────────
  static Color get bgPage => darkFallback ? bgPageDark : bgPageLight;
  static Color get cardWhite => darkFallback ? cardDark : cardLight;
  static Color get border => darkFallback ? borderDark : borderLight;
  static Color get borderStrong =>
      darkFallback ? borderStrongDark : borderStrongLight;
  static Color get textPrimary =>
      darkFallback ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary =>
      darkFallback ? textSecondaryDark : textSecondaryLight;
  static Color get textMuted =>
      darkFallback ? textMutedDark : textMutedLight;
  static Color get divider => darkFallback ? dividerDark : dividerLight;
  static Color get tertiaryBg => darkFallback ? tertiaryDark : tertiaryLight;
}
