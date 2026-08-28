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

  // ─── Legacy aliases (kept for compatibility) ─────────────────────────────
  // Fixed-color aliases
  static const Color iosBlue = green;
  static const Color iosGreen = green;
  static const Color iosIndigo = green;
  static const Color iosOrange = orange;
  static const Color iosPink = red;
  static const Color iosPurple = purple;
  static const Color iosRed = red;
  static const Color iosTeal = blue;
  static const Color iosYellow = yellow;

  static const Color appleBlue = green;
  static const Color appleGreen = green;
  static const Color appleIndigo = green;
  static const Color appleOrange = orange;
  static const Color applePurple = purple;
  static const Color appleRed = red;
  static const Color appleYellow = yellow;
  static const Color appleTeal = blue;

  static const Color neonCyan = blue;
  static const Color neonPurple = purple;
  static const Color neonOrange = orange;
  static const Color neonGreen = green;

  static const Color brandStart = green;
  static const Color brandEnd = greenDark;

  // Theme-dependent aliases
  static Color get iosSystemBg => bgPage;
  static Color get iosGroupedBg => bgPage;
  static Color get iosSecondaryGrouped => cardWhite;
  static Color get iosTertiaryGrouped => tertiaryBg;
  static Color get iosElevated => cardWhite;
  static Color get iosBarBg => cardWhite;

  static Color get iosSystemBgLight => bgPage;
  static Color get iosSecondaryGroupedLight => cardWhite;
  static Color get iosTertiaryGroupedLight => tertiaryBg;
  static Color get iosBarBgLight => cardWhite;

  static Color get iosSeparator => border;
  static Color get iosBorder => border;
  static Color get iosBorderLight => border;

  static Color get textMainDark => textPrimary;
  static Color get textMutedDark => textSecondary;
  static Color get textSubtleDark => textMuted;

  static Color get textMainLight => textPrimary;
  static Color get textMutedLight => textSecondary;
  static Color get textSubtleLight => textMuted;

  static const Color examUrgent = red;
  static const Color examSoon = orange;
  static const Color examFuture = green;

  static const Color primary500 = green;
  static const Color primary600 = greenDark;
  static Color get darkCard => cardWhite;
  static Color get darkBorder => border;
  static Color get darkBg => bgPage;
  static Color get darkSidebar => cardWhite;
  static Color get darkSecondary => tertiaryBg;
  static Color get darkInput => tertiaryBg;
  static Color get textMutedDark2 => textSecondary;
  static Color get textSubtleDark2 => textMuted;
  static const Color riskCritical = red;
  static const Color riskWarning = orange;
  static const Color riskNormal = green;
  static const Color riskCriticalBg = Color(0x2EFF453A);
  static const Color riskWarningBg = Color(0x2EFF9600);
  static const Color riskNormalBg = Color(0x2E58CC02);
  static const Color accentPurple = purple;
}
