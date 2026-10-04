import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/ai/ai_copilot_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/calendar/presentation/screens/calendar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Phase 1.1: Pomodoro AI integration', () {
    test('Preferred subject fallback và weakest subject detection', () {
      expect(AiCopilotService.preferredSubject(), 'Toán');

      // Thêm mock score cho môn Hóa với điểm thấp
      final mock = MockScore(
        id: 'm1',
        subject: 'Hóa học',
        score: 5.5,
        date: DateTime.now(),
      );
      StorageService.setMockScoreJson(mock.id, mock.toJsonString());
      StorageService.setMockScoreIds([mock.id]);

      final weak = AiCopilotService.weakestSubject();
      expect(weak?.$1, 'Hóa học');
      expect(weak?.$2, 5.5);
      expect(AiCopilotService.preferredSubject(), 'Hóa học');
    });
  });

  group('Phase 1.2: Calendar AI Auto-Schedule', () {
    testWidgets('Lập lịch tuần AI tạo 5 nhiệm vụ cân đối rải đều',
        (tester) async {
      final exam = ExamModel(
        id: 'exam-1',
        name: 'Tốt nghiệp THPT 2026',
        dateTime: DateTime.now().add(const Duration(days: 90)),
      );
      StorageService.setExamJson(exam.id, exam.toJsonString());
      StorageService.setExamIds([exam.id]);
      StorageService.setPrimaryExamId(exam.id);

      // Thêm điểm môn yếu
      final mock = MockScore(
        id: 'm-phys',
        subject: 'Vật lý',
        score: 4.5,
        date: DateTime.now(),
      );
      StorageService.setMockScoreJson(mock.id, mock.toJsonString());
      StorageService.setMockScoreIds([mock.id]);

      await tester.pumpWidget(
        const MaterialApp(
          home: CalendarScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm "Tối ưu tuần" khi chưa có task -> hiện popup đề xuất AI
      await tester.tap(find.text('Tối ưu tuần').first);
      await tester.pumpAndSettle();

      expect(find.text('AI Lập lịch tuần ôn thi'), findsOneWidget);

      // Bấm "AI Lên lịch ngay"
      await tester.tap(find.text('AI Lên lịch ngay'));
      await tester.pumpAndSettle();

      // Kiểm tra 5 tasks đã được tạo trong StorageService
      final taskIds = StorageService.getTodayTaskIds();
      expect(taskIds.length, 5);

      final tasks = taskIds
          .map((id) =>
              TodayTask.fromJsonString(StorageService.getTodayTaskJson(id)!))
          .toList();

      expect(tasks.any((t) => t.subject == 'Vật lý'), isTrue);
      expect(tasks.every((t) => t.scheduledAt != null), isTrue);
    });
  });
}
