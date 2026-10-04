import '../../features/study/domain/models/study_models.dart';
import '../../features/study/domain/repositories/study_session_repository.dart';
import '../utils/storage_service.dart';

/// Một kết luận về nhịp học của học sinh, kèm độ tin cậy và bằng chứng.
class RhythmInsight {
  const RhythmInsight({
    required this.key,
    required this.summary,
    required this.confidence,
    this.evidence,
    this.subject,
  });

  final String key;
  final String summary;

  /// Môn liên quan (nếu insight này về một môn cụ thể).
  final String? subject;

  /// 0..1 — dựa trên số mẫu dữ liệu. < 0.5 coi như "đoán", UI/AI không nên
  /// nói chắc chắn.
  final double confidence;
  final String? evidence;
}

/// Nhịp học cá nhân — suy luận hoàn toàn trên thiết bị, không gọi model.
///
/// Nguồn dữ liệu: các phiên focus (Pomodoro) học sinh chủ động lưu, kèm điểm
/// tự đánh giá `focus`/`effectiveness` (1–5). Từ đó rút ra:
/// - **Giờ vàng**: khung giờ học sinh đang học hiệu quả nhất thật sự.
/// - **Môn bị bỏ quên**: có trong kế hoạch nhưng lâu không có phiên nào.
/// - **Nguy cơ chán học (burnout)**: 2 phiên gần nhất liên tiếp chất lượng thấp.
///
/// Lớp này là NGUỒN DUY NHẤT cho: bản tin hằng ngày, readiness factor
/// "nhịp phù hợp", đề xuất thứ tự task và khối NGỮ CẢNH gửi AI.
class StudyRhythm {
  StudyRhythm._();

  static const int _minSessionsForPeak = 3;
  static const int _minPerHour = 2;

  /// Đọc toàn bộ phiên focus từ Storage (local-first).
  ///
  /// Qua [StudySessionRepository] để mọi nơi đọc phiên học thấy cùng một
  /// cách xử lý phiên JSON hỏng.
  static List<StudySession> sessions() => StudySessionRepository.instance.getAll();

  // ------------------------------------------------------------------
  // Giờ vàng
  // ------------------------------------------------------------------

  /// Khung giờ học hiệu quả nhất (dựa trên phiên có self-rating cao).
  /// Trả null khi chưa đủ dữ liệu — người gọi phải xử lý thân thiện.
  static RhythmInsight? peakHour({DateTime? now, List<StudySession>? source}) {
    final reference = now ?? DateTime.now();
    final recent = (source ?? sessions())
        .where((s) =>
            reference.difference(s.completedAt).inDays >= 0 &&
            reference.difference(s.completedAt).inDays <= 28)
        .toList();
    if (recent.length < _minSessionsForPeak) return null;

    final byHour = <int, List<StudySession>>{};
    for (final s in recent) {
      byHour.putIfAbsent(s.completedAt.hour, () => []).add(s);
    }
    final viable = byHour.entries.where((e) => e.value.length >= _minPerHour);
    if (viable.isEmpty) return null;

    final best = viable.reduce((a, b) =>
        _quality(a.value) >= _quality(b.value) ? a : b);
    final end = (best.key + 2) % 24;
    final total = recent.length;
    return RhythmInsight(
      key: 'peak_hour',
      summary: 'Học hiệu quả nhất khung ${_hh(best.key)}–${_hh(end)}',
      confidence: (best.value.length / total).clamp(0.0, 1.0),
      evidence: '${best.value.length}/$total phiên gần đây trong khung này '
          'có chất lượng ${_quality(best.value).toStringAsFixed(1)}/5',
    );
  }

  // ------------------------------------------------------------------
  // Môn bị bỏ quên
  // ------------------------------------------------------------------

  /// Môn có nhiệm vụ trong kế hoạch nhưng >= 5 ngày không có phiên focus nào.
  static RhythmInsight? neglectedSubject({
    DateTime? now,
    List<StudySession>? source,
    List<String>? taskSubjects,
  }) {
    final reference = now ?? DateTime.now();
    final sessionsList = source ?? sessions();
    // Chưa có phiên học nào ⇒ chưa đủ cơ sở nói môn nào "bị bỏ quên"
    // (mọi môn sẽ cùng 99 ngày — tín hiệu vô nghĩa, loãng cảnh báo thật).
    if (sessionsList.isEmpty) return null;

    String? worst;
    var worstDays = 0;
    for (final subject in taskSubjects ?? _taskSubjects()) {
      if (subject.trim().isEmpty) continue;
      DateTime? last;
      for (final s in sessionsList) {
        if (s.subject.trim().toLowerCase() != subject.trim().toLowerCase()) {
          continue;
        }
        if (last == null || s.completedAt.isAfter(last)) last = s.completedAt;
      }
      final days = last == null
          ? 99
          : reference.difference(last).inDays;
      if (days >= 5 && days > worstDays) {
        worst = subject;
        worstDays = days;
      }
    }
    if (worst == null) return null;
    return RhythmInsight(
      key: 'neglected_subject',
      summary: worstDays >= 99
          ? '"$worst" chưa có phiên học nào dù đang trong kế hoạch'
          : '"$worst" đã $worstDays ngày không được chạm tới',
      confidence: worstDays >= 99 ? 0.9 : (worstDays / 14).clamp(0.5, 1.0),
      evidence: 'Kế hoạch hôm nay có nhiệm vụ môn "$worst"',
      subject: worst,
    );
  }

