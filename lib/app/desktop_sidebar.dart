import 'package:flutter/material.dart';
import '../../../../core/utils/feedback_service.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/storage_service.dart';
import '../shared/widgets/sync_status_bar.dart';

/// Ngưỡng breakpoint (đặc tả mục 22: Mobile < 768, Tablet 768–1024,
/// Desktop ≥ 1024).
const double kTabletBreakpoint = 768;
const double kDesktopBreakpoint = 1024;

bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

bool isTabletWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= kTabletBreakpoint && w < kDesktopBreakpoint;
}

/// Cả tablet lẫn desktop dùng layout sidebar (thay vì bottom nav của phone) —
/// tablet dùng rail thu gọn để tận dụng chiều ngang thay vì phóng to giao diện
/// điện thoại (FE-6.2).
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpoint;

/// Mô tả một mục điều hướng (dùng chung cho bottom nav và sidebar).
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Intent di chuyển focus trong sidebar — hướng nằm trong Action.
class _SidebarMoveIntent extends Intent {
  final int delta;
  const _SidebarMoveIntent([this.delta = 1]);
}

/// Action di chuyển focus trong sidebar — binding tạo ở _navRow.

/// Sidebar desktop (đặc tả mục 23): cùng visual language với bottom nav
/// nhưng khác layout. Có thể **collapse** — expanded hiển thị icon + nhãn
/// + avatar user, collapsed chỉ còn icon với tooltip (mục 23: "Collapsed:
/// Icons + tooltip").
///
/// Keyboard navigation (mục 21 — Desktop keyboard navigation): Tab đi vào
/// sidebar, mũi tên lên/xuống di chuyển giữa các mục, Enter/Space kích
/// hoạt. Focus ring mặc định của Material được giữ nguyên làm indicator.
class DesktopSidebar extends StatefulWidget {
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

  @override
  DesktopSidebarState createState() => DesktopSidebarState();
}

/// State công khai để widget test có thể điều khiển focus trực tiếp.
class DesktopSidebarState extends State<DesktopSidebar> {
  static const double _widthExpanded = 232;
  static const double _widthCollapsed = 72;

  /// FocusNode của từng mục nav (main + secondary), theo thứ tự hiển thị.
  final List<FocusNode> navFocusNodes = [];
  final FocusNode _collapseNode = FocusNode();

  int get _totalNavItems => widget.items.length + widget.secondaryItems.length;

  @override
  void initState() {
    super.initState();
    _syncNodeCount();
  }

  @override
  void didUpdateWidget(covariant DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodeCount();
  }

  /// Đảm bảo số FocusNode khớp số mục nav (mục phụ có thể đổi runtime).
  void _syncNodeCount() {
    while (navFocusNodes.length < _totalNavItems) {
      navFocusNodes
          .add(FocusNode(debugLabel: 'sidebar-nav-${navFocusNodes.length}'));
    }
    while (navFocusNodes.length > _totalNavItems) {
      navFocusNodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final node in navFocusNodes) {
      node.dispose();
    }
    _collapseNode.dispose();
    super.dispose();
  }

