import 'dart:convert';

import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../utils/storage_service.dart';
import 'readiness_score.dart';
import 'study_rhythm.dart';

/// Một mục trong báo cáo tuần, học sinh CHỌN được có chia sẻ hay không.
class ReportItem {
  const ReportItem({
    required this.key,
    required this.title,
    required this.value,
    this.detail,
    this.enabledByDefault = true,
  });

  final String key;
  final String title;
  final String value;
  final String? detail;

  /// Mặc định bật/tắt khi học sinh lần đầu mở thẻ chia sẻ.
  final bool enabledByDefault;

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'value': value,
        if (detail != null) 'detail': detail,
      };

  /// Đọc lại một mục từ JSON — dùng ở phía PHỤ HUYNH, nơi báo cáo đến từ
  /// cloud chứ không dựng từ dữ liệu trên máy.
  static ReportItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = '${raw['title'] ?? ''}'.trim();
    if (title.isEmpty) return null;
    return ReportItem(
      key: '${raw['key'] ?? ''}',
      title: title,
      value: '${raw['value'] ?? ''}',
      detail: raw['detail'] == null ? null : '${raw['detail']}',
    );
  }
}

/// Báo cáo học tập TUẦN — "cửa sổ tin cậy" giữa học sinh và phụ huynh.
///
/// Nguyên tắc thiết kế (đặc tả Giai đoạn 3):
/// - **Học sinh là chủ**: chỉ những mục học sinh BẬT mới vào báo cáo;
///   tắt hết = không có gì để gửi, không có mục nào bị ép chia sẻ.
/// - **Ngôn ngữ không áp lực**: kể câu chuyện tuần học (điều tích cực trước),
///   KHÔNG dùng streak làm vũ khí so sánh, không so với bạn bè.
/// - **On-device, miễn phí**: tổng hợp từ dữ liệu local, không gọi model.
/// - Lựa chọn mục được NHỚ (cache 7 ngày) để tuần sau không phải chọn lại.
class WeeklyReport {
  WeeklyReport._();

  static const String _prefsKey = 'ai_weekly_report_v1';

  /// Mặc định khi học sinh CHƯA chọn lần nào: cả 4 mục đều bật sẵn — kể cả
  /// "Điểm thi thử mới nhất" và "Đếm ngược kỳ thi" (yêu cầu: cho phép chia
  /// sẻ hai mục này mặc định). Học sinh vẫn có thể tắt từng mục khi mở thẻ
  /// chia sẻ; ba mẹ chỉ thấy mục nào để bật.
  static Map<String, bool> get defaultChoices => const {
        'study_time': true,
        'readiness': true,
        'mock_score': true,
        'exam_countdown': true,
      };

  /// Tuần hiện tại: thứ 2 → chủ nhật.
  static (DateTime, DateTime) weekBounds([DateTime? now]) {
    final d = now ?? DateTime.now();
    final weekday = d.weekday; // 1 = Monday
    final monday = DateTime(d.year, d.month, d.day - (weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59));
    return (monday, sunday);
  }