  static List<String> _taskSubjects() {
    final out = <String>[];
    for (final id in StorageService.getTodayTaskIds()) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        out.add(TodayTask.fromJsonString(raw).subject);
      } catch (_) {}
    }
    return out;
  }

  // ------------------------------------------------------------------
  // Burnout — 2 phiên gần nhất liên tiếp chất lượng thấp
  // ------------------------------------------------------------------

  /// True khi 2 phiên có tự đánh giá GẦN NHẤT đều thấp (≤ 2/5 trung bình)
  /// và diễn ra trong 7 ngày. Cảnh báo nhẹ nhàng: mời nghỉ, không đe doạ.
  static RhythmInsight? burnoutRisk({
    DateTime? now,
    List<StudySession>? source,
  }) {
    final reference = now ?? DateTime.now();
    final rated = (source ?? sessions())
        .where((s) => s.focus != null || s.effectiveness != null)
        .where((s) => reference.difference(s.completedAt).inDays <= 7)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    if (rated.length < 2) return null;

    double quality(StudySession s) =>
        ((s.focus ?? 3) + (s.effectiveness ?? 3)) / 2;
    final last2Low = quality(rated[0]) <= 2 && quality(rated[1]) <= 2;
    if (!last2Low) return null;

    return RhythmInsight(
      key: 'burnout_risk',
      summary: 'Hai phiên gần nhất đều nặng nhọc — hôm nay nên học nhẹ',
      confidence: 0.75,
      evidence:
          'Chất lượng tự đánh giá: ${quality(rated[0]).toStringAsFixed(1)}/5, '
          '${quality(rated[1]).toStringAsFixed(1)}/5',
    );
  }

  /// Tổng phút focus hôm nay (dùng cho đề xuất giờ vàng còn trống).
  static int minutesToday({DateTime? now, List<StudySession>? source}) {
    final reference = now ?? DateTime.now();
    return (source ?? sessions())
        .where((s) =>
            s.completedAt.year == reference.year &&
            s.completedAt.month == reference.month &&
            s.completedAt.day == reference.day)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  // ------------------------------------------------------------------
  // Đề xuất thứ tự task theo nhịp học (P1b)
  // ------------------------------------------------------------------

  /// Đề xuất xếp lại nhiệm vụ hôm nay: môn khó (điểm thi thử thấp nhất) và
  /// môn bị bỏ quên lên trước — để học sinh làm phần nặng vào lúc còn sức,
  /// ghép với giờ vàng hiện ở bản tin. Không xoá/không đổi gì ngoài THỨ TỰ;
  /// task đã xong giữ nguyên vị trí. Học sinh vẫn chốt cuối cùng (1 nút).
  static List<TodayTask> suggestOrder(List<TodayTask> tasks,
      {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final pending =
        tasks.where((t) => !t.isDone && t.status != 'skipped').toList();
    if (pending.length < 2) return tasks;

    final weakest = _weakestTaskSubject(pending);
    final neglected = neglectedSubject(
        now: reference, taskSubjects: pending.map((t) => t.subject).toList());
    final prioritySubjects = <String>{
      if (weakest != null) weakest,
      if (neglected?.subject != null) neglected!.subject!.trim().toLowerCase(),
    }..removeWhere((s) => s.trim().isEmpty);

    if (prioritySubjects.isEmpty) return tasks;

    // Chỉ thay pending vào đúng các vị trí pending — giữ nguyên vị trí task
    // đã xong/bỏ qua để UI không nhảy lung tung.
    var pi = 0;
    final orderedPending = [
      ...pending.where((t) => prioritySubjects
          .contains(t.subject.trim().toLowerCase())),
      ...pending.where((t) => !prioritySubjects
          .contains(t.subject.trim().toLowerCase())),
    ];
    return [
      for (final t in tasks)
        if (!t.isDone && t.status != 'skipped') orderedPending[pi++] else t,
    ];
  }

  /// Môn có điểm thi thử trung bình THẤP NHẤT trong các môn đang có task —
  /// proxy đơn giản cho "môn khó".
  static String? _weakestTaskSubject(List<TodayTask> tasks) {
    final subjects =
        tasks.map((t) => t.subject.trim()).where((s) => s.isNotEmpty).toSet();
    if (subjects.isEmpty) return null;

    final sums = <String, List<double>>{};
    for (final id in StorageService.getMockScoreIds()) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        final m = MockScore.fromJsonString(raw);
        final key = m.subject.trim().toLowerCase();
        if (subjects.contains(m.subject.trim()) ||
            subjects.any((s) => s.trim().toLowerCase() == key)) {
          sums.putIfAbsent(key, () => []).add(m.score);
        }
      } catch (_) {}
    }
    if (sums.isEmpty) return null;
    String? weakest;
    var worst = double.infinity;
    for (final e in sums.entries) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      if (avg < worst) {
        worst = avg;
        weakest = e.key;
      }
    }
    return weakest;
  }

  static double _quality(List<StudySession> group) {
    final scored = group
        .where((s) => s.focus != null || s.effectiveness != null)
        .toList();
    if (scored.isEmpty) return 3;
    final ratings =
        scored.map((s) => ((s.focus ?? 3) + (s.effectiveness ?? 3)) / 2);
    return ratings.reduce((a, b) => a + b) / scored.length;
  }

  static String _hh(int hour) => hour.toString().padLeft(2, '0');
}
