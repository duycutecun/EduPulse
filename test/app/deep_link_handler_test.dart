import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:edupulse/app/deep_link_handler.dart';
import 'package:edupulse/app/app_navigator_key.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DeepLinkHandler class exists and has openTaskDetail method', () {
    expect(DeepLinkHandler, isNotNull);
    expect(DeepLinkHandler.openTaskDetail, isNotNull);
  });

  group('Widget integration', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    testWidgets('openTaskDetail mở chi tiết task khi task tồn tại', (WidgetTester tester) async {
      final testTask = TodayTask(
        id: 'test-task-123',
        title: 'Test Task',
        subject: 'Toán',
        estimateMinutes: 45,
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        status: 'todo',
      );

      await TaskRepository.instance.createTask(testTask);

      final savedTask = TaskRepository.instance.getTaskById('test-task-123');
      expect(savedTask, isNotNull);
      expect(savedTask!.title, equals('Test Task'));

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    DeepLinkHandler.openTaskDetail(context, taskId: 'test-task-123');
                  },
                  child: const Text('Mở chi tiết task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Test Task'), findsOneWidget);
    });

    testWidgets('openTaskDetail hiển thị SnackBar khi task không tồn tại', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    DeepLinkHandler.openTaskDetail(context, taskId: 'non-existent-task');
                  },
                  child: const Text('Mở task không tồn tại'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy nhiệm vụ: non-existent-task'), findsOneWidget);
    });    tearDown(() async {
      try {
        await TaskRepository.instance.deleteTask('test-task-123');
      } catch (_) {
        // Task không tồn tại thì bỏ qua.
      }
    });
  });
}