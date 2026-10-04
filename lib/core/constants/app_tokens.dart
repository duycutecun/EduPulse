import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Semantic design tokens for EduPulse v2.
/// Guarantees consistent spacing, radiuses, elevations, icon sizes, and touch targets.
abstract class AppTokens {
  // ─── Spacing Tokens ────────────────────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // ─── Radius Tokens ─────────────────────────────────────────────────────────
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2Xl = 24.0;
  static const double radiusFull = 999.0;

  static const Radius rXs = Radius.circular(radiusXs);
  static const Radius rSm = Radius.circular(radiusSm);
  static const Radius rMd = Radius.circular(radiusMd);
  static const Radius rLg = Radius.circular(radiusLg);
  static const Radius rXl = Radius.circular(radiusXl);
  static const Radius r2Xl = Radius.circular(radius2Xl);

  static const BorderRadius brXs = BorderRadius.all(rXs);
  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
  static const BorderRadius br2Xl = BorderRadius.all(r2Xl);
  static const BorderRadius brFull =
      BorderRadius.all(Radius.circular(radiusFull));

  // ─── Icon Sizes ────────────────────────────────────────────────────────────
  static const double iconXs = 14.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;
  static const double iconHero = 48.0;

  // ─── Touch Targets (Mobile & Accessibility Compliant) ─────────────────────
  /// Minimum touch target size according to Material and iOS guidelines (44-48px).
  static const double minTouchTarget = 44.0;
  static const double standardTouchTarget = 48.0;

  // ─── Elevations & Shadows ──────────────────────────────────────────────────
  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowModal = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  // ─── Typography Helpers ────────────────────────────────────────────────────
  static const TextStyle displayTimer = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 54,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  /// Tiêu đề khối/nhóm (G4-A): nặng hơn [heading3], nhỏ hơn [heading2].
  /// Trước đó chỗ này hay viết thẳng `fontSize: 16, w800` rải rác ở mỗi
  /// widget, dẫn tới lệch nhau khi ai đó chỉnh một chỗ — nay gom về đây.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Nhãn nhỏ cho nút/chip phụ (G4-A). Dùng khi nút cần nhỏ hơn chữ thân bài
  /// nhưng vẫn phải đủ tương phản để bấm.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySubtle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: Colors.white,
  );
}
