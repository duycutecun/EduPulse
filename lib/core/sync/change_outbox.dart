import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/storage_service.dart';

/// Trạng thái của một thay đổi cục bộ đang chờ lên cloud.
enum ChangeStatus {
  /// Đã ghi trên máy, chưa gửi đi lần nào.
  pending,

  /// Đang trong một vòng sync.
  syncing,

  /// Đã lên tới cloud (chỉ giữ lại một lúc rồi dọn).
  synced,

  /// Gửi lỗi — còn giữ để thử lại, kèm lý do.
  failed,
}

/// Một thay đổi cục bộ cần đẩy lên cloud (đặc tả mục 19 + kế hoạch 7.2).
///
/// Vì sao phải có bản ghi này thay vì chỉ có một cờ "dữ liệu đã đổi": sau khi
/// app bị tắt giữa lúc sync hoặc khi mạng chập chờn, người dùng cần biết
/// **cái gì** còn nằm trên máy, **từ máy nào**, **lúc nào**, và **đã thử mấy
/// lần**. Một cờ boolean không trả lời được câu nào trong số đó.
class PendingChange {
  /// Định danh của lần thay đổi (khác `entityId`: một nhiệm vụ có thể đổi
  /// nhiều lần, nhưng hàng đợi gộp lại thành một dòng mới nhất).
  final String id;

  /// Loại dữ liệu: `task`, `exam`, `session`… (khoá để biết sync nhánh nào
  /// đã thành công).
  final String entity;

  /// Id của bản ghi bị ảnh hưởng trong kho dữ liệu.
  final String entityId;

  /// `upsert` hoặc `delete`.
  final String op;

  /// Thời điểm thay đổi trên máy (epoch ms) — mốc để so bản mới hơn khi có
  /// xung đột giữa hai thiết bị.
  final int updatedAt;

  /// Máy đã tạo thay đổi này.
  final String deviceId;

  /// Phiên bản schema của dữ liệu lúc ghi — để sau này đọc lại biết cách hiểu.
  final int schemaVersion;

  final ChangeStatus status;

  /// Số lần đã thử gửi.
  final int attempts;

  /// Lý do lần gửi lỗi gần nhất (đã lọc, không chứa dữ liệu học tập).
  final String? lastError;

