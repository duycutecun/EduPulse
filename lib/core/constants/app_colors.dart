import 'package:flutter/material.dart';

/// Palette màu theo phong cách Duolingo — tươi sáng, nổi bật.
/// Không hỗ trợ dark mode: toàn bộ app dùng chế độ sáng.
class AppColors {
  // ─── Brand Colors (Duolingo-style) ───────────────────────────────────────
  /// Xanh lá đậm #58CC02 — màu chủ đạo, dùng cho nút, progress, active states.
  static const Color primary = Color(0xFF58CC02);
  static const Color primaryDark = Color(0xFF46A302);
  static const Color primaryLight = Color(0xFFE7FBD0);

  static const Color green = primary;
  static const Color greenDark = primaryDark;
  static const Color greenLight = primaryLight;

  /// Xanh dương #1CB0F6 — phụ trợ cho icon, info badges.
  static const Color blue = Color(0xFF1CB0F6);
  static const Color blueDark = Color(0xFF1899D6);
  static const Color blueLight = Color(0xFFE1F3FB);

  /// Đỏ #FF5732 — warning, lỗi,삭제.
  static const Color red = Color(0xFFFF5732);
  static const Color redDark = Color(0xFFCC4428);
  static const Color redLight = Color(0xFFFFE4E1);

  /// Cam #FF9600 — nhắc nhở, priority cao.
  static const Color orange = Color(0xFFFF9600);
  static const Color orangeDark = Color(0xFFCC7A00);
  static const Color orangeLight = Color(0xFFFFF1E0);

  /// Vàng #FFC800 — streak flame, điểm XP, danh hiệu.
  static const Color yellow = Color(0xFFFFC800);
  static const Color yellowDark = Color(0xFFD4A800);
  static const Color yellowLight = Color(0xFFFFF9E0);

  /// Tím — AI features, phụ trợ.
  static const Color purple = Color(0xFF3F3FF3);
  static const Color purpleDark = Color(0xFF3232C9);
  static const Color purpleLight = Color(0xFFECECFE);

  // ─── Soft tinted backgrounds ─────────────────────────────────────────────
  static const Color greenSoft = Color(0xFFD7FFB8);
  static const Color blueSoft = Color(0xFFDDF4FF);
  static const Color redSoft = Color(0xFFFFE3E3);
  static const Color orangeSoft = Color(0xFFFFEBC9);
  static const Color purpleSoft = Color(0xFFF3E4FF);
  static const Color yellowSoft = Color(0xFFFFF4C9);

  // ─── Neutrals ────────────────────────────────────────────────────────────
  /// Background trang chính — trắng tinh.
  static const Color bgPage = Color(0xFFFFFFFF);
  static const Color bgPageSoft = Color(0xFFF5F7F5);

  /// Card — trắng, có viền mỏng.
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF8F9FA);

  /// Viền card — xám nhạt.
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFCDD1D5);

  /// Text.
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF555B6E);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);

  /// Nền phụ trợ cho chip, section.
  static const Color tertiaryBg = Color(0xFFF3F4F6);

  // ─── Semantic Aliases (đặc tả v2 §10.3) ──────────────────────────────────
  /// Ngữ nghĩa thay vì tên hiển thị — màn hình mới chỉ dùng nhóm này.
  static const Color background = bgPageSoft;
  static const Color surface = cardWhite;
  static const Color text = textPrimary;
  static const Color textSubtle = textSecondary;
  static const Color success = primary;
  static const Color successDark = primaryDark;
  static const Color successLight = primaryLight;
  static const Color warning = orange;
  static const Color warningDark = orangeDark;
  static const Color warningLight = orangeLight;
  static const Color error = red;
  static const Color errorDark = redDark;
  static const Color errorLight = redLight;
  static const Color info = blue;
  static const Color infoDark = blueDark;
  static const Color infoLight = blueLight;

  // ─── Duolingo-specific accents ──────────────────────────────────────────
  /// Xanh lá nhạt cho progress done.
  static const Color progressDone = Color(0xFF58CC02);

  /// Xanh lá rất nhạt cho fill.
  static const Color progressBg = Color(0xFFE8F5E0);

  /// Xám đỏ cho任务 thất bại / overdue.
  static const Color dangerBg = Color(0xFFFFE4E1);

  /// Vàng streak.
  static const Color streakGold = Color(0xFFFFC800);
  static const Color streakBg = Color(0xFFFFF9E0);
}
