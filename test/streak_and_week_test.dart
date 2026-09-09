import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/ai_coach/domain/quiz_models.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/ai_plan.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/score_summary.dart';
import 'package:edupulse/features/study/domain/weekly_summary.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('registerStudyActivity (streak)', () {
    test('Ngày đầu tiên → streak = 1, kỷ lục = 1', () {
      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 1);
      expect(StorageService.getStreakRecord(), 1);
    });

    test('Học 2 lần trong cùng ngày → không cộng lặp', () {
      StorageService.registerStudyActivity();
      StorageService.registerStudyActivity();
      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 1);
    });

    test('Học liền ngày hôm qua → +1 liên tục', () {
      // Giả lập đã học hôm qua: ghi key ngày hôm qua rồi gọi hàm hôm nay.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      StorageService.setString('last_study_date', _dayKey(yesterday));
      StorageService.setStreak(3);
      StorageService.setStreakRecord(3);

      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 4);
      expect(StorageService.getStreakRecord(), 4);
    });

    test('Bỏ lỡ >= 1 ngày → reset về 1', () {
      final threeDaysAgo =
          DateTime.now().subtract(const Duration(days: 3));
      StorageService.setString('last_study_date', _dayKey(threeDaysAgo));
      StorageService.setStreak(10);
      StorageService.setStreakRecord(10);

      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 1);
      expect(StorageService.getStreakRecord(), 10); // kỷ lục giữ nguyên
    });

    test('Streak mới không vượt kỷ lục cũ thì kỷ lục không đổi', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      StorageService.setString('last_study_date', _dayKey(yesterday));
      StorageService.setStreak(5);
      StorageService.setStreakRecord(20);

      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 6);
      expect(StorageService.getStreakRecord(), 20);
    });
  });

  group('summarizeWeek (tuần lịch T2–CN)', () {
    DateTime mondayNoon(int weekOffset) {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(monday.year, monday.month, monday.day + 7 * weekOffset, 12);
    }

    test('Log hôm nay rơi đúng cột weekday', () {
      final today = DateTime.now();
      final summary = summarizeWeek([
        StudyLog(id: 'a', date: today, subject: 'Toán', hours: 2.0),
      ]);
      expect(summary.dailyHours[today.weekday - 1], 2.0);
      expect(summary.totalHours, 2.0);
    });

    test('Log của tuần trước KHÔNG bị đếm vào tuần này (bug cũ)', () {
      final lastWeek = mondayNoon(-1); // 12h trưa T2 tuần trước
      final summary = summarizeWeek([
        StudyLog(id: 'old', date: lastWeek, subject: 'Lý', hours: 5.0),
      ]);
      expect(summary.totalHours, 0.0);
      expect(summary.subjectHours, isEmpty);
    });

    test('Log tuần trước không làm sai cột của tuần này', () {
      final today = DateTime.now();
      final lastWeekSameWeekday = today.subtract(const Duration(days: 7));
      final summary = summarizeWeek([
        StudyLog(id: 'cur', date: today, subject: 'Toán', hours: 1.0),
        StudyLog(
            id: 'prev', date: lastWeekSameWeekday, subject: 'Toán', hours: 9.0),
      ]);
      // Chỉ log tuần này được tính.
      expect(summary.totalHours, 1.0);
      expect(summary.dailyHours[today.weekday - 1], 1.0);
    });

    test('Nhiều log cùng ngày cộng dồn; phân bổ môn đúng', () {
      final today = DateTime.now();
      final summary = summarizeWeek([
        StudyLog(id: 'a', date: today, subject: 'Toán', hours: 1.5),
        StudyLog(id: 'b', date: today, subject: 'Văn', hours: 0.5),
        StudyLog(id: 'c', date: today, subject: 'Toán', hours: 2.0),
      ]);
      expect(summary.totalHours, 4.0);
      expect(summary.subjectHours['Toán'], 3.5);
      expect(summary.subjectHours['Văn'], 0.5);
    });
  });

  group('TodayTask storage round-trip', () {
    test('toJsonString → fromJsonString giữ nguyên dữ liệu', () {
      final task = TodayTask(
        id: 't1',
        title: 'Giải đề Toán',
        subject: '📐 Toán',
        priority: 'high',
        estimateMinutes: 60,
      );
      final parsed = TodayTask.fromJsonString(task.toJsonString());
      expect(parsed.id, 't1');
      expect(parsed.title, 'Giải đề Toán');
      expect(parsed.priority, 'high');
      expect(parsed.estimateMinutes, 60);
      expect(parsed.isDone, false);
    });
  });

  group('Lá bùa giữ chuỗi (streak freeze)', () {
    test('Bỏ lỡ đúng 1 ngày + có bùa → giữ streak, tiêu 1 bùa', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      StorageService.setString('last_study_date', _dayKey(twoDaysAgo));
      StorageService.setStreak(7);
      StorageService.setStreakRecord(10);
      StorageService.setStreakFreezes(2);

      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 7); // không reset, không tăng
      expect(StorageService.getStreakFreezes(), 1); // tiêu 1 lá
      expect(StorageService.getStreakRecord(), 10);
    });

    test('Bỏ lỡ đúng 1 ngày + HẾT bùa → reset về 1', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      StorageService.setString('last_study_date', _dayKey(twoDaysAgo));
      StorageService.setStreak(7);
      StorageService.setStreakRecord(10);
      StorageService.setStreakFreezes(0);

      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 1);
      expect(StorageService.getStreakFreezes(), 0);
    });

    test('Bỏ lỡ >= 2 ngày + có bùa → vẫn reset (bùa không cứu được)', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      StorageService.setString('last_study_date', _dayKey(threeDaysAgo));
      StorageService.setStreak(7);
      StorageService.setStreakFreezes(3);

      StorageService.registerStudyActivity();
      expect(StorageService.getStreak(), 1);
      expect(StorageService.getStreakFreezes(), 3); // không tiêu
    });

    test('Mua bùa: đủ EXP → trừ EXP, tối đa 3 lá; thiếu EXP → không mua', () {
      StorageService.setMascotBondExp(250);
      expect(StorageService.buyStreakFreeze(), true);
      expect(StorageService.getStreakFreezes(), 1);
      expect(StorageService.getMascotBondExp(), 150);

      StorageService.setMascotBondExp(50);
      expect(StorageService.buyStreakFreeze(), false);
      expect(StorageService.getStreakFreezes(), 1);
    });
  });

  group('summarizeMockScores (điểm thi thử)', () {
    test('Tính TB, mới nhất, cao nhất theo môn; xếp môn yếu lên đầu', () {
      final now = DateTime.now();
      final scores = [
        MockScore(id: 'a', date: now, subject: 'Toán', score: 8.0),
        MockScore(
            id: 'b',
            date: now.subtract(const Duration(days: 1)),
            subject: 'Toán',
            score: 9.0),
        MockScore(id: 'c', date: now, subject: 'Văn', score: 5.0),
        MockScore(
            id: 'd',
            date: now.subtract(const Duration(days: 1)),
            subject: 'Văn',
            score: 6.0),
      ];
      final sum = summarizeMockScores(scores);
      expect(sum.length, 2);
      expect(sum.first.subject, 'Văn'); // yếu nhất đứng đầu
      expect(sum.first.average, 5.5);
      expect(sum.first.latest, 5.0); // 5.0 ghi hôm nay → mới nhất
      expect(sum.first.best, 6.0);
      expect(sum[1].average, 8.5);
      expect(weakestSubject(scores), 'Văn');
    });

    test('buildScorePrompt chứa danh sách điểm + môn yếu', () {
      final prompt = buildScorePrompt([
        MockScore(id: 'a', date: DateTime.now(), subject: 'Toán', score: 7.0),
      ]);
      expect(prompt, contains('Toán'));
      expect(prompt, contains('Toán')); // môn yếu duy nhất
    });
  });

  group('parseAiPlan (lộ trình AI)', () {
    test('Parse JSON thuần có tasks đầy đủ', () {
      const raw = '{"tasks":[{"title":"Giải 1 đề Toán","subject":"📐 Toán","priority":"high","minutes":90}]}';
      final tasks = parseAiPlan(raw);
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Giải 1 đề Toán');
      expect(tasks.first.priority, 'high');
      expect(tasks.first.minutes, 90);
    });

    test('Bóc khối ```json ... ``` và cắt text thừa quanh JSON', () {
      const raw = 'Đây là lộ trình:\n```json\n{"tasks":[{"title":"Ôn từ vựng","subject":"🇬🇧 Anh","priority":"low","minutes":30}]}\n```\nChúc may mắn!';
      final tasks = parseAiPlan(raw);
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Ôn từ vựng');
      expect(tasks.first.priority, 'low');
    });

    test('Bỏ phần tử thiếu title; mặc định priority/minutes', () {
      const raw = '{"tasks":[{"title":"","subject":"x"},{"subject":"📖 Văn"},{"title":"Học bài","priority":"??","minutes":-5}]}';
      final tasks = parseAiPlan(raw);
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Học bài');
      expect(tasks.first.priority, 'medium'); // giá trị lạ → mặc định
      expect(tasks.first.minutes, 45);
    });

    test('JSON hỏng → danh sách rỗng (không crash)', () {
      expect(parseAiPlan('không phải json'), isEmpty);
      expect(parseAiPlan(''), isEmpty);
    });
  });

  group('parseQuiz (quiz từ ảnh)', () {
    test('Parse JSON quiz đầy đủ', () {
      const raw = '{"questions":[{"question":"1+1=?","options":["2","3","4","5"],"correctIndex":0,"explanation":"Cộng cơ bản"}]}';
      final qs = parseQuiz(raw);
      expect(qs.length, 1);
      expect(qs.first.question, '1+1=?');
      expect(qs.first.options.length, 4);
      expect(qs.first.correctIndex, 0);
      expect(qs.first.explanation, 'Cộng cơ bản');
    });

    test('correctIndex ngoài phạm vi → clamp về options hợp lệ', () {
      const raw = '{"questions":[{"question":"Q","options":["A","B"],"correctIndex":9}]}';
      final qs = parseQuiz(raw);
      expect(qs.first.correctIndex, 1); // clamp 0..1
    });

    test('Bỏ câu hỏi thiếu options hợp lệ', () {
      const raw = '{"questions":[{"question":"Q1","options":["A"]},{"question":"","options":["A","B"]},{"question":"Q2","options":["A","B"],"correctIndex":1}]}';
      final qs = parseQuiz(raw);
      expect(qs.length, 1);
      expect(qs.first.question, 'Q2');
    });

    test('JSON hỏng → rỗng (không crash)', () {
      expect(parseQuiz('abc'), isEmpty);
    });
  });

  group('Onboarding seed', () {
    test('Chọn preset THPTQG → tạo kỳ thi chính + 3 nhiệm vụ mẫu + đánh dấu done',
        () {
      // Mô phỏng đúng logic _pickPreset của OnboardingScreen.
      final exam = ExamModel(
        id: 'thptqg',
        name: 'Tốt nghiệp THPT',
        dateTime: DateTime(2027, 6, 11),
        type: ExamType.preset,
        emoji: '🎓',
      );
      StorageService.setExamJson(exam.id, exam.toJsonString());
      StorageService.setExamIds([exam.id]);
      StorageService.setPrimaryExamId(exam.id);

      const samples = [
        (title: 'Giải 1 đề Toán THPTQG (50 câu)', subject: '📐 Toán', priority: 'high', minutes: 90),
        (title: 'Luyện đọc hiểu tiếng Anh 30 phút', subject: '🇬🇧 Anh', priority: 'medium', minutes: 30),
        (title: 'Ôn nghị luận xã hội — dàn ý + viết mở bài', subject: '📖 Văn', priority: 'medium', minutes: 45),
      ];
      for (final t in samples) {
        final task = TodayTask(
          id: 'task-${t.title.hashCode}',
          title: t.title,
          subject: t.subject,
          priority: t.priority,
          estimateMinutes: t.minutes,
        );
        StorageService.setTodayTaskJson(task.id, task.toJsonString());
        final ids = StorageService.getTodayTaskIds()..add(task.id);
        StorageService.setTodayTaskIds(ids);
      }
      StorageService.setOnboardingDone();

      expect(StorageService.isOnboardingDone(), true);
      expect(StorageService.getExamIds(), ['thptqg']);
      expect(StorageService.getPrimaryExamId(), 'thptqg');
      expect(StorageService.getTodayTaskIds().length, 3);
      final first = StorageService.getTodayTaskJson(StorageService.getTodayTaskIds().first);
      expect(first, isNotNull);
      expect(TodayTask.fromJsonString(first!).priority, 'high');
    });
  });
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
