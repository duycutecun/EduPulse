import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/pwa/pwa_service.dart';
import '../../core/sync/sync_state.dart';

/// Chip trạng thái đồng bộ gọn (cho sidebar desktop + footer tab Tôi).
///
/// Đặc tả mục 19 — Sync states: Online/Syncing/Synced/Offline hiển thị
/// nhẹ nhàng, không chặn thao tác, không gây lo lắng khi offline.
class SyncStatusBar extends StatelessWidget {
  final bool compact;

  const SyncStatusBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: SyncStateService.state,
      builder: (context, sync, _) {
        // Ưu tiên tín hiệu mạng trực tiếp — listener service có thể lag.
        final offline = !PwaService.isOnline ||
            sync.status == SyncStatus.offline;
        return _SyncChip(sync: sync, offline: offline, compact: compact);
      },
    );
  }
}

class _SyncChip extends StatelessWidget {
  final SyncState sync;
  final bool offline;
  final bool compact;

  const _SyncChip({
    required this.sync,
    required this.offline,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _resolve();

    if (compact) {
      return Tooltip(
        message: label,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _resolve() {
    if (offline) {
      return (
        Icons.wifi_off_rounded,
        AppColors.orange,
        sync.status == SyncStatus.syncing && !PwaService.isOnline
            ? 'Ngoại tuyến — thử lại sau'
            : 'Ngoại tuyến — lưu trên máy',
      );
    }
    switch (sync.status) {
      case SyncStatus.syncing:
        return (Icons.sync_rounded, AppColors.blue, 'Đang đồng bộ…');
      case SyncStatus.error:
        return (
          Icons.cloud_off_rounded,
          AppColors.orange,
          'Chưa sync được — thử lại sau',
        );
      case SyncStatus.synced:
      case SyncStatus.offline:
        final last = sync.lastSyncedAtMs;
        if (last == null) {
          return (Icons.cloud_rounded, AppColors.textMuted, 'Chưa đồng bộ');
        }
        final dt = DateTime.fromMillisecondsSinceEpoch(last);
        final diff = DateTime.now().difference(dt);
        final label = diff.inMinutes < 1
            ? 'Đã đồng bộ vừa xong'
            : diff.inHours < 1
                ? 'Đã đồng bộ ${diff.inMinutes} phút trước'
                : diff.inDays < 1
                    ? 'Đã đồng bộ ${diff.inHours} giờ trước'
                    : 'Đã đồng bộ ${dt.day}/${dt.month}';
        return (Icons.cloud_done_rounded, AppColors.primary, label);
    }
  }
}
