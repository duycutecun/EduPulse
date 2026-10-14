import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/home/presentation/widgets/today_mission_card.dart';
import 'package:edupulse/features/ai_coach/presentation/widgets/chat_bubble.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// QA — kích thước vùng chạm (P1-4, đặc tả mục 21).
///
/// Trước đây nhiều control chỉ có vùng chạm 24–40px (nút tròn hoàn thành 24px,
/// các IconButton density compact 40px) nên khó bấm bằng ngón tay. Test này
/// khoá lại ngưỡng tối thiểu 44dp cho các control chính để không tái phát.
void main() {
  void noop() {}
  void noopTask(TodayTask _) {}

  Future<void> pumpTaskCard(
    WidgetTester tester, {
    ValueChanged<TodayTask>? onStartStudy,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TodayMissionCard(
            tasks: [TodayTask(id: 't', title: 'Hàm số', subject: '📐 Toán')],
            onAddTask: noop,
            onToggle: noopTask,
            onDelete: noopTask,
            onSkip: noopTask,
            onReschedule: noopTask,
            onStartStudy: onStartStudy,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  void expectMinTarget(WidgetTester tester, Finder finder, {double min = 44}) {
    final size = tester.getSize(finder);
    expect(size.width, greaterThanOrEqualTo(min),
        reason: 'vùng chạm rộng ${size.width}px < ${min}px');
    expect(size.height, greaterThanOrEqualTo(min),
        reason: 'vùng chạm cao ${size.height}px < ${min}px');
  }

  /// Nút IconButton chứa tooltip — đo chính nút (gồm cả vùng đệm chạm), không
  /// phải widget Tooltip bên trong (chỉ là phần hình ảnh nhỏ hơn).
  Finder iconButtonWithTooltip(String tooltip) => find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      );

  group('Touch target ≥44dp (P1-4, mục 21)', () {
    testWidgets('Nút tròn đánh dấu hoàn thành đạt ≥44dp', (tester) async {
      await pumpTaskCard(tester);
      expectMinTarget(tester, find.bySemanticsLabel('Đánh dấu hoàn thành'));
    });

    testWidgets('Nút bắt đầu học & menu nhiệm vụ đạt ≥44dp', (tester) async {
      await pumpTaskCard(tester, onStartStudy: noopTask);
      expectMinTarget(tester, iconButtonWithTooltip('Bắt đầu học ngay'));
      expectMinTarget(tester, iconButtonWithTooltip('Tùy chọn nhiệm vụ'));
    });

    testWidgets('Nút phản hồi AI trong ChatBubble đạt ≥44dp', (tester) async {
      final msg = ChatMessage(
        id: 'm1',
        text:
            'Đây là một câu trả lời đủ dài để hiện thanh phản hồi chất lượng.',
        isUser: false,
        timestamp: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ChatBubble(msg: msg)),
      ));
      await tester.pump();
      expectMinTarget(tester, iconButtonWithTooltip('Câu trả lời tốt'));
      expectMinTarget(tester, iconButtonWithTooltip('Câu trả lời chưa tốt'));
      expectMinTarget(tester, iconButtonWithTooltip('Sao chép câu trả lời'));
    });
  });
}
