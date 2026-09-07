import 'package:flutter/material.dart';

/// Bảng màu chính thức của linh vật mèo Cú Sĩ tử.
///
/// Trích xuất từ ảnh icon hiện tại (`assets/images/mascot.png`,
/// `web/icons/Icon-512.png`):
/// - Lông kem `#E6E3DD`, vùng đậm `#B9B3AA`
/// - Tai trong / mũi nâu-vàng `#C08040`
/// - Mắt đen viền đậm
/// - Má hồng `#D9A9A9`
/// - Chân nâu sẫm `#7A5648`
/// - Viền đen nét to kiểu "kawaii outline" `#1A1A1A`
abstract final class MascotPalette {
  static const Color furLight = Color(0xFFE6E3DD);
  static const Color furMid = Color(0xFFD9D5CE);
  static const Color furDark = Color(0xFFB9B3AA);
  static const Color belly = Color(0xFFF4F1EA);
  static const Color earInner = Color(0xFFC99B66);
  static const Color nose = Color(0xFFC08040);
  static const Color paw = Color(0xFF7A5648);
  static const Color blush = Color(0x59D9A9A9);
  static const Color outline = Color(0xFF1A1A1A);
  static const Color eyeWhite = Color(0xFFFFFFFF);

  /// Màu nền icon / splash — nền vàng-kem của icon hiện tại.
  static const Color iconBackground = Color(0xFFE0C080);
}