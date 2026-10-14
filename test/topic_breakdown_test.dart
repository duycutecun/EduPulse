import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/topic_breakdown.dart';

void main() {
  MockScore score({
    String id = 'x',
    String subject = 'Toán',
    String? topic,
    required double value,
    DateTime? date,
  }) =>
      MockScore(
        id: id,
        date: date ?? DateTime(2026, 9, 1),
        subject: subject,
        score: value,
        topic: topic,
      );

  group('analyzeTopicWeakness', () {
    test('gộp điểm theo (môn, chủ đề) và tính trung bình + số lần thi', () {
      final topics = analyzeTopicWeakness([
        score(topic: 'Hàm số', value: 5),
        score(topic: 'Hàm số', value: 7),
        score(topic: 'Hình học', value: 8),
      ]);

      expect(topics, hasLength(2));
      final ham = topics.firstWhere((t) => t.topic == 'Hàm số');
      expect(ham.average, 6.0);
      expect(ham.attempts, 2);
      expect(ham.subject, 'Toán');
    });

    test('sắp chủ đề yếu nhất (điểm TB thấp) lên đầu', () {
      final topics = analyzeTopicWeakness([
        score(topic: 'Hình học', value: 9),
        score(topic: 'Hàm số', value: 4),
        score(topic: 'Điện', value: 7),
      ]);

      expect(
          topics.map((t) => t.topic).toList(), ['Hàm số', 'Điện', 'Hình học']);
    });

    test('cùng điểm TB → chủ đề thi nhiều lần hơn lên trước', () {
      final topics = analyzeTopicWeakness([
        score(id: 'a', topic: 'X', value: 5),
        score(id: 'b', topic: 'Y', value: 5),
        score(id: 'c', topic: 'Y', value: 5),
      ]);

      expect(topics.first.topic, 'Y');
      expect(topics.first.attempts, 2);
    });

    test('bỏ qua bản ghi thiếu chủ đề (dữ liệu cũ chỉ có môn)', () {
      final topics = analyzeTopicWeakness([
        score(value: 4), // không có topic
        score(topic: '', value: 3), // topic rỗng
        score(topic: 'Hàm số', value: 6),
      ]);

      expect(topics, hasLength(1));
      expect(topics.single.topic, 'Hàm số');
    });

    test('phân biệt chủ đề khác nhau giữa các môn', () {
      final topics = analyzeTopicWeakness([
        score(subject: 'Toán', topic: 'Hàm số', value: 5),
        score(subject: 'Lý', topic: 'Hàm số', value: 9),
      ]);

      expect(topics, hasLength(2));
      expect(topics.first.subject, 'Toán');
    });

    test('danh sách rỗng → rỗng (không bịa dữ liệu)', () {
      expect(analyzeTopicWeakness(const []), isEmpty);
    });
  });

  group('weakestTopic', () {
    test('trả chủ đề yếu nhất khi dưới ngưỡng', () {
      final w = weakestTopic([
        score(topic: 'Hàm số', value: 4.5),
        score(topic: 'Hình học', value: 9),
      ]);

      expect(w, isNotNull);
      expect(w!.topic, 'Hàm số');
      expect(w.average, 4.5);
    });

    test('mọi chủ đề đều ổn (>= 6.5) → null, không nhắc thừa', () {
      final w = weakestTopic([
        score(topic: 'Hàm số', value: 7),
        score(topic: 'Hình học', value: 8),
      ]);

      expect(w, isNull);
    });

    test('không có chủ đề nào → null', () {
      expect(weakestTopic([score(value: 3)]), isNull);
    });
  });

  group('MockScore.topic tương thích ngược', () {
    test('JSON cũ không có topic vẫn parse được (topic = null)', () {
      final s = MockScore.fromJsonString(
          '{"id":"1","date":"2026-09-01T00:00:00.000","subject":"Toán","score":7.5}');
      expect(s.topic, isNull);
      expect(s.score, 7.5);
    });

    test('topic được lưu và đọc lại đúng', () {
      final original = score(topic: 'Hàm số', value: 6.5);
      final round = MockScore.fromJsonString(original.toJsonString());
      expect(round.topic, 'Hàm số');
    });
  });
}
