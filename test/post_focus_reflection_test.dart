import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/presentation/widgets/ai_post_focus_sheet.dart';

/// Đặc tả 5.3 — phản tư kết thúc phiên có mức hiểu 3 bậc:
/// chưa hiểu / tạm ổn / tự tin (không còn 2 bậc như trước).
void main() {
  StudySession session() => StudySession(
        id: 's1',
        completedAt: DateTime(2026, 10, 14, 20, 0),
        subject: 'Toán',
        plannedMinutes: 25,
        actualMinutes: 25,
      );

  Future<void> open(
      WidgetTester tester, void Function(SessionFeedback) onSaved) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAiPostFocusSheet(
              context: context,
              session: session(),
              hasSelectedTask: false,
              onSave: (ctx, s, fb) async {
                onSaved(fb);
                Navigator.pop(ctx);
              },
              onCompleteAndGo: (ctx, s, fb) async {
                onSaved(fb);
                Navigator.pop(ctx);
              },
              onScheduleReview: (_) async {},
              onQuickNote: (_, {String? sessionId}) {},
              onTasksChanged: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
  }

  testWidgets('hiện đủ 3 mức hiểu', (tester) async {
    await open(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa hiểu'), findsOneWidget);
    expect(find.text('Tạm ổn'), findsOneWidget);
    expect(find.text('Tự tin'), findsOneWidget);
    expect(find.text('Hiểu tốt'), findsNothing);
    expect(find.text('Cần củng cố'), findsNothing);
  });

  testWidgets('chọn "Chưa hiểu" → mức hiểu 1, hiệu quả 2', (tester) async {
    SessionFeedback? saved;
    await open(tester, (fb) => saved = fb);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chưa hiểu'));
    await tester.pump();

    final save = find.text('Lưu phản hồi & Hoàn tất');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.understanding, 1);
    expect(saved!.effectiveness, 2);
  });

  testWidgets('chọn "Tự tin" → mức hiểu 4', (tester) async {
    SessionFeedback? saved;
    await open(tester, (fb) => saved = fb);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tự tin'));
    await tester.pump();

    final save = find.text('Lưu phản hồi & Hoàn tất');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.understanding, 4);
  });
}
