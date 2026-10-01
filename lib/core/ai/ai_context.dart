import 'dart:convert';

import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../utils/storage_service.dart';
import 'flashcard_service.dart';
import 'readiness_score.dart';

/// Gom dữ liệu học tập của học sinh thành một khối văn bản gửi kèm mọi
/// câu hỏi cho AI Coach (đặc tả mục 10.2).
///
/// Mục tiêu: AI không còn là khung chat rời rạc tách rời khỏi phần còn lại của
/// app. Nó biết đang ôn kỳ thi nào, còn mấy ngày, hôm nay làm được gì, điểm
/// yếu nằm ở môn nào, mỗi môn đang dùng bao nhiêu thời gian, chuỗi học thế
/// nào — nên lời khuyên cụ thể thay vì hỏi lại hoặc nói chung chung.
///
/// Toàn bộ dữ liệu đọc từ `StorageService` (local-first), nên AI vẫn hoạt
/// động kể cả khi chưa đăng nhập. Vì đây là dữ liệu cá nhân, chỉ gửi khi
/// người dùng cho phép qua cờ `ai_permission_read` (mặc định bật, có công
/// tắc trong Account). Tắt cờ => [build] trả về chuỗi rỗng và AI trở lại
/// trò chuyện thuần như trước.
///
/// Khối ngữ cảnh luôn được cắt gọn: proxy web (`api/openrouter.js`) giới hạn
/// payload ~20.000 ký tự, và context thừa làm model xao nhãng.
class AiStudyContext {
  /// Ngưỡng ký tự của cả khối. Chừa chỗ cho ảnh + lịch sử chat trong payload.
  static const int _maxChars = 2500;

  /// Số mục tối đa cho mỗi danh sách liệt kê.
  static const int _maxListItems = 6;

  /// Cửa sổ "gần đây" tính bằng ngày cho nhật ký học và phiên focus.
  static const int _recentDays = 7;

  /// Dựng khối ngữ cảnh. Trả về chuỗi rỗng khi không có gì để kể hoặc khi
  /// người dùng không cho phép AI đọc dữ liệu.
  static String build({DateTime? now}) {
    if (StorageService.getBool('ai_permission_read') == false) return '';

    final t = now ?? DateTime.now();
    final lines = <String>[];
    void add(String line) {
      if (line.trim().isNotEmpty) lines.add(line);
    }

    _profile(add);
    _exam(add, t);
    _momentum(add);
    _readiness(add);
    _tasks(add);
    _sessions(add, t);
    _logs(add, t);
    _mockScores(add, t);
    _notes(add);
    _flashcards(add);

    if (lines.isEmpty) return '';
    final block = lines.join('\n');
    if (block.length <= _maxChars) return block;
    return '${block.substring(0, _maxChars)}\n(ngữ cảnh bị rút gọn phía cuối)';
  }

  // --- Từng phần ---------------------------------------------------------

  static void _profile(void Function(String) add) {
    final parts = <String>[];
    final name = StorageService.getUserName().trim();
    final target = StorageService.getUserTarget().trim();
    if (name.isNotEmpty && name != 'Sĩ tử EduPulse') parts.add('tên $name');
    if (target.isNotEmpty) parts.add('mục tiêu "$target"');
    if (parts.isNotEmpty) add('HỌC SINH: ${parts.join(' · ')}');
  }

  static void _exam(void Function(String) add, DateTime now) {
    final exams = _readAll(
      StorageService.getExamIds(),
      StorageService.getExamJson,
      ExamModel.fromJsonString,
    );
    if (exams.isEmpty) return;

    // Ưu tiên kỳ thi được đánh dấu chính; nếu chưa chọn thì lấy kỳ thi sắp
    // tới gần nhất, không có thì lấy kỳ thi gần nhất nói chung.
    final primaryId = StorageService.getPrimaryExamId();
    ExamModel? main;
    if (primaryId != null) {
      for (final e in exams) {
        if (e.id == primaryId) {
          main = e;
          break;
        }
      }
    }
    main ??= _nearest(exams, now);
    if (main == null) return;
    final focus = main;

    final left = focus.daysLeft;
    final when = left > 0
        ? 'còn $left ngày'
        : left == 0
            ? 'thi hôm nay'
            : 'đã thi ${-left} ngày trước';
    final date = '${focus.dateTime.day}/${focus.dateTime.month}';
    final hasScore = focus.currentScore != null || focus.targetScore != null;
    final score = hasScore
        ? ' · điểm ${_score(focus.currentScore)} → mục tiêu ${_score(focus.targetScore)}'
        : '';
    add('KỲ THI CHÍNH: ${focus.name} ($when, ngày $date · ${_phase(focus)}$score)');

    final others = exams.where((e) => e.id != focus.id).toList(growable: false);
    if (others.isNotEmpty) {
      final text = others
          .take(_maxListItems)
          .map((e) =>
              '${e.name} (${e.daysLeft > 0 ? 'còn ${e.daysLeft} ngày' : 'đã qua'})')
          .join('; ');
      add('  Kỳ thi khác: $text');
    }
  }

