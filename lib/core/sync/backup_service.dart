import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/exams/domain/exam_repository.dart';
import '../../features/study/domain/repositories/study_session_repository.dart';
import '../../features/tasks/domain/models/task_attachment.dart';
import '../../features/tasks/domain/repositories/task_repository.dart';
import '../pwa/pwa_service.dart';
import '../utils/auth_service.dart';
import '../utils/storage_service.dart';
import 'sync_state.dart';

/// Sao lưu TỰ ĐỘNG toàn bộ dữ liệu, đồng bộ gần như thời gian thực giữa mọi
/// thiết bị (đặc tả mục 19 — Backup/restore).
///
/// BA NGUYÊN TẮC
/// 1. **Sao lưu tất cả mọi thứ.** Snapshot = mọi khoá SharedPreferences trừ
///    khoá riêng của thiết bị (xem [deviceLocalKeys]) và ảnh đính kèm (nặng, đi
///    riêng). Nhờ chụp theo khoá nên thêm tính năng mới sau này cũng được sao
///    lưu mà không phải khai báo lại — trước đây chỉ kỳ thi / nhiệm vụ / nhật
///    ký học được đẩy lên cloud, còn ghi chú, phiên học, điểm thi thử, XP,
///    streak, linh vật, lịch sử chat AI và cài đặt nằm trên máy và mất sạch
///    khi gỡ app.
/// 2. **Bản mới nhất thắng.** Server đóng dấu thời gian, client chỉ ghi khi
///    mình không biết có bản mới hơn; nếu có thì nhận bản đó về. Nhờ vậy mọi
///    thiết bị hội tụ về cùng một trạng thái mà không phải hỏi người dùng.
/// 3. **Không bao giờ mất cục bộ.** Dữ liệu ghi vào SharedPreferences trước,
///    cloud là bản sao lưu. Mất mạng thì chỉ là hoãn đẩy, không mất gì.
///
/// Sao lưu chỉ chạy khi **đã đăng nhập**: Firebase UID mới là danh tính ổn
/// định nối mọi thiết bị. Chưa đăng nhập thì mỗi máy một `user_id` riêng — đó
/// chính là lý do trước đây "bản gốc" và "bản sao lưu" không có linking.
class BackupService {
  BackupService._();

  /// Khoá KHÔNG bao giờ đi theo snapshot — thuộc về thiết bị này hoặc do hệ
  /// thống quản lý. Đưa chúng lên cloud sẽ làm máy khác mất cấu hình riêng
  /// (URL/khoá Supabase) hoặc tưởng đã đăng nhập/xác minh khi chưa.
  static const Set<String> deviceLocalKeys = {
    'user_uuid', // danh tính cục bộ, thay bằng Firebase UID khi đăng nhập
    'supabase_url',
    'supabase_anon_key',
    'onboarding_done', // mỗi thiết bị tự trải qua onboarding một lần
    'email_verified', // suy ra từ Firebase, không phải dữ liệu người dùng
    'free_models_cache_v1',
    'free_models_cache_time_v1', // cache danh sách model, tự tải lại
    'exam_pending_deletes', // hàng đợi xoá riêng của máy
    'last_cloud_sync_ms', // mốc của luồng sync per-table cũ
    'backup_device_id',
    'backup_synced_at_ms',
    'backup_fingerprint',
    'backup_blob_index',
    'backup_prev_snapshot',
  };

  /// Tiền tố khoá chứa ảnh đính kèm (base64). Chỉ danh sách id đi trong
  /// snapshot; dữ liệu ảnh đi riêng (bảng `user_blobs`) để snapshot không phình
  /// theo dung lượng ảnh.
  static const String attachmentPrefix = 'task_attachment_';
  static const String attachmentIndexPrefix = 'task_attachments_';

  static const String _deviceIdKey = 'backup_device_id';
  static const String _syncedAtKey = 'backup_synced_at_ms';
  static const String _fingerprintKey = 'backup_fingerprint';
  static const String _blobIndexKey = 'backup_blob_index';

  /// Chu kỳ hỏi cloud có bản mới hơn không. Ngắn để "gần như thời gian thực"
  /// mà vẫn không spam mạng: mỗi vòng chỉ một request nhẹ (`?meta=1`), chỉ tải
  /// hoặc ghi payload đầy đủ khi thật sự có thay đổi.
  static const Duration pollInterval = Duration(seconds: 20);

