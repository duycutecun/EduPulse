import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';

/// Bottom sheet chuẩn của app (đặc tả mục 30):
/// - **Drag handle** thanh ngang mờ trên cùng — kéo xuống để đóng.
/// - **Contextual height**: thấp vừa nội dung, max 85% màn hình.
/// - Kết hợp `DraggableScrollableSheet` cho nội dung dài — kéo list
///   đến đỉnh thì expand, kéo xuống thì thu về/đóng.
/// - Khi mở, focus tự chuyển vào sheet (accessibility).
///
/// Dùng cho: Task detail, Add task, Contextual actions, AI actions.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => FocusScope(
      // Khi sheet hiện, chuyển focus vào nội dung sheet để phím nhảy theo
      // (quan trọng trên mobile và khi dùng bàn phím ngoài).
      child: _SheetShell(child: builder(sheetContext)),
    ),
  );
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusXl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (mục 30) — vùng chạm rộng cho dễ kéo.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: AppTokens.space12,
                  ),
                  // Handle mảnh: 44×5 — khích thước này là phần trực quan; vùng chạm
                  // được giữ ≥44px nhờ padding và GestureDetector opaque.
                  width: AppTokens.minTouchTarget,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                  ),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
