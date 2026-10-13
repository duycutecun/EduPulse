import 'dart:async';
import 'package:flutter/foundation.dart';
import '../pwa/pwa_service.dart';
import '../utils/storage_service.dart';
import '../utils/supabase_service.dart';
import '../../features/exams/domain/exam_repository.dart';
import '../../features/tasks/domain/repositories/task_repository.dart';
import 'change_outbox.dart';

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

  /// Số thay đổi còn nằm trên máy, chưa được cloud xác nhận (kế hoạch 7.2).
  ///
  /// Đọc sống từ hàng đợi thay vì chụp vào state: hàng đợi đổi ở mọi thao tác
  /// học, còn state này chỉ đổi khi trạng thái mạng/sync đổi — chụp lại sẽ có
  /// lúc chip hiện số cũ.
  int get pendingCount => ChangeOutbox.pendingCount;

  /// Số thay đổi đã thử gửi nhưng lỗi — cần người dùng biết để thử lại.
  int get failedCount => ChangeOutbox.failedCount;

  /// Số thay đổi chờ để HIỂN THỊ: bằng 0 khi cloud chưa được cấu hình.
  ///
  /// Máy chưa đăng nhập mà hiện "3 thay đổi chờ đồng bộ" là câu vô nghĩa và
  /// chỉ làm người dùng lo — nên con số chỉ xuất hiện khi việc đồng bộ là
  /// chuyện có thật trên máy này.
  int get visiblePending => SupabaseService.cloudSyncEnabled ? pendingCount : 0;

  /// Như [visiblePending] nhưng cho số thay đổi gửi lỗi.
  int get visibleFailed => SupabaseService.cloudSyncEnabled ? failedCount : 0;

  /// Câu mô tả cho UI. Không dùng ngôn ngữ gây lo lắng — lỗi sync là
  /// bình thường khi offline, dữ liệu vẫn an toàn trên máy.
  String get label {
    final pending = visiblePending;
    final failed = visibleFailed;

    if (failed > 0) {
      return '$failed thay đổi chưa gửi được — chạm để thử lại';
    }

    switch (status) {
      case SyncStatus.synced:
        if (pending > 0) return '$pending thay đổi chờ đồng bộ';
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
        return pending > 0
            ? 'Đang đồng bộ $pending thay đổi…'
            : 'Đang đồng bộ…';
      case SyncStatus.offline:
        return pending > 0
            ? 'Ngoại tuyến — $pending thay đổi lưu an toàn trên máy'
            : 'Ngoại tuyến — dữ liệu lưu an toàn trên máy';
      case SyncStatus.error:
        return errorMessage ??
            (pending > 0
                ? '$pending thay đổi chờ gửi lại — chạm để thử lại'
                : 'Chưa đồng bộ được — thử lại khi sẵn sàng');
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
    final wasOffline = state.value.status == SyncStatus.offline;
    state.value = SyncState(
      status: isOnline ? SyncStatus.synced : SyncStatus.offline,
      lastSyncedAtMs: StorageService.getInt(_lastSyncKey),
    );
    // Vừa có mạng lại: đẩy ngay thay đổi đã gẹn lúc offline, không bắt
    // người dùng đợi tới chu kỳ 15 phút (hoặc tự bấm nút đồng bộ).
    if (isOnline && wasOffline) {
      ExamRepository.instance.flushNow();
      TaskRepository.instance.flushNow();
    }
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
    ChangeOutbox.markAllSyncing();
    bool ok;
    try {
      ok = await SupabaseService.syncAll();
    } catch (_) {
      ChangeOutbox.markAllFailed('syncAll');
      markError();
      return;
    }
    if (ok) {
      // Đã đẩy toàn bộ trạng thái → sổ ý định không còn gì chờ.
      ChangeOutbox.markAllSynced();
      markSynced();
    } else {
      ChangeOutbox.markAllFailed();
      markError();
    }
  }

  /// Người dùng chủ động thử lại (chạm chip trạng thái).
  ///
  /// Đẩy hai nguồn dữ liệu chính ngay (kỳ thi + nhiệm vụ), rồi chạy một vòng
  /// sync đầy đủ để phủ phần còn lại (phiên học, ghi chú, cài đặt).
  static void retryNow() {
    if (!SupabaseService.isConfigured) return;
    if (!PwaService.isOnline) {
      updateConnectivity(isOnline: false);
      return;
    }
    markSyncing();
    ExamRepository.instance.flushNow();
    TaskRepository.instance.flushNow();
    unawaited(syncInBackground());
  }

  /// Gọi một lần lúc khởi động app.
  ///
  /// Hai việc mà trước đây không ai làm: (1) dòng nào còn `syncing` là dấu vết
  /// của lần app bị tắt giữa lúc gửi — trả về `pending` để vòng sau thử lại,
  /// không để thay đổi kẹt vĩnh viễn; (2) dọn các dòng đã đồng bộ xong từ
  /// phiên trước để hàng đợi không phình theo thời gian.
  static void recoverAfterRestart() {
    ChangeOutbox.recoverInterrupted();
    ChangeOutbox.clearSynced();
    updateConnectivity(isOnline: PwaService.isOnline);
  }
}
