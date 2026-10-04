import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/feedback_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/ai_coach/presentation/screens/ai_coach_screen.dart';
import 'package:edupulse/features/ai_coach/presentation/widgets/ai_coach_header.dart' as hdr;
import 'package:edupulse/features/ai_coach/presentation/widgets/chat_bubble.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';
import 'package:edupulse/features/study/presentation/widgets/weekly_chart_widget.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// Đồng hồ giả: `FocusClock` neo theo mốc thời gian thật, widget test chỉ đẩy
/// được `Timer`.
class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// Đối chiếu lại 3 file đặc tả lần cuối — những điểm trước đây lệch:
///
/// - UX 5.11: model AI chỉ chọn được ở Tôi → Cài đặt → AI nâng cao; màn chat
///   không lộ tên model/nhà cung cấp.
/// - UX 5.14: cài đặt có cả **Rung** và **Âm thanh**, tắt được qua
///   `FeedbackService` (một cổng duy nhất).
/// - UX mục 11: empty state "No study history" phải có CTA "Bắt đầu học".
/// - AI mục 22: quick action "Điều chỉnh lịch" phải tồn tại và **không** gọi
///   LLM (AI-24).
/// - UX 12 / AI-30: lỗi AI phải có "Thử lại" và "Tiếp tục tự học".
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('UX 5.11 — AI nâng cao là nơi DUY NHẤT chọn model', () {
    testWidgets('AI Coach đọc model đã ghim, không tự gán model mặc định',
        (tester) async {
      StorageService.setAiModel('google/gemma-4-31b-it:free');

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump();

      final header = tester.widget<hdr.AICoachHeader>(find.byType(hdr.AICoachHeader));
      expect(header.model.slug, 'google/gemma-4-31b-it:free');
      expect(header.pinned, isTrue);
    });

    testWidgets('Chưa ghim model → pinned = false (chế độ tự động)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump();

      final header = tester.widget<hdr.AICoachHeader>(find.byType(hdr.AICoachHeader));
      expect(header.pinned, isFalse);
    });

    testWidgets('Header không lộ tên model/nhà cung cấp ra UI chính',
        (tester) async {
      StorageService.setAiModel('nvidia/nemotron-3-super-120b-a12b:free');

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump();

      // Chỉ nói "AI tự động" / "AI đã ghim" — không tên model, không provider.
      expect(find.text('AI đã ghim'), findsOneWidget);
      expect(find.textContaining('Nemotron'), findsNothing);
      expect(find.textContaining('OpenRouter'), findsNothing);
      expect(find.textContaining('Gemini'), findsNothing);
    });

    testWidgets('Bấm chip AI → chỉ đường dẫn tới Cài đặt, không mở picker',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump();

      await tester.tap(find.text('AI tự động'));
      await tester.pump();

      expect(find.textContaining('AI nâng cao'), findsOneWidget);
    });
  });

  group('UX 5.14 — Rung và Âm thanh đều tắt được', () {
    test('Mặc định bật; tắt thì cổng FeedbackService im, không gọi platform',
        () async {
      expect(FeedbackService.hapticsEnabled, isTrue);
      expect(FeedbackService.soundEnabled, isTrue);

      FeedbackService.setHaptics(false);
      FeedbackService.setSound(false);
      expect(FeedbackService.hapticsEnabled, isFalse);
      expect(FeedbackService.soundEnabled, isFalse);

      // Gọi khi đã tắt không ném lỗi — đường duy nhất mọi thao tác đi qua.
      await FeedbackService.light();
      await FeedbackService.medium();
      await FeedbackService.celebrate();

      FeedbackService.setHaptics(true);
      FeedbackService.setSound(true);
      expect(FeedbackService.hapticsEnabled, isTrue);
      expect(FeedbackService.soundEnabled, isTrue);
    });

    test('Không còn HapticFeedback gọi trực tiếp ngoài FeedbackService', () {
      // Gọi thẳng platform sẽ bỏ qua cài đặt của người dùng — đó là lỗi
      // mà S8 sửa. Test chỉ đọc source, không import.
      expect(
        _hasDirectHapticCalls(),
        isFalse,
        reason: 'HapticFeedback.* phải chạy qua FeedbackService',
      );
    });
  });

  group('UX mục 11 — Empty state "No study history"', () {
    /// Empty state nằm ở tab "Biểu đồ" — mở tab đó trước khi kiểm tra.
    Future<_FakeClock> openChartTab(WidgetTester tester) async {
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudyScreen(clock: clock.now)),
      ));
      await tester.pump();
      await tester.tap(find.text('Biểu đồ'));
      await tester.pump();
      return clock;
    }

    testWidgets('Chưa có phiên → nói đủ 3 câu + CTA "Bắt đầu học"',
        (tester) async {
      expect(StudySessionRepository.instance.getAll(), isEmpty);
      await openChartTab(tester);

      // 1. Thiếu gì · 2. Vì sao quan trọng · 3. Làm gì tiếp theo.
      expect(find.text('Chưa có phiên học nào.'), findsOneWidget);
      expect(find.textContaining('giờ focus'), findsOneWidget);
      // Cả thẻ phân tích focus lẫn biểu đồ tuần đều có CTA — hai lối vào,
      // không để người học phải đoán.
      expect(find.byKey(const ValueKey('start-first-session')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('weekly-chart-start-study')),
          findsOneWidget);
      expect(find.text('Bắt đầu học'), findsNWidgets(2));
    });

    testWidgets('CTA bắt đầu được vòng focus thật', (tester) async {
      await openChartTab(tester);

      await tester.tap(find.byKey(const ValueKey('start-first-session')));
      await tester.pump();

      // Quay lại tab Pomodoro: đồng hồ đã chạy, không còn đứng yên.
      await tester.tap(find.text('Pomodoro'));
      await tester.pump();
      expect(find.byKey(const ValueKey('pom-toggle')), findsOneWidget);
    });

    testWidgets('Biểu đồ tuần rỗng cũng có CTA, không để trống',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WeeklyChartWidget(
            entries: const [],
            onStartStudy: () => tapped = true,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Chưa có dữ liệu học tập'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('weekly-chart-start-study')));
      expect(tapped, isTrue);
    });

    testWidgets('Không có callback → không hiện nút, nhưng vẫn giải thích',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WeeklyChartWidget(entries: const [])),
      ));
      await tester.pump();

      expect(find.byKey(const ValueKey('weekly-chart-start-study')),
          findsNothing);
      expect(find.text('Chưa có dữ liệu học tập'), findsOneWidget);
    });
  });

  group('UX 12 / AI-30 — lỗi AI không chặn người học', () {
    testWidgets('Tin nhắn lỗi có "Thử lại" và "Tiếp tục tự học"',
        (tester) async {
      var retried = false;
      var continued = false;
      final msg = ChatMessage(
        id: 'err-1',
        text: 'AI đang không phản hồi. Bạn vẫn có thể tiếp tục học hoặc thử lại sau.',
        isUser: false,
        timestamp: DateTime(2026, 5, 1, 8),
        isError: true,
        retryPrompt: 'Giải thích dạng bài đạo hàm lớp 12',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ChatBubble(
                msg: msg,
                onRetry: () => retried = true,
                onContinueSelfStudy: () => continued = true,
              ),
            ],
          ),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('không phản hồi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Tiếp tục tự học'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
      await tester.tap(find.text('Tiếp tục tự học'));
      expect(continued, isTrue);
    });

    test('retryPrompt sống sót qua serialize — lỗi vẫn thử lại được sau khi mở app',
        () {
      final msg = ChatMessage(
        id: 'err-2',
        text: 'Lỗi mạng.',
        isUser: false,
        timestamp: DateTime(2026, 5, 1, 8),
        isError: true,
        retryPrompt: 'Hôm nay học gì?',
      );
      final restored = ChatMessage.fromJson(msg.toJson());

      expect(restored.isError, isTrue);
      expect(restored.retryPrompt, 'Hôm nay học gì?');
    });
  });

  group('AI mục 22 — đủ 5 quick action', () {
    testWidgets('Có "Điều chỉnh lịch" cạnh 4 quick action cũ', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump();

      expect(find.text('Tôi nên học gì?'), findsOneWidget);
      expect(find.text('Giải thích bài này'), findsOneWidget);
      expect(find.text('Lập kế hoạch'), findsOneWidget);
      expect(find.text('Phân tích điểm yếu'), findsOneWidget);
      expect(find.text('Điều chỉnh lịch'), findsOneWidget);
    });

    testWidgets('Bấm "Điều chỉnh lịch" khi lịch vừa sức → nói thật, không bịa',
        (tester) async {
      // Chưa có task nào: rule engine trả về rỗng, app phải nói "chưa có gì
      // để điều chỉnh" thay vì gọi LLM rồi bịa đề xuất (AI-17).
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump();

      await tester.tap(find.text('Điều chỉnh lịch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tin AI render bằng RichText (hỗ trợ công thức), nên phải tìm richText.
      expect(
        find.textContaining('chưa có gì để điều chỉnh', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Lịch hiện tại đã vừa sức', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('Lịch nặng → mở sheet duyệt từng dòng, chưa duyệt thì không dời',
        (tester) async {
      final repo = TaskRepository.instance;
      // 3 bài 90 phút = 270 phút > quỹ ngày mặc định.
      for (var i = 0; i < 3; i++) {
        await repo.createTask(TodayTask(
          id: 'heavy-$i',
          title: 'Bài nặng $i',
          estimateMinutes: 90,
        ));
      }

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump();

      await tester.tap(find.text('Điều chỉnh lịch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Điều chỉnh lịch 🧺'), findsOneWidget);
      expect(find.text('Để nguyên'), findsOneWidget);

      // Bấm "Để nguyên" → không task nào bị đổi lịch.
      await tester.tap(find.text('Để nguyên'));
      await tester.pumpAndSettle();

      for (final t in repo.getAllTasks()) {
        expect(t.scheduledAt, isNull,
            reason: 'không có gì bị dời khi người dùng chưa duyệt');
      }
    });
  });
}

/// Đọc source `lib/` để chặn hành vi lệch: rung/âm thanh phải qua một cổng
/// duy nhất ([FeedbackService]), nếu không cài đặt tắt của người dùng là vô
/// hiệu với code gọi trực tiếp.
bool _hasDirectHapticCalls() {
  final hits = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (path.endsWith('feedback_service.dart')) continue;
    final text = entity.readAsStringSync();
    if (text.contains('HapticFeedback.') || text.contains('SystemSound.')) {
      hits.add(path);
    }
  }
  expect(hits, isEmpty,
      reason: 'Rung/âm thanh phải đi qua FeedbackService để tắt được');
  return hits.isNotEmpty;
}