  /// Lựa chọn chia sẻ đã lưu của học sinh (key → on/off). null = chưa chọn.
  static Map<String, bool>? savedChoices() {
    final raw = StorageService.getString('$_prefsKey' '_choices');
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveChoices(Map<String, bool> choices) async {
    await StorageService.prefs
        .setString('${_prefsKey}_choices', jsonEncode(choices));
  }

  /// Dựng báo cáo tuần này. [enabled] quyết định mục nào được đưa vào —
  /// truyền từ UI (toggle của học sinh). Trả về null khi không còn mục nào.
  static WeeklyReportData? build({
    required Map<String, bool> enabled,
    DateTime? now,
    String? checkin,
  }) {
    final reference = now ?? DateTime.now();
    final (start, end) = weekBounds(reference);

    // --- Phiên focus trong tuần ---
    final weekSessions = StudyRhythm.sessions()
        .where((s) =>
            !s.completedAt.isBefore(start) && !s.completedAt.isAfter(end))
        .toList();
    final minutes = weekSessions.fold(0, (sum, s) => sum + s.actualMinutes);
    final days = weekSessions.map((s) => s.completedAt.day).toSet().length;

    // --- Readiness hiện tại ---
    final readiness = ReadinessScore.compute();

    // --- Kỳ thi chính ---
    // Đúng ngữ nghĩa toàn app (xem ExamRepository.primaryExam): kỳ thi đã ghim
    // (còn đếm được), chưa ghim hay ghim vào kỳ thi đã qua thì lấy kỳ thi chưa
    // qua gần nhất. Chỉ đọc chứ không ghi gì vào storage.
    ExamModel? exam;
    final primaryId = StorageService.getPrimaryExamId();
    final allExams = <ExamModel>[];
    for (final id in StorageService.getExamIds()) {
      final raw = StorageService.getExamJson(id);
      if (raw == null) continue;
      try {
        allExams.add(ExamModel.fromJsonString(raw));
      } catch (_) {}
    }
    final referenceId = primaryId;
    for (final e in allExams) {
      if (referenceId != null &&
          e.id == referenceId &&
          !e.isExamDayOverAt(reference)) {
        exam = e;
        break;
      }
    }
    if (exam == null) {
      final upcoming = allExams
          .where((e) => !e.isExamDayOverAt(reference))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      exam = upcoming.isNotEmpty
          ? upcoming.first
          : (allExams.isNotEmpty ? allExams.first : null);
    }
    final daysLeft = exam?.dateTime.difference(reference).inDays;

    // --- Điểm thi thử mới nhất ---
    // Chọn THEO NGÀY (m.date) thay vì vị trí trong danh sách: dữ liệu sau khi
    // synced/khôi phục có thể thứ tự không còn là "cũ → mới", nên bản ghi đầu
    // danh sách chưa chắc là bản mới nhất — đúng nhãn hiển thị "mới nhất".
    MockScore? newestScore;
    for (final id in StorageService.getMockScoreIds()) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        final m = MockScore.fromJsonString(raw);
        if (newestScore == null || m.date.isAfter(newestScore.date)) {
          newestScore = m;
        }
      } catch (_) {}
    }
    final latestScore = newestScore == null
        ? null
        : '${newestScore.subject}: ${newestScore.score.toStringAsFixed(1)}/10';

    // --- Mục theo tuỳ chọn của học sinh ---
    final items = <ReportItem>[];
    if (enabled['study_time'] ?? true) {
      items.add(ReportItem(
        key: 'study_time',
        title: 'Thời gian tập trung',
        value: '$minutes phút',
        detail: days > 0 ? 'Học $days ngày trong tuần' : null,
      ));
    }
    if (enabled['readiness'] ?? true) {
      items.add(ReportItem(
        key: 'readiness',
        title: 'Chỉ số sẵn sàng thi',
        value: readiness == null ? 'Chưa đủ dữ liệu' : '${readiness.score}/100',
        detail: readiness?.band,
      ));
    }
    if ((enabled['mock_score'] ?? false) && latestScore != null) {
      items.add(ReportItem(
        key: 'mock_score',
        title: 'Điểm thi thử mới nhất',
        value: latestScore,
      ));
    }
    if ((enabled['exam_countdown'] ?? false) &&
        exam != null &&
        daysLeft != null &&
        daysLeft >= 0) {
      items.add(ReportItem(
        key: 'exam_countdown',
        title: 'Kỳ thi gần nhất',
        value: '${exam.name} — còn $daysLeft ngày',
      ));
    }
    if (items.isEmpty) return null;

    final peak = StudyRhythm.peakHour(now: reference);
    final burnout = StudyRhythm.burnoutRisk(now: reference);

