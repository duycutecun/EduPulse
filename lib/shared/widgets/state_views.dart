import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/ui/app_motion.dart';
import 'primary_button.dart';

/// Trạng thái rỗng chuẩn mực với biểu tượng nhẹ nhàng và hành động gợi ý.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppTokens.iconXl,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTokens.heading2,
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTokens.bodySubtle,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTokens.space20),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trạng thái báo lỗi thân thiện, có nút thử lại.
class ErrorStateView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorStateView({
    super.key,
    this.title = 'Đã có lỗi xảy ra',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.redLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: AppTokens.iconXl,
                color: AppColors.red,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTokens.heading2.copyWith(color: AppColors.redDark),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTokens.bodySubtle,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.space20),
              SecondaryButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Khối xương (skeleton) có hiệu ứng shimmer — dùng khi chờ dữ liệu để cảm
/// giác tải mượt thay vì spinner trắng. Tự tắt chuyển động khi người dùng bật
/// "giảm chuyển động" (FE-6.6).
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Chỉ chạy shimmer khi người dùng KHÔNG bật giảm chuyển động — tránh
    // ticker vô hạn (và tránh treo `pumpAndSettle` trong test).
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box(Color color) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: widget.borderRadius,
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Giảm chuyển động: giữ một sắc tĩnh, không nhấp nháy.
    if (AppMotion.reduced(context)) {
      return _box(AppColors.border);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => _box(
        Color.lerp(AppColors.border, AppColors.bgPageSoft, _controller.value)!,
      ),
    );
  }
}

/// Danh sách dòng xương gợi hình dạng nội dung đang tải.
class SkeletonList extends StatelessWidget {
  final int lines;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.lines = 4,
    this.padding = const EdgeInsets.all(AppTokens.space16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space12),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: i.isEven ? 1.0 : 0.7,
                child: const SkeletonBox(height: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Trạng thái đang tải mượt mà.
class LoadingStateView extends StatelessWidget {
  final String? message;

  const LoadingStateView({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTokens.space16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTokens.bodySubtle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