  /// Chờ sau thay đổi local rồi mới đẩy (gộp nhiều thao tác liên tiếp).
  static const Duration pushDebounce = Duration(seconds: 2);

  static Timer? _pollTimer;
  static Timer? _pushDebounceTimer;
  static StreamSubscription<Object?>? _authSubscription;
  static bool _running = false;
  static bool _started = false;

  /// Cần chạy thêm một vòng sau khi vòng hiện tại xong (thay đổi phát sinh
  /// giữa lúc đang chạy, hoặc yêu cầu đẩy ngay).
  static bool _rerunRequested = false;

  /// Chỉ mục ảnh đã gửi lên cloud: key → {checksum, updatedAt}. Cache trong
  /// RAM vì mỗi vòng đồng bộ đọc nó vài lần mà `prefs` không thay đổi giữa
  /// vòng.
  static Map<String, dynamic> _blobIndexCache = {};
  static bool _blobIndexLoaded = false;

  /// Đang chạy thật: đã khởi động + đã đăng nhập (chưa cần mạng).
  static bool get isActive => _started && AuthService.isLoggedIn;

  /// Mốc server mà máy này đã đồng bộ tới (epoch ms). 0 = chưa từng sync.
  static int get syncedAtMs => StorageService.getInt(_syncedAtKey) ?? 0;

