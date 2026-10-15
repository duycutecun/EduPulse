import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/presentation/screens/ai_plan_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiPlanScreen()));
    await tester.pump();
  }

  testWidgets('thẻ phân tích hiện số điểm thi thử đã có', (tester) async {
    final s1 = MockScore(
        id: 's1', date: DateTime(2026, 10, 1), subject: 'Toán', score: 6.5);
    final s2 = MockScore(
        id: 's2', date: DateTime(2026, 10, 5), subject: 'Lý', score: 7.0);
    StorageService.setMockScoreJson('s1', s1.toJsonString());
    StorageService.setMockScoreJson('s2', s2.toJsonString());
    StorageService.setMockScoreIds(['s1', 's2']);

    await pumpScreen(tester);

    expect(find.textContaining('2 điểm thi thử'), findsOneWidget);
  });

  testWidgets('chưa có điểm thử thì nhắc thêm ở tab Tiến độ', (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('Chưa có điểm thi thử'), findsOneWidget);
  });

  testWidgets('tắt quyền AI phân tích thì chặn và báo bật lại', (tester) async {
    StorageService.setBool('ai_permission_analyze', false);
    await pumpScreen(tester);

    await tester.tap(find.text('PHÂN TÍCH ĐIỂM THỬ & SINH LỘ TRÌNH'));
    await tester.pump();

    expect(find.textContaining('Bạn đã tắt quyền'), findsOneWidget);
  });
}
