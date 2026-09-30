import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/study/domain/models/study_models.dart';
import '../utils/storage_service.dart';

/// Kết quả một lần migration (đặc tả mục 42 — Migration).
///
/// Nguyên tắc bất biến: **không để mất dữ liệu** — luôn có snapshot
/// backup trước khi chạy bất kỳ bước nào; lỗi → rollback tự động.
class MigrationReport {
  /// Migration có chạy hay không (false khi schema đã mới, bỏ qua).
  final bool ran;

  /// true khi mọi bước thành công (hoặc bỏ qua).
  final bool success;

  /// true khi đã rollback + restore backup do lỗi.
  final bool rolledBack;

  /// Các bước đã chạy (tên), để debug và hiển thị cho user nếu lỗi.
  final List<String> stepsRun;

  /// Thông điệp ngắn cho user khi lỗi (notify user — mục 42).
  final String? userMessage;

  const MigrationReport({
    required this.ran,
    required this.success,
    this.rolledBack = false,
    this.stepsRun = const [],
    this.userMessage,
  });
}

/// Một bước migration có tên. [migrate] trả true khi OK.
/// Ném exception hoặc trả false coi như lỗi → rollback toàn bộ.
class MigrationStep {
  final String name;
  final bool Function() migrate;

  const MigrationStep(this.name, this.migrate);
}

/// Framework migration local data (SharedPreferences) — mục 42.
///
/// Flow đặc tả:
/// 1. **Auto backup** toàn bộ keys trước khi đụng dữ liệu.
/// 2. Chạy từng bước **theo thứ tự**; dừng ngay khi có bước fail.
/// 3. Lỗi → **Rollback + Restore backup + Notify user**.
/// 4. Thành công → lưu `data_schema_version`, xoá backup tạm.
class DataMigration {
  /// Version schema hiện tại của code (tăng khi đổi data model).
  static const int currentSchemaVersion = 1;

  static const String _versionKey = 'data_schema_version';

  /// Báo cáo lần chạy gần nhất trong phiên — UI dùng để notify user khi
  /// rollback (mục 42). In-memory, không lưu storage.
  static MigrationReport? lastReport;

  /// Notifier cho UI: phát report sau khi migration chạy xong (kể cả
  /// rollback) — MainShell lắng nghe để hiện SnackBar đúng một lần.
  static final ValueNotifier<MigrationReport?> reportNotifier =
      ValueNotifier(null);

  /// Version đang lưu trong storage (0 = cài mới, chưa từng migrate).
  static int storedVersion() => StorageService.getInt(_versionKey) ?? 0;

  /// Có cần chạy migration không.
  static bool needsMigration() => storedVersion() < currentSchemaVersion;

  /// Snapshot toàn bộ keys hiện có của StorageService.
  ///
  /// SharedPreferences không expose danh sách keys qua wrapper hiện tại —
  /// đọc qua [StorageService.prefs].getKeys() (chỉ dùng trong migration,
  /// không lạm dụng ở nơi khác để giữ pattern StorageService).
  static Map<String, Object> snapshot() {
    final prefs = StorageService.prefs;
    final out = <String, Object>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value != null) out[key] = value;
    }
    return out;
  }

  /// Ghi lại toàn bộ snapshot (restore sau rollback).
  static void restoreSnapshot(Map<String, Object> backup) {
    final prefs = StorageService.prefs;
    for (final entry in backup.entries) {
      final v = entry.value;
      if (v is int) {
        prefs.setInt(entry.key, v);
      } else if (v is double) {
        prefs.setDouble(entry.key, v);
      } else if (v is bool) {
        prefs.setBool(entry.key, v);
      } else if (v is String) {
        prefs.setString(entry.key, v);
      } else if (v is List<String>) {
        prefs.setStringList(entry.key, v);
      }
    }
  }

  /// Encode snapshot thành JSON string (backup bền qua schema đổi kiểu).
  static String encodeBackup(Map<String, Object> backup) => jsonEncode(
        backup.map((k, v) => MapEntry(k, {'t': v.runtimeType.toString(), 'v': v.toString()})),
      );

  /// Các bước migration v0 → v1 hiện tại. Thêm bước mới khi tăng
  /// [currentSchemaVersion] — mỗi bước phải idempotent và không mất dữ liệu.
  static List<MigrationStep> defaultSteps() => [
        MigrationStep('dedupe_id_lists', _dedupeIdLists),
        MigrationStep('normalize_task_json', _normalizeTaskJson),
      ];

  /// Danh sách keys chứa danh sách id (StringList) — dẹp trùng lặp giữ thứ tự.
  static const List<String> _idListKeys = [
    'exam_ids',
    'today_task_ids',
    'study_log_ids',
    'mock_score_ids',
    'study_note_ids',
    'study_session_ids',
  ];

  static bool _dedupeIdLists() {
    final prefs = StorageService.prefs;
    for (final key in _idListKeys) {
      final list = prefs.getStringList(key);
      if (list == null) continue;
      // LinkedHashSet giữ thứ tự xuất hiện đầu tiên.
      final deduped = list.toSet().toList();
      if (deduped.length != list.length) {
        prefs.setStringList(key, deduped);
      }
    }
    return true;
  }

  /// Re-serialize task qua model mới để JSON thống nhất shape (bổ sung
  /// field mới với giá trị mặc định). JSON hỏng → **giữ nguyên**, không
  /// xóa (không để mất dữ liệu — mục 42).
  static bool _normalizeTaskJson() {
    for (final id in StorageService.getTodayTaskIds()) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        final normalized = TodayTask.fromJsonString(raw).toJsonString();
        if (normalized != raw) {
          StorageService.setTodayTaskJson(id, normalized);
        }
      } catch (_) {
        // Bỏ qua entry hỏng — người dùng có thể xuất dữ liệu để tự soát.
      }
    }
    return true;
  }

  /// Chạy migration với các bước khai báo. Trả [MigrationReport].
  static MigrationReport run(List<MigrationStep> steps) {
    final from = storedVersion();

    // Đã mới → không làm gì (idempotent, chạy lại vô hại).
    if (from >= currentSchemaVersion) {
      return const MigrationReport(ran: false, success: true);
    }

    // 1. Auto backup — bắt buộc trước khi đụng dữ liệu.
    final backup = snapshot();

    final ran = <String>[];
    for (final step in steps) {
      ran.add(step.name);
      bool ok;
      try {
        ok = step.migrate();
      } catch (_) {
        ok = false;
      }
      if (!ok) {
        // 3. Rollback + Restore + Notify (mục 42).
        restoreSnapshot(backup);
        return lastReport = MigrationReport(
          ran: true,
          success: false,
          rolledBack: true,
          stepsRun: ran,
          userMessage:
              'Có chút sự cố khi cập nhật dữ liệu — EduPulse đã khôi phục nguyên trạng. Dữ liệu của bạn vẫn an toàn, thử lại sau nhé.',
        );
      }
    }

    // 4. Thành công — đánh dấu version, snapshot cũ không cần nữa.
    StorageService.setInt(_versionKey, currentSchemaVersion);
    return MigrationReport(ran: true, success: true, stepsRun: ran)
      .._notify();
  }
}

extension _MigrationReportNotify on MigrationReport {
  void _notify() {
    DataMigration.lastReport = this;
    DataMigration.reportNotifier.value = this;
  }
}

/// Logger debug-only cho console.
void logMigration(MigrationReport report) {
  if (!kDebugMode) return;
  // ignore: avoid_print
  print('[Migration] ran=${report.ran} success=${report.success} '
      'rolledBack=${report.rolledBack} steps=${report.stepsRun}');
}
