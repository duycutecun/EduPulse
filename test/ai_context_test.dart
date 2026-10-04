import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/ai/ai_context.dart';
import '''
package:edupulse/core/utils/storage_service.dart''';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });
//
  /// Nạp một học sinh giả: thi sắp tới, nhiệm vụ, phiên học, điểm, ghi chú.
  void seedStudent(DateTime now) {
    StorageService.setUserName('Minh');
    StorageService.setUserTarget('Đỗ 9.0 Toán');
    StorageService.setStreak(12);
    StorageService.setStreakRecord(20);

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

    void task(
        String id, String title, String subject, String priority, String status,
        {int est = 45, int resched = 0, String? skip}) {
      final t = TodayTask(
        id: id,
        title: title,
        subject: subject,
        priority: priority,
        status: status,
        estimateMinutes: est,
        rescheduleCount: resched,
        skipReason: skip,
      );
      StorageService.setTodayTaskJson(id, t.toJsonString());
      StorageService.setTodayTaskIds([...StorageService.getTodayTaskIds(), id]);
    }

    task('t1', 'Tích phân đa biến', 'Toán', 'high', 'completed');
    task('t2', 'Cân bằng hóa học', 'Hóa', 'high', 'todo', est: 60);
    task('t3', 'Đọc Hiệp phân', 'Văn', 'low', 'skipped',
        skip: 'thiếu thời gian');
    task('t4', 'Luyện đề Lý', 'Lý', 'medium', 'todo', resched: 2);

    void session(String id, String subject, int minutes, DateTime at,
        {int? understanding}) {
      final s = StudySession(
        id: id,
        subject: subject,
        plannedMinutes: minutes,
        actualMinutes: minutes,
        completedAt: at,
        understanding: understanding,
        difficulty: 4,
      );
      StorageService.setStudySessionJson(id, jsonEncodeNoImage(s));
      StorageService.setStudySessionIds(
          [...StorageService.getStudySessionIds(), id]);
    }

    session('s1', 'Toán', 90, now.subtract(const Duration(days: 1)),
        understanding: 4);
    session('s2', 'Hóa', 45, now.subtract(const Duration(days: 2)),
        understanding: 2);
    session('s3', 'Toán', 60, now.subtract(const Duration(days: 20)),
        understanding: 3);

    void log(String id, String subject, double hours, DateTime at) {
      final l = StudyLog(id: id, subject: subject, hours: hours, date: at);
      StorageService.setStudyLogJson(id, l.toJsonString());
      StorageService.setStudyLogIds([...StorageService.getStudyLogIds(), id]);
    }

    log('l1', 'Toán', 3.5, now.subtract(const Duration(days: 1)));
    log('l2', 'Hóa', 1.0, now.subtract(const Duration(days: 3)));

    void mock(String id, String subject, double score, DateTime at) {
      final m = MockScore(id: id, subject: subject, score: score, date: at);
      StorageService.setMockScoreJson(id, m.toJsonString());
      StorageService.setMockScoreIds([...StorageService.getMockScoreIds(), id]);
    }

    mock('m1', 'Toán', 7.0, now.subtract(const Duration(days: 30)));
    mock('m2', 'Toán', 8.0, now.subtract(const Duration(days: 2)));
    mock('m3', 'Hóa', 6.0, now.subtract(const Duration(days: 25)));

    final note = StudyNote(
      id: 'n1',
      title: 'Công thức đạo hàm cấp 2',
      body: '...',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
      subject: 'Toán',
    );
    StorageService.setStudyNoteJson('n1', note.toJsonString());
    StorageService.setStudyNoteIds(['n1']);
  }

  group('AiStudyContext', () {
    test('không có dữ liệu → trả chuỗi rỗng', () {
      expect(AiStudyContext.build(), '');
    });

    test('gom được kỳ thi, nhiệm vụ, điểm và ghi chú', () {
      final now = DateTime(2026, 9, 30, 10);
      seedStudent(now);
      final ctx = AiStudyContext.build(now: now);

      // Kỳ thi: tên + số ngày còn lại + điểm.
      expect(ctx, contains('THPTQG 2027'));
      expect(ctx, matches(RegExp(r'còn \d+ ngày')));
      expect(ctx, contains('mục tiêu 9.0'));

      // Nhiệm vụ: đếm đúng trạng thái, nêu tên việc chưa làm.
      expect(ctx, contains('1/4 đã xong'));
      expect(ctx, contains('Cân bằng hóa học'));
      expect(ctx, contains('Luyện đề Lý'));

      // Nhiệm vụ bỏ qua phải kèm lý do.
      expect(ctx, contains('thiếu thời gian'));

      // Điểm: môn yếu nhất là Hóa, mạnh nhất là Toán.
      expect(ctx, contains('Yếu nhất: Hóa'));
      expect(ctx, contains('mạnh nhất: Toán'));

      // Ghi chú.
      expect(ctx, contains('Công thức đạo hàm cấp 2'));

      // Chuỗi học.
      expect(ctx, contains('chuỗi học 12 ngày'));
    });

    test('tôn trọng quyền riêng tư: tắt thì không gửi gì', () {
      final now = DateTime(2026, 9, 30, 10);
      seedStudent(now);
      StorageService.setBool('ai_permission_read', false);
      expect(AiStudyContext.build(now: now), '');
    });

    test('bỏ qua bản ghi hỏng thay vì ném lỗi', () {
      final now = DateTime(2026, 9, 30, 10);
      seedStudent(now);
      StorageService.setExamJson('broken', '{khong phai json');
      StorageService.setExamIds([...StorageService.getExamIds(), 'broken']);
      expect(() => AiStudyContext.build(now: now), returnsNormally);
    });

    test('không vượt quá giới hạn ký tự', () {
      final now = DateTime(2026, 9, 30, 10);
      seedStudent(now);
      expect(AiStudyContext.build(now: now).length, lessThan(3000));
    });

    test('tổng giờ học cộng cả phiên học lẫn ghi chép nhập tay', () {
      final now = DateTime(2026, 9, 30, 10);
      seedStudent(now);
      final ctx = AiStudyContext.build(now: now);

      // Phiên học: 90 + 45 + 60 phút = 3.25h; ghi chép nhập tay: 3.5 + 1.0h.
      // Trước khi gộp, AI chỉ thấy 4.5h và bỏ sót toàn bộ thời gian pomodoro.
      expect(ctx, contains('7.8 giờ tích lũy'));
      expect(ctx, contains('Toán'));
    });

    test('chỉ có phiên học pomodoro thì AI vẫn thấy thời gian học', () {
      final now = DateTime(2026, 9, 30, 10);
      seedStudent(now);
      StorageService.setStudyLogIds([]);
      final ctx = AiStudyContext.build(now: now);
      // 3.25h từ ba phiên học, không còn dòng log nhập tay nào.
      expect(ctx, contains('3.3 giờ tích lũy'));
    });
  });
}

/// StudySession chưa có fromJsonString nên test tự encode.
String jsonEncodeNoImage(StudySession s) => s.toJsonString();
