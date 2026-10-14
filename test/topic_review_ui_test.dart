import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// P1-2: insight chủ đề yếu + một chạm đặt nhiệm vụ ôn lại (mức chủ đề).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  void seedScore({
    required String id,
    required String subject,
    required String? topic,
    required double score,
  }) {
    final s = MockScore(
      id: id,
      date: DateTime.now(),
      subject: subject,
      score: score,
      topic: topic,
    );
    StorageService.setMockScoreJson(s.id, s.toJsonString());
    final ids = StorageService.getMockScoreIds()..add(s.id);
    StorageService.setMockScoreIds(ids);
  }

  Future<void> openScoreTab(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StudyScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Điểm thi'));
    await tester.pumpAndSettle();
  }

  testWidgets('điểm thấp theo chủ đề → hiện thẻ "Chủ đề cần ôn lại"',
      (tester) async {
    seedScore(id: 'a', subject: 'Toán', topic: 'Hàm số', score: 4.5);
    seedScore(id: 'b', subject: 'Toán', topic: 'Hình học', score: 9);

    await openScoreTab(tester);

    expect(find.text('Chủ đề cần ôn lại'), findsOneWidget);
    expect(find.text('Ôn chủ đề này'), findsOneWidget);
    expect(find.textContaining('Hàm số'), findsWidgets);
  });

  testWidgets('mọi chủ đề đều ổn → không hiện thẻ, không làm nhiễu',
      (tester) async {
    seedScore(id: 'a', subject: 'Toán', topic: 'Hàm số', score: 8);

    await openScoreTab(tester);

    expect(find.text('Chủ đề cần ôn lại'), findsNothing);
  });

  testWidgets('"Ôn chủ đề này" tạo nhiệm vụ mang đúng chủ đề', (tester) async {
    seedScore(id: 'a', subject: 'Toán', topic: 'Hàm số', score: 4.0);

    await openScoreTab(tester);

    final button = find.text('Ôn chủ đề này');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    final created = TaskRepository.instance
        .getAllTasks()
        .where((t) => t.title == 'Ôn chủ đề: Hàm số')
        .toList();
    expect(created, hasLength(1), reason: 'phải tạo đúng một nhiệm vụ ôn');
    expect(created.single.topic, 'Hàm số');
    expect(created.single.priority, 'high');
  });
}