  /// Di chuyển focus lên/xuống qua các mục nav, wrap ở hai đầu.
  void moveFocus(int delta) {
    if (navFocusNodes.isEmpty) return;
    final current = navFocusNodes.indexWhere((n) => n.hasFocus);
    var next = current < 0 ? 0 : current + delta;
    if (next < 0) next = navFocusNodes.length - 1;
    if (next >= navFocusNodes.length) next = 0;
    navFocusNodes[next].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final divider = AppColors.border.withValues(alpha: 0.5);
    // Switch tức thời (không animate width) để tránh RenderFlex overflow
    // trong transition — đặc tả ưu tiên tốc độ hơn visual effect (mục 55).
    return Container(
      width: widget.collapsed ? _widthCollapsed : _widthExpanded,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(right: BorderSide(color: divider, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: widget.collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            // Nút thu gọn/mở rộng.
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 12, vertical: 10),
              child: widget.collapsed
                  ? Center(child: _collapseButton())
                  : Row(
                      children: [
                        _collapseButton(),
                        const SizedBox(width: 8),
                        // Sidebar hẹp cố định 232px: cỡ chữ lớn phải cắt nhãn
                        // chứ không tràn ra ngoài.
                        const Flexible(
                          child: Text(
                            'EduPulse',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
            ),
            Divider(color: divider, height: 1),
            const SizedBox(height: 8),
            // Mục chính = 3 tab (Học, AI, Tôi).
            for (var i = 0; i < widget.items.length; i++)
              _navRow(
                context,
                focusNode: navFocusNodes[i],
                icon: i == widget.index
                    ? widget.items[i].activeIcon
                    : widget.items[i].icon,
                label: widget.items[i].label,
                active: i == widget.index,
                onTap: () {
                  FeedbackService.selection();
                  if (i != widget.index) widget.onChanged(i);
                },
              ),
            const SizedBox(height: 8),
            // Mục phụ: mở trang riêng từ sidebar (Calendar, Goals, Focus…).
            for (var j = 0; j < widget.secondaryItems.length; j++)
              _navRow(
                context,
                focusNode: navFocusNodes[widget.items.length + j],
                icon: widget.secondaryItems[j].icon,
                label: widget.secondaryItems[j].label,
                active: false,
                onTap: widget.secondaryItems[j].onOpen,
              ),
            const Spacer(),
            Divider(color: divider, height: 1),
            // Trạng thái sync (mục 19) — chip gọn ngay trên avatar.
            Padding(
              padding: EdgeInsets.fromLTRB(widget.collapsed ? 0 : 12, 8, 12, 0),
              child: widget.collapsed
                  ? const Center(child: SyncStatusBar(compact: true))
                  : const SyncStatusBar(),
            ),
            // Avatar user ở đáy sidebar (mục 23: collapsed có avatar).
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 12, vertical: 10),
              child: widget.collapsed
                  ? Center(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.greenSoft,
                        child: Text(
                          widget.userName.isNotEmpty
                              ? widget.userName[0].toUpperCase()
                              : '?',
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
                            widget.userName.isNotEmpty
                                ? widget.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(widget.userName,
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
      tooltip: widget.collapsed
          ? 'Mở rộng thanh điều hướng'
          : 'Thu gọn thanh điều hướng',
      focusNode: _collapseNode,
      onPressed: widget.onToggleCollapse,
      icon: Icon(
        widget.collapsed
            ? Icons.chevron_right_rounded
            : Icons.chevron_left_rounded,
        size: 22,
        color: AppColors.textMuted,
      ),
    );
  }

  /// Một mục nav có thể focus bằng bàn phím (mục 21 — Desktop keyboard
  /// navigation): arrow keys di chuyển giữa các mục, Enter/Space kích hoạt.
  /// Traversal mặc định của Tab bị tắt trong mục để arrow keys là chuẩn.
  Widget _navRow(
    BuildContext context, {
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final row = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed ? 0 : 12, vertical: 2),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowDown): _SidebarMoveIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _SidebarMoveIntent(-1),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SidebarMoveIntent: _SidebarMoveAction(this),
          },
          child: Material(
            color: active
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              focusNode: focusNode,
              // Tab skip qua mục nav — điều hướng chính bằng arrow keys.
              child: Container(
                height: 42,
                // G4-C: vạch chỉ báo bên trái. Khi sidebar mở rộng, người dùng
                // đã đọc được trạng thái qua màu chữ + nét đậm; nhưng lúc THU
                // GỌN chỉ còn icon, màu chữ gần như không đủ để phân biệt —
                // vạch này là tín hiệu duy nhất còn lại nên phải luôn hiện.
                key: active ? const Key('sidebar-active-indicator') : null,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? const Border(
                          left: BorderSide(color: AppColors.primary, width: 3),
                        )
                      : null,
                ),
                padding:
                    EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12),
                child: Row(
                  mainAxisAlignment: widget.collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(icon,
                        size: 22,
                        color:
                            active ? AppColors.primary : AppColors.textMuted),
                    if (!widget.collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.collapsed ? Tooltip(message: label, child: row) : row;
  }
}

/// Action di chuyển focus theo hướng của intent, wrap ở hai đầu.
class _SidebarMoveAction extends Action<_SidebarMoveIntent> {
  final DesktopSidebarState state;

  _SidebarMoveAction(this.state);

  @override
  Object? invoke(_SidebarMoveIntent intent) {
    state.moveFocus(intent.delta);
    return null;
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
