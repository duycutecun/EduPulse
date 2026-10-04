import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import 'state_views.dart';

/// Khung xương hình dạng một thẻ nhiệm vụ (G3-C).
///
/// Vì sao không dùng `SkeletonList`: danh sách nhiệm vụ gần như luôn có cấu
/// trúc cụ thể — tiêu đề, môn, thời lượng — nên vẽ sẵn bố cục đó giúp người
/// dùng đoán trước nội dung sắp tới, chờ vui hơn là nhìn màn trắng.
///
/// Chiều rộng các thanh giảm dần và ngẫu nhiên theo `index` để danh sách
/// không trông giống hệt nhau lặp đi lặp lại.
class SkeletonTaskCard extends StatelessWidget {
  const SkeletonTaskCard({super.key, this.index = 0});

  /// Vị trí trong danh sách — chỉ để làm các thanh lệch nhau một chút.
  final int index;

  @override
  Widget build(BuildContext context) {
    // Dao động nhẹ theo index: 0.78 / 0.62 / 0.9… — đủ để tự nhiên mà
    // không tạo cảm giác "random lung tung" khi màn hình vừa hiện.
    final ratios = <double>[0.85, 0.62, 0.92, 0.7];
    final titleWidth = ratios[index % ratios.length];

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng tiêu đề: ô tròn môn + tiêu đề nhiệm vụ.
          Row(
            children: [
              const SkeletonBox(width: 36, height: 36),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: titleWidth,
                      child: const SkeletonBox(height: 15),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    const SkeletonBox(width: 70, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          // Hàng chip phụ: thời lượng, giờ hẹn, mức ưu tiên.
          Row(
            children: [
              const SkeletonBox(width: 52, height: 12),
              const SizedBox(width: AppTokens.space8),
              const SkeletonBox(width: 64, height: 12),
              const SizedBox(width: AppTokens.space8),
              const SkeletonBox(width: 40, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Danh sách khung xương nhiệm vụ dùng khi dữ liệu chưa về.
class SkeletonTaskList extends StatelessWidget {
  const SkeletonTaskList({super.key, this.count = 3, this.padding});

  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(AppTokens.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) SkeletonTaskCard(index: i),
        ],
      ),
    );
  }
}