  /// Định danh thiết bị (tự sinh, không đổi theo máy) — chỉ để server biết
  /// bản ghi vừa tới từ đâu khi cần tra cứu.
  static String get deviceId {
    var id = StorageService.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      StorageService.setString(_deviceIdKey, id);
    }
    return id;
  }

  // ─── Vòng đời ───────────────────────────────────────────────────────────────

  /// Bắt đầu sao lưu tự động. Gọi một lần sau khi khởi tạo xong auth.
  ///
  /// An toàn khi gọi lại nhiều lần: timer cũ bị huỷ trước.
  static void start() {
    _started = true;
    stopTimers();
    unawaited(syncNow());
    // Timer luôn chạy (kể cả lúc chưa đăng nhập) vì người dùng có thể đăng
    // nhập giữa phiên: nếu chỉ bật timer lúc `isActive` thì việc đăng nhập sau
    // sẽ không bao giờ kích hoạt được sao lưu.
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (isActive) unawaited(syncNow());
    });
    // Vừa đăng nhập xong → đồng bộ ngay, không bắt chờ chu kỳ.
    _authSubscription ??= AuthService.authStateChanges?.listen((_) {
      if (isActive) {
        SyncStateService.updateConnectivity(isOnline: PwaService.isOnline);
        unawaited(syncNow());
      }
    });
  }

  static void stop() {
    stopTimers();
    _authSubscription?.cancel();
    _authSubscription = null;
    _started = false;
    _rerunRequested = false;
  }

  static void stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = null;
  }

  /// Có thay đổi local vừa xảy ra → hẹn đẩy lên.
  ///
  /// Các repository gọi hàm này sau mỗi lần ghi, nên lưu xong có trên cloud sau
  /// ~2 giây, không cần bấm nút.
  static void notifyLocalChange() {
    if (!isActive || !PwaService.isOnline) return;
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = Timer(pushDebounce, () => syncNow());
  }

  /// Đẩy ngay lập tức, bỏ qua debounce (app chuyển nền / sắp bị đóng).
  ///
  /// Không await vì không ai chờ nổi lúc app bị treo; lỗi đã bên trong xử lý.
  static void flush() {
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = null;
    _rerunRequested = true;
    unawaited(syncNow());
  }

  // ─── Vòng đồng bộ ──────────────────────────────────────────────────────────

  /// Một vòng: hỏi mốc mới nhất trên cloud → quyết định kéo về hay đẩy lên.
  ///
  /// Có khoá chống chạy chồng: repository và timer có thể gọi cùng lúc, mà vòng
  /// đồng bộ phải tuần tự để không đẩy bản cũ đè bản mới.
  static Future<void> syncNow() async {
    if (!isActive || !PwaService.isOnline) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerunRequested = false;
        await _runOnce();
      } while (_rerunRequested && isActive && PwaService.isOnline);
    } catch (e) {
      debugPrint('[BackupService] Lỗi đồng bộ: $e');
      SyncStateService.markError('Chưa sao lưu được — thử lại sau');
    } finally {
      _running = false;
    }
  }

  static Future<void> _runOnce() async {
    final localAt = syncedAtMs;

    // Chưa từng đồng bộ: ưu tiên bản sao lưu trên cloud nếu có (đây là lúc
    // mở app trên máy mới và cần thấy đúng dữ liệu vừa làm ở máy khác). Cloud
    // trống thì đẩy dữ liệu máy này lên làm bản gốc chung.
    if (localAt == 0) {
      final meta = await _get(const {'meta': '1'});
      if (meta['ok'] != true) return;
      if (meta['exists'] == true) {
        // Bản trên cloud TRỐNG thì không có gì để "ưu tiên": đẩy dữ liệu máy
        // này lên làm bản gốc chung. Nếu không, tình huống rất dễ xảy ra và rất
        // đau: máy A vừa tạo tài khoản (chưa làm gì) đẩy snapshot rỗng; mở app
        // trên máy B đã có dữ liệu → nhận snapshot rỗng về và **xoá sạch** dữ
        // liệu B.
        final remote = await _get(const {});
        if (remote['ok'] == true &&
            hasRealData(remote['payload']) &&
            !hasRealData(BackupSnapshot.capture())) {
          _adopt(remote);
          return;
        }
        await _push();
        return;
      }
      await _push();
      return;
    }

    final meta = await _get(const {'meta': '1'});
    if (meta['ok'] != true) return;
    final remoteAt = (meta['updatedAt'] as num?)?.toInt() ?? 0;

    if (remoteAt > localAt) {
      // Máy khác vừa ghi mới hơn thứ mình biết → lấy bản đó về.
      await _pullAndApply();
      return;
    }
    if (remoteAt < localAt) {
      // Cloud bị tụt mốc (ví dụ dữ liệu bị xoá tay) → đẩy lại bản máy này.
      await _push();
      return;
    }

    // Hai bên cùng mốc: chỉ việc gì khi máy này vừa thay đổi.
    if (_fingerprint != StorageService.getString(_fingerprintKey)) {
      await _push();
    } else {
      SyncStateService.markSynced();
    }
  }

  static String get _fingerprint =>
      BackupService.fingerprint(BackupSnapshot.capture());

  /// Snapshot có dữ liệu thật không (không tính khoá phiên bản)?
  ///
  /// Dùng để quyết định lúc hai bên lệch nhau: một bản sao lưu rỗng không đáng
  /// để ghi đè dữ liệu thật trên máy.
  @visibleForTesting
  static bool hasRealData(Object? payload) {
    if (payload is! Map) return false;
    for (final key in payload.keys) {
      if ('$key' == BackupSnapshot.schemaKey) continue;
      return true;
    }
    return false;
  }

  /// Kéo bản sao lưu mới nhất về và ghi đè máy — đúng yêu cầu "mở app luôn
  /// thấy bản sao lưu gần nhất trên mọi thiết bị".
  static Future<void> _pullAndApply() async {
    SyncStateService.markSyncing();
    final body = await _get(const {});
    if (body['ok'] != true) return;
    _adopt(body);
  }

  /// Đẩy toàn bộ máy lên cloud.
  static Future<void> _push() async {
    SyncStateService.markSyncing();
    final pending = _pendingBlobs();
    final removed = _removedBlobs();

    final body = await _post({
      'deviceId': deviceId,
      'baseUpdatedAt': syncedAtMs,
      'payload': BackupSnapshot.capture(),
      'blobs': pending.map(_blobPayload).toList(),
      'deletedBlobs': removed,
    });
    if (body.isEmpty) {
      // Không gọi được server (mạng, 5xx, chưa cấu hình) — báo nhẹ nhàng, dữ
      // liệu trên máy vẫn an toàn và vòng sau sẽ thử lại.
      SyncStateService.markError('Chưa sao lưu được — thử lại sau');
      return;
    }

    // Server báo bản trên cloud mới hơn → nhận bản đó về thay vì ghi đè.
    if (body['applied'] == false) {
      _adopt(body);
      return;
    }

    // Ảnh chưa gửi hết (server giới hạn số ảnh mỗi lần) → giữ lại gửi vòng sau.
    final accepted = body['acceptedBlobs'];
    final sentKeys = accepted is List
        ? accepted.map((e) => '$e').toList()
        : pending.map(_blobKeyOf).toList();
    _rememberSent(sentKeys, pending);
    _forgetRemoved(removed);
    _markSynced((body['updatedAt'] as num?)?.toInt() ?? 0);
  }

  /// Nhận một trạng thái từ server: ghi đè máy, cập nhật mốc + chỉ mục ảnh.
  static Future<void> _adopt(Map<String, dynamic> body) async {
    final payload = body['payload'];
    if (payload is Map) {
      BackupSnapshot.apply(Map<String, dynamic>.from(payload));
    }
    final serverAt = (body['updatedAt'] as num?)?.toInt() ?? 0;
    if (serverAt > 0) StorageService.setInt(_syncedAtKey, serverAt);
    StorageService.setString(_fingerprintKey, _fingerprint);
    SyncStateService.markSynced();
    await _reconcileBlobs(_asIndex(body['blobs']));
  }

  static void _markSynced(int serverAt) {
    if (serverAt > 0) StorageService.setInt(_syncedAtKey, serverAt);
    StorageService.setString(_fingerprintKey, _fingerprint);
    SyncStateService.markSynced();
  }

  // ─── Ảnh đính kèm ─────────────────────────────────────────────────────────

  /// Chỉ mục ảnh đang có trên máy: `taskId__attachmentId` → {taskId,
  /// attachmentId, json}. Chỉ đọc danh sách id, phần base64 tách riêng khi
  /// đẩy lên.
  static Map<String, Map<String, dynamic>> _localBlobs() {
    final index = <String, Map<String, dynamic>>{};
    for (final key in StorageService.prefs.getKeys()) {
      if (!key.startsWith(attachmentIndexPrefix)) continue;
      final taskId = key.substring(attachmentIndexPrefix.length);
      for (final id in StorageService.getTaskAttachmentIds(taskId)) {
        final json = StorageService.getTaskAttachmentJson(taskId, id);
        if (json == null) continue;
        index[_blobKey(taskId, id)] = {
          'taskId': taskId,
          'attachmentId': id,
          'json': json,
        };
      }
    }
    return index;
  }

  /// Chỉ mục ảnh đã biết là có trên cloud: key → {checksum, updatedAt}.
  static Map<String, dynamic> _blobIndex() {
    if (!_blobIndexLoaded) {
      final raw = StorageService.getString(_blobIndexKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            _blobIndexCache = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          // Chỉ mục hỏng → coi như chưa gửi gì, đẩy lại từ đầu (an toàn).
          _blobIndexCache = {};
        }
      }
      _blobIndexLoaded = true;
    }
    return _blobIndexCache;
  }

  static void _saveBlobIndex() {
    StorageService.setString(_blobIndexKey, jsonEncode(_blobIndexCache));
  }

  /// Ảnh local chưa từng gửi lên (checksum trên cloud chưa khớp).
  static List<Map<String, dynamic>> _pendingBlobs() {
    final local = _localBlobs();
    final known = _blobIndex();
    final pending = <Map<String, dynamic>>[];
    local.forEach((key, value) {
      final checksum = BackupService.checksum(_base64Of(value['json']));
      final sent = known[key];
      if (sent is Map && sent['checksum'] == checksum) return;
      pending.add({
        'key': key,
        'taskId': value['taskId'],
        'attachmentId': value['attachmentId'],
        'name': _nameOf(value['json']),
        'base64': _base64Of(value['json']),
        'checksum': checksum,
      });
    });
    return pending;
  }

  /// Ảnh đã xoá trên máy nhưng còn trong chỉ mục đã gửi → báo xoá cho cloud.
  static List<String> _removedBlobs() {
    final local = _localBlobs();
    return _blobIndex().keys
        .where((key) => !local.containsKey(key))
        .toList(growable: false);
  }

  static void _rememberSent(
      List<String> sentKeys, List<Map<String, dynamic>> pending) {
    if (sentKeys.isEmpty && pending.isEmpty) return;
    final byKey = {for (final p in pending) _blobKeyOf(p): p};
    final index = _blobIndex();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in sentKeys) {
      final json = byKey[key]?['base64'] as String?;
      index[key] = {'checksum': BackupService.checksum(json ?? ''), 'updatedAt': now};
    }
    _saveBlobIndex();
  }

  static void _forgetRemoved(List<String> removed) {
    if (removed.isEmpty) return;
    final index = _blobIndex();
    for (final key in removed) {
      index.remove(key);
    }
    _saveBlobIndex();
  }

  /// Tải ảnh còn thiếu trên máy, xoá ảnh không còn trên cloud.
  ///
  /// Xoá là cần thiết: nếu chỉ thêm mà không xoá thì ảnh đã gỡ trên máy này
  /// lại "sống lại" từ cloud ở lần mở app sau trên mọi thiết bị.
  static Future<void> _reconcileBlobs(List<Map<String, dynamic>> index) async {
    final local = _localBlobs();
    final remoteKeys = index.map((e) => '${e['key']}').toSet();

    for (final entry in index) {
      final key = '${entry['key']}';
      final localEntry = local[key];
      if (localEntry != null &&
          BackupService.checksum(_base64Of(localEntry['json'])) ==
              '${entry['checksum']}') {
        // Đã có bản giống hệt → ghi vào chỉ mục để không tải lại lần sau.
        _blobIndex()[key] = {
          'checksum': '${entry['checksum']}',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
        continue;
      }
      await _downloadBlob(key, entry);
    }

    for (final key in local.keys) {
      if (remoteKeys.contains(key)) continue;
      _deleteLocalBlob(key);
      _forgetRemoved([key]);
    }
    _saveBlobIndex();
  }

  static Future<void> _downloadBlob(
      String key, Map<String, dynamic> entry) async {
    final body = await _get({'blob': key});
    if (body['ok'] != true) return;
    final data = body['data'];
    if (data is! String || data.isEmpty) return;
    final taskId = key.split('__').first;
    final attachmentId = key.split('__').skip(1).join('__');

    // Ghi qua TaskRepository chứ không tự setTaskAttachmentJson: đó là đường
    // ghi DUY NHẤT của tệp đính kèm (bỏ qua nó sẽ mất quy tắc id, chống trùng
    // và Undo — xem test "Single Write Path").
    final result = TaskRepository.instance.restoreAttachment(
      taskId,
      TaskAttachment(
        id: attachmentId,
        name: '${body['name'] ?? entry['name'] ?? 'Tài liệu'}',
        sizeBytes: (body['sizeBytes'] as num?)?.toInt() ?? 0,
        base64: data,
        addedAt: DateTime.now(),
      ),
    );
    // Nhiệm vụ cha đã bị xoá cả ở bản cloud này → không gắn, và cũng đừng đánh
    // dấu đã tải để còn thử lại được ở vòng sau.
    if (result.failed) return;

    _blobIndex()[key] = {
      'checksum': '${body['checksum'] ?? entry['checksum'] ?? ''}',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    _saveBlobIndex();
  }

  static void _deleteLocalBlob(String key) {
    final parts = key.split('__');
    if (parts.length < 2) return;
    // Qua repository cho đúng một đường ghi: nếu nhiệm vụ cha đã bị xoá thì
    // tệp đính kèm cũng đã đi theo, không còn gì để dọn.
    TaskRepository.instance
        .removeAttachment(parts.first, parts.skip(1).join('__'));
  }

  // ─── Gọi API ───────────────────────────────────────────────────────────────

  static String _blobKey(String taskId, String attachmentId) =>
      '${taskId}__$attachmentId';

  static String _blobKeyOf(Map<String, dynamic> pending) =>
      _blobKey('${pending['taskId']}', '${pending['attachmentId']}');

  static Map<String, dynamic> _blobPayload(Map<String, dynamic> pending) => {
        'taskId': pending['taskId'],
        'attachmentId': pending['attachmentId'],
        'name': pending['name'],
        'sizeBytes': (pending['base64'] as String? ?? '').length,
        'checksum': pending['checksum'],
        'base64': pending['base64'],
      };

  static List<Map<String, dynamic>> _asIndex(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static String _base64Of(Object? attachmentJson) {
    if (attachmentJson is! String) return '';
    try {
      final decoded = jsonDecode(attachmentJson);
      if (decoded is Map && decoded['base64'] is String) {
        return decoded['base64'] as String;
      }
    } catch (_) {
      // JSON hỏng → coi như không có ảnh, không làm hỏng cả lần đồng bộ.
    }
    return '';
  }

  static String _nameOf(Object? attachmentJson) {
    if (attachmentJson is! String) return '';
    try {
      final decoded = jsonDecode(attachmentJson);
      if (decoded is Map && decoded['name'] is String) {
        return decoded['name'] as String;
      }
    } catch (_) {
      // Bỏ qua — tên không quan trọng bằng nội dung.
    }
    return '';
  }

  /// FNV-1a 32-bit — chỉ để so sánh "nội dung ảnh có đổi không", không phải
  /// bảo mật. Tự viết để không thêm dependency và để **ổn định giữa các phiên
  /// bản Dart** (`String.hashCode` thì không bảo đảm điều đó).
  @visibleForTesting
  static String checksum(String value) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < value.length; i++) {
      hash ^= value.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Dấu vân tay của snapshot — rẻ hơn nhiều so với gửi cả payload, dùng để
  /// biết máy có vừa thay đổi không.
  @visibleForTesting
  static String fingerprint(Map<String, dynamic> payload) =>
      checksum(jsonEncode(_sortedKeys(payload)));

  static Map<String, dynamic> _sortedKeys(Map<String, dynamic> input) {
    final keys = input.keys.toList()..sort();
    return {for (final k in keys) k: input[k]};
  }

  /// Gọi `/api/backup` (cùng origin của bản deploy).
  ///
  /// Server tự xác thực Firebase ID token nên 401 nghĩa là phiên hết hạn và
  /// cần đăng nhập lại — chỉ log, không báo động: dữ liệu trên máy vẫn an toàn
  /// và sẽ tự đẩy lại ở lần sau.
  static Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    final token = await _idToken();
    if (token == null) return const {};
    try {
      final resp = await http
          .get(
            Uri.base.resolve('/api/backup').replace(queryParameters: query),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      return _decode(resp);
    } catch (e) {
      debugPrint('[BackupService] Mạng lỗi, hoãn đồng bộ: $e');
      return const {};
    }
  }

  static Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final token = await _idToken();
    if (token == null) return const {};
    try {
      final resp = await http
          .post(
            Uri.base.resolve('/api/backup'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'idToken': token, ...body}),
          )
          .timeout(const Duration(seconds: 30));
      return _decode(resp);
    } catch (e) {
      debugPrint('[BackupService] Mạng lỗi, hoãn đồng bộ: $e');
      return const {};
    }
  }

  static Future<String?> _idToken() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decode(http.Response resp) {
    if (resp.statusCode >= 400) {
      debugPrint('[BackupService] HTTP ${resp.statusCode} — ${resp.body}');
      return const {};
    }
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Phản hồi không phải JSON (vd trang lỗi HTML của Vercel) → thất bại.
    }
    debugPrint('[BackupService] Phản hồi không đọc được: ${resp.body}');
    return const {};
  }
}