  const PendingChange({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.updatedAt,
    required this.deviceId,
    this.schemaVersion = ChangeOutbox.schema,
    this.status = ChangeStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  static const String opUpsert = 'upsert';
  static const String opDelete = 'delete';

  /// Chưa được cloud xác nhận (đang chờ, đang gửi, hoặc gửi lỗi).
  bool get isOutstanding => status != ChangeStatus.synced;

  PendingChange copyWith({
    String? id,
    String? entity,
    String? entityId,
    String? op,
    int? updatedAt,
    String? deviceId,
    int? schemaVersion,
    ChangeStatus? status,
    int? attempts,
    String? lastError,
    bool clearError = false,
  }) {
    return PendingChange(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity': entity,
        'entityId': entityId,
        'op': op,
        'updatedAt': updatedAt,
        'deviceId': deviceId,
        'schemaVersion': schemaVersion,
        'status': status.name,
        'attempts': attempts,
        if (lastError != null) 'lastError': lastError,
      };

  /// Trả `null` khi bản ghi không đọc được — người gọi bỏ qua dòng hỏng chứ
  /// không làm hỏng cả hàng đợi.
  static PendingChange? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final entity = raw['entity'];
    final entityId = raw['entityId'];
    if (id is! String || entity is! String || entityId is! String) return null;
    return PendingChange(
      id: id,
      entity: entity,
      entityId: entityId,
      op: raw['op'] is String ? raw['op'] as String : opUpsert,
      updatedAt: (raw['updatedAt'] as num?)?.toInt() ?? 0,
      deviceId: raw['deviceId'] is String ? raw['deviceId'] as String : '',
      schemaVersion: (raw['schemaVersion'] as num?)?.toInt() ?? ChangeOutbox.schema,
      status: ChangeStatus.values.firstWhere(
        (s) => s.name == raw['status'],
        orElse: () => ChangeStatus.pending,
      ),
      attempts: (raw['attempts'] as num?)?.toInt() ?? 0,
      lastError: raw['lastError'] is String ? raw['lastError'] as String : null,
    );
  }
}

/// Hàng đợi thay đổi cục bộ chưa lên cloud.
///
/// Ba việc nó làm mà trước đây không ai làm:
/// 1. **Ghi lại ý định** mỗi lần dữ liệu học đổi (kể cả khi đang offline) —
///    trước đây offline thì `_scheduleCloudSync` bỏ qua luôn, không để lại dấu
///    vết nào, nên không thể nói cho người dùng biết còn bao nhiêu thay đổi
///    chưa lên cloud.
/// 2. **Sống sót qua cái chết giữa lúc sync**: bản ghi `syncing` được trả về
///    `pending` khi mở app lại ([recoverInterrupted]), nên không có thay đổi
///    nào bị kẹt vĩnh viễn ở trạng thái "đang gửi" mà không ai thử lại.
/// 3. **Gộp theo bản ghi**: sửa cùng một nhiệm vụ 10 lần chỉ để lại một dòng
///    mới nhất — hàng đợi không phình theo số thao tác.
///
/// Dữ liệu thật vẫn nằm ở các khoá riêng của nó; đây chỉ là sổ theo dõi ý
/// định, nên không bao giờ xoá dữ liệu người dùng khi hàng đợi hỏng.
class ChangeOutbox {
  ChangeOutbox._();

  /// Phiên bản schema của chính payload hàng đợi.
  static const int schema = 1;

  static const String storageKey = 'sync_outbox_v1';

  /// Khoá cách ly payload không đọc được. Đổi schema hay gặp JSON hỏng thì
  /// chuyển sang đây thay vì xoá — người dùng không mất gì, còn tra cứu thì
  /// vẫn còn dấu vết.
  static const String quarantineKey = 'sync_outbox_corrupt';

  /// Trần số dòng giữ lại. Hàng đợi là sổ ý định, không phải kho dữ liệu:
  /// vượt trần thì dọn dòng đã đồng bộ trước, chỉ cắt dòng cũ nhất khi buộc
  /// phải — và dữ liệu học vẫn nguyên vẹn trên máy.
  static const int maxEntries = 400;

  /// Tín hiệu "hàng đợi vừa đổi" cho UI (chip trạng thái, màn Tài khoản).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Nguồn định danh thiết bị, do tầng khởi động gắn vào (`main.dart`).
  ///
  /// Cố ý không import thẳng dịch vụ sao lưu: hàng đợi là tầng thấp hơn và
  /// dịch vụ sao lưu cũng cần gọi ngược lại nó — để hai chiều sẽ thành phụ
  /// thuộc vòng.
  static String Function()? deviceIdProvider;

  static List<PendingChange> _items = const [];
  static bool _loaded = false;

  /// Dùng trong test và khi reset dữ liệu.
  @visibleForTesting
  static void reset() {
    _items = const [];
    _loaded = true;
    revision.value++;
  }

  /// Nạp lại từ storage như thể app vừa mở lại lần nữa (dùng trong test,
  /// cũng là cách mô phỏng "app bị tắt rồi mở lại" mà không cần process mới).
  @visibleForTesting
  static void reloadForTest() {
    _loaded = false;
    ensureLoaded();
    revision.value++;
  }

  // ── Đọc ─────────────────────────────────────────────────────────────────────

  static List<PendingChange> get items {
    ensureLoaded();
    return List.unmodifiable(_items);
  }

  /// Mọi thay đổi chưa được cloud xác nhận.
  static List<PendingChange> get outstanding =>
      items.where((c) => c.isOutstanding).toList(growable: false);

  /// Số thay đổi còn nằm trên máy (chờ gửi, đang gửi hoặc gửi lỗi).
  static int get pendingCount => outstanding.length;

  /// Số thay đổi đã thử gửi nhưng lỗi.
  static int get failedCount =>
      items.where((c) => c.status == ChangeStatus.failed).length;

  static int get syncedCount =>
      items.where((c) => c.status == ChangeStatus.synced).length;

  /// Nạp hàng đợi một lần. Payload hỏng hoặc sai schema → cách ly và bắt đầu
  /// rỗng, tuyệt đối không ném lỗi ra lúc khởi động app.
  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    final raw = StorageService.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    final decoded = _decode(raw);
    if (decoded == null) {
      StorageService.setString(quarantineKey, raw);
      StorageService.removeString(storageKey);
      _items = const [];
      debugPrint('[ChangeOutbox] Payload hỏng — đã cách ly, bắt đầu hàng đợi mới');
      return;
    }
    _items = decoded;
  }

  static List<PendingChange>? _decode(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      final version = (data['schema'] as num?)?.toInt();
      if (version == null || version > schema) return null;
      final list = data['items'];
      if (list is! List) return null;
      final parsed = <PendingChange>[];
      for (final entry in list) {
        final change = PendingChange.tryParse(entry);
        if (change != null) parsed.add(change);
      }
      return parsed;
    } catch (e) {
      debugPrint('[ChangeOutbox] Không đọc được hàng đợi: $e');
      return null;
    }
  }

