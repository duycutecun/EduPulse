import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/ai_daily_briefing.dart';
import 'package:edupulse/core/ai/ai_insights.dart';
import 'package:edupulse/core/ai/ai_refresh_service.dart';
import 'package:edupulse/core/ai/flashcard_service.dart';
import 'package:edupulse/core/notifications/adaptive_policy.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// Test cho CHU TRÌNH học tập khép kín: dữ liệu thay đổi → AI tính lại →
/// dẫn dắt hành động tiếp theo.
///
/// Trong môi trường test không có kênh gọi AI thật (không web, không API
/// key build-time), nên toàn bộ vòng lặp chạy ở lớp offline/quy tắc — đây
/// cũng chính là lớp đảm bảo chu trình không bao giờ "đứt" khi mất mạng.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AiRefreshService.cancelPending();
  });
  tearDown(AiRefreshService.cancelPending);

  // Nạp học sinh giả: 1 kỳ thi mục tiêu + điểm thi thử + task.
  void seedStudent() {
    final now = DateTime.now();
    final exam = ExamModel(
      id: 'e1',
      name: 'THPTQG 2027',
      dateTime: now.add(const Duration(days: 45)),
      currentScore: 7.2,
      targetScore: 9.0,
    );
    StorageService.setExamIds(['e1']);
    StorageService.setExamJson('e1', exam.toJsonString());
    StorageService.setPrimaryExamId('e1');

    void mock(String id, String subject, double score, DateTime at) {
      final m = MockScore(id: id, subject: subject, score: score, date: at);
      StorageService.setMockScoreJson(id, m.toJsonString());
      StorageService.setMockScoreIds(
          [...StorageService.getMockScoreIds(), id]);
    }

    mock('m1', 'Toán', 7.0, now.subtract(const Duration(days: 30)));
    mock('m2', 'Toán', 8.0, now.subtract(const Duration(days: 2)));
  }

  group('AiRefreshService — vòng lặp dữ liệu → AI', () {
    test('dữ liệu đổi → bản tin được tính lại từ dữ liệu MỚI, không dùng cache',
        () async {
      StorageService.setUserName('Minh');
      seedStudent();

      // Bản tin lần đầu: cache theo ngày với dữ liệu hiện tại.
      final b1 = await AiDailyBriefing.load();
      expect(b1.greeting, contains('Minh'));
      expect(b1.focus, isNotEmpty); // readiness có dữ liệu → có việc ưu tiên

      // Học sinh đổi dữ liệu (đổi tên) → chu trình báo AI tính lại.
      StorageService.setUserName('Bảo');
      AiRefreshService.notifyDataChanged();

      // Bản tin kế tiếp phải phản ánh dữ liệu mới — nếu invalidate hỏng,
      // greeting vẫn còn 'Minh' từ cache cũ.
      final b2 = await AiDailyBriefing.load();
      expect(b2.greeting, contains('Bảo'));
    });

    test('không có kênh AI thật thì không đặt timer tính lại nền', () {
      AiRefreshService.notifyDataChanged();
      expect(AiRefreshService.hasPendingRefresh, isFalse);
    });

    test('AiInsights.refresh trả null khi không có kênh gọi (không gọi mù)',
        () async {
      seedStudent(); // đủ dữ liệu phân tích, nhưng không có kênh AI.
      expect(await AiInsights.refresh(), isNull);
    });
  });

  group('Flashcard SM-2 — vòng lặp ôn tập', () {
    test('ôn xong thẻ đến hạn → dueAt bị đẩy sang ngày khác → hết hàng đến hạn',
        () {
      final card = Flashcard(
        id: 'fc_test_1',
        front: 'Định nghĩa đạo hàm?',
        back: 'lim (f(x+h)-f(x))/h',
        subject: 'Toán',
      );
      // Thẻ mới tạo có dueAt = hiện tại → đến hạn ngay.
      FlashcardService.save(card);
      expect(FlashcardService.dueCards().length, 1);

      // Chấm "Được" → interval tối thiểu 1 ngày → không còn đến hạn.
      FlashcardService.grade(card, ReviewGrade.good);
      expect(card.intervalDays, greaterThanOrEqualTo(1));
      expect(FlashcardService.dueCards(), isEmpty);
    });
  });

  group('Nhắc & digest — đuôi chu trình ra ngoài app', () {
    test('syncFlashcardReminder không nổ trên nền không hỗ trợ notification',
        () async {
      final card = Flashcard(
          id: 'fc_test_2', front: 'Câu hỏi', back: 'Đáp án', subject: 'Lý');
      FlashcardService.save(card);
      // flutter test mặc định nhận defaultTargetPlatform = android (plugin
      // thật không tồn tại trên host) — ép về windows để đi đúng nhánh
      // no-op như khi chạy trên web/desktop thật.
      final prev = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = prev);
      await AdaptivePolicy.syncFlashcardReminder();
    });

    test('digest ưu tiên lời dẫn từ bản tin AI khi được cung cấp', () {
      final now = DateTime.now();
      final task = TodayTask(
        id: 't1',
        title: 'Giải đề Toán',
        subject: 'Toán',
        priority: 'high',
        status: 'todo',
        estimateMinutes: 45,
      );
      final session = StudySession(
        id: 's1',
        subject: 'Toán',
        plannedMinutes: 25,
        actualMinutes: 25,
        completedAt: now,
      );
      final exam = ExamModel(
        id: 'e1',
        name: 'THPT QG',
        dateTime: now.add(const Duration(days: 42)),
      );

      final withGreeting = AdaptivePolicy.buildDigest(
        tasks: [task],
        sessions: [session],
        primaryExam: exam,
        now: now,
        briefingGreeting: 'Chào buổi sáng! Hôm nay tập trung Hóa nhé.',
      );
      expect(withGreeting.body, contains('tập trung Hóa'));
      expect(withGreeting.body, contains('Focus 25 phút'));

      // Lời dẫn quá dài bị cắt để notification không tràn.
      final longGreeting = AdaptivePolicy.buildDigest(
        tasks: [task],
        sessions: [session],
        primaryExam: exam,
        now: now,
        briefingGreeting: 'x' * 200,
      );
      expect(longGreeting.body.length, lessThan(200));
      expect(longGreeting.body, contains('…'));
    });
  });
}