  /// Kỳ thi gần thời điểm hiện tại nhất, ưu tiên những kỳ còn chưa thi.
  static ExamModel? _nearest(List<ExamModel> exams, DateTime now) {
    ExamModel? upcoming;
    var upcomingGap = 1 << 62;
    ExamModel? any;
    var anyGap = 1 << 62;
    for (final e in exams) {
      final gap = e.dateTime.difference(now).abs().inMinutes;
      if (any == null || gap < anyGap) {
        any = e;
        anyGap = gap;
      }
      final ahead = e.dateTime.isAfter(now);
      if (ahead && gap < upcomingGap) {
        upcoming = e;
        upcomingGap = gap;
      }
    }
    return upcoming ?? any;
  }

  static String _phase(ExamModel e) {
    switch (e.examPhase) {
      case ExamPhase.normal:
        return 'đang ôn dài hạn';
      case ExamPhase.revision:
        return 'rà soát cuối, còn ≤7 ngày';
      case ExamPhase.examDay:
        return 'ngày thi';
      case ExamPhase.postExam:
        return 'đã thi xong';
    }
  }

  static String _score(double? v) =>
      v == null ? 'chưa có' : v.toStringAsFixed(1);

  static void _momentum(void Function(String) add) {
    // Học sinh mới dùng app chưa có hoạt động nào thì bỏ qua mục này — gửi
    // "chuỗi học 0 ngày, cấp 1 (0/100 EXP)" chỉ là nhiễu, còn làm AI tưởng
    // học sinh đang học rất tệ.
    final streak = StorageService.getStreak();
    final record = StorageService.getStreakRecord();
    if (streak <= 0 && record <= 0 && StorageService.getXp() <= 0) return;

    final level = StorageService.getLevel();
    final progress = StorageService.getLevelProgress();
    final recordText = record > streak ? ', kỷ lục $record ngày' : '';
    add('ĐỘNG LỰC: chuỗi học $streak ngày$recordText · '
        'cấp $level (${progress.$1}/${progress.$2} EXP)');
  }

  /// Chỉ số sẵn sàng thi — AI dùng để trả lời các câu kiểu "mình sẵng sàng
  /// chưa", "nên ưu tiên gì" mà không phải tính lại từ đầu.
  static void _readiness(void Function(String) add) {
    final r = ReadinessScore.compute();
    if (r == null) return;
    add('SẴN SÀNG THI: ${r.score}/100 (${r.band})');
    for (final w in r.warnings.take(2)) {
      add('  Rủi ro: $w');
    }
    if (r.levers.isNotEmpty) {
      add('  Đòn bẩy hàng đầu: ${r.levers.first}');
    }
  }