  static void _save() {
    final payload = jsonEncode({
      'schema': schema,
      'items': _items.map((c) => c.toJson()).toList(),
    });
    StorageService.setString(storageKey, payload);
    revision.value++;
  }

  // ── Ghi nhận thay đổi ───────────────────────────────────────────────────────

  /// Ghi nhận một bản ghi vừa đổi trên máy này.
  ///
  /// Gộp theo `(entity, entityId)`: dòng cũ của cùng bản ghi được thay bằng
  /// dòng mới (giữ `id` đầu tiên để lịch sử không nhảy), trừ khi dòng cũ đã
  /// `synced` — lúc đó thay đổi mới là một dòng mới thật sự.
  static PendingChange enqueue({
    required String entity,
    required String entityId,
    String op = PendingChange.opUpsert,
    DateTime? at,
  }) {
    ensureLoaded();
    final now = at ?? DateTime.now();
    final index = _items.indexWhere((c) =>
        c.entity == entity &&
        c.entityId == entityId &&
        c.status != ChangeStatus.synced);

    final change = PendingChange(
      id: index >= 0 ? _items[index].id : _newId(now),
      entity: entity,
      entityId: entityId,
      op: op,
      updatedAt: now.millisecondsSinceEpoch,
      deviceId: _deviceId(),
      status: ChangeStatus.pending,
    );

    final next = [..._items];
    if (index >= 0) {
      next[index] = change;
    } else {
      next.add(change);
    }
    _items = _prune(next);
    _save();
    return change;
  }

  /// Đánh dấu các thay đổi của một loại dữ liệu là đang được gửi.
  static void markSyncing(String entity) => _update(
        (c) => c.entity == entity && c.isOutstanding,
        (c) => c.copyWith(status: ChangeStatus.syncing),
      );

  /// Cloud đã nhận nhánh dữ liệu này → dọn các dòng chờ tương ứng.
  static void markSyncedForEntity(String entity) => _update(
        (c) => c.entity == entity && c.isOutstanding,
        (c) => c.copyWith(status: ChangeStatus.synced, clearError: true),
      );

  /// Gửi nhánh này lỗi → giữ lại để thử lần sau, kèm số lần thử.
  static void markFailedForEntity(String entity, [String? error]) => _update(
        (c) => c.entity == entity && c.isOutstanding,
        (c) => c.copyWith(
          status: ChangeStatus.failed,
          attempts: c.attempts + 1,
          lastError: error ?? c.lastError,
        ),
      );

