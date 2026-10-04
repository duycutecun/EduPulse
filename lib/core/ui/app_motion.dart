import 'package:flutter/material.dart';

/// FE-6.6 — Tôn trọng lựa chọn "giảm chuyển động" của hệ điều hành.
///
/// Flutter hợp nhất "reduce motion" của iOS/Android thành
/// `MediaQuery.disableAnimations`. Mọi animation trang trí (shimmer, chuyển
/// cảnh) đi qua đây để học sinh nhạy cảm thị giác có trải nghiệm tĩnh, thay vì
/// tự đọc cờ ở từng widget và dễ bỏ sót.
abstract class AppMotion {
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Thời lượng hiệu ứng: về 0 khi người dùng bật giảm chuyển động.
  static Duration duration(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;
}