  static void _tasks(void Function(String) add) {
    final tasks = _readAll(
      StorageService.getTodayTaskIds(),
      StorageService.getTodayTaskJson,
      TodayTask.fromJsonString,
    );
    if (tasks.isEmpty) return;

    var done = 0;
    var skipped = 0;
    final todo = <TodayTask>[];
    var rescheduled = 0;
    for (final t in tasks) {
      if (t.status == 'completed' || t.isDone) {
        done += 1;
      } else if (t.status == 'skipped') {
        skipped += 1;
      } else {
        todo.add(t);
      }
      if (t.rescheduleCount > 0) rescheduled += 1;
    }
    todo.sort((a, b) =>
        _priorityRank(a.priority).compareTo(_priorityRank(b.priority)));

    add('NHIỆM VỤ: $done/${tasks.length} đã xong · ${todo.length} chưa làm · '
        '$skipped bỏ qua');
    if (todo.isNotEmpty) {
      final shown = todo
          .take(_maxListItems)
          .map((t) => '${t.title} [${t.subject}, ${t.priority}, dự kiến '
              '${t.estimateMinutes}p]')
          .join('; ');
      add('  Còn lại: $shown${todo.length > _maxListItems ? ' …' : ''}');
    }
    if (skipped > 0) {
      final text = tasks
          .where((t) => t.status == 'skipped')
          .take(3)
          .map((t) => '${t.title}'
              '${t.skipReason == null ? '' : ' (${t.skipReason})'}')
          .join('; ');
      add('  Hay bỏ qua: $text');
    }
    if (rescheduled > 0) {
      add('  $rescheduled nhiệm vụ từng bị dời lịch');
    }
  }

  static int _priorityRank(String p) {
    switch (p) {
      case 'high':
        return 0;
      case 'low':
        return 2;
      default:
        return 1;
    }
  }

  static void _sessions(void Function(String) add, DateTime now) {
    final all = _sessionsFrom(StorageService.getStudySessionIds());
    if (all.isEmpty) return;

    var totalMinutes = 0;
    var recentMinutes = 0;
    var recentCount = 0;
    var focusSum = 0;
    var focusN = 0;
    var understandingSum = 0;
    var understandingN = 0;
    final bySubject = <String, int>{};

    for (final s in all) {
      totalMinutes += s.actualMinutes;
      bySubject[s.subject.isEmpty ? 'khác' : s.subject] =
          (bySubject[s.subject.isEmpty ? 'khác' : s.subject] ?? 0) +
              s.actualMinutes;
      if (now.difference(s.completedAt).inDays <= _recentDays) {
        recentMinutes += s.actualMinutes;
        recentCount += 1;
      }
      if (s.focus != null) {
        focusSum += s.focus!;
        focusN += 1;
      }
      if (s.understanding != null) {
        understandingSum += s.understanding!;
        understandingN += 1;
      }
    }

    add('PHIÊN FOCUS: ${all.length} phiên, tổng ${_hours(totalMinutes)} · '
        '$_recentDays ngày qua: $recentCount phiên / ${_hours(recentMinutes)}');
    final ranking = bySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final timeText = ranking
        .take(_maxListItems)
        .map((e) => '${e.key} ${_hours(e.value)}')
        .join(' · ');
    add('  Thời gian theo môn: $timeText');
    if (focusN > 0 || understandingN > 0) {
      final parts = <String>[];
      if (focusN > 0) {
        parts.add('tập trung TB ${(focusSum / focusN).toStringAsFixed(1)}/5');
      }
      if (understandingN > 0) {
        parts.add(
            'hiểu bài TB ${(understandingSum / understandingN).toStringAsFixed(1)}/5');
      }
      add('  Tự đánh giá sau phiên: ${parts.join(' · ')}');
    }
    final hard = all.where((s) => (s.difficulty ?? 0) >= 4).length;
    if (hard > 0) {
      add('  $hard phiên được đánh dấu khó');
    }
  }

  static void _logs(void Function(String) add, DateTime now) {
    final logs = _readAll(
      StorageService.getStudyLogIds(),
      StorageService.getStudyLogJson,
      StudyLog.fromJsonString,
    );
    if (logs.isEmpty) return;

    var totalHours = 0.0;
    var recentHours = 0.0;
    final bySubject = <String, double>{};
    for (final l in logs) {
      totalHours += l.hours;
      bySubject[l.subject.isEmpty ? 'khác' : l.subject] =
          (bySubject[l.subject.isEmpty ? 'khác' : l.subject] ?? 0) + l.hours;
      if (now.difference(l.date).inDays <= _recentDays) {
        recentHours += l.hours;
      }
    }
    add('NHẬT KÝ HỌC: ${totalHours.toStringAsFixed(1)} giờ tích lũy · '
        '$_recentDays ngày qua ${recentHours.toStringAsFixed(1)} giờ');
    final ranking = bySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final splitText = ranking
        .take(_maxListItems)
        .map((e) => '${e.key} ${e.value.toStringAsFixed(1)}h')
        .join(' · ');
    add('  Phân bổ môn: $splitText');
  }

