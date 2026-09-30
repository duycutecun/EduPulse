import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/ai/ai_insights.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/home/presentation/widgets/ai_suggestion_card.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  void writeCache(List<AiInsight> items) {
    final bundle = AiInsightBundle(
      items: items,
      generatedAt: DateTime.now(),
    );
    StorageService.setString('ai_insights_v1', jsonEncode(bundle.toJson()));
    StorageService.setString(
        'ai_insights_time_v1', bundle.generatedAt.toIso8601String());
  }

  Widget host({
    required String fallback,
    VoidCallback? onAskAi,
    ValueChanged<String>? onOpenInsight,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: AiSuggestionCard(
          fallback: fallback,
          onAskAi: onAskAi ?? () {},
          onOpenInsight: onOpenInsight,
        ),
      ),
    );
  }

  testWidgets('chưa có phân tích → hiện gợi ý quy tắc dự phòng',
      (tester) async {
    await tester.pumpWidget(host(fallback: 'Hãy bắt đầu một phiên Focus.'));

    expect(find.text('Gợi ý cho bạn'), findsOneWidget);
    expect(find.text('Hãy bắt đầu một phiên Focus.'), findsOneWidget);
    // Nút làm mới vẫn hiện để học sinh mới kích hoạt lần phân tích đầu.
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.text('Hỏi AI Coach'), findsOneWidget);
  });

  testWidgets('có cache → hiện gợi ý AI kèm bằng chứng', (tester) async {
    writeCache(const [
      AiInsight(
        text: 'Dồn buổi ôn Hóa tối nay',
        evidence: 'Hóa TB 6.0/10, thấp hơn Toán 1.5 điểm',
      ),
      AiInsight(text: 'Chia nhỏ bài tích phân thành 3 phần'),
    ]);

    await tester.pumpWidget(host(fallback: 'fallback không dùng'));

    expect(find.text('AI nghĩ bạn nên làm'), findsOneWidget);
    expect(find.text('Dồn buổi ôn Hóa tối nay'), findsOneWidget);
    expect(find.text('Hóa TB 6.0/10, thấp hơn Toán 1.5 điểm'), findsOneWidget);
    expect(find.text('Chia nhỏ bài tích phân thành 3 phần'), findsOneWidget);
    expect(find.text('Bấm gợi ý để hỏi tiếp'), findsOneWidget);
    // Fallback không được lọt lên.
    expect(find.text('fallback không dùng'), findsNothing);
  });

  testWidgets('bấm gợi ý → truyền đúng nội dung ra ngoài', (tester) async {
    writeCache(const [
      AiInsight(text: 'Dồn buổi ôn Hóa tối nay', evidence: 'Hóa TB 6.0/10'),
    ]);

    String? opened;
    var askAiCount = 0;
    await tester.pumpWidget(host(
      fallback: 'x',
      onAskAi: () => askAiCount++,
      onOpenInsight: (p) => opened = p,
    ));

    await tester.tap(find.text('Dồn buổi ôn Hóa tối nay'));
    await tester.pump();

    expect(opened, 'Dồn buổi ôn Hóa tối nay');
    // Bấm gợi ý thì không được mở chat trống.
    expect(askAiCount, 0);
  });

  testWidgets('không có callback gợi ý → quay về mở chat thường',
      (tester) async {
    writeCache(const [AiInsight(text: 'Ôn Hóa tối nay')]);

    var askAiCount = 0;
    await tester.pumpWidget(host(fallback: 'x', onAskAi: () => askAiCount++));

    await tester.tap(find.text('Ôn Hóa tối nay'));
    await tester.pump();
    expect(askAiCount, 1);
  });

  testWidgets('card cập nhật khi có phân tích mới được ghi vào cache',
      (tester) async {
    await tester.pumpWidget(host(fallback: 'chưa có gợi ý AI'));
    expect(find.text('chưa có gợi ý AI'), findsOneWidget);

    // Mô phỏng phân tích nền trong main.dart vừa ghi xong cache.
    writeCache(const [AiInsight(text: 'Ôn Toán trước', evidence: 'Toán 2.5h')]);
    AiInsights.revision.value += 1;
    await tester.pump();

    expect(find.text('AI nghĩ bạn nên làm'), findsOneWidget);
    expect(find.text('Ôn Toán trước'), findsOneWidget);
  });

  testWidgets('cache hết hạn → hiện lại gợi ý quy tắc', (tester) async {
    final bundle = AiInsightBundle(
      items: const [AiInsight(text: 'Ôn Toán trước')],
      generatedAt: DateTime.now().subtract(const Duration(hours: 9)),
    );
    StorageService.setString('ai_insights_v1', jsonEncode(bundle.toJson()));
    StorageService.setString(
        'ai_insights_time_v1', bundle.generatedAt.toIso8601String());

    await tester.pumpWidget(host(fallback: 'gợi ý quy tắc'));
    expect(find.text('gợi ý quy tắc'), findsOneWidget);
    expect(find.text('Ôn Toán trước'), findsNothing);
  });

  testWidgets('card không gọi mạng khi dựng (không chặn Home)', (tester) async {
    // Không seed gì: nếu card gọi model trong initState thì sẽ còn timer
    // pending lúc teardown và test fail.
    await tester.pumpWidget(host(fallback: 'gợi ý quy tắc'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('gợi ý quy tắc'), findsOneWidget);
  });

  testWidgets('tắt quyền phân tích → không dùng cache, hiện gợi ý quy tắc',
      (tester) async {
    writeCache(const [AiInsight(text: 'Ôn Toán trước')]);
    StorageService.setBool('ai_permission_analyze', false);

    await tester.pumpWidget(host(fallback: 'gợi ý quy tắc'));
    expect(find.text('gợi ý quy tắc'), findsOneWidget);
    expect(find.text('Ôn Toán trước'), findsNothing);
  });
}