/// Đóng gói / mở gói TOÀN BỘ dữ liệu local thành snapshot JSON.
///
/// Tách riêng khỏi [BackupService] để kiểm thử được độc lập: "bỏ vào cái gì
/// thì lấy ra đúng cái đó" là điều kiện tiên quyết của mọi thay đổi khác.
class BackupSnapshot {
  BackupSnapshot._();

  /// Phiên bản cấu trúc snapshot — để sau này vẫn đọc được snapshot cũ.
  static const int schema = 1;
  static const String schemaKey = 'backup_schema';
  static const String previousSnapshotKey = 'backup_prev_snapshot';

  /// Chụp mọi khoá dữ liệu, trừ khoá riêng thiết bị và ảnh đính kèm.
  ///
  /// Cố ý KHÔNG liệt kê từng loại dữ liệu (kỳ thi, nhiệm vụ, ghi chú…): cách
  /// đó chính là lý do trước đây thiếu sót. Duyệt theo khoá thì ghi chú, phiên
  /// học, điểm thi thử, XP, streak, linh vật, lịch sử chat AI, cài đặt… đều vào
  /// snapshot, và tính năng thêm sau cũng tự được sao lưu.
  static Map<String, dynamic> capture() {
    final prefs = StorageService.prefs;
    final out = <String, dynamic>{schemaKey: schema};
    for (final key in prefs.getKeys()) {
      if (BackupService.deviceLocalKeys.contains(key)) continue;
      if (key.startsWith(BackupService.attachmentPrefix)) continue;
      if (key.startsWith(BackupService.attachmentIndexPrefix)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      out[key] = value;
    }
    return out;
  }

  /// Ghi đè máy bằng snapshot nhận từ cloud.
  ///
  /// Xoá luôn khoá có ở máy mà không có trong snapshot — đó là điều làm cho
  /// "bản mới nhất thắng" đúng nghĩa: xoá trên máy này thì mọi máy khác cũng
  /// phải xoá, nếu không bản ghi đã xoá sẽ sống lại ở lần mở app sau.
  ///
  /// Trước khi ghi đè, toàn bộ dữ liệu đang có được cất vào
  /// [previousSnapshotKey] để vẫn còn đường quay lại nếu lần khôi phục sai.
  static void apply(Map<String, dynamic> payload) {
    final prefs = StorageService.prefs;
    _stashCurrent();

    payload.forEach((key, value) {
      if (BackupService.deviceLocalKeys.contains(key)) return;
      if (key.startsWith(BackupService.attachmentPrefix)) return;
      if (key.startsWith(BackupService.attachmentIndexPrefix)) return;
      _write(prefs, key, value);
    });

    for (final key in prefs.getKeys().toList()) {
      if (BackupService.deviceLocalKeys.contains(key)) continue;
      if (key.startsWith(BackupService.attachmentIndexPrefix)) continue;
      // KHÔNG xoá dữ liệu ảnh ở đây: ảnh không nằm trong snapshot mà nằm ở bảng
      // riêng, việc dọn ảnh là của `_reconcileBlobs` (nó tải về trước rồi mới
      // xoá cái thừa). Xoá ở đây nghĩa là xoá ảnh trước khi kịp tải lại — mất
      // ảnh chỉ vì một lần tải thất bại.
      if (key.startsWith(BackupService.attachmentPrefix)) continue;
      if (payload.containsKey(key)) continue;
      prefs.remove(key);
    }

    _afterApply();
  }

  static void _write(SharedPreferences prefs, String key, Object? value) {
    if (value is String) {
      prefs.setString(key, value);
    } else if (value is bool) {
      prefs.setBool(key, value);
    } else if (value is int) {
      prefs.setInt(key, value);
    } else if (value is double) {
      prefs.setDouble(key, value);
    } else if (value is List) {
      prefs.setStringList(key, value.map((e) => '$e').toList());
    }
    // Kiểu lạ (vd null) → bỏ qua thay vì làm hỏng cả lần khôi phục.
  }

  /// Cất lại bản đang có trên máy (giới hạn 1 bản để không phình prefs).
  static void _stashCurrent() {
    try {
      StorageService.setString(previousSnapshotKey, jsonEncode(capture()));
    } catch (_) {
      // prefs đầy → bỏ qua, việc khôi phục vẫn chạy bình thường.
    }
  }

  /// Bản cục bộ ngay trước lần khôi phục gần nhất (null nếu chưa có) — dùng
  /// cho nút "Hoàn tác khôi phục".
  static String? get previousSnapshot {
    final raw = StorageService.getString(previousSnapshotKey);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// Có thể quay lại dữ liệu trước lần khôi phục vừa rồi không.
  static bool get canUndoLastRestore => previousSnapshot != null;

  /// Quay lại bản cục bộ trước lần khôi phục gần nhất.
  ///
  /// Đường an toàn của chính sách "bản mới nhất thắng": cài app lên máy mới
  /// thì luôn thấy dữ liệu cloud, nhưng nếu máy đó lỡ có việc riêng chưa kịp
  /// lên cloud thì vẫn lấy lại được thay vì mất.
  ///
  /// Trả false khi không có bản trước hoặc bản đó hỏng.
  static bool undoLastRestore() {
    final raw = previousSnapshot;
    if (raw == null) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      apply(Map<String, dynamic>.from(decoded));
      return true;
    } catch (_) {
      // Bản cũ hỏng → không xoá, để người dùng thử lại hoặc dùng bản cloud.
      return false;
    }
  }

  /// Ghi xong phải bắn tín hiệu cho UI vẽ lại — dữ liệu được ghi thẳng qua
  /// StorageService nên repository không tự biết có thay đổi.
  static void _afterApply() {
    ExamRepository.instance.notifyExternalChange();
    TaskRepository.instance.notifyExternalChange();
    StudySessionRepository.instance.notifyExternalChange();
  }
}