    // Mở đầu luôn là điều TÍCH CỰC — câu chuyện tuần, không phải bảng điểm.
    // Nhận diện EduPulse nằm ở chữ kèm theo (xem [toPlainText]) và ở thẻ ảnh
    // thành tựu — KHÔNG nhét vào headline: headline là lời kể cho ba mẹ đọc,
    // thêm tên app vào đầu mỗi câu chỉ làm câu chuyện khó đọc hơn.
    final headline = minutes == 0
        ? 'Tuần này con chưa ghi được phiên tập trung nào — tuần sau mình bắt đầu nhẹ thôi nhé.'
        : 'Tuần này con đã tập trung $minutes phút trong $days ngày'
            '${peak != null ? ' và giữ nhịp khá đều' : ''}.'
            '${burnout != null ? ' Con đang hơi overloaded, gia đình có thể nhắc con nghỉ ngơi hợp lý.' : ''}';

    return WeeklyReportData(
      headline: headline,
      items: items,
      from: start,
      to: end,
      generatedAt: DateTime.now(),
      checkin: checkin,
    );
  }
}

/// Dữ liệu báo cáo đã dựng, sẵn sàng render/chia sẻ.
class WeeklyReportData {
  const WeeklyReportData({
    required this.headline,
    required this.items,
    required this.from,
    required this.to,
    required this.generatedAt,
    this.checkin,
  });

  final String headline;
  final List<ReportItem> items;
  final DateTime from;
  final DateTime to;
  final DateTime generatedAt;

  /// Lời nhắn ngắn con gửi kèm báo cáo (tuỳ chọn). null = không có.
  final String? checkin;

  /// Đóng gói để gửi lên cloud cho gia đình (và để phụ huynh đọc lại).
  ///
  /// Chỉ chứa ĐÚNG những mục học sinh đã bật — bản thân báo cáo là bằng chứng
  /// của sự đồng ý, nên phía phụ huynh không cần (và không có) quyền đọc thêm
  /// dữ liệu nào khác.
  Map<String, dynamic> toJson() => {
        'headline': headline,
        'items': items.map((e) => e.toJson()).toList(),
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        if (checkin != null && checkin!.trim().isNotEmpty)
          'checkin': checkin!.trim(),
      };

  /// Đọc báo cáo từ cloud. Trả về null khi dữ liệu hỏng/thiếu mục — thà không
  /// hiện gì còn hơn hiện một báo cáo trống rỗng gây hiểu nhầm.
  static WeeklyReportData? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final items = <ReportItem>[];
    final rawItems = raw['items'];
    if (rawItems is List) {
      for (final entry in rawItems) {
        final item = ReportItem.fromJson(entry);
        if (item != null) items.add(item);
      }
    }
    if (items.isEmpty) return null;
    final now = DateTime.now();
    final rawCheckin = raw['checkin'];
    final checkin =
        rawCheckin == null ? null : '$rawCheckin'.trim();
    return WeeklyReportData(
      headline: '${raw['headline'] ?? ''}',
      items: items,
      from: DateTime.tryParse('${raw['from']}') ?? now,
      to: DateTime.tryParse('${raw['to']}') ?? now,
      generatedAt: DateTime.tryParse('${raw['generatedAt']}') ?? now,
      checkin: (checkin == null || checkin.isEmpty) ? null : checkin,
    );
  }

  /// Chữ thuần dùng cho chia sẻ SMS/Zalo (không cần ảnh).
  String toPlainText({required String studentName}) {
    final buf = StringBuffer();
    buf.writeln('📊 BÁO CÁO HỌC TẬP TUẦN — EduPulse');
    buf.writeln(
        '(${_d(from)} → ${_d(to)})${studentName.trim().isEmpty ? '' : ' — $studentName'}');
    buf.writeln();
    buf.writeln(headline);
    buf.writeln();
    for (final item in items) {
      buf.writeln('• ${item.title}: ${item.value}'
          '${item.detail == null ? '' : ' (${item.detail})'}');
    }
    buf.writeln();
    buf.write('Gửi từ EduPulse — học sinh chủ động chia sẻ 💚');
    return buf.toString();
  }

  /// Học sinh hiện tên mình — dùng cho placeholder/chào, không send đến cloud.
  String studentDisplayName(String name, {String fallback = 'con'}) {
    final n = name.trim();
    return n.isEmpty ? fallback : n;
  }

  static String _d(DateTime d) => '${d.day}/${d.month}';
}