  /// Cả một vòng `syncAll` thành công → mọi thay đổi đã lên cloud.
  static void markAllSynced() => _update(
        (c) => c.isOutstanding,
        (c) => c.copyWith(status: ChangeStatus.synced, clearError: true),
      );

  static void markAllSyncing() => _update(
        (c) => c.isOutstanding,
        (c) => c.copyWith(status: ChangeStatus.syncing),
      );

  static void markAllFailed([String? error]) => _update(
        (c) => c.isOutstanding,
        (c) => c.copyWith(
          status: ChangeStatus.failed,
          attempts: c.attempts + 1,
          lastError: error ?? c.lastError,
        ),
      );

  static void _update(
    bool Function(PendingChange) where,
    PendingChange Function(PendingChange) transform,
  ) {
    ensureLoaded();
    var changed = false;
    final next = <PendingChange>[];
    for (final c in _items) {
      if (where(c)) {
        next.add(transform(c));
        changed = true;
      } else {
        next.add(c);
      }
    }
    if (!changed) return;
    _items = _prune(next);
    _save();
  }

  /// Dọn các dòng đã đồng bộ (không cần giữ dấu vết lâu hơn một phiên).
  static void clearSynced() {
    ensureLoaded();
    if (syncedCount == 0) return;
    _items = _items.where((c) => c.isOutstanding).toList(growable: false);
    _save();
  }

  /// App vừa mở lại: dòng nào còn `syncing` là dấu vết của lần bị tắt giữa
  /// lúc gửi — trả về `pending` để vòng sync sau thử lại, không để chúng kẹt
  /// vĩnh viễn.
  ///
  /// Trả về số dòng đã khôi phục (thuận tiện cho log/test).
  static int recoverInterrupted() {
    ensureLoaded();
    var recovered = 0;
    final next = _items.map((c) {
      if (c.status != ChangeStatus.syncing) return c;
      recovered++;
      return c.copyWith(status: ChangeStatus.pending);
    }).toList();
    if (recovered == 0) return 0;
    _items = next;
    _save();
    debugPrint('[ChangeOutbox] Khôi phục $recovered thay đổi bị bỏ dở');
    return recovered;
  }

  static List<PendingChange> _prune(List<PendingChange> list) {
    final pending = list.where((c) => c.isOutstanding).toList();
    final synced = list.where((c) => !c.isOutstanding).toList();
    final room = maxEntries - pending.length;
    if (room >= 0) {
      // Còn chỗ: giữ tối đa vài dòng synced gần nhất để UI khoe "vừa đồng bộ".
      final keepSynced = synced.length > 20
          ? synced.sublist(synced.length - 20)
          : synced;
      return [...pending, ...keepSynced];
    }
    // Buộc phải cắt: bỏ dòng chờ cũ nhất. Dữ liệu học vẫn nguyên trên máy;
    // lần `syncAll` kế tiếp vẫn đẩy toàn bộ trạng thái như trước giờ.
    final trimmed = pending.sublist(pending.length - maxEntries);
    debugPrint('[ChangeOutbox] Hàng đợi vượt trần — gộp bớt dòng cũ nhất');
    return trimmed;
  }

  static String _newId(DateTime at) =>
      '${at.microsecondsSinceEpoch}-${_counter++}';
  static int _counter = 0;

  /// Khoá định danh thiết bị do [BackupService] tạo — chỉ đọc, không tạo mới:
  /// hàng đợi không phải nơi sinh định danh thiết bị.
  static const String _deviceIdFallbackKey = 'backup_device_id';

  static String _deviceId() {
    try {
      final provided = deviceIdProvider?.call();
      if (provided != null && provided.isNotEmpty) return provided;
    } catch (_) {
      // Không có định danh cũng không được làm hỏng việc ghi nhận thay đổi.
    }
    return StorageService.getString(_deviceIdFallbackKey) ?? '';
  }
}
