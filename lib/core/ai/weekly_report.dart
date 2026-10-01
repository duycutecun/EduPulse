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

  /// Mặc định khi học sinh CHƯA chọn lần nào: thời gian học + readiness
  /// bật (an toàn, không nhạy cảm), điểm số + đếm ngược thi tắt (học sinh
  /// phải chủ động bật nếu muốn chia sẻ).
  static Map<String, bool> get defaultChoices => const {
        'study_time': true,
        'readiness': true,
        'mock_score': false,
        'exam_countdown': false,
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
    await StorageService.prefs.setString(
        '${_prefsKey}_choices', jsonEncode(choices));
  }

  /// Dựng báo cáo tuần này. [enabled] quyết định mục nào được đưa vào —
  /// truyền từ UI (toggle của học sinh). Trả về null khi không còn mục nào.
  static WeeklyReportData? build({
    required Map<String, bool> enabled,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final (start, end) = weekBounds(reference);

    // --- Phiên focus trong tuần ---
    final weekSessions = StudyRhythm.sessions()
        .where((s) => !s.completedAt.isBefore(start) && !s.completedAt.isAfter(end))
        .toList();
    final minutes = weekSessions.fold(0, (sum, s) => sum + s.actualMinutes);
    final days = weekSessions.map((s) => s.completedAt.day).toSet().length;

    // --- Readiness hiện tại ---
    final readiness = ReadinessScore.compute();

    // --- Kỳ thi chính ---
    ExamModel? exam;
    final primaryId = StorageService.getPrimaryExamId();
    for (final id in StorageService.getExamIds()) {
      final raw = StorageService.getExamJson(id);
      if (raw == null) continue;
      try {
        final e = ExamModel.fromJsonString(raw);
        if (e.id == primaryId) {
          exam = e;
          break;
        }
      } catch (_) {}
    }
    final daysLeft = exam == null
        ? null
        : exam.dateTime.difference(reference).inDays;

    // --- Điểm thi thử mới nhất ---
    String? latestScore;
    for (final id in StorageService.getMockScoreIds()) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        final m = MockScore.fromJsonString(raw);
        latestScore ??= '${m.subject}: ${m.score.toStringAsFixed(1)}/10';
      } catch (_) {}
    }

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
  });

  final String headline;
  final List<ReportItem> items;
  final DateTime from;
  final DateTime to;
  final DateTime generatedAt;

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

  static String _d(DateTime d) =>
      '${d.day}/${d.month}';
}
