import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/ai/ai_refresh_service.dart';
import '../../../core/pwa/pwa_service.dart';
import '../../../core/sync/sync_state.dart';
import '../../../core/utils/storage_service.dart';
import '../../../core/utils/supabase_service.dart';
import 'models/exam_model.dart';

/// BE-5.2 — Quản lý dữ liệu Kỳ thi.
///
/// Trước đây mỗi màn tự gọi `StorageService.setExamJson` + `setExamIds` theo
/// đúng chuỗi, và `MainShellScreen` giữ thêm bản sao danh sách kỳ thi trong
/// state. Hai bản sao sớm muộn cũng lệch nhau (xoá kỳ thi chính → primary id
/// trỏ vào khoảng không). Repository này là **đường duy nhất** để đọc/ghi kỳ
/// thi, và phát [revision] để mọi màn vẽ lại khi dữ liệu đổi.
class ExamRepository {
  ExamRepository._();

  static final ExamRepository instance = ExamRepository._();

  /// Tín hiệu "dữ liệu kỳ thi vừa đổi" — UI listen để refresh.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Debounce cho đẩy lên cloud (xem [_scheduleCloudSync]).
  Timer? _syncDebounce;

  /// Mọi thay đổi đều đi qua đây: bắn `revision` cho UI, kích AI, rồi hẹn
  /// đẩy lên cloud. Trước đây kỳ thi chỉ lên cloud khi bấm nút đồng bộ tay
  /// trong Tài khoản — lưu xong nó nằm im trên máy, mất nếu gỡ app.
  /// Báo “dữ liệu kỳ thi đổi từ BÊN NGOÀI” (ví dụ khôi phục từ cloud).
  ///
  /// Cố ý KHÔNG đẩy cloud lại: vừa kéo về thì đẩy lên sẽ là một vòng
  /// đẩy–kéo vô nghĩa. Chỉ bắn tín hiệu cho UI vẽ lại.
  void notifyExternalChange() => revision.value++;

  void _afterMutation() {
    revision.value++;
    AiRefreshService.notifyDataChanged();
    _scheduleCloudSync();
  }

  /// Debounce 2s như Task: thao tác liên tiếp chỉ gọi cloud một lần.
  /// Offline thì bỏ qua — local đã ghi an toàn, `SyncStateService` lo phần định kỳ.
  void _scheduleCloudSync() {
    if (!SupabaseService.isConfigured || !PwaService.isOnline) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), () async {
      try {
        final ok = await SupabaseService.syncExams(
            getAll(), StorageService.getPrimaryExamId());
        if (ok) SyncStateService.markSynced();
      } catch (e) {
        debugPrint('[ExamRepository] Cloud sync failed (offline-first): $e');
      }
    });
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Toàn bộ kỳ thi, giữ nguyên thứ tự đã lưu.
  List<ExamModel> getAll() {
    final list = <ExamModel>[];
    for (final id in StorageService.getExamIds()) {
      final json = StorageService.getExamJson(id);
      if (json == null) continue;
      try {
        list.add(ExamModel.fromJsonString(json));
      } catch (e) {
        debugPrint('[ExamRepository] Corrupt exam $id: $e');
      }
    }
    return list;
  }

  ExamModel? getById(String id) {
    final json = StorageService.getExamJson(id);
    if (json == null) return null;
    try {
      return ExamModel.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  String? get primaryExamId => StorageService.getPrimaryExamId();

  /// Kỳ thi chính: theo id đã ghim, fallback về kỳ thi chưa qua gần nhất rồi
  /// mới đến kỳ thi bất kỳ. Không bao giờ trả về kỳ thi của id đã bị xoá.
  ExamModel? get primaryExam {
    final exams = getAll();
    if (exams.isEmpty) return null;

    final upcoming = exams.where((e) => !e.isExamDayOver).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final id = primaryExamId;
    if (id != null) {
      final pinned = exams.where((e) => e.id == id).toList();
      if (pinned.isNotEmpty) {
        // Kỳ thi đã qua ngày → tự chuyển sang kỳ thi sắp tới gần nhất (mục 40)
        // và ghim lại, thay vì tiếp tục đếm ngược một kỳ thi đã xong.
        if (!pinned.first.isExamDayOver) return pinned.first;
        if (upcoming.isNotEmpty) {
          StorageService.setPrimaryExamId(upcoming.first.id);
          return upcoming.first;
        }
        return pinned.first; // giữ kỳ thi cũ trong lịch sử
      }
    }

    if (upcoming.isNotEmpty) return upcoming.first;
    return exams.first;
  }

  /// Kỳ thi chưa kết thúc ngày thi, sớm nhất trước.
  List<ExamModel> upcoming({DateTime? now}) {
    final at = now ?? DateTime.now();
    final list = getAll()
        .where((e) => !e.isExamDayOver && e.dateTime.isAfter(at))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Thêm mới hoặc cập nhật (upsert theo `id`).
  void save(ExamModel exam) {
    StorageService.setExamJson(exam.id, exam.toJsonString());
    final ids = StorageService.getExamIds();
    if (!ids.contains(exam.id)) {
      ids.add(exam.id);
      StorageService.setExamIds(ids);
    }
    AiRefreshService.notifyDataChanged();
    _afterMutation();
  }

  /// Chỉ định kỳ thi chính. Id không tồn tại → từ chối (không ghim vào hư vô).
  bool setPrimary(String examId) {
    if (getById(examId) == null) return false;
    StorageService.setPrimaryExamId(examId);
    AiRefreshService.notifyDataChanged();
    _afterMutation();
    return true;
  }

  /// Đổi ngày thi — giữ nguyên mọi thông tin khác của kỳ thi.
  bool changeDate(String examId, DateTime newDate) {
    final exam = getById(examId);
    if (exam == null) return false;
    save(ExamModel(
      id: exam.id,
      name: exam.name,
      dateTime: newDate,
      type: exam.type,
      description: exam.description,
      emoji: exam.emoji,
      currentScore: exam.currentScore,
      targetScore: exam.targetScore,
    ));
    return true;
  }

  /// Xoá kỳ thi. Nếu là kỳ thi chính thì tự chuyển sang kỳ thi sắp tới gần nhất
  /// (hoặc xoá hẳn ghim nếu không còn kỳ thi nào).
  /// Xoá kỳ thi và **trả về bản ghi đã xoá** để hoàn tác (đối xứng với
  /// `TaskRepository.deleteTask` trả `DeletedTaskRef`).
  ///
  /// Xoá kỳ thi là mất vĩnh viễn dù các nhiệm vụ đã gắn `examId` — nên nơi
  /// gọi PHẢI cho người dùng hoàn tác được, hoặc hỏi xác nhận.
  ExamModel? delete(String id) {
    final removed = getById(id);
    StorageService.removeExam(id);
    StorageService.removeExam(id);
    if (StorageService.getPrimaryExamId() == id) {
      final remaining = getAll();
      if (remaining.isEmpty) {
        StorageService.removeString(primaryExamKey);
      } else {
        final upcoming = remaining.where((e) => !e.isExamDayOver).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        StorageService.setPrimaryExamId(
            upcoming.isNotEmpty ? upcoming.first.id : remaining.first.id);
      }
    }
    AiRefreshService.notifyDataChanged();
    _afterMutation();
    return removed;
  }

  /// Xoá hết kỳ thi (dùng khi reset dữ liệu).
  void clear() {
    for (final id in StorageService.getExamIds()) {
      StorageService.removeExam(id);
    }
    StorageService.removeString(primaryExamKey);
    _afterMutation();
  }

  static const String primaryExamKey = 'primary_exam_id';
}
