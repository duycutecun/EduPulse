import 'package:flutter/material.dart';

class AppColors {
  // Call isDark(context) inside build() to get the current brightness.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Forced false — the app is light-mode only (dark mode removed).
  static bool darkFallback = false;

  // ─── Fixed Functional Colors (same in light & dark) ─────────────────────
  static const Color green = Color(0xFF58CC02);
  static const Color greenDark = Color(0xFF58A700);
  static const Color greenLight = Color(0xFFD7FFB8);

  static const Color blue = Color(0xFF1CB0F6);
  static const Color blueDark = Color(0xFF1899D6);
  static const Color red = Color(0xFFFF4B4B);
  static const Color redDark = Color(0xFFEA2B2B);
  static const Color orange = Color(0xFFFF9600);
  static const Color orangeDark = Color(0xFFCC7A00);
  static const Color yellow = Color(0xFFFFC800);
  static const Color purple = Color(0xFFCE82FF);

  // ─── Soft tinted backgrounds (for dimensional icon tiles & chips) ───────
  static const Color greenSoft = Color(0xFFD7FFB8);
  static const Color blueSoft = Color(0xFFDDF4FF);
  static const Color redSoft = Color(0xFFFFE3E3);
  static const Color orangeSoft = Color(0xFFFFEBC9);
  static const Color purpleSoft = Color(0xFFF3E4FF);
  static const Color yellowSoft = Color(0xFFFFF4C9);

  // ─── Theme-dependent Neutrals ───────────────────────────────────────────
  // App is light-mode only (dark mode removed). These light values are used
  // unconditionally.
  static const Color _bgPageLight = Color(0xFFF7F7F7);

  static const Color _cardLight = Color(0xFFFFFFFF);

  static const Color _borderLight = Color(0xFFE5E5E5);

  static const Color _borderStrongLight = Color(0xFFD7D7D7);

  static const Color _textPrimaryLight = Color(0xFF4B4B4B);

  static const Color _textSecondaryLight = Color(0xFF777777);

  static const Color _textMutedLight = Color(0xFFAFAFAF);

  static const Color _dividerLight = Color(0xFFE5E5E5);

  static const Color _tertiaryLight = Color(0xFFF0F0F0);

  // ─── Resolved getters (always light) ────────────────────────────────────
  static Color get bgPage => _bgPageLight;
  static Color get cardWhite => _cardLight;
  static Color get border => _borderLight;
  static Color get borderDark => _borderStrongLight;
  static Color get textPrimary => _textPrimaryLight;
  static Color get textSecondary => _textSecondaryLight;
  static Color get textMuted => _textMutedLight;
  static Color get divider => _dividerLight;
  static Color get tertiaryBg => _tertiaryLight;
}
