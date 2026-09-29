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

/// Thanh điều hướng bottom — phong cách Duolingo: nền trắng, icon xanh lá
/// khi active, font bold, bo tròn, haptic nhẹ khi chuyển tab.
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
    // Viền ngang mảnh giữa nội dung và bottom nav.
    final divider = AppColors.border.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
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
                      Stack(
                        children: [
                          // Nền xanh lá nổi behind icon active.
                          if (active)
                            Positioned(
                              top: 2,
                              bottom: 2,
                              left: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          Icon(
                            active ? item.activeIcon : item.icon,
                            size: 24,
                            color: active ? AppColors.primary : AppColors.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
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
