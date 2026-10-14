import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/pwa/pwa_service.dart';
import '../../core/sync/change_outbox.dart';
import '../../core/sync/sync_state.dart';
import '../../core/utils/feedback_service.dart';
import '../../core/utils/supabase_service.dart';
import 'app_icon.dart';
import 'glass_card.dart';
import 'primary_button.dart';

/// Chip trạng thái đồng bộ gọn (cho sidebar desktop + footer tab Tôi).
///
/// Đặc tả mục 19 — Sync states: Online/Syncing/Synced/Offline hiển thị
/// nhẹ nhàng, không chặn thao tác, không gây lo lắng khi offline. Kế hoạch 7.2
/// bổ sung điều mà trước đây thiếu: chip **nói ra còn bao nhiêu thay đổi nằm
/// trên máy** và cho **chạm để thử lại** thay vì bắt người dùng mò vào cài đặt.
class SyncStatusBar extends StatelessWidget {
  final bool compact;

  const SyncStatusBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: SyncStateService.state,
      builder: (context, sync, _) {
        // Số thay đổi chờ nằm trong hàng đợi, không trong state — nghe thêm
        // hàng đợi để chip nhảy số ngay khi có thao tác học mới.
        return ValueListenableBuilder<int>(
          valueListenable: ChangeOutbox.revision,
          builder: (context, _, __) {
            // Ưu tiên tín hiệu mạng trực tiếp — listener service có thể lag.
            final offline =
                !PwaService.isOnline || sync.status == SyncStatus.offline;
            return _SyncChip(sync: sync, offline: offline, compact: compact);
          },
        );
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

    final retryable = _retryable;
    final chip = Container(
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
          if (retryable) ...[
            const SizedBox(width: 6),
            Icon(Icons.refresh_rounded, size: 14, color: color),
          ],
        ],
      ),
    );

    if (!retryable) return chip;
    // Có thay đổi chưa lên cloud → chip vừa báo vừa là nút thử lại.
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        FeedbackService.selection();
        SyncStateService.retryNow();
      },
      child: Tooltip(message: 'Chạm để đồng bộ ngay', child: chip),
    );
  }

  /// Còn thay đổi chưa lên cloud (kể cả đang ngoại tuyến) → chip bấm được.
  /// Cloud chưa cấu hình thì không có gì để thử lại, cũng không hiện số.
  bool get _retryable => sync.visiblePending > 0 || sync.visibleFailed > 0;

  (IconData, Color, String) _resolve() {
    final pending = sync.visiblePending;
    final failed = sync.visibleFailed;
    // Có thay đổi gửi lỗi: nói rõ số lượng và mời thử lại, thay vì câu chung
    // chung "chưa sync được" khiến người dùng không biết còn gì tồn đọng.
    if (failed > 0) {
      return (
        Icons.cloud_off_rounded,
        AppColors.orange,
        '$failed thay đổi chưa gửi được — chạm để thử lại',
      );
    }
    if (offline) {
      return (
        Icons.wifi_off_rounded,
        AppColors.orange,
        sync.status == SyncStatus.syncing && !PwaService.isOnline
            ? 'Ngoại tuyến — thử lại sau'
            : pending > 0
                ? 'Ngoại tuyến — $pending thay đổi chờ gửi'
                : 'Ngoại tuyến — lưu trên máy',
      );
    }
    switch (sync.status) {
      case SyncStatus.syncing:
        return (
          Icons.sync_rounded,
          AppColors.blue,
          pending > 0 ? 'Đang đồng bộ $pending thay đổi…' : 'Đang đồng bộ…',
        );
      case SyncStatus.error:
        return (
          Icons.cloud_off_rounded,
          AppColors.orange,
          'Chưa sync được — thử lại sau',
        );
      case SyncStatus.synced:
      case SyncStatus.offline:
        if (pending > 0) {
          return (
            Icons.cloud_queue_rounded,
            AppColors.blue,
            '$pending thay đổi chờ đồng bộ',
          );
        }
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

/// Thẻ trạng thái đồng bộ đầy đủ cho màn Cá nhân (kế hoạch 7.2).
///
/// Chip nhỏ ở sidebar trả lời câu "đang ổn không"; thẻ này trả lời câu người
/// dùng thực sự tự hỏi khi mở cài đặt: *dữ liệu của tôi đã lên cloud chưa, còn
/// bao nhiêu thay đổi chưa gửi, và nếu lỗi thì bấm vào đâu?* — kèm nút đồng bộ
/// lại ngay tại chỗ, không bắt mò sang nơi khác.
///
/// Không hiện con số "N thay đổi" khi máy chưa bật cloud: lúc đó câu đó vô
/// nghĩa và chỉ làm người dùng lo (xem [SyncState.visiblePending]).
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: SyncStateService.state,
      builder: (context, sync, _) => ValueListenableBuilder<int>(
        valueListenable: ChangeOutbox.revision,
        builder: (context, _, __) => _SyncStatusCardBody(sync: sync),
      ),
    );
  }
}

