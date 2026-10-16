import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/presentation/widgets/ai_post_focus_sheet.dart';

/// V2 (`docs/BAN_THAY_DOI_V2.md` mục C.3) — phản tư kết thúc phiên là **một
/// câu, hai nút to**: "Hiểu chưa?" → Hiểu rồi / Chưa hiểu. Ba bậc chi tiết
/// (chưa hiểu / tạm ổn / tự tin) bị bỏ: đó là dữ liệu khai chi tiết hơn thứ
/// người học muốn bấm sau một phiên ngắn. Ba chip lý do (quá khó / hết giờ /
/// làm việc khác) chỉ hiện khi họ chọn "Chưa hiểu".
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

  testWidgets('hiện đúng 2 lựa chọn hiểu bài, không còn 3 bậc', (tester) async {
    await open(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Hiểu chưa?'), findsOneWidget);
    expect(find.text('Chưa hiểu'), findsOneWidget);
    expect(find.text('Hiểu rồi'), findsOneWidget);
    expect(find.text('Tạm ổn'), findsNothing);
    expect(find.text('Tự tin'), findsNothing);
    // Chưa chọn "Chưa hiểu" thì chưa hỏi lý do — hỏi trước là bắt khai thêm.
    expect(find.text('Quá khó'), findsNothing);
  });

  testWidgets('chọn "Chưa hiểu" → hiện 3 chip lý do ngắn', (tester) async {
    await open(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chưa hiểu'));
    await tester.pump();

    expect(find.text('Quá khó'), findsOneWidget);
    expect(find.text('Hết giờ'), findsOneWidget);
    expect(find.text('Làm việc khác'), findsOneWidget);
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

  testWidgets('chọn "Hiểu rồi" → mức hiểu 4', (tester) async {
    SessionFeedback? saved;
    await open(tester, (fb) => saved = fb);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hiểu rồi'));
    await tester.pump();

    final save = find.text('Lưu phản hồi & Hoàn tất');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.understanding, 4);
  });

  testWidgets('im lặng 4 giây → ghi "chưa rõ" và tự đóng, không bắt trả lời',
      (tester) async {
    SessionFeedback? saved;
    await open(tester, (fb) => saved = fb);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Hiểu chưa?'), findsOneWidget);
    // Không chạm gì: hết 4 giây là app tự ghi "chưa rõ" rồi biến (V2 mục C.3).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(saved, isNotNull,
        reason: 'im lặng phải được ghi lại thành "chưa rõ"');
    expect(saved!.note, 'chưa rõ');
    expect(find.text('Hiểu chưa?'), findsNothing, reason: 'sheet đã tự đóng');
  });

  testWidgets('đã chạm vào sheet thì KHÔNG tự lưu thay người học',
      (tester) async {
    SessionFeedback? saved;
    await open(tester, (fb) => saved = fb);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Chạm "Hiểu rồi" rồi ngồi im: người học đang trả lời, im lặng sau đó
    // không được hiểu thành "chưa rõ".
    await tester.tap(find.text('Hiểu rồi'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(saved, isNull, reason: 'đã trả lời thì chỉ lưu khi họ bấm lưu');
    expect(find.text('Hiểu chưa?'), findsOneWidget, reason: 'sheet vẫn mở');
  });

  testWidgets('mặc định: đã hoàn thành mục tiêu, không trở ngại',
      (tester) async {
    SessionFeedback? saved;
    await open(tester, (fb) => saved = fb);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final save = find.text('Lưu phản hồi & Hoàn tất');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.goalMet, isTrue);
    expect(saved!.blocker, isEmpty);
  });

  testWidgets('chọn "Chưa xong" + "Có trở ngại" → lưu đúng', (tester) async {
    SessionFeedback? saved;
    await open(tester, (fb) => saved = fb);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm đánh giá chi tiết ▾'));
    await tester.pumpAndSettle();

    final chuaXong = find.text('Chưa xong');
    await tester.ensureVisible(chuaXong);
    await tester.tap(chuaXong);
    await tester.pump();
    final troNgai = find.text('🚧 Có trở ngại');
    await tester.ensureVisible(troNgai);
    await tester.tap(troNgai);
    await tester.pump();

    final save = find.text('Lưu phản hồi & Hoàn tất');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.goalMet, isFalse);
    expect(saved!.blocker, 'Có trở ngại');
  });

  testWidgets('"Chưa hiểu" → chip lý do → hiện đề xuất chia nhỏ (≤2 chạm)',
      (tester) async {
    var splitTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAiPostFocusSheet(
              context: context,
              session: session(),
              hasSelectedTask: true,
              onSave: (ctx, s, fb) async => Navigator.pop(ctx),
              onCompleteAndGo: (ctx, s, fb) async => Navigator.pop(ctx),
              onScheduleReview: (_) async {},
              onQuickNote: (_, {String? sessionId}) {},
              onTasksChanged: () {},
              onSplitTask: () => splitTapped = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // V2 mục C.3: "Chưa hiểu" → hỏi lý do → đề xuất chia nhỏ/đổi lịch trong
    // tối đa 2 chạm. Đây là cả chuỗi đó, chạm đúng như người học.
    expect(find.text('✂️ Chia nhỏ cho lần sau'), findsNothing);
    await tester.tap(find.text('Chưa hiểu'));
    await tester.pump();
    await tester.tap(find.text('Quá khó'));
    await tester.pumpAndSettle();

    final split = find.text('✂️ Chia nhỏ cho lần sau');
    expect(split, findsOneWidget);
    await tester.ensureVisible(split);
    await tester.pumpAndSettle();
    await tester.tap(split);
    await tester.pumpAndSettle();
    expect(splitTapped, isTrue);
  });

  testWidgets('"Chưa xong" + có nhiệm vụ → hiện đề xuất chia nhỏ',
      (tester) async {
    var splitTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAiPostFocusSheet(
              context: context,
              session: session(),
              hasSelectedTask: true,
              onSave: (ctx, s, fb) async => Navigator.pop(ctx),
              onCompleteAndGo: (ctx, s, fb) async => Navigator.pop(ctx),
              onScheduleReview: (_) async {},
              onQuickNote: (_, {String? sessionId}) {},
              onTasksChanged: () {},
              onSplitTask: () => splitTapped = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('✂️ Chia nhỏ cho lần sau'), findsNothing);

    await tester.tap(find.text('Thêm đánh giá chi tiết ▾'));
    await tester.pumpAndSettle();
    final chuaXong = find.text('Chưa xong');
    await tester.ensureVisible(chuaXong);
    await tester.tap(chuaXong);
    await tester.pump();

    final split = find.text('✂️ Chia nhỏ cho lần sau');
    expect(split, findsOneWidget);
    await tester.ensureVisible(split);
    await tester.pumpAndSettle();
    await tester.tap(split);
    await tester.pumpAndSettle();
    expect(splitTapped, isTrue);
  });

  testWidgets('không có nhiệm vụ → không hiện đề xuất chia nhỏ',
      (tester) async {
    await open(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm đánh giá chi tiết ▾'));
    await tester.pumpAndSettle();
    final chuaXong = find.text('Chưa xong');
    await tester.ensureVisible(chuaXong);
    await tester.tap(chuaXong);
    await tester.pump();

    expect(find.text('✂️ Chia nhỏ cho lần sau'), findsNothing);
  });

  testWidgets('chọn trở ngại "Cần ôn lại" → hiện đề xuất ôn lại',
      (tester) async {
    await open(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('📅 Ôn lại ngày mai'), findsNothing);

    await tester.tap(find.text('Thêm đánh giá chi tiết ▾'));
    await tester.pumpAndSettle();

    final onLai = find.text('🔁 Cần ôn lại');
    await tester.ensureVisible(onLai);
    await tester.tap(onLai);
    await tester.pump();

    expect(find.text('📅 Ôn lại ngày mai'), findsOneWidget);
  });
}
