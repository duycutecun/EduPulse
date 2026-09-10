import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

/// Mô tả một mục trong bottom navigation (icon + nhãn).
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Chuyển tab giữ state bằng [IndexedStack] + thanh navigation tĩnh.
class TabChrome extends StatelessWidget {
  final int index;
  final List<Widget> children;
  final List<NavItem> items;
  final ValueChanged<int> onChanged;

  const TabChrome({
    super.key,
    required this.index,
    required this.children,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: index,
            children: children,
          ),
        ),
        _buildNav(context),
      ],
    );
  }

  Widget _buildNav(BuildContext context) {
    // Hairline divider mảnh kiểu iOS thay vì border dày 2px.
    final divider = AppColors.border.withValues(alpha: 0.6);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == index;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (i != index) onChanged(i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        size: 23,
                        color: active ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          color:
                              active ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
