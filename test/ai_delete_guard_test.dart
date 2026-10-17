import 'package:edupulse/core/ai/ai_copilot_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/models/task_state.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chặn chống bug "user accept AI xoá task nhưng task vẫn còn trong danh
/// sách" — AI phải:
/// 1. Khớp đúng instance (exact > prefix > substring, ngày AI hẹn ưu tiên);
/// 2. Trùng tên nhiều bản → hỏi lại, KHÔNG chọn thầm;
/// 3. Hộp thoại hiện ngày + môn bản sắp xoá;
/// 4. Task lặp cho lựa chọn "chỉ lượt này" / "cả chuỗi";
/// 5. Xoá hỏng (race) → chip lỗi thay vì kẹt.
void main() {
  late TaskRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo = TaskRepository.instance;
  });

  TodayTask makeTask({
    String id = 't1',
    String title = 'Ôn hàm số',
    String subject = '📐 Toán',
    DateTime? scheduledAt,
    String? recurrence,
  }) {
    return TodayTask(
      id: id,
      title: title,
      subject: subject,
      priority: 'medium',
      estimateMinutes: 45,
      scheduledAt: scheduledAt ?? DateTime.now(),
      recurrence: recurrence,
    );
  }

  String iso(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute).toIso8601String();

  DateTime todayAt(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour);
  }

  DateTime dayOffset(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }

  List<String> idsLeft() => StorageService.getTodayTaskIds();

  group('khi khớp theo tầng bậc (exact > prefix > substring)', () {
    test('exact thắng prefix — "Toán ch5" trúng đúng bản tên ngắn', () async {
      await repo.createTask(
          makeTask(id: 'exact', title: 'Toán ch5', scheduledAt: todayAt(19)));
      await repo.createTask(makeTask(
          id: 'prefix', title: 'Toán ch5 nâng cao', scheduledAt: todayAt(20)));

      final outcome = await AiCopilotService.performRescheduleTask({
        'title': 'Toán ch5',
        'date': iso(dayOffset(1)),
      });
      expect(outcome.kind, AiActionResultKind.done);
      expect(outcome.message, contains('Đã dời "Toán ch5"'));

      // Chỉ bản exact được dời; bản prefix giữ nguyên lịch.
      final d = dayOffset(1);
      final moved = repo.getTaskById('exact')!;
      expect(moved.scheduledAt!.day, d.day);
      expect(moved.scheduledAt!.month, d.month);
      final untouched = repo.getTaskById('prefix')!;
      expect(untouched.scheduledAt!.day, todayAt(20).day);
    });

    test('prefix thắng substring — không nhảy nhầm bản "Đề cương"', () async {
      await repo.createTask(makeTask(
          id: 'prefix', title: 'Toán ch5 nâng cao', scheduledAt: todayAt(19)));
      await repo.createTask(makeTask(
          id: 'substring',
          title: 'Đề cương Toán ch5 ôn thi',
          scheduledAt: todayAt(20)));

      final outcome = await AiCopilotService.performRescheduleTask({
        'title': 'Toán ch5',
        'date': iso(dayOffset(2)),
      });
      expect(outcome.kind, AiActionResultKind.done);
      expect(outcome.message, contains('Toán ch5 nâng cao'));

      final moved = repo.getTaskById('prefix')!;
      final d = dayOffset(2);
      expect(moved.scheduledAt!.day, d.day);
      // Bản substring chưa bị đụng gì.
      final untouched = repo.getTaskById('substring')!;
      expect(untouched.scheduledAt!.day, todayAt(20).day);
    });

    test('chỉ còn khớp substring (2 chiều) → vẫn xử lý đúng bản đó', () async {
      await repo.createTask(makeTask(
          id: 'sub',
          title: 'Đề cương Toán ch5 ôn thi',
          scheduledAt: todayAt(19)));

      final outcome = await AiCopilotService.performRescheduleTask({
        'title': 'Toán ch5',
        'date': iso(dayOffset(3)),
      });
      expect(outcome.kind, AiActionResultKind.done);
      expect(outcome.message, contains('Đề cương Toán ch5 ôn thi'));
    });
  });

  group('trùng tên mơ hồ — không xoá thầm', () {
    testWidgets('2 bản chưa làm cùng tên → failed + hỏi lại, không xoá gì',
        (tester) async {
      await repo.createTask(makeTask(id: 'a', scheduledAt: todayAt(19)));
      await repo.createTask(makeTask(id: 'b', scheduledAt: todayAt(21)));

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
        payload: {'title': 'Ôn hàm số', 'subject': 'Toán'},
      );

      final res = await AiCopilotService.executeAuto(screenContext, action);
      expect(res.kind, AiActionResultKind.failed);
      expect(res.message, contains('bản trùng tên'));
      expect(find.text('Xóa nhiệm vụ?'), findsNothing);
      expect(idsLeft().length, 2);
    });
  });

  group('khi AI hẹn ngày mai', () {
    testWidgets('tìm đúng task của NGÀY MAI, task hôm nay sống sót',
        (tester) async {
      await repo.createTask(makeTask(id: 'today', scheduledAt: todayAt(19)));
      await repo.createTask(makeTask(
          id: 'tomorrow',
          scheduledAt: dayOffset(1).add(const Duration(hours: 20))));

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
        payload: {
          'title': 'Ôn hàm số',
          'subject': 'Toán',
          'scheduledAt': iso(dayOffset(1)),
        },
      );

      final future = AiCopilotService.executeAuto(screenContext, action);
      await tester.pumpAndSettle();
      expect(find.text('Xóa nhiệm vụ?'), findsOneWidget);

      await tester.tap(find.text('Xóa'));
      await tester.pump();
      final res = await future;
      expect(res.kind, AiActionResultKind.done);

      // Đúng instance: bản mai xoá, bản hôm nay vẫn nằm nguyên.
      final left = idsLeft();
      expect(left, contains('today'));
      expect(left, isNot(contains('tomorrow')));
    });
  });

  group('dialog thể hiện đúng instance', () {
    testWidgets('hiện ngày mai + môn của bản sắp xoá', (tester) async {
      await repo.createTask(makeTask(
          id: 'tomorrow',
          scheduledAt: dayOffset(1).add(const Duration(hours: 20))));

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
        payload: {
          'title': 'Ôn hàm số',
          'subject': 'Toán',
          'scheduledAt': iso(dayOffset(1).add(const Duration(hours: 20))),
        },
      );

      final future = AiCopilotService.executeAuto(screenContext, action);
      await tester.pumpAndSettle();

      // Dòng chi tiết phải nói rõ ngày (mai) và môn (Toán).
      expect(find.textContaining('mai'), findsOneWidget);
      expect(find.textContaining('Toán'), findsOneWidget);
      expect(find.text('Ôn hàm số'), findsOneWidget);

      await tester.tap(find.text('Giữ lại'));
      final res = await future;
      expect(res.kind, AiActionResultKind.rejected);
      expect(idsLeft(), contains('tomorrow'));
    });

    testWidgets('task lặp: 3 lựa chọn trong dialog, "chỉ lượt này" giữ bản mai',
        (tester) async {
      await repo.createTask(
          makeTask(id: 's1', scheduledAt: todayAt(19), recurrence: 'daily'));
      await repo.createTask(makeTask(
          id: 's2',
          scheduledAt: dayOffset(1).add(const Duration(hours: 19)),
          recurrence: 'daily'));

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
        payload: {
          'title': 'Ôn hàm số',
          'subject': 'Toán',
          'scheduledAt': iso(todayAt(19)),
        },
      );

      final future = AiCopilotService.executeAuto(screenContext, action);
      await tester.pumpAndSettle();
      // Dialog lặp phải cho 2 mức xoá rõ ràng.
      expect(find.text('Chỉ xoá lượt này'), findsOneWidget);
      expect(find.text('Xoá cả chuỗi'), findsOneWidget);
      expect(find.textContaining('lặp hằng ngày'), findsOneWidget);

      await tester.tap(find.text('Chỉ xoá lượt này'));
      await tester.pump();
      final res = await future;
      expect(res.kind, AiActionResultKind.done);
      expect(res.message, contains('Đã xoá'));

      // Lượt mai cùng chuỗi vẫn còn nguyên.
      final left = idsLeft();
      expect(left, isNot(contains('s1')));
      expect(left, contains('s2'));
    });

    testWidgets('task lặp: "xoá cả chuỗi" dọn cả các lượt tuần theo sau',
        (tester) async {
      await repo.createTask(
          makeTask(id: 'w1', scheduledAt: todayAt(19), recurrence: 'weekly'));
      await repo.createTask(makeTask(
          id: 'w2',
          scheduledAt: dayOffset(7).add(const Duration(hours: 19)),
          recurrence: 'weekly'));

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
        payload: {
          'title': 'Ôn hàm số',
          'subject': 'Toán',
          'scheduledAt': iso(todayAt(19)),
        },
      );

      final future = AiCopilotService.executeAuto(screenContext, action);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xoá cả chuỗi'));
      await tester.pump();
      final res = await future;
      expect(res.kind, AiActionResultKind.done);
      expect(res.message, contains('cả chuỗi'));
      // Cả hai lượt trong khung hôm nay→+30 ngày đều mất.
      expect(idsLeft(), isEmpty);
    });
  });

  group('chip kết quả trung thực', () {
    testWidgets('xoá lượt chưa làm rồi thì còn bản đã hoàn thành cùng tên',
        (tester) async {
      await repo.createTask(makeTask(id: 'pending', scheduledAt: todayAt(19)));
      await repo.createTask(makeTask(id: 'doneCopy', scheduledAt: todayAt(8)));
      // Bản "đã hoàn thành + hôm nay" vẫn hiển thị cuối danh sách Hôm nay.
      await repo.setTaskStatus('doneCopy', TaskStatus.completed);

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
        payload: {
          'title': 'Ôn hàm số',
          'subject': 'Toán',
          'scheduledAt': iso(todayAt(19)),
        },
      );

      final future = AiCopilotService.executeAuto(screenContext, action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pump();
      final res = await future;
      expect(res.kind, AiActionResultKind.done);
      expect(res.message, contains('còn 1 bản đã hoàn thành cùng tên'));

      // Bản record không bị tự tay xoá hộ người học.
      final left = idsLeft();
      expect(left, contains('doneCopy'));
      expect(left, isNot(contains('pending')));
    });
  });

  group('xoá hỏng — không kẹt', () {
    testWidgets('task biến mất giữa hai lần tra → chip lỗi, không crash',
        (tester) async {
      await repo.createTask(makeTask(id: 't1', scheduledAt: todayAt(19)));

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
        payload: {
          'title': 'Ôn hàm số',
          'subject': 'Toán',
        },
      );

      final future = AiCopilotService.executeAuto(screenContext, action);
      await tester.pumpAndSettle();
      expect(find.text('Xóa nhiệm vụ?'), findsOneWidget);

      // Anh em khác xoá hộ giữa chừng — repository sẽ nổ StateError.
      StorageService.removeTodayTask('t1');

      await tester.tap(find.text('Xóa'));
      await tester.pump();
      final res = await future;
      expect(res.kind, AiActionResultKind.failed);
      expect(res.message, contains('lỗi khi xoá'));
    });
  });
}
