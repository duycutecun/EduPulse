import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../constants/app_colors.dart';

/// Theme theo phong cách Duolingo: nền trắng, card trắng, viền mỏng,
/// font Nunito bold, màu xanh lá #58CC02 làm primary.
/// Không có dark mode — app luôn ở chế độ sáng.
/// **High contrast** (mục 21): bật → viền đậm hơn, chữ phụ tối hơn,
/// đủ điều kiện WCAG AA, không đổi palette brand.
class AppTheme {
  /// Theme sáng mặc định (tương thích nơi gọi cũ).
  static final ThemeData lightTheme = _build(highContrast: false);

  /// Theme sáng + biến thể high contrast.
  static ThemeData lightWithContrast(bool highContrast) =>
      _build(highContrast: highContrast);

  static ThemeData _build({required bool highContrast}) {
    // Màu tương phản: viền đậm hơn, chữ phụ/mờ tối hơn khi bật.
    final border = highContrast ? AppColors.borderStrong : AppColors.border;
    final textSecondary =
        highContrast ? const Color(0xFF3D4450) : AppColors.textSecondary;
    final textMuted =
        highContrast ? const Color(0xFF4A5260) : AppColors.textMuted;

    final textTheme =
        Typography.englishLike2021.apply(fontFamily: 'Nunito').copyWith(
              headlineLarge: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 32,
                height: 1.2,
                color: AppColors.textPrimary,
              ),
              headlineMedium: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                height: 1.25,
                color: AppColors.textPrimary,
              ),
              headlineSmall: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
              titleLarge: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
              titleMedium: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
              bodyLarge: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
              bodyMedium: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.4,
                color: textSecondary,
              ),
              bodySmall: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.4,
                color: textSecondary,
              ),
              labelLarge: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
              labelMedium: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
                color: textSecondary,
              ),
              labelSmall: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                height: 1.35,
                color: textMuted,
              ),
            );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgPage,

      /// Font: Nunito (đã bundle trong pubspec.yaml).
      textTheme: textTheme,

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.blue,
        onSecondary: Colors.white,
        error: AppColors.red,
        onError: Colors.white,
        surface: AppColors.cardWhite,
        onSurface: AppColors.textPrimary,
      ),

      /// AppBar trắng, không elevation — như Duolingo.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),

      /// Dialog trắng, viền mỏng (đậm hơn khi high contrast).
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: highContrast ? 1.5 : 1),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      /// Snackbar nổi, trắng.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      /// Card trắng, viền 1px, không shadow (phẳng như Duolingo).
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: highContrast ? 1.5 : 1),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: highContrast ? 1.5 : 1,
        space: 1,
      ),

      /// Input: trắng, viền nhạt, focus xanh lá.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: highContrast ? 1.5 : 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: highContrast ? 1.5 : 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
      ),

      /// Chip: nền xanh lá, chữ trắng, bo tròn.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: AppColors.primary),
      ),

      /// Button: Duolingo-style — nền xanh lá, chữ trắng, bo tròn 12.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      /// Text button: xanh lá nhạt, chữ xanh lá.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      /// FAB: xanh lá, bo tròn 16.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: CircleBorder(),
      ),

      /// Cupertino override.
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        barBackgroundColor: AppColors.cardWhite,
        scaffoldBackgroundColor: AppColors.bgPage,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.primary,
          textStyle: TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
