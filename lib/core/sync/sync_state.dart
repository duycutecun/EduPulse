import 'dart:async';
import 'package:flutter/foundation.dart';
import '../pwa/pwa_service.dart';
import '../utils/storage_service.dart';
import '../utils/supabase_service.dart';

/// Trạng thái đồng bộ dữ liệu local → cloud (đặc tả mục 19 — Sync states).
///
/// Quy tắc mục 19:
/// - **Offline** là trạng thái mặc định an toàn — dữ liệu luôn lưu local
///   trước, cloud chỉ là sao lưu (local-first).
/// - **Syncing** hiển thị tiến trình nhẹ nhàng, không chặn thao tác.
/// - **Synced** xác nhận ngắn gọn kèm thời điểm, tạo cảm giác an tâm mà
///   không gây gián đoạn (Calm principle).
enum SyncStatus { synced, syncing, offline, error }

/// Không hiển thị gì — người dùng chỉ cần biết khi có gì đó đáng chú ý.
class SyncState {
  final SyncStatus status;

  /// Thời điểm sync thành công gần nhất (local epoch ms), null khi chưa từng.
  final int? lastSyncedAtMs;

  /// Thông điệp ngắn khi [status] là [SyncStatus.error].
  final String? errorMessage;

  const SyncState({
    required this.status,
    this.lastSyncedAtMs,
    this.errorMessage,
  });

  /// Câu mô tả cho UI. Không dùng ngôn ngữ gây lo lắng — lỗi sync là
  /// bình thường khi offline, dữ liệu vẫn an toàn trên máy.
  String get label {
    switch (status) {
      case SyncStatus.synced:
        final t = lastSyncedAtMs;
        if (t == null) return 'Chưa đồng bộ';
        final dt = DateTime.fromMillisecondsSinceEpoch(t);
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 1) return 'Đã đồng bộ vừa xong';
        if (diff.inHours < 1) return 'Đã đồng bộ ${diff.inMinutes} phút trước';
        if (diff.inDays < 1) return 'Đã đồng bộ ${diff.inHours} giờ trước';
        return 'Đã đồng bộ ${dt.day}/${dt.month}';
      case SyncStatus.syncing:
        return 'Đang đồng bộ…';
      case SyncStatus.offline:
        return 'Ngoại tuyến — dữ liệu lưu an toàn trên máy';
      case SyncStatus.error:
        return errorMessage ?? 'Chưa đồng bộ được — thử lại khi sẵn sàng';
    }
  }
}

/// Service trung tâm báo trạng thái sync cho mọi UI (banner, sidebar,
/// tab Tôi). Pattern giống PwaService: ValueNotifier + static facade.
class SyncStateService {
  static final ValueNotifier<SyncState> state = ValueNotifier<SyncState>(
    const SyncState(status: SyncStatus.synced),
  );

  static const String _lastSyncKey = 'last_cloud_sync_ms';
  static Timer? _autoTimer;

  static SyncStatus get status => state.value.status;

  /// Ghi dấu một lần sync thành công và phát [SyncStatus.synced].
  static void markSynced() {
    final now = DateTime.now().millisecondsSinceEpoch;
    StorageService.setInt(_lastSyncKey, now);
    state.value = SyncState(
      status: SyncStatus.synced,
      lastSyncedAtMs: now,
    );
  }

  /// Đánh dấu đang sync.
  static void markSyncing() {
    state.value = SyncState(
      status: SyncStatus.syncing,
      lastSyncedAtMs: StorageService.getInt(_lastSyncKey),
    );
  }

  /// Đánh dấu sync lỗi (vd timeout) — không gây hoang mang, có thể thử lại.
  static void markError([String? message]) {
    state.value = SyncState(
      status: SyncStatus.error,
      lastSyncedAtMs: StorageService.getInt(_lastSyncKey),
      errorMessage: message,
    );
  }

  /// Cập nhật trạng thái offline/online từ PwaService.
  static void updateConnectivity({required bool isOnline}) {
    if (state.value.status == SyncStatus.syncing && isOnline) return;
    state.value = SyncState(
      status: isOnline ? SyncStatus.synced : SyncStatus.offline,
      lastSyncedAtMs: StorageService.getInt(_lastSyncKey),
    );
  }

  /// Sync nền định kỳ 15 phút khi online (chỉ khi đã cấu hình cloud).
  static void startAutoSync() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (PwaService.isOnline) syncInBackground();
    });
  }

  static void stopAutoSync() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  /// Chạy syncAll và cập nhật SyncState theo kết quả.
  ///
  /// Cloud chưa cấu hình → giữ nguyên trạng thái (không fake "Synced").
  /// Lỗi mạng thật → [SyncStatus.error] với thông điệp nhẹ nhàng.
  static Future<void> syncInBackground() async {
    if (!SupabaseService.isConfigured) return;
    markSyncing();
    bool ok;
    try {
      ok = await SupabaseService.syncAll();
    } catch (_) {
      markError();
      return;
    }
    if (ok) {
      markSynced();
    } else {
      markError();
    }
  }
}