class _SyncStatusCardBody extends StatelessWidget {
  final SyncState sync;

  const _SyncStatusCardBody({required this.sync});

  @override
  Widget build(BuildContext context) {
    final view = _resolve();

    return GlassCard(
      key: const Key('account-sync-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                view.icon,
                tileSize: 40,
                iconSize: 20,
                color: view.color,
                bg: view.color.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      view.detail,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (view.actionLabel != null) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              key: const Key('account-sync-retry'),
              label: view.actionLabel!,
              icon: Icons.sync_rounded,
              height: AppTokens.minTouchTarget,
              onPressed: () {
                FeedbackService.selection();
                SyncStateService.retryNow();
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Trạng thái hiển thị được suy ra từ: cloud có bật không → có thay đổi gửi
  /// lỗi không → có mạng không → đang gửi không → còn gì chờ không → còn lại.
  ///
  /// Thứ tự này quan trọng: "gửi lỗi" phải được nói trước "đang đồng bộ", nếu
  /// không thì một vòng sync hỏng sẽ bị giấu sau câu "đang đồng bộ…" trông như
  /// mọi thứ vẫn ổn.
  _StatusView _resolve() {
    final pending = sync.visiblePending;
    final failed = sync.visibleFailed;
    final offline = !PwaService.isOnline || sync.status == SyncStatus.offline;

    if (!SupabaseService.cloudSyncEnabled) {
      if (SupabaseService.isLoggedIn) {
        return const _StatusView(
          icon: Icons.cloud_off_rounded,
          color: AppColors.orange,
          title: 'Chưa kết nối được cloud',
          detail:
              'Dữ liệu vẫn an toàn trên máy. App sẽ tự kết nối lại khi sẵn sàng.',
        );
      }
      return const _StatusView(
        icon: Icons.phone_iphone_rounded,
        color: AppColors.textMuted,
        title: 'Dữ liệu lưu trên máy này',
        detail: 'Đăng nhập để sao lưu và đồng bộ giữa các thiết bị.',
      );
    }

    if (failed > 0) {
      return _StatusView(
        icon: Icons.cloud_off_rounded,
        color: AppColors.orange,
        title: '$failed thay đổi chưa gửi được',
        detail: 'Dữ liệu vẫn an toàn trên máy. Thử lại khi có mạng trở lại.',
        actionLabel: 'Thử lại',
      );
    }

    if (offline) {
      return _StatusView(
        icon: Icons.wifi_off_rounded,
        color: AppColors.orange,
        title: 'Ngoại tuyến — dữ liệu lưu an toàn trên máy',
        detail: pending > 0
            ? '$pending thay đổi sẽ tự gửi khi có mạng trở lại.'
            : 'Sẽ tự đồng bộ khi có mạng trở lại.',
      );
    }

    if (sync.status == SyncStatus.syncing) {
      return _StatusView(
        icon: Icons.sync_rounded,
        color: AppColors.blue,
        title: sync.label,
        detail: pending > 0
            ? 'Quá trình chạy nền — bạn cứ tiếp tục học.'
            : 'Đang kiểm tra dữ liệu trên cloud.',
      );
    }

    if (pending > 0) {
      return _StatusView(
        icon: Icons.cloud_queue_rounded,
        color: AppColors.blue,
        title: '$pending thay đổi chờ đồng bộ',
        detail: 'Đồng bộ ngay để dữ liệu lên cloud và máy khác.',
        actionLabel: 'Đồng bộ ngay',
      );
    }

    return _StatusView(
      icon: Icons.cloud_done_rounded,
      color: AppColors.primary,
      title: sync.label,
      detail: 'Dữ liệu trên máy đã khớp với cloud.',
    );
  }
}

class _StatusView {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String? actionLabel;

  const _StatusView({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.actionLabel,
  });
}
