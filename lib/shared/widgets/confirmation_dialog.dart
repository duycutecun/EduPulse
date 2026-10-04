import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import 'primary_button.dart';

/// Hộp thoại xác nhận an toàn cho các hành động quan trọng/phá hủy (FE-0.3, AI-0.1, FE-2.5).
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? highlightedItem;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.highlightedItem,
    this.confirmLabel = 'Xác nhận',
    this.cancelLabel = 'Hủy',
    this.isDestructive = false,
    required this.onConfirm,
    this.onCancel,
  });

  /// Tiện ích mở dialog nhanh chóng.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String? highlightedItem,
    String confirmLabel = 'Xác nhận',
    String cancelLabel = 'Hủy',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        content: content,
        highlightedItem: highlightedItem,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.brXl),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          if (isDestructive) ...[
            Container(
              padding: const EdgeInsets.all(AppTokens.space8),
              decoration: const BoxDecoration(
                color: AppColors.redLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.red,
                size: AppTokens.iconMd,
              ),
            ),
            const SizedBox(width: AppTokens.space12),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTokens.heading2,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, style: AppTokens.body),
          if (highlightedItem != null) ...[
            const SizedBox(height: AppTokens.space12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space12,
                vertical: AppTokens.space8,
              ),
              decoration: BoxDecoration(
                color:
                    isDestructive ? AppColors.redLight : AppColors.primaryLight,
                borderRadius: AppTokens.brMd,
              ),
              child: Text(
                highlightedItem!,
                style: AppTokens.heading3.copyWith(
                  color:
                      isDestructive ? AppColors.redDark : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.all(AppTokens.space16),
      actions: [
        SecondaryButton(
          label: cancelLabel,
          onPressed: () {
            if (onCancel != null) {
              onCancel!();
            } else {
              Navigator.of(context).pop(false);
            }
          },
        ),
        PrimaryButton(
          label: confirmLabel,
          backgroundColor: isDestructive ? AppColors.red : AppColors.primary,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}
