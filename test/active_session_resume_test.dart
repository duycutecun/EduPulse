import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/home/presentation/widgets/active_session_resume_card.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';

/// Đặc tả 5.2 — màn Hôm nay phải nhắc lại phiên học đang dở để không mất
/// quãng thời gian đã học.
void main() {
  final now = DateTime(2026, 10, 14, 20, 0);

  ActiveStudySession session(
          {bool isBreak = false, String? title = 'Hàm số'}) =>
      ActiveStudySession(
        taskId: 't1',
        taskTitle: title,
        subject: 'Toán',
        totalSeconds: 1500,
        remainingAtAnchor: 720,
        anchorAt: now,
        startedAt: now,
        isBreak: isBreak,
      );

  Future<void> pump(
    WidgetTester tester,
    ActiveStudySession s, {
    VoidCallback? onResume,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActiveSessionResumeCard(
          session: s,
          clock: () => now,
          onResume: onResume ?? () {},
        ),
      ),
    ));
  }

  testWidgets('hiện tên việc và số phút còn lại', (tester) async {
    await pump(tester, session());
    expect(find.text('Bạn có phiên học đang dở'), findsOneWidget);
    expect(find.textContaining('Hàm số'), findsOneWidget);
    expect(find.textContaining('còn 12 phút'), findsOneWidget);
  });

  testWidgets('đang nghỉ → nhãn "Đang nghỉ"', (tester) async {
    await pump(tester, session(isBreak: true));
    expect(find.textContaining('Đang nghỉ'), findsOneWidget);
  });

  testWidgets('bấm "Tiếp tục" → gọi callback', (tester) async {
    var resumed = 0;
    await pump(tester, session(), onResume: () => resumed++);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    expect(resumed, 1);
  });

  testWidgets('không có tên việc → lấy tên môn', (tester) async {
    await pump(tester, session(title: null));
    expect(find.textContaining('Toán'), findsOneWidget);
  });
}
