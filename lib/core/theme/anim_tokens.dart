import 'package:flutter/material.dart';

/// Bộ token chuẩn hoá cho animation toàn app:
/// - Tránh trùng lặp magic number (duration / curve) giữa các màn hình
/// - Một chỗ chỉnh, mọi nơi đồng bộ
/// - Theo phong cách "Duolingo flat": spring nhẹ + easeOutCubic kết thúc dứt khoát
abstract final class AnimTokens {
  // Duration
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration med = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 400);

  // Mascot
  static const Duration mascotFloat = Duration(milliseconds: 3000);
  static const Duration mascotTap = Duration(milliseconds: 380);
  static const Duration mascotEarTwitch = Duration(milliseconds: 320);
  static const Duration mascotParticle = Duration(milliseconds: 850);
  static const Duration mascotBlink = Duration(milliseconds: 180);
  static const Duration mascotQuote = Duration(milliseconds: 250);

  // Các Curve dùng chung
  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutSine = Curves.easeInOutSine;
  static const Curve easeInSine = Curves.easeInSine;

  /// Kiểm tra chế độ giảm chuyển động của hệ điều hành.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;
}