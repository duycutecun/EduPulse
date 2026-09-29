import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/storage_service.dart';

/// Chiều rộng tối thiểu để chuyển sang layout desktop với sidebar
/// (đặc tả mục 22: Mobile < 768, Tablet 768–1024, Desktop ≥ 1024).
const double kDesktopBreakpoint = 1024;

bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Mô tả một mục điều hướng (dùng chung cho bottom nav và sidebar).
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Sidebar desktop (đặc tả mục 23): cùng visual language với bottom nav
/// nhưng khác layout. Có thể **collapse** — expanded hiển thị icon + nhãn
/// + avatar user, collapsed chỉ còn icon với tooltip (mục 23: "Collapsed:
/// Icons + tooltip").
class DesktopSidebar extends StatelessWidget {
  final int index;
  final List<NavItem> items;
  final ValueChanged<int> onChanged;

  /// Số mục desktop nhiều hơn mobile (mục 52: Học, Calendar, Goals, Focus,
  /// AI, Notes, Tôi) — các mục phụ mở bằng callback thay vì đổi tab chính.
  final List<DesktopNavAction> secondaryItems;

  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final String userName;

  const DesktopSidebar({
    super.key,
    required this.index,
    required this.items,
    required this.onChanged,
    required this.secondaryItems,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.userName,
  });

  static const double _widthExpanded = 232;
  static const double _widthCollapsed = 72;

  @override
  Widget build(BuildContext context) {
    final divider = AppColors.border.withValues(alpha: 0.5);
    // Switch tức thời (không animate width) để tránh RenderFlex overflow
    // trong transition — đặc tả ưu tiên tốc độ hơn visual effect (mục 55).
    return Container(
      width: collapsed ? _widthCollapsed : _widthExpanded,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(right: BorderSide(color: divider, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment:
              collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            // Nút thu gọn/mở rộng.
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 0 : 12, vertical: 10),
              child: collapsed
                  ? Center(
                      child: _collapseButton(),
                    )
                  : Row(
                      children: [
                        _collapseButton(),
                        const SizedBox(width: 8),
                        const Text('EduPulse',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                      ],
                    ),
            ),
            Divider(color: divider, height: 1),
            const SizedBox(height: 8),
            // Mục chính = 3 tab (Học, AI, Tôi).
            for (var i = 0; i < items.length; i++)
              _navRow(
                context,
                icon: i == index ? items[i].activeIcon : items[i].icon,
                label: items[i].label,
                active: i == index,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (i != index) onChanged(i);
                },
              ),
            const SizedBox(height: 8),
            // Mục phụ: mở trang riêng từ sidebar (Calendar, Goals, Focus…).
            for (final action in secondaryItems)
              _navRow(
                context,
                icon: action.icon,
                label: action.label,
                active: false,
                onTap: action.onOpen,
              ),
            const Spacer(),
            Divider(color: divider, height: 1),
            // Avatar user ở đáy sidebar (mục 23: collapsed có avatar).
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 0 : 12, vertical: 10),
              child: collapsed
                  ? Center(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.greenSoft,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.greenSoft,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collapseButton() {
    return IconButton(
      tooltip: collapsed ? 'Mở rộng thanh điều hướng' : 'Thu gọn thanh điều hướng',
      onPressed: onToggleCollapse,
      icon: Icon(
        collapsed
            ? Icons.chevron_right_rounded
            : Icons.chevron_left_rounded,
        size: 22,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _navRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final row = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 12, vertical: 2),
      child: Material(
        color: active ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 22,
                    color: active ? AppColors.primary : AppColors.textMuted),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : AppColors.textPrimary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return collapsed
        ? Tooltip(message: label, child: row)
        : row;
  }
}

/// Một mục phụ trên sidebar desktop — mở trang full-screen.
class DesktopNavAction {
  final IconData icon;
  final String label;
  final VoidCallback onOpen;

  const DesktopNavAction({
    required this.icon,
    required this.label,
    required this.onOpen,
  });
}

/// Lưu trạng thái collapse của sidebar.
class SidebarPreference {
  SidebarPreference._();

  static bool get isCollapsed =>
      StorageService.getBool('desktop_sidebar_collapsed') ?? false;

  static void setCollapsed(bool v) =>
      StorageService.setBool('desktop_sidebar_collapsed', v);
}
