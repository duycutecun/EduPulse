import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/ai/ai_insights.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('AiInsights.parse', () {
    test('định dạng chuẩn', () {
      final items = AiInsights.parse('''
Dồn buổi ôn Hóa tối nay, điểm môn này đang thấp nhất | Hóa TB 6.0/10, thấp hơn Toán 1.5 điểm
Chia nhỏ bài tích phân thành 3 phần | Dự kiến 90 phút nhưng bạn dời lịch 2 lần''');

      expect(items, hasLength(2));
      expect(items[0].text,
          'Dồn buổi ôn Hóa tối nay, điểm môn này đang thấp nhất');
      expect(items[0].evidence, 'Hóa TB 6.0/10, thấp hơn Toán 1.5 điểm');
      expect(items[1].evidence, 'Dự kiến 90 phút nhưng bạn dời lịch 2 lần');
    });

    test('bỏ gạch đầu dòng và số thứ tự', () {
      final items = AiInsights.parse('''
1. Tập trung ôn Toán trước | Toán chiếm 2.5h nhưng đề thi thử tăng
- Rà lại Hóa chưa học | Hóa TB 6.0/10
• Xem lại ghi chú đạo hàm | Bạn có 1 ghi chú môn Toán''');

      expect(items, hasLength(3));
      expect(items[0].text, 'Tập trung ôn Toán trước');
      expect(items[1].text, 'Rà lại Hóa chưa học');
      expect(items[2].text, 'Xem lại ghi chú đạo hàm');
    });

    test('bỏ qua dòng không có bằng chứng', () {
      final items = AiInsights.parse('''
Hãy chăm chỉ học hơn
Ôn Toán tối nay | Toán chiếm nhiều thời gian nhất
Một câu rất ngắn''');

      expect(items, hasLength(1));
      expect(items[0].text, 'Ôn Toán tối nay');
    });

    test('giới hạn 3 gợi ý', () {
      final items = AiInsights.parse('''
A a a a a a a a a a | bằng chứng 1
B b b b b b b b b b | bằng chứng 2
C c c c c c c c c c | bằng chứng 3
D d d d d d d d d d | bằng chứng 4
E e e e e e e e e e | bằng chứng 5''');

      expect(items, hasLength(3));
      expect(items[2].evidence, 'bằng chứng 3');
    });

    test('cắt bằng chứng quá dài', () {
      final long = 'y' * 200;
      final items = AiInsights.parse('Ôn Toán tối nay | $long');

      expect(items, hasLength(1));
      expect(items[0].evidence!.length, lessThanOrEqualTo(91));
      expect(items[0].evidence, endsWith('…'));
    });

    test('model trả vết bậy → không có gợi ý nào', () {
      expect(AiInsights.parse('❌ Lỗi 429: model free hết lượt'), isEmpty);
      expect(AiInsights.parse('AI không trả lời được nội dung này.'), isEmpty);
      expect(AiInsights.parse(''), isEmpty);
      expect(AiInsights.parse('   \n  \n '), isEmpty);
    });

    test('bỏ khoảng trắng và ký tự thừa quanh dấu |', () {
      final items = AiInsights.parse('  Ôn Toán tối nay   |   Toán đang yếu  ');
      expect(items[0].text, 'Ôn Toán tối nay');
      expect(items[0].evidence, 'Toán đang yếu');
    });
  });

  group('AiInsights.cache', () {
    void seedData() {
      final exam = ExamModel(
        id: 'e1',
        name: 'THPTQG 2027',
        dateTime: DateTime(2026, 11, 14),
      );
      StorageService.setExamIds(['e1']);
      StorageService.setExamJson('e1', exam.toJsonString());
      StorageService.setPrimaryExamId('e1');
    }

    test('chưa có cache → null', () {
      expect(AiInsights.cached(), isNull);
    });

    test('lưu và đọc lại được', () {
      seedData();
      final at = DateTime(2026, 9, 30, 10);
      final bundle = AiInsightBundle(
        generatedAt: at,
        items: const [
          AiInsight(text: 'Ôn Hóa tối nay', evidence: 'Hóa TB 6.0/10'),
          AiInsight(text: 'Chia nhỏ bài tích phân'),
        ],
      );
      // Ghi cache theo cách mà refresh() làm.
      StorageService.setString('ai_insights_v1', _encode(bundle));
      StorageService.setString(
          'ai_insights_time_v1', bundle.generatedAt.toIso8601String());

      final read = AiInsights.cached(now: at.add(const Duration(hours: 2)));
      expect(read, isNotNull);
      expect(read!.items, hasLength(2));
      expect(read.items[0].text, 'Ôn Hóa tối nay');
      expect(read.items[1].evidence, isNull);
    });

    test('hết hạn sau 6 giờ → null', () {
      seedData();
      final at = DateTime(2026, 9, 30, 10);
      final bundle = AiInsightBundle(
        generatedAt: at,
        items: const [AiInsight(text: 'Ôn Hóa tối nay')],
      );
      StorageService.setString('ai_insights_v1', _encode(bundle));
      StorageService.setString(
          'ai_insights_time_v1', bundle.generatedAt.toIso8601String());

      expect(
          AiInsights.cached(now: at.add(const Duration(hours: 5))), isNotNull);
      expect(AiInsights.cached(now: at.add(const Duration(hours: 7))), isNull);
    });

    test('tắt quyền phân tích → không đọc cache, không gọi AI', () async {
      seedData();
      final at = DateTime(2026, 9, 30, 10);
      final bundle = AiInsightBundle(
        generatedAt: at,
        items: const [AiInsight(text: 'Ôn Hóa tối nay')],
      );
      StorageService.setString('ai_insights_v1', _encode(bundle));
      StorageService.setString(
          'ai_insights_time_v1', bundle.generatedAt.toIso8601String());

      StorageService.setBool('ai_permission_analyze', false);
      expect(AiInsights.cached(now: at), isNull);
      expect(await AiInsights.load(), isNull);
      expect(await AiInsights.refresh(), isNull);
    });

    test('user mới chưa có dữ liệu → không gọi model', () async {
      // Không seed gì: AiStudyContext rỗng nên không đáng tiêu quota.
      expect(await AiInsights.refresh(), isNull);
    });

    test('cache hỏng → bỏ qua, không ném lỗi', () {
      seedData();
      StorageService.setString('ai_insights_v1', '{khong phai json');
      StorageService.setString(
          'ai_insights_time_v1', DateTime.now().toIso8601String());
      expect(AiInsights.cached(), isNull);
    });

    test('invalidate xoá cache', () {
      seedData();
      final bundle = AiInsightBundle(
        generatedAt: DateTime.now(),
        items: const [AiInsight(text: 'Ôn Hóa tối nay')],
      );
      StorageService.setString('ai_insights_v1', _encode(bundle));
      StorageService.setString(
          'ai_insights_time_v1', bundle.generatedAt.toIso8601String());
      expect(AiInsights.cached(), isNotNull);

      AiInsights.invalidate();
      expect(AiInsights.cached(), isNull);
    });
  });
}

String _encode(AiInsightBundle b) => jsonEncode(b.toJson());
