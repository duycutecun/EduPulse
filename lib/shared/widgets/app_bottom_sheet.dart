import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Bottom sheet chuẩn của app (đặc tả mục 30):
/// - **Drag handle** thanh ngang mờ trên cùng — kéo xuống để đóng.
/// - **Contextual height**: thấp vừa nội dung, max 85% màn hình.
/// - Kết hợp `DraggableScrollableSheet` cho nội dung dài — kéo list
///   đến đỉnh thì expand, kéo xuống thì thu về/đóng.
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
    builder: (sheetContext) => _SheetShell(child: builder(sheetContext)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(3),
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
