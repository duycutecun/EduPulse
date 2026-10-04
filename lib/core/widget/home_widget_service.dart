import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import '../ai/readiness_score.dart';
import '../utils/storage_service.dart';

/// Cầu nối giữa chu trình AI trong app và **widget màn hình chính Android**.
///
/// Không dùng package trung gian (giữ app gọn, miễn phí): Dart ghi dữ liệu
/// vào SharedPreferences (file `FlutterSharedPreferences.xml`) — chính là
/// nơi [StorageService] đã dùng — và widget Kotlin đọc trực tiếp các key
/// đó với prefix `flutter.`. Khi app được mở/resume, [sync] ghi lại toàn bộ
/// để widget luôn khớp dữ liệu mới nhất; khi app đóng, widget vẫn hiện giá
/// trị lần cuối (không đòi hỏi WorkManager/background fetch).
///
/// Quy ước key (widget đọc `flutter.<key>`):
/// - `widget_exam_name` (String), `widget_days_left` (int), `widget_exam_iso`
/// - `widget_task1_title` (String), `widget_task1_done` (bool), ... task2
/// - `widget_ready_score` (int), `widget_updated_iso`
class HomeWidgetService {
  HomeWidgetService._();

  static const String _prefix = 'widget_';

  /// Ghi toàn bộ dữ liệu widget. Gọi khi mở/resume app và sau mỗi lần
  /// dữ liệu quan trọng đổi (task toggle, điểm mới, đổi kỳ thi chính).
  static Future<void> sync() async {
    if (!defaultTargetPlatform.toString().contains('android') || kIsWeb) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();

      // --- Kỳ thi chính + đếm ngược ---
      final primaryId = StorageService.getPrimaryExamId();
      String? examName;
      int? daysLeft;
      String? examIso;
      for (final id in StorageService.getExamIds()) {
        final raw = StorageService.getExamJson(id);
        if (raw == null) continue;
        try {
          final e = ExamModel.fromJsonString(raw);
          if (e.id == primaryId || (examName == null && !e.isExamDayOver)) {
            examName = e.name;
            final d = e.dateTime.difference(DateTime.now()).inDays;
            daysLeft = d < 0 ? 0 : d;
            examIso = e.dateTime.toIso8601String();
            if (e.id == primaryId) break;
          }
        } catch (_) {}
      }
      await _write(prefs, 'exam_name', examName ?? '');
      await _write(prefs, 'days_left', daysLeft ?? -1);
      await _write(prefs, 'exam_iso', examIso ?? '');

      // --- 2 nhiệm vụ đầu chưa xong ---
      final pending = <TodayTask>[];
      for (final id in StorageService.getTodayTaskIds()) {
        final raw = StorageService.getTodayTaskJson(id);
        if (raw == null) continue;
        try {
          final t = TodayTask.fromJsonString(raw);
          if (!t.isDone && t.status != 'skipped') pending.add(t);
          if (pending.length >= 2) break;
        } catch (_) {}
      }
      for (var i = 0; i < 2; i++) {
        final t = i < pending.length ? pending[i] : null;
        await _write(prefs, 'task${i + 1}_title', t?.title ?? '');
        await _write(prefs, 'task${i + 1}_subject', t?.subject ?? '');
      }

      // --- Readiness thu nhỏ (0–100) — tính on-device, không gọi mạng ---
      int ready = -1;
      try {
        ready = ReadinessScore.compute()?.score ?? -1;
      } catch (_) {}
      await _write(prefs, 'ready_score', ready);

      await _write(prefs, 'updated_iso', DateTime.now().toIso8601String());
    } catch (_) {
      // Widget là "nice to have" — không bao giờ làm app văng lỗi.
    }
  }

  static Future<void> _write(
      SharedPreferences prefs, String key, Object value) async {
    final full = '$_prefix$key';
    if (value is int) {
      await prefs.setInt(full, value);
    } else if (value is bool) {
      await prefs.setBool(full, value);
    } else {
      await prefs.setString(full, value.toString());
    }
  }
}
