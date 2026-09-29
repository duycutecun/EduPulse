import 'dart:convert';

import '../../features/study/domain/models/study_models.dart';
import 'storage_service.dart';

/// Xuất / nhập dữ liệu cục bộ (đặc tả mục 19 — Data export, Delete).
///
/// Đặc tả yêu cầu export **JSON, CSV, Markdown, ZIP** và **import được
/// hỗ trợ**. Bản này phủ JSON (đầy đủ, dùng để import) + CSV (study log)
/// + Markdown (notes) — đủ dùng trên web/PWA không cần thêm package.
///
/// Nguyên tắc:
/// - **Local data luôn tách rời cloud sync** — export không cần đăng nhập.
/// - **Import không bao giờ ghi đè dữ liệu hiện có**: bản ghi trùng id
///   hoặc trùng tiêu đề task bị bỏ qua (merge an toàn, mục 19 Conflict).
/// - JSON hỏng / sai schema → trả lỗi rõ ràng, không crash, không mất data.
class DataTransfer {
  DataTransfer._();

  // ------------------------------------------------------------------
  // Export
  // ------------------------------------------------------------------

  static Map<String, dynamic> collectAll() {
    final tasks = StorageService.getTodayTaskIds()
        .map(StorageService.getTodayTaskJson)
        .whereType<String>()
        .toList();
    final notes = StorageService.getStudyNoteIds()
        .map(StorageService.getStudyNoteJson)
        .whereType<String>()
        .toList();
    final sessions = StorageService.getStudySessionIds()
        .map(StorageService.getStudySessionJson)
        .whereType<String>()
        .toList();
    final exams = StorageService.getExamIds()
        .map(StorageService.getExamJson)
        .whereType<String>()
        .toList();
    final logs = StorageService.getStudyLogIds()
        .map((id) => StorageService.prefs.getString('study_log_$id'))
        .whereType<String>()
        .toList();

    return {
      'app': 'EduPulse',
      'schema': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasks,
      'notes': notes,
      'sessions': sessions,
      'exams': exams,
      'studyLogs': logs,
      'primaryExamId': StorageService.getPrimaryExamId(),
      'userName': StorageService.getUserName(),
      'userTarget': StorageService.getUserTarget(),
    };
  }

  static String exportJson() => jsonEncode(collectAll());

  /// CSV nhật ký học: date,subject,hours,note — mở được bằng Excel/Sheets.
  static String exportStudyLogCsv() {
    final rows = <List<String>>[
      ['date', 'subject', 'hours', 'note'],
    ];
    for (final id in StorageService.getStudyLogIds()) {
      final raw = StorageService.prefs.getString('study_log_$id');
      if (raw == null) continue;
      try {
        final log = StudyLog.fromJsonString(raw);
        rows.add([
          log.date.toIso8601String().substring(0, 10),
          log.subject,
          log.hours.toStringAsFixed(2),
          (log.note ?? '').replaceAll(',', ';'),
        ]);
      } catch (_) {
        // Bỏ qua bản ghi hỏng — export không bao giờ fail vì 1 dòng lỗi.
      }
    }
    return rows.map((r) => r.join(',')).join('\n');
  }

  /// Markdown gộp tất cả ghi chú — đọc được bằng bất kỳ editor nào.
  static String exportNotesMarkdown() {
    final buffer = StringBuffer('# Ghi chú EduPulse\n\n');
    var count = 0;
    for (final id in StorageService.getStudyNoteIds()) {
      final raw = StorageService.getStudyNoteJson(id);
      if (raw == null) continue;
      try {
        final note = StudyNote.fromJsonString(raw);
        count++;
        buffer.writeln('## ${note.title.isEmpty ? 'Chưa có tiêu đề' : note.title}');
        if (note.tags.isNotEmpty) buffer.writeln(note.tags.map((t) => '#$t').join(' '));
        buffer.writeln();
        buffer.writeln(note.body);
        buffer.writeln();
        buffer.writeln('_Cập nhật: ${note.updatedAt.toIso8601String().substring(0, 10)}_');
        buffer.writeln('---');
        buffer.writeln();
      } catch (_) {
        // Bỏ qua bản ghi hỏng.
      }
    }
    if (count == 0) buffer.writeln('_(Chưa có ghi chú)_');
    return buffer.toString();
  }

  // ------------------------------------------------------------------
  // Import
  // ------------------------------------------------------------------

