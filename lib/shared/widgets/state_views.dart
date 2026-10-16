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
                color: AppColors.iosPrimarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppTokens.iconXl,
                color: AppColors.iosPrimaryDark,
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

/// Trạng thái rỗng cho **một vùng nội dung** (trong thẻ, trong sheet, trong
/// danh sách con) — cùng ngôn ngữ hình ảnh với [EmptyStateView] nhưng thu gọn.
///
/// Vì sao cần: trước đây mỗi màn tự dựng một kiểu rỗng — chỗ chỉ một dòng chữ,
/// chỗ emoji 48px, chỗ khối có nút — nên cùng một tình huống "chưa có dữ liệu"
/// lại trông khác nhau ở mỗi nơi. Panel này giữ đúng cấu trúc ba câu trả lời
/// (thiếu gì / vì sao quan trọng / làm gì tiếp theo) và chỉ nhận diện bằng một
/// khuôn duy nhất, để người dùng học cách đọc nó một lần là đọc được mọi chỗ.
class EmptyStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Gắn cho nút hành động để test/`find.byKey` trỏ tới đúng nút này.
  final Key? actionKey;
  final IconData? actionIcon;

  /// Màu nhấn cho biểu tượng — đổi theo ngữ cảnh (môn học, AI, cảnh báo).
  final Color accent;

  /// Hàng gọn (biểu tượng + chữ + nút) cho vùng hẹp như sheet hoặc danh sách
  /// lồng, thay vì khối canh giữa.
  final bool compact;

  /// Bản xếp dọc nhưng tiết kiệm chiều cao: biểu tượng nằm ngay cạnh tiêu đề
  /// thay vì chiếm một hàng riêng. Dùng cho vùng rỗng nằm sâu trong một màn
  /// dài — ở đó CTA phải còn trong tầm mắt, không bị đẩy xuống dưới.
  final bool dense;

  final EdgeInsetsGeometry padding;

  const EmptyStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.actionIcon,
    this.accent = AppColors.iosPrimary,
    this.compact = false,
    this.dense = false,
    this.padding = const EdgeInsets.all(AppTokens.space16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.iosFill,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: AppColors.iosSeparator),
      ),
      child: compact
          ? _compactBody()
          : dense
              ? _denseBody()
              : _blockBody(),
    );
  }

  Widget _denseBody() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(28, AppTokens.iconSm),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  title,
                  style: AppTokens.heading3.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            description,
            style: AppTokens.bodySubtle.copyWith(fontSize: 12),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTokens.space10),
            PrimaryButton(
              key: actionKey,
              label: actionLabel!,
              icon: actionIcon,
              height: AppTokens.minTouchTarget,
              onPressed: onAction,
            ),
          ],
        ],
      );

  Widget _badge(double size, double iconSize) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: accent),
      );

  Widget _blockBody() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(48, AppTokens.iconLg),
          const SizedBox(height: AppTokens.space12),
          Text(title, textAlign: TextAlign.center, style: AppTokens.heading3),
          const SizedBox(height: AppTokens.space4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTokens.bodySubtle,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTokens.space16),
            PrimaryButton(
              key: actionKey,
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ],
      );

  Widget _compactBody() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(32, AppTokens.iconSm),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTokens.heading3.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  description,
                  style: AppTokens.bodySubtle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppTokens.space8),
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: AppTokens.labelSmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      );
}

/// Trạng thái lỗi cho **một vùng nội dung** — bản thu gọn của
/// [ErrorStateView]. Dùng khi phần còn lại của màn vẫn hoạt động được (ví dụ:
/// số liệu cục bộ vẫn đúng, chỉ nhánh AI không gọi được), nên lỗi phải nằm
/// ngay tại vùng đó kèm nút thử lại thay vì trôi qua dưới dạng toast.
class ErrorStatePanel extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final EdgeInsetsGeometry padding;

  const ErrorStatePanel({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Thử lại',
    this.padding = const EdgeInsets.all(AppTokens.space12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.iosErrorSoft,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: AppColors.iosError.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: AppTokens.iconSm, color: AppColors.iosErrorDark),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Text(
              message,
              style: AppTokens.bodySubtle.copyWith(
                fontSize: 12,
                color: AppColors.iosErrorDark,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppTokens.space8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTokens.space8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                retryLabel,
                style: AppTokens.labelSmall.copyWith(
                  color: AppColors.iosErrorDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
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
                color: AppColors.iosErrorSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: AppTokens.iconXl,
                color: AppColors.iosError,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTokens.heading2.copyWith(color: AppColors.iosErrorDark),
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
      return _box(AppColors.iosSeparator);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => _box(
        Color.lerp(
            AppColors.iosSeparator, AppColors.iosFill, _controller.value)!,
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
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.iosPrimary),
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
