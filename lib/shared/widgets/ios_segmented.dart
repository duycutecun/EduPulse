import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Một mục của [IosSegmentedControl].
class IosSegmentItem {
  /// Nhãn chữ hiển thị trên segment.
  final String label;

  /// Icon nhỏ bên cạnh nhãn (tùy chọn — không truyền là có nhãn thôi).
  final IconData? icon;

  const IosSegmentItem({required this.label, this.icon});
}

/// Segmented control kiểu iOS (CupertinoSlidingSegmentedControl) dựng thuần
/// bằng token `ios*` sẵn có — KHÔNG thêm phụ thuộc mới.
///
/// Viên thuốc trượt (pill) được animate bằng [AnimatedAlign] qua các vị trí
/// đều nhau, nên với N segment đều nhau pill luôn khớp đúng segment chọn.
/// Nhấn một segment thì gọi [onChanged]; haptic/giọng phản hồi do màn cha lo
/// (widget này giữ nguyên thuần hiển thị, test được độc lập).
class IosSegmentedControl extends StatelessWidget {
  final List<IosSegmentItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  const IosSegmentedControl({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  })  : assert(items.length >= 2, 'Cần ít nhất 2 segment'),
        assert(index >= 0 && index < items.length, 'Index nằm ngoài danh sách');

  /// Vị trí align của pill với N segment đều nhau: -1, 0, +1…
  double get _alignment => (index * 2 / (items.length - 1)) - 1;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chuyển nhóm trong tab',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.iosFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.iosSeparator, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            height: 36,
            child: Stack(
              children: [
                // Viên pill nền trượt — chỉ vẽ, không chặn touch (IgnorePointer).
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(_alignment, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / items.length,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.iosCard,
                        borderRadius: BorderRadius.circular(9),
                        border:
                            Border.all(color: AppColors.iosSeparator, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Cách hàng chạm dọc theo độ rộng đều.
                Row(
                  children: [
                    for (final (i, item) in items.indexed)
                      Expanded(child: _buildSegment(context, i, item)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegment(BuildContext context, int i, IosSegmentItem item) {
    final selected = i == index;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        key: Key('ios-segment-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: FittedBox(
            key: ValueKey<bool>(selected),
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon,
                      size: 16,
                      color: selected
                          ? AppColors.iosPrimary
                          : AppColors.iosTextMuted),
                  const SizedBox(width: 5),
                ],
                Text(
                  item.label,
                  maxLines: 1,
                  // KHÔNG wrap: nhãn dài 1 dòng — nếu quá rộng segment thì
                  // FittedBox co cả cụm lại vừa khít, không bao giờ tràn
                  // RenderFlex ở màn 320px hay cỡ chữ hệ thống lớn.
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.iosTextPrimary
                        : AppColors.iosTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
