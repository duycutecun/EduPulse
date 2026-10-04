import 'package:flutter/material.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';

/// Nút chính (CTA) nổi bật nhất trên màn hình theo phong cách Duolingo/EduPulse v2.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final String? tooltip;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = AppTokens.standardTouchTarget,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.primary;
    final effectiveText = textColor ?? Colors.white;

    Widget button = SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: (isLoading || onPressed == null)
            ? null
            : () {
                FeedbackService.light();
                onPressed!();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBg,
          foregroundColor: effectiveText,
          disabledBackgroundColor: effectiveBg.withValues(alpha: 0.5),
          disabledForegroundColor: effectiveText.withValues(alpha: 0.8),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppTokens.brLg,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space20),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveText),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppTokens.iconMd, color: effectiveText),
                    const SizedBox(width: AppTokens.space8),
                  ],
                  // Nhãn luôn co lại được: nút nằm trong hàng hẹp (sheet chi tiết, cột phụ
                  // desktop…) thì nhãn dài phải cắt bằng ellipsis chứ không được
                  // tràn ra ngoài.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.button.copyWith(color: effectiveText),
                    ),
                  ),
                ],
              ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

/// Nút phụ (Secondary) có viền tinh tế, dùng cho thao tác thứ cấp.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? borderColor;
  final Color? textColor;
  final double? width;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.borderColor,
    this.textColor,
    this.width,
    this.height = AppTokens.standardTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? AppColors.border;
    final effectiveText = textColor ?? AppColors.textPrimary;

    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                FeedbackService.selection();
                onPressed!();
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveText,
          side: BorderSide(color: effectiveBorder, width: 1.5),
          shape: const RoundedRectangleBorder(
            borderRadius: AppTokens.brLg,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppTokens.iconMd, color: effectiveText),
              const SizedBox(width: AppTokens.space8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.button.copyWith(
                  color: effectiveText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút icon có diện tích chạm đạt chuẩn WCAG (tối thiểu 44px).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconColor,
    this.backgroundColor,
    this.size = AppTokens.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: AppTokens.brMd,
        child: InkWell(
          borderRadius: AppTokens.brMd,
          onTap: onPressed == null
              ? null
              : () {
                  FeedbackService.selection();
                  onPressed!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: AppTokens.iconMd,
              color: iconColor ?? AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
