import 'package:edupulse/core/constants/subject_catalog.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:flutter/foundation.dart';

/// Đường đọc/ghi duy nhất cho Phiên học (Study Session).
///
/// Trước đây mỗi màn tự giải mã `study_session_*` bằng tay: `study_screen`,
/// `calendar_screen`, `search_screen`, `today_service` và 4 tệp trong
/// `core/ai` đều có vòng lặp `try/catch` riêng. Hệ quả: JSON hỏng bị nuốt
/// im lặng ở một chỗ, lại hiện ra ở chỗ khác — và không ai xoá được phiên cũ
/// vì [StorageService] thiếu hàm `remove`.
class StudySessionRepository {
  StudySessionRepository._();

  static final StudySessionRepository instance = StudySessionRepository._();

  /// Tín hiệu "dữ liệu phiên học vừa đổi" (BE-3.3).
  ///
  /// Widget tổng thời gian học nghe [revision] để vẽ lại ngay khi phiên vừa
  /// kết thúc, thay vì chờ người dùng điều hướng. Tổng phút **tính ra** từ
  /// danh sách phiên nên bản thân nó luôn đúng — chỉ cần ai đó vẽ lại.
  ///
  /// Không dùng cho ảnh chụp vòng đang chạy: đó là tiến độ nội bộ của màn hình
  /// học, và việc lưu ảnh chụp diễn ra mỗi lần bấm — bắn tín hiệu sẽ vẽ lại
  /// toàn bộ widget giữa lúc đếm giờ.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Tăng [revision] sau mỗi lần ghi/xoá phiên.
  void _bumpRevision() => revision.value++;

  /// Mọi phiên, mới nhất trước. Phiên JSON hỏng bị bỏ qua **và log lại** —
  /// không có lý do âm thầm làm mất dữ liệu.
  List<StudySession> getAll() {
    final sessions = <StudySession>[];
    for (final id in StorageService.getStudySessionIds()) {
      final session = getById(id);
      if (session != null) sessions.add(session);
    }
    sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return sessions;
  }

  StudySession? getById(String id) {
    final json = StorageService.getStudySessionJson(id);
    if (json == null) return null;
    try {
      return StudySession.fromJsonString(json);
    } catch (e) {
      debugPrint('[StudySessionRepository] Corrupt session $id: $e');
      return null;
    }
  }

  /// Lịch sử phiên học của một nhiệm vụ (FE-2.2), mới nhất trước.
  ///
  /// Phiên không gắn task nào (`taskId == null`, ví dụ học Pomodoro rời rạc)
  /// không thuộc nhiệm vụ nào nên không xuất hiện ở đây.
  List<StudySession> getForTask(String taskId) {
    if (taskId.isEmpty) return const [];
    return getAll()
        .where((session) => session.taskId == taskId)
        .toList(growable: false);
  }

  /// Tổng phút đã học thực tế cho một nhiệm vụ.
  int totalMinutesForTask(String taskId) => getForTask(taskId)
      .fold<int>(0, (sum, session) => sum + session.actualMinutes);

  /// Tổng phút học trong một ngày (BE-3.1).
  ///
  /// Tính ra từ danh sách phiên thay vì lưu tổng riêng: tổng lưu sẵn trôi lệch
  /// mỗi khi người dùng xoá/sửa một phiên, rồi phải có thêm đường dọn dẹp và
  /// thêm một chỗ nữa để sai.
  int minutesOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return getAll().where((session) {
      final at = session.completedAt;
      return at.year == target.year &&
          at.month == target.month &&
          at.day == target.day;
    }).fold<int>(0, (sum, session) => sum + session.actualMinutes);
  }

  /// Tổng phút học của một môn, tuỳ chọn giới hạn theo ngày (BE-3.1).
  ///
  /// So khớp sau khi chuẩn hoá, vì `'Toán'` và `'📐 Toán'` cùng một môn — nếu
  /// so chuỗi thẳng thì tổng sẽ chia đôi tùy cách ghi.
  int minutesForSubject(String subject, {DateTime? day}) {
    final target = subject.trim();
    if (target.isEmpty) return 0;

    return getAll()
        .where((session) => _sameSubject(session.subject, target))
        .where((session) {
      if (day == null) return true;
      final at = session.completedAt;
      return at.year == day.year && at.month == day.month && at.day == day.day;
    }).fold<int>(0, (sum, session) => sum + session.actualMinutes);
  }

  static bool _sameSubject(String a, String b) {
    if (a == b) return true;
    return AppSubjects.normalize(a) == AppSubjects.normalize(b);
  }

  Future<void> save(StudySession session) async {
    final ids = StorageService.getStudySessionIds();
    if (!ids.contains(session.id)) ids.add(session.id);
    StorageService.setStudySessionIds(ids);
    StorageService.setStudySessionJson(session.id, session.toJsonString());
    _bumpRevision();
  }

  /// Cập nhật phản hồi của một phiên đã có (mood, focus, độ khó…).
  Future<bool> updateFeedback(
    String id, {
    int? mood,
    int? focus,
    int? difficulty,
    int? understanding,
    int? effectiveness,
    String? reflectionNote,
  }) async {
    final session = getById(id);
    if (session == null) return false;

    if (mood != null) session.mood = mood;
    if (focus != null) session.focus = focus;
    if (difficulty != null) session.difficulty = difficulty;
    if (understanding != null) session.understanding = understanding;
    if (effectiveness != null) session.effectiveness = effectiveness;
    if (reflectionNote != null) session.reflectionNote = reflectionNote;

    await save(session);
    return true;
  }

  void delete(String id) {
    StorageService.removeStudySession(id);
    _bumpRevision();
  }

  // --- Phiên đang chạy (BE-3.2) ------------------------------------------------
  //
  // Chỉ một vòng chạy tại một thời điểm nên dùng một khoá duy nhất, không phải
  // danh sách: có danh sách thì phải lo "vòng nào còn sống", mà vòng nào còn
  // sống chính là thứ ta không biết sau khi app bị kill.

  /// Lưu ảnh chụp vòng đang chạy để khôi phục sau khi app bị kill.
  void saveActive(ActiveStudySession session) =>
      StorageService.setString(activeSessionKey, session.toJsonString());

  /// Vòng đang chạy, hoặc `null` nếu không có / JSON hỏng.
  ActiveStudySession? getActive() =>
      ActiveStudySession.tryParse(StorageService.getString(activeSessionKey));

  void clearActive() => StorageService.removeString(activeSessionKey);

  static const String activeSessionKey = 'active_study_session';
}
