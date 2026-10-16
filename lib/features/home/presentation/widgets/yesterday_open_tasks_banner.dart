import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';

/// Banner trung tính cho «việc mở từ hôm qua» (V2-M1').
///
/// Vì sao trung tính: không trình bày accusing «(delayed 7 tasks!»); chỉ ghi
/// «Còn N việc mở từ hôm qua» với màu/grayscale soft. Z ordering precedence
/// phải subordinate to today's primary card (gap ≥ `AppTokens.space12`).
class YesterdayOpenTasksBanner extends StatelessWidget {
  final int count;

  const YesterdayOpenTasksBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final label = count == 1
        ? 'Còn 1 việc mở từ hôm qua'
        : 'Còn $count việc mở từ hôm qua';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space4,
      ),
      child: Material(
        color: AppColors.iosFill,
        borderRadius: AppTokens.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space12,
            vertical: AppTokens.space10,
          ),
          decoration: BoxDecoration(
            borderRadius: AppTokens.brMd,
            border: Border.all(color: AppColors.iosSeparator),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: AppTokens.iconSm,
                color: AppColors.iosTextSecondary,
              ),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  label,
                  style: AppTokens.bodySubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
