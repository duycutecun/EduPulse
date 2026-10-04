import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../features/study/domain/repositories/study_session_repository.dart';
import '../../features/tasks/domain/models/task_state.dart';
import '../constants/subject_catalog.dart';
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
  ///
  /// - **v1** — shape `TodayTask` chuẩn hoá (bổ sung field mới với giá trị mặc định).
  /// - **v2** — Sprint 2 (BE-2.3): backfill `createdAt`/`updatedAt`, chuẩn hoá
  ///   `status` về giá trị canonical, cứu task "mồ côi", vá mâu thuẫn `isDone`.
  /// - **v3** — Sprint 3 (STUDY-LOG-MERGE): xoá các dòng `StudyLog` mà bản cũ
  ///   tự sinh cho *cùng* một vòng Pomodoro đã có `StudySession`.
  static const int currentSchemaVersion = 3;

  static const String _versionKey = 'data_schema_version';

  /// Tiền tố khoá lưu từng TodayTask — phải khớp `StorageService`
  /// (`task_$id`). Sai tiền tố ⇒ bước cứu task mồ côi im lặng không làm gì.
  static const String _taskKeyPrefix = 'task_';

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

  /// Các bước migration v0 → v2 hiện tại. Thêm bước mới khi tăng
  /// [currentSchemaVersion] — mỗi bước phải idempotent và không mất dữ liệu.
  static List<MigrationStep> defaultSteps() => [
        MigrationStep('dedupe_id_lists', _dedupeIdLists),
        MigrationStep('normalize_task_json', _normalizeTaskJson),
        MigrationStep('recover_orphan_tasks', _recoverOrphanTasks),
        MigrationStep('backfill_task_timestamps', _backfillTaskTimestamps),
        MigrationStep('heal_task_consistency', _healTaskConsistency),
        MigrationStep('drop_legacy_pomodoro_logs', _dropLegacyPomodoroLogs),
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

  /// Cứu task "mồ côi" (BE-2.3): JSON của task còn trong storage nhưng `id`
  /// đã bị mất khỏi `today_task_ids` (rủi ro thật khi app bị kill giữa lúc
  /// ghi). Không có bước này thì task đó **biến mất vĩnh viễn khỏi UI**.
  ///
  /// Cách dò: mọi key `today_task_*` trong storage là JSON, trừ chính
  /// `today_task_ids`. Task parse được → thêm lại id vào danh sách (giữ thứ tự
  /// cũ cho các id đã có, task mồ côi xếp cuối).
  static bool _recoverOrphanTasks() {
    final known = StorageService.getTodayTaskIds().toSet();
    final orphans = <String>[];

    for (final key in StorageService.prefs.getKeys().toList()) {
      // Khoá thật của TodayTask là `task_$id` (xem StorageService).
      if (!key.startsWith(_taskKeyPrefix)) continue;
      final id = key.substring(_taskKeyPrefix.length);
      if (id.isEmpty || known.contains(id)) continue;
      // Chỉ nhận lại nếu JSON thực sự parse được thành task hợp lệ.
      final raw = StorageService.prefs.getString(key);
      if (raw == null) continue;
      try {
        final task = TodayTask.fromJsonString(raw);
        if (task.id.isEmpty) continue;
        orphans.add(task.id);
      } catch (_) {
        // JSON hỏng → để nguyên cho user tự xuất dữ liệu, không xoá.
      }
    }

    if (orphans.isEmpty) return true;
    StorageService.setTodayTaskIds([...StorageService.getTodayTaskIds(), ...orphans]);
    return true;
  }

  /// Backfill `createdAt`/`updatedAt` cho task tạo ở bản v1 (BE-2.1 yêu cầu
  /// timestamp bắt buộc nhưng dữ liệu cũ không có).
  ///
  /// Suy ra từ dữ liệu sẵn có để giá trị gần đúng, không bịa đặt:
  /// `updatedAt` = task có `deadline`/`scheduledAt` không? dùng mốc đó :
  /// `createdAt` = `scheduledAt` : `deadline` : `now`.
  static bool _backfillTaskTimestamps() {
    final now = DateTime.now();
    for (final id in StorageService.getTodayTaskIds()) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        final task = TodayTask.fromJsonString(raw);
        if (task.createdAt != null && task.updatedAt != null) continue;

        final inferred = task.scheduledAt ?? task.deadline;
        task.createdAt ??= inferred ?? now;
        task.updatedAt ??= inferred ?? now;

        StorageService.setTodayTaskJson(id, task.toJsonString());
      } catch (_) {
        // Giữ nguyên entry hỏng — không xoá dữ liệu người dùng.
      }
    }
    return true;
  }

  /// Vá mâu thuẫn giữa `isDone` và `status` (BE-2.3): v1 cho phép hai trường này
  /// lệch nhau do nhiều nơi tự ghi, khiến state machine và UI hiển thị khác nhau.
  ///
  /// Quy tắc: `status` là nguồn chân lý, `isDone` chỉ là cờ dẫn xuất.
  /// - `completed` → `isDone = true`.
  /// - `todo`/`started`/`rescheduled` → `isDone = false`.
  /// - `skipped` giữ `isDone = false` nhưng **không** xoá `skipReason`.
  static bool _healTaskConsistency() {
    for (final id in StorageService.getTodayTaskIds()) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        final task = TodayTask.fromJsonString(raw);
        final status = TaskStatus.fromString(task.status);
        final canonical = status.value;
        final expectedIsDone = status == TaskStatus.completed;
        final normalizedStatus = canonical != task.status;

        if (!normalizedStatus && task.isDone == expectedIsDone) continue;

        task.status = canonical;
        task.isDone = expectedIsDone;
        StorageService.setTodayTaskJson(id, task.toJsonString());
      } catch (_) {
        // Giữ nguyên entry hỏng.
      }
    }
    return true;
  }

  /// Xoá dòng `StudyLog` mà bản cũ tự sinh cho một vòng Pomodoro (v3).
  ///
  /// Bản cũ ghi **hai** bản ghi cho cùng một khoảng thời gian: `StudySession`
  /// (phút, có phản hồi) và `StudyLog` (giờ thập phân). Mọi tổng hợp đã gộp hai
  /// nguồn nên thời gian học cũ đang bị đếm hai lần.
  ///
  /// Xoá phía `StudyLog`, giữ `StudySession`, vì phiên học là bản ghi giàu
  /// thông tin hơn (`startedAt`/`endedAt`, phản hồi, `taskId`).
  ///
  /// **Chỉ xoá khi có bằng chứng**, không đoán bừa:
  /// 1. `note` đúng mẫu `Phiên <số>` — nguyên văn chuỗi bản cũ tự sinh, người
  ///    dùng không gõ thế.
  /// 2. Hoặc khớp được một phiên học thật: cùng môn, giờ lệch ≤ 3 phút (chênh
  ///    do làm tròn `_focusMinutes / 60`), và cách nhau ≤ 2 giờ.
  ///
  /// Dòng không khớp điều kiện nào được giữ nguyên — đó là ghi chép nhập tay,
  /// xoá nhầm là mất dữ liệu thật của người dùng.
  static bool _dropLegacyPomodoroLogs() {
    final sessions = StudySessionRepository.instance.getAll();
    final ids = StorageService.getStudyLogIds().toList();
    final duplicates = <String>[];

    for (final id in ids) {
      final raw = StorageService.getStudyLogJson(id);
      if (raw == null) continue;
      StudyLog log;
      try {
        log = StudyLog.fromJsonString(raw);
      } catch (_) {
        continue; // JSON hỏng — để nguyên cho user tự xuất dữ liệu.
      }
      if (_isLegacyPomodoroLog(log, sessions)) duplicates.add(id);
    }

    for (final id in duplicates) {
      StorageService.removeStudyLog(id);
    }
    return true;
  }

  /// Nguyên văn ghi chú bản cũ tự sinh khi vòng Pomodoro không gắn task.
  static final RegExp _legacyRoundNote = RegExp(r'^Phi\u00ean \d+$');

  /// Cùng loại trùng: khớp được một `StudySession` cùng môn, cùng độ dài,
  /// sát thời điểm. Lệch giờ nhiều hơn 3 phút hoặc lệch thời gian quá 2 giờ
  /// thì coi là ghi chép riêng của người dùng — giữ lại.
  static const double _legacyHoursTolerance = 3 / 60;

  static const Duration _legacyTimeTolerance = Duration(hours: 2);

  static bool _isLegacyPomodoroLog(StudyLog log, List<StudySession> sessions) {
    final note = (log.note ?? '').trim();
    if (_legacyRoundNote.hasMatch(note)) return true;

    final subject = _normalizeSubject(log.subject);
    if (subject.isEmpty) return false;
    for (final session in sessions) {
      if (_normalizeSubject(session.subject) != subject) continue;
      final sessionHours = session.actualMinutes / 60;
      if ((log.hours - sessionHours).abs() > _legacyHoursTolerance) continue;
      final gap = log.date.difference(session.completedAt).abs();
      if (gap <= _legacyTimeTolerance) return true;
    }
    return false;
  }

  static String _normalizeSubject(String value) =>
      AppSubjects.normalize(value).toLowerCase();


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