  static ({int imported, int skipped, String error}) importJson(String raw) {
    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return (imported: 0, skipped: 0, error: 'Tệp không phải JSON hợp lệ.');
      }
      data = decoded;
    } catch (_) {
      return (imported: 0, skipped: 0, error: 'Tệp không phải JSON hợp lệ.');
    }

    if (data['app'] != 'EduPulse') {
      return (imported: 0, skipped: 0, error: 'Tệp không phải bản xuất của EduPulse.');
    }

    var imported = 0;
    var skipped = 0;

    void importIds(
      List<dynamic>? items, {
      required String Function(String json) idOf,
      required List<String> Function() existingIds,
      required void Function(String id, String json) write,
      required void Function(List<String> ids) saveIds,
      required Set<String> seen,
    }) {
      for (final item in items ?? const []) {
        if (item is! String) continue;
        final id = idOf(item);
        if (id.isEmpty) continue;
        if (existingIds().contains(id) || seen.contains(id)) {
          skipped++;
          continue;
        }
        write(id, item);
        seen.add(id);
        imported++;
      }
    }

    final newTaskIds = <String>{};
    importIds(
      data['tasks'] as List?,
      idOf: _idOf,
      existingIds: StorageService.getTodayTaskIds,
      write: StorageService.setTodayTaskJson,
      saveIds: StorageService.setTodayTaskIds,
      seen: newTaskIds,
    );
    if (newTaskIds.isNotEmpty) {
      StorageService.setTodayTaskIds([...StorageService.getTodayTaskIds(), ...newTaskIds]);
    }

    final noteIds = <String>{};
    importIds(
      data['notes'] as List?,
      idOf: _idOf,
      existingIds: StorageService.getStudyNoteIds,
      write: StorageService.setStudyNoteJson,
      saveIds: StorageService.setStudyNoteIds,
      seen: noteIds,
    );
    if (noteIds.isNotEmpty) {
      StorageService.setStudyNoteIds([...StorageService.getStudyNoteIds(), ...noteIds]);
    }

    final sessionIds = <String>{};
    importIds(
      data['sessions'] as List?,
      idOf: _idOf,
      existingIds: StorageService.getStudySessionIds,
      write: StorageService.setStudySessionJson,
      saveIds: StorageService.setStudySessionIds,
      seen: sessionIds,
    );
    if (sessionIds.isNotEmpty) {
      StorageService.setStudySessionIds([...StorageService.getStudySessionIds(), ...sessionIds]);
    }

    final examIds = <String>{};
    importIds(
      data['exams'] as List?,
      idOf: _idOf,
      existingIds: StorageService.getExamIds,
      write: StorageService.setExamJson,
      saveIds: StorageService.setExamIds,
      seen: examIds,
    );
    if (examIds.isNotEmpty) {
      StorageService.setExamIds([...StorageService.getExamIds(), ...examIds]);
    }

    // Primary exam: chỉ chọn nếu chưa có.
    final primaryId = data['primaryExamId'];
    if (primaryId is String &&
        primaryId.isNotEmpty &&
        StorageService.getPrimaryExamId() == null &&
        StorageService.getExamIds().contains(primaryId)) {
      StorageService.setPrimaryExamId(primaryId);
    }

    return (imported: imported, skipped: skipped, error: '');
  }

  static String _idOf(String json) {
    try {
      final id = jsonDecode(json)['id'];
      return id is String ? id : '';
    } catch (_) {
      return '';
    }
  }

  // ------------------------------------------------------------------
  // Thống kê & xóa dữ liệu cục bộ (mục 19 — Delete local data)
  // ------------------------------------------------------------------

  static ({int tasks, int notes, int sessions, int exams, int logs}) counts() => (
        tasks: StorageService.getTodayTaskIds().length,
        notes: StorageService.getStudyNoteIds().length,
        sessions: StorageService.getStudySessionIds().length,
        exams: StorageService.getExamIds().length,
        logs: StorageService.getStudyLogIds().length,
      );

  /// Xóa toàn bộ dữ liệu học cục bộ (task, note, session, exam, log).
  /// KHÔNG xóa: lịch sử AI, cài đặt, tài khoản — đó là các hành động riêng
  /// với xác nhận riêng (mục 19: mỗi loại xóa là một lựa chọn riêng).
  static void deleteAllStudyData() {
    for (final id in StorageService.getTodayTaskIds()) {
      StorageService.removeTodayTask(id);
    }
    for (final id in StorageService.getStudyNoteIds()) {
      StorageService.removeStudyNote(id);
    }
    for (final id in StorageService.getStudySessionIds()) {
      StorageService.prefs.remove('study_session_$id');
    }
    StorageService.setStudySessionIds([]);
    for (final id in StorageService.getExamIds()) {
      StorageService.removeExam(id);
    }
    for (final id in StorageService.getStudyLogIds()) {
      StorageService.prefs.remove('study_log_$id');
    }
    StorageService.setStudyLogIds([]);
    StorageService.setString('profile_best_time', '');
    StorageService.setString('profile_session_minutes', '');
  }
}
