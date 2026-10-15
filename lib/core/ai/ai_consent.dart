import 'package:flutter/material.dart';

import '../utils/storage_service.dart';

/// Cổng quyền riêng tư cho MỌI luồng AI đọc/phân tích dữ liệu học tập (§8).
///
/// Hai công tắc nằm ở Tôi → Cloud & AI, mặc định BẬT; người dùng tắt đi nghĩa
/// là chặn gửi dữ liệu học tập (điểm thi thử, ghi chú, lịch sử học…) lên AI.
/// Mọi điểm gọi AI kèm dữ liệu học tập phải đi qua [ensure] trước khi gọi —
/// nếu không, dữ liệu vẫn bị gửi đi dù người dùng đã tắt quyền.
class AiConsent {
  AiConsent._();

  /// AI được phép ĐỌC dữ liệu học tập (cờ `ai_permission_read`).
  static bool get mayRead =>
      StorageService.getBool('ai_permission_read') ?? true;

  /// AI được phép PHÂN TÍCH dữ liệu học tập (cờ `ai_permission_analyze`).
  static bool get mayAnalyze =>
      StorageService.getBool('ai_permission_analyze') ?? true;

  /// Có đủ quyền đọc + phân tích dữ liệu học tập.
  static bool get canAnalyzeData => mayRead && mayAnalyze;

  /// `true` nếu được phép đi tiếp; nếu bị chặn thì hiện SnackBar hướng dẫn
  /// bật lại quyền và trả `false`. Dùng: `if (!AiConsent.ensure(context)) return;`
  static bool ensure(BuildContext context) {
    if (canAnalyzeData) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Bạn đã tắt quyền cho AI đọc/phân tích dữ liệu. Bật lại ở Tôi → Cloud & AI nhé!'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ));
    return false;
  }
}
