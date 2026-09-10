import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../constants/app_colors.dart';

class AppTheme {
  /// Dùng palette explicit (không qua darkFallback) để theme luôn đúng
  /// bất kể thứ tự build.
  ///
  /// Cache static final: không dựng lại text theme mỗi lần đổi theme. Font
  /// Nunito được bundle local (xem pubspec.yaml) nên không phải tải từ mạng.
  static final ThemeData lightTheme = _build(
    brightness: Brightness.light,
    bg: AppColors.bgPageLight,
    card: AppColors.cardLight,
    border: AppColors.borderLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    muted: AppColors.textMutedLight,
    tertiary: AppColors.tertiaryLight,
  );

  static final ThemeData darkTheme = _build(
    brightness: Brightness.dark,
    bg: AppColors.bgPageDark,
    card: AppColors.cardDark,
    border: AppColors.borderStrong,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    muted: AppColors.textMutedDark,
    tertiary: AppColors.tertiaryDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color card,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color muted,
    required Color tertiary,
  }) {
    final baseTextTheme = ThemeData(brightness: brightness)
        .textTheme
        .apply(
          bodyColor: textPrimary,
          displayColor: textPrimary,
          fontFamily: 'Nunito',
        );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      error: AppColors.red,
      onError: Colors.white,
      surface: card,
      onSurface: textPrimary,
      surfaceContainerHighest: tertiary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: AppColors.primary,
      colorScheme: colorScheme,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: AppColors.primary,
        barBackgroundColor: card,
        scaffoldBackgroundColor: bg,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.primary,
          textStyle: TextStyle(color: textPrimary),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