  static void _mockScores(void Function(String) add, DateTime now) {
    final scores = _readAll(
      StorageService.getMockScoreIds(),
      StorageService.getMockScoreJson,
      MockScore.fromJsonString,
    );
    if (scores.isEmpty) return;
    scores.sort((a, b) => a.date.compareTo(b.date));

    final bySubject = <String, List<double>>{};
    for (final s in scores) {
      bySubject
          .putIfAbsent(s.subject.isEmpty ? 'khác' : s.subject, () => <double>[])
          .add(s.score);
    }
    final averages = bySubject.entries
        .map((e) => MapEntry(e.key, _avg(e.value)))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final recent =
        scores.where((s) => now.difference(s.date).inDays <= 90).toList();
    final recentLabel = recent.isEmpty ? 'tất cả' : '90 ngày qua';
    final scoreText = averages
        .take(_maxListItems)
        .map((e) => '${e.key} TB ${e.value.toStringAsFixed(1)}/10')
        .join(' · ');
    add('ĐIỂM THI THỬ ($recentLabel): $scoreText');
    if (averages.isNotEmpty) {
      add('  Yếu nhất: ${averages.first.key}; mạnh nhất: ${averages.last.key}');
    }
    if (scores.length >= 2) {
      final latest = scores[scores.length - 1];
      final prev = scores[scores.length - 2];
      if (latest.subject == prev.subject) {
        final delta = latest.score - prev.score;
        final word = delta > 0.05
            ? 'tăng'
            : delta < -0.05
                ? 'giảm'
                : 'đi ngang';
        add('  Lần gần nhất ${latest.subject}: '
            '${prev.score.toStringAsFixed(1)} → ${latest.score.toStringAsFixed(1)} ($word)');
      }
    }
  }

  static double _avg(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  static void _notes(void Function(String) add) {
    final notes = _readAll(
      StorageService.getStudyNoteIds(),
      StorageService.getStudyNoteJson,
      StudyNote.fromJsonString,
    );
    if (notes.isEmpty) return;
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final bySubject = <String, int>{};
    for (final n in notes) {
      if (n.subject != null && n.subject!.isNotEmpty) {
        bySubject[n.subject!] = (bySubject[n.subject!] ?? 0) + 1;
      }
    }
    add('GHI CHÚ: ${notes.length} ghi chú');
    if (bySubject.isNotEmpty) {
      final ranking = bySubject.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final subjectText =
          ranking.take(3).map((e) => '${e.key} (${e.value})').join(' · ');
      add('  Môn đang ghi nhiều: $subjectText');
    }
    final latestText = notes.take(_maxListItems).map((n) => n.title).join('; ');
    add('  Mới nhất: $latestText');
  }

  static void _flashcards(void Function(String) add) {
    try {
      final due = FlashcardService.dueCount;
      final total = FlashcardService.loadAll().length;
      if (total == 0) return;
      add('FLASHCARD: $total thẻ, $due thẻ đến hạn ôn hôm nay');
    } catch (_) {
      // Flashcard hỏng không được làm hỏng cả khối ngữ cảnh chat.
    }
  }

  // --- Tiện ích ----------------------------------------------------------

  /// Đọc & giải mã danh sách bản ghi, bỏ qua bản ghi hỏng thay vì làm hỏng
  /// cả luồng chat.
  static List<T> _readAll<T>(
    List<String> ids,
    String? Function(String) readJson,
    T Function(String) decode,
  ) {
    final out = <T>[];
    for (final id in ids) {
      final raw = readJson(id);
      if (raw == null || raw.isEmpty) continue;
      try {
        out.add(decode(raw));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  /// [StudySession] chưa có hàm `fromJsonString` nên tự giải mã.
  static List<StudySession> _sessionsFrom(List<String> ids) {
    final out = <StudySession>[];
    for (final id in ids) {
      final raw = StorageService.getStudySessionJson(id);
      if (raw == null || raw.isEmpty) continue;
      try {
        out.add(StudySession.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  static String _hours(int minutes) => '${(minutes / 60).toStringAsFixed(1)}h';
}
