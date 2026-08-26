import 'package:flutter/material.dart';

class AppColors {
  // Apple System Palette (Dark Mode Default)
  static const Color iosBlue = Color(0xFF0A84FF);
  static const Color iosGreen = Color(0xFF30D158);
  static const Color iosIndigo = Color(0xFF5E5CE6);
  static const Color iosOrange = Color(0xFFFF9F0A);
  static const Color iosPink = Color(0xFFFF375F);
  static const Color iosPurple = Color(0xFFBF5AF2);
  static const Color iosRed = Color(0xFFFF453A);
  static const Color iosTeal = Color(0xFF64D2FF);
  static const Color iosYellow = Color(0xFFFFD60A);

  // Modern Neon & Apple Aliases
  static const Color appleBlue = iosBlue;
  static const Color appleGreen = iosGreen;
  static const Color appleIndigo = iosIndigo;
  static const Color appleOrange = iosOrange;
  static const Color applePurple = iosPurple;
  static const Color appleRed = iosRed;
  static const Color appleYellow = iosYellow;
  static const Color appleTeal = iosTeal;

  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFFBD00FF);
  static const Color neonOrange = Color(0xFFFF6D00);
  static const Color neonGreen = Color(0xFF00E676);

  // Brand Gradient Colors
  static const Color brandStart = Color(0xFF5E5CE6);  // Indigo
  static const Color brandEnd   = Color(0xFF0A84FF);  // Blue

  // Apple Inset Grouped Backgrounds
  static const Color iosSystemBg         = Color(0xFF000000);
  static const Color iosGroupedBg        = Color(0xFF000000);
  static const Color iosSecondaryGrouped = Color(0xFF1C1C1E);
  static const Color iosTertiaryGrouped  = Color(0xFF2C2C2E);
  static const Color iosElevated         = Color(0xFF1C1C1E);
  static const Color iosBarBg            = Color(0xE0161618);

  // Light Mode
  static const Color iosSystemBgLight         = Color(0xFFF2F2F7);
  static const Color iosSecondaryGroupedLight = Color(0xFFFFFFFF);
  static const Color iosTertiaryGroupedLight  = Color(0xFFE5E5EA);
  static const Color iosBarBgLight            = Color(0xEEF6F6F6);

  // Separators & Borders
  static const Color iosSeparator    = Color(0x5C545458);
  static const Color iosBorder       = Color(0x1FFFFFFF);
  static const Color iosBorderLight  = Color(0x1A000000);

  // Text Colors Dark
  static const Color textMainDark    = Color(0xFFFFFFFF);
  static const Color textMutedDark   = Color(0xFF8E8E93);
  static const Color textSubtleDark  = Color(0xFF636366);

  // Text Colors Light
  static const Color textMainLight   = Color(0xFF000000);
  static const Color textMutedLight  = Color(0xFF6C6C70);
  static const Color textSubtleLight = Color(0xFF8E8E93);

  // Exam Risk Colors
  static const Color examUrgent  = iosRed;
  static const Color examSoon    = iosOrange;
  static const Color examFuture  = iosGreen;

  // Backward compat
  static const Color primary500 = iosBlue;
  static const Color primary600 = Color(0xFF007AFF);
  static const Color darkCard   = iosSecondaryGrouped;
  static const Color darkBorder = iosBorder;
  static const Color darkBg     = iosSystemBg;
  static const Color darkSidebar = Color(0xFF141416);
  static const Color darkSecondary = iosTertiaryGrouped;
  static const Color darkInput     = iosTertiaryGrouped;
  static const Color textMutedDark2 = textMutedDark;
  static const Color textSubtleDark2 = textSubtleDark;
  static const Color riskCritical = iosRed;
  static const Color riskWarning  = iosOrange;
  static const Color riskNormal   = iosGreen;
  static const Color riskCriticalBg = Color(0x2EFF453A);
  static const Color riskWarningBg  = Color(0x2EFF9F0A);
  static const Color riskNormalBg   = Color(0x2E30D158);
  static const Color accentPurple   = iosPurple;
}
