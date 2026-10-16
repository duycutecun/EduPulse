import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import 'primary_button.dart';

/// Hộp thoại xác nhận an toàn cho các hành động quan trọng/phá hủy (FE-0.3, AI-0.1, FE-2.5).
///
/// Khi mở, focus tự chuyển vào nút chính để phím nhảy theo dialog (accessibility
/// + tránh focus bị "mất" phía sau barrier).
class ConfirmationDialog extends StatefulWidget {
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
  State<ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<ConfirmationDialog> {
  late final FocusNode _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Đợi frame đầu rồi nhảy focus vào nút Xác nhận — tránh focus bị "mất" phía
    // sau barrier khi dialog mở (accessibility bắt buộc).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confirmFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.brXl),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          if (widget.isDestructive) ...[
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
              widget.title,
              style: AppTokens.heading2,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.content, style: AppTokens.body),
          if (widget.highlightedItem != null) ...[
            const SizedBox(height: AppTokens.space12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space12,
                vertical: AppTokens.space8,
              ),
              decoration: BoxDecoration(
                color:
                    widget.isDestructive ? AppColors.redLight : AppColors.primaryLight,
                borderRadius: AppTokens.brMd,
              ),
              child: Text(
                widget.highlightedItem!,
                style: AppTokens.heading3.copyWith(
                  color:
                      widget.isDestructive ? AppColors.redDark : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.all(AppTokens.space16),
      actions: [
        SecondaryButton(
          label: widget.cancelLabel,
          onPressed: () {
            if (widget.onCancel != null) {
              widget.onCancel!();
            } else {
              Navigator.of(context).pop(false);
            }
          },
        ),
        PrimaryButton(
          focusNode: _confirmFocus,
          label: widget.confirmLabel,
          backgroundColor: widget.isDestructive ? AppColors.red : AppColors.primary,
          onPressed: widget.onConfirm,
        ),
      ],
    );
  }
}
