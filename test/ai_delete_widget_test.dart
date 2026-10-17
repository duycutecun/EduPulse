import 'package:edupulse/core/ai/ai_copilot_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI-2.2 — xoá task là hành động chỉ đi theo **đề nghị** của AI:
/// người dùng chốt → hộp thoại xác nhận (FE-2.5) → xoá → vẫn hoàn tác được.
void main() {
  testWidgets('deleteTask tự thực thi: dialog xác nhận → xoá → hoàn tác',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    final repo = TaskRepository.instance;
    await repo.createTaskIfMissing(TodayTask(
      id: 't1',
      title: 'Ôn hàm số',
      subject: '📐 Toán',
      priority: 'medium',
      estimateMinutes: 45,
      scheduledAt: DateTime.now(),
    ));
    expect(StorageService.getTodayTaskIds().length, 1);

    BuildContext? screenContext;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) {
            screenContext = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    ));

    final action = AiCopilotAction(
      type: AiActionType.deleteTask,
      label: '🗑 Xoá nhiệm vụ',
      icon: Icons.delete_outline_rounded,
      payload: {'title': 'Ôn hàm số', 'subject': 'Toán', 'confirm': true},
    );

    final future = AiCopilotService.executeAuto(screenContext, action);
    await tester.pumpAndSettle();
    // Hộp thoại của người dùng (không phải dialog AI dựng riêng) hiện đúng tên
    // nhiệm vụ đích danh — xoá nhầm là chuyện không được phép.
    expect(find.text('Xóa nhiệm vụ?'), findsOneWidget);
    expect(find.text('Ôn hàm số'), findsOneWidget);

    await tester.tap(find.text('Xóa'));
    await tester.pump();

    final result = await future;
    expect(result.kind, AiActionResultKind.done);
    expect(result.message, contains('Đã xoá'));
    expect(StorageService.getTodayTaskIds(), isEmpty);

    // Người dùng đổi ý → chip Hoàn tác khôi phục nguyên vẹn (FE-2.5).
    await result.undo!();
    await tester.pump();

    final ids = StorageService.getTodayTaskIds();
    expect(ids.length, 1);
    final task =
        TodayTask.fromJsonString(StorageService.getTodayTaskJson(ids.first)!);
    expect(task.title, 'Ôn hàm số');
  });
}
