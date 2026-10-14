import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';

/// G3-A — ngữ nghĩa phản hồi bằng BA kênh: icon + màu nền + chữ.
///
/// Trước đây mọi SnackBar đều nền xanh mặc định và chỉ có chữ: học sinh không
/// phân biệt được “đã xoá” với “không xoá được” nếu không đọc kỹ từng chữ.
/// Giờ mỗi loại có một icon riêng — người mù màu vẫn đọc được.
enum SnackKind {
  /// Hành động đã thành công.
  success(Icons.check_circle_rounded, AppColors.greenDark),

  /// Thông tin trung tính / thay đổi lịch.
  moved(Icons.event_rounded, AppColors.orangeDark),

  /// Xoá hẳn — cần nút Hoàn tác đi kèm.
  destructive(Icons.delete_rounded, AppColors.red),

  /// Không làm được vì lý do chủ quan (đã có dữ liệu, hết hạn…).
  warning(Icons.warning_rounded, AppColors.orangeDark),

  /// Lỗi hệ thống / thất bại.
  error(Icons.error_rounded, AppColors.redDark),

  /// Trạng thái trung tính, không có gì để ăn mừng.
  info(Icons.info_rounded, AppColors.blueDark);

  const SnackKind(this.icon, this.background);

  final IconData icon;
  final Color background;

  /// Nền snack đậm → chữ/nút luôn dùng trắng để đủ tương phản (WCAG AA).
  Color get onBackground => Colors.white;
}

/// Icon + chữ trong SnackBar. Tách riêng để phần trình bày không lẫn vào
/// logic của màn Home.
class SnackMessage extends StatelessWidget {
  const SnackMessage({super.key, required this.message, required this.kind});

  final String message;
  final SnackKind kind;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(kind.icon, size: 20, color: kind.onBackground),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: Text(
            message,
            style: AppTokens.body.copyWith(
              color: kind.onBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
