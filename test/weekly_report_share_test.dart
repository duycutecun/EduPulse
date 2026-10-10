import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/weekly_report.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// Khoá lại hai mục học sinh bật trong "Cửa sổ tin cậy":
/// 1. "Điểm thi thử mới nhất" phải là điểm có NGÀY mới nhất, không phải bản ghi
///    đầu tiên trong danh sách (thứ tự có thể đảo sau sync/khôi phục).
/// 2. "Đếm ngược kỳ thi" chạy ngay khi có kỳ thi sắp tới, kể cả chưa ghim kỳ
///    thi chính — đúng như màn Home vẫn đếm ngược theo kỳ thi gần nhất.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Map<String, bool> onlyEnabled(String key) => {
        'study_time': false,
        'readiness': false,
        'mock_score': false,
        'exam_countdown': false,
        key: true,
      };

  MockScore score(String id, DateTime date, String subject, double value) =>
      MockScore(id: id, date: date, subject: subject, score: value);

  group('WeeklyReport.build — Điểm thi thử mới nhất', () {
    test('lấy điểm có NGÀY gần nhất, không phải bản ghi đứng trước', () {
      StorageService.setMockScoreIds(['old', 'new']);
      StorageService.setMockScoreJson('old', score('old', DateTime(2026, 6, 1), 'Toán', 5.0).toJsonString());
      StorageService.setMockScoreJson('new', score('new', DateTime(2026, 6, 5), 'Toán', 8.5).toJsonString());

      final report = WeeklyReport.build(
        enabled: onlyEnabled('mock_score'),
        now: DateTime(2026, 6, 30),
      );

      expect(report, isNotNull);
      final item = report!.items.singleWhere((i) => i.key == 'mock_score');
      expect(item.value, 'Toán: 8.5/10');
    });

    test('danh sách bị đảo thứ tự vẫn chọn bản mới nhất theo ngày', () {
      // Giả lập dữ liệu sau khôi phục: bản "mới" lại nằm trước trong ids.
      StorageService.setMockScoreIds(['new', 'old']);
      StorageService.setMockScoreJson('new', score('new', DateTime(2026, 8, 9), 'Lý', 9.0).toJsonString());
      StorageService.setMockScoreJson('old', score('old', DateTime(2026, 7, 2), 'Lý', 6.5).toJsonString());

      final report = WeeklyReport.build(
        enabled: onlyEnabled('mock_score'),
        now: DateTime(2026, 8, 10),
      );

      final item = report!.items.singleWhere((i) => i.key == 'mock_score');
      expect(item.value, 'Lý: 9.0/10');
    });

    test('không có điểm thi thử → không thêm mục (không gửi số 0)', () {
      final report = WeeklyReport.build(
        enabled: onlyEnabled('mock_score'),
        now: DateTime(2026, 6, 30),
      );
      expect(report, isNull, reason: 'chỉ bật mục mock_score nhưng chưa có dữ liệu');
    });
  });

  group('WeeklyReport.build — Đếm ngược kỳ thi', () {
    ExamModel exam(String id, String name, DateTime when) =>
        ExamModel(id: id, name: name, dateTime: when);

    test('chưa ghim kỳ thi chính → vẫn đếm kỳ thi chưa qua gần nhất', () {
      final now = DateTime(2026, 10, 10);
      StorageService.setExamIds(['xe', 'near']);
      StorageService.setExamJson('xe', exam('xe', 'THPT 2027', now.add(const Duration(days: 90))).toJsonString());
      StorageService.setExamJson('near', exam('near', 'Giữa kỳ 1', now.add(const Duration(days: 30))).toJsonString());

      final report = WeeklyReport.build(
        enabled: onlyEnabled('exam_countdown'),
        now: now,
      );

      expect(report, isNotNull);
      final item = report!.items.singleWhere((i) => i.key == 'exam_countdown');
      expect(item.value, 'Giữa kỳ 1 — còn 30 ngày');
    });

    test('kỳ thi ghim đã qua ngày → đếm sang kỳ thi sắp tới gần nhất', () {
      final now = DateTime(2026, 10, 10);
      StorageService.setPrimaryExamId('past');
      StorageService.setExamIds(['past', 'near']);
      StorageService.setExamJson('past', exam('past', 'Đã thi', now.subtract(const Duration(days: 1))).toJsonString());
      StorageService.setExamJson('near', exam('near', 'Cuối kỳ 1', now.add(const Duration(days: 45))).toJsonString());

      final report = WeeklyReport.build(
        enabled: onlyEnabled('exam_countdown'),
        now: now,
      );

      final item = report!.items.singleWhere((i) => i.key == 'exam_countdown');
      expect(item.value, 'Cuối kỳ 1 — còn 45 ngày');
    });

    test('kỳ thi ghim còn đếm được → ưu tiên đúng kỳ thi đó', () {
      final now = DateTime(2026, 10, 10);
      StorageService.setPrimaryExamId('pinned');
      StorageService.setExamIds(['far', 'pinned']);
      StorageService.setExamJson('far', exam('far', 'Kỳ thi xa', now.add(const Duration(days: 200))).toJsonString());
      StorageService.setExamJson('pinned', exam('pinned', 'Kỳ thi ghim', now.add(const Duration(days: 15))).toJsonString());

      final report = WeeklyReport.build(
        enabled: onlyEnabled('exam_countdown'),
        now: now,
      );

      final item = report!.items.singleWhere((i) => i.key == 'exam_countdown');
      expect(item.value, 'Kỳ thi ghim — còn 15 ngày');
    });

    test('chưa có kỳ thi nào → không thêm mục', () {
      final report = WeeklyReport.build(
        enabled: onlyEnabled('exam_countdown'),
        now: DateTime(2026, 10, 10),
      );
      expect(report, isNull);
    });
  });
}