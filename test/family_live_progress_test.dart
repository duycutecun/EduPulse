import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/weekly_report.dart';
import 'package:edupulse/core/family/family_models.dart';
import 'package:edupulse/core/family/family_notify_service.dart';
import 'package:edupulse/core/family/family_service.dart';
import 'package:edupulse/core/family/live_progress_service.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/family/presentation/screens/child_report_screen.dart';

/// "Cập nhật trực tiếp" — ba mẹ thấy tiến độ liên tục, không phải chờ con bấm
/// gửi, mà vẫn đúng giao kèo "Cửa sổ tin cậy":
/// 1. Chỉ những mục con BẬT mới đi lên cloud — kể cả bản cập nhật liên tục.
/// 2. Con tắt công tắc là bản trực tiếp bị xoá (ba mẹ không thấy bản cũ).
/// 3. Màn ba mẹ tự cập nhật: tín hiệu Realtime kéo ngay, nhịp hỏi 30 giây là
///    lưới an toàn khi tín hiệu không tới.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  tearDown(() {
    FamilyService.debugProgressFetcher = null;
    FamilyService.stopLive();
    FamilyNotifyService.debugShow = null;
  });

  WeeklyReportData sampleLive() => WeeklyReportData(
        headline: 'Tuần này con đã tập trung 120 phút trong 3 ngày.',
        items: const [
          ReportItem(
              key: 'study_time',
              title: 'Thời gian tập trung',
              value: '120 phút',
              detail: 'Học 3 ngày trong tuần'),
        ],
        from: DateTime(2026, 10, 5),
        to: DateTime(2026, 10, 11),
        generatedAt: DateTime(2026, 10, 10, 8),
      );

  SharedReport liveShared({int at = 1760000000000}) => SharedReport(
        id: 'live',
        studentName: 'Minh',
        createdAt: DateTime.fromMillisecondsSinceEpoch(at),
        report: sampleLive(),
      );

  group('Đọc gói tiến độ của con', () {
    test('có cả trạng thái trực tiếp lẫn báo cáo tuần', () {
      final progress = ChildProgress.fromJson({
        'ok': true,
        'serverTime': 1760000500000,
        'live': {
          'studentName': 'Minh',
          'updatedAt': 1760000000000,
          'payload': sampleLive().toJson(),
        },
        'reports': [
          {
            'id': 'r1',
            'studentName': 'Minh',
            'createdAt': 1759990000000,
            'payload': sampleLive().toJson(),
          }
        ],
      });

      expect(progress, isNotNull);
      expect(progress!.live, isNotNull);
      expect(progress.live!.id, 'live');
      expect(progress.live!.report?.items.single.title, 'Thời gian tập trung');
      expect(progress.reports.single.id, 'r1');
      expect(progress.serverTime, DateTime.fromMillisecondsSinceEpoch(1760000500000));
      expect(progress.isEmpty, isFalse);
    });

    test('bản trực tiếp hỏng/không có mục → bỏ, không hiện thẻ rỗng', () {
      expect(ChildProgress.fromJson({'live': null})!.live, isNull);
      expect(ChildProgress.fromJson({'live': 'x'})!.live, isNull);
      final empty = ChildProgress.fromJson({
        'live': {'updatedAt': 1, 'payload': {'items': []}},
      });
      expect(empty!.live, isNull, reason: 'không có mục nào thì không có gì để hiện');
      expect(empty.isEmpty, isTrue);
    });

    test('đọc từ chối dữ liệu không phải map', () {
      expect(ChildProgress.fromJson(null), isNull);
      expect(ChildProgress.fromJson('không phải map'), isNull);
    });
  });

  group('Bản cập nhật trực tiếp chỉ mang mục con đã bật', () {
    test('mục con TẮT không lọt vào payload lên cloud', () {
      // Con chỉ bật thời gian học: dù máy có dữ liệu điểm thi thử, payload
      // gửi ba mẹ cũng không được chứa mục đó.
      final report = WeeklyReport.build(enabled: {
        'study_time': true,
        'readiness': false,
        'mock_score': false,
        'exam_countdown': false,
      });
      expect(report, isNotNull);
      final keys = report!.items.map((i) => i.key).toList();
      expect(keys, ['study_time']);

      final json = report.toJson();
      final encoded = json.toString();
      expect(encoded, isNot(contains('readiness')));
      expect(encoded, isNot(contains('mock_score')));
      expect(encoded, isNot(contains('exam_countdown')));
    });

    test('tắt hết mục → không có gì để đẩy lên', () {
      final report = WeeklyReport.build(enabled: {
        'study_time': false,
        'readiness': false,
        'mock_score': false,
        'exam_countdown': false,
      });
      expect(report, isNull);
    });
  });

  group('Vân tay nội dung — chỉ đẩy khi thật sự đổi', () {
    test('khác mốc thời gian nhưng cùng nội dung → cùng vân tay', () {
      final a = sampleLive();
      final b = WeeklyReportData(
        headline: a.headline,
        items: a.items,
        from: a.from,
        to: a.to,
        // Báo cáo dựng lại lúc nào cũng có generatedAt mới.
        generatedAt: DateTime(2026, 10, 10, 21, 45),
      );
      expect(LiveProgressService.fingerprintOf(a),
          LiveProgressService.fingerprintOf(b));
    });

    test('số liệu đổi → vân tay đổi (để nhịp sau đẩy tiếp)', () {
      final a = sampleLive();
      final b = WeeklyReportData(
        headline: a.headline,
        items: const [
          ReportItem(
              key: 'study_time',
              title: 'Thời gian tập trung',
              value: '180 phút',
              detail: 'Học 4 ngày trong tuần'),
        ],
        from: a.from,
        to: a.to,
        generatedAt: a.generatedAt,
      );
      expect(LiveProgressService.fingerprintOf(a),
          isNot(LiveProgressService.fingerprintOf(b)));
    });
  });

  group('Công tắc của con', () {
    test('mặc định BẬT — ba mẹ đồng hành cùng con', () {
      expect(LiveProgressService.enabled, isTrue);
    });

    test('bật rồi tắt: nhớ lựa chọn và quên vân tay (bật lại phải gửi mới)',
        () async {
      StorageService.setString('family_live_fingerprint', 'vân-tay-cũ');

      final off = await LiveProgressService.setEnabled(false);
      expect(off, isTrue, reason: 'chưa đăng nhập thì không cần gọi mạng');
      expect(LiveProgressService.enabled, isFalse);
      expect(StorageService.getString('family_live_fingerprint'), isNull);

      StorageService.setBool('family_live_share', true);
      expect(LiveProgressService.enabled, isTrue);
    });
  });

  group('Tín hiệu Realtime', () {
    test('bỏ qua tín hiệu cũ hoặc trùng, chỉ kéo khi mới hơn', () {
      FamilyService.stopLive();
      FamilyService.debugProgressFetcher = null;
      // Chưa biết mốc nào ⇒ tín hiệu đầu tiên luôn đáng để kéo.
      expect(FamilyService.shouldPullOnSignal(100), isTrue);
      expect(FamilyService.shouldPullOnSignal(0), isFalse);
    });
  });

  group('Thành viên gia đình biết con đang cập nhật trực tiếp', () {
    test('liveAt → isLive, và mốc báo cáo vẫn đọc được', () {
      final child = FamilyMember.fromJson({
        'linkId': 'l1',
        'userId': 's1',
        'name': 'Minh',
        'latestReportAt': 1760000000000,
        'liveAt': 1760003000000,
      });
      expect(child!.isLive, isTrue);
      expect(child.hasReport, isTrue);

      final quiet = FamilyMember.fromJson({
        'linkId': 'l2',
        'userId': 's2',
        'name': 'An',
      });
      expect(quiet!.isLive, isFalse,
          reason: 'chưa bật thì không được coi là đang theo dõi');
    });

    test('trạng thái gia đình giữ kênh Realtime server trả về', () {
      final state = FamilyState.fromJson({
        'children': [
          {'linkId': 'l1', 'userId': 's1', 'name': 'Minh', 'liveAt': 5}
        ],
        'topic': 'abc123',
      });
      expect(state.topic, 'abc123');
      expect(state.children.single.isLive, isTrue);
      expect(FamilyState.fromJson({'children': []}).topic, isNull);
    });
  });

  group('Thông báo cho ba mẹ khi con cập nhật', () {
    FamilyState stateWith({
      int? liveAt,
      int? latestReportAt,
      String name = 'Minh',
    }) =>
        FamilyState(
          children: [
            FamilyMember(
              linkId: 'l1',
              userId: 's1',
              name: name,
              liveAt: liveAt == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(liveAt),
              latestReportAt: latestReportAt == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(latestReportAt),
            ),
          ],
        );

    test('lần đầu thấy con thì chỉ ghi nhớ, không dội thông báo', () async {
      StorageService.setBool(FamilyNotifyService.enabledKey, true);
      final shown = <String>[];
      FamilyNotifyService.debugShow =
          ({required String title, required String body}) async {
        shown.add(body);
        return true;
      };

      await FamilyNotifyService.handleState(stateWith(liveAt: 1760000000000));
      expect(shown, isEmpty);
      expect(StorageService.getString(FamilyNotifyService.seenKey), isNotNull);
    });

    test('con cập nhật mới → báo đúng tên con, và không báo lại lần hai',
        () async {
      StorageService.setBool(FamilyNotifyService.enabledKey, true);
      StorageService.setString(FamilyNotifyService.seenKey, '{"s1":100}');
      final shown = <String>[];
      FamilyNotifyService.debugShow =
          ({required String title, required String body}) async {
        shown.add(body);
        return true;
      };

      await FamilyNotifyService.handleState(stateWith(liveAt: 1760000000000));
      expect(shown.length, 1);
      expect(shown.single, contains('Minh'));
      expect(shown.single, contains('cập nhật mới'));

      // Cùng mốc đó đọc lại (nhịp hỏi định kỳ) → không báo thêm.
      await FamilyNotifyService.handleState(stateWith(liveAt: 1760000000000));
      expect(shown.length, 1);
    });

    test('báo cáo tuần mới thì nói đúng là báo cáo tuần', () async {
      StorageService.setBool(FamilyNotifyService.enabledKey, true);
      StorageService.setString(FamilyNotifyService.seenKey, '{"s1":100}');
      final shown = <String>[];
      FamilyNotifyService.debugShow =
          ({required String title, required String body}) async {
        shown.add(body);
        return true;
      };

      await FamilyNotifyService.handleState(stateWith(latestReportAt: 1760000000000));
      expect(shown.single, contains('báo cáo tuần'));
    });

    test('chưa bật thì không báo và không ghi mốc', () async {
      final shown = <String>[];
      FamilyNotifyService.debugShow =
          ({required String title, required String body}) async {
        shown.add(body);
        return true;
      };

      await FamilyNotifyService.handleState(stateWith(liveAt: 1760000000000));
      expect(shown, isEmpty);
      expect(StorageService.getString(FamilyNotifyService.seenKey), isNull);
      expect(FamilyNotifyService.enabled, isFalse);
    });
  });

  group('Màn ba mẹ tự cập nhật', () {
    Future<void> pumpScreen(WidgetTester tester, FamilyMember child) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChildReportScreen(child: child),
      ));
      await tester.pump();
      await tester.pump();
    }

    const child = FamilyMember(
      linkId: 'l1',
      userId: 's1',
      name: 'Minh',
    );

    testWidgets('con bật → thẻ "CẬP NHẬT TRỰC TIẾP" hiện và tự thêm báo cáo mới',
        (tester) async {
      final calls = <int>[];
      var first = true;
      const oldReportAt = 1760000000000;
      FamilyService.debugProgressFetcher = (userId, since) async {
        calls.add(since);
        final initial = first;
        first = false;
        return ChildProgress(
          live: liveShared(),
          // Lần đầu trả đủ trang; nhịp sau chỉ trả phần mới hơn `since` — đúng
          // cách server lọc `since`.
          reports: initial
              ? [
                  SharedReport(
                    id: 'r-old',
                    studentName: 'Minh',
                    createdAt: DateTime.fromMillisecondsSinceEpoch(oldReportAt),
                    report: sampleLive(),
                  ),
                ]
              : [
                  SharedReport(
                    id: 'r-new',
                    studentName: 'Minh',
                    createdAt: DateTime.fromMillisecondsSinceEpoch(
                        oldReportAt + 60000),
                    report: sampleLive(),
                  ),
                ],
        );
      };

      await pumpScreen(tester, child);
      expect(find.byKey(const Key('child-live-card')), findsOneWidget);
      expect(find.text('CẬP NHẬT TRỰC TIẾP'), findsOneWidget);
      expect(find.textContaining('Cập nhật lúc'), findsOneWidget);
      expect(find.text('Trực tiếp'), findsOneWidget);
      expect(find.byKey(const Key('child-report-r-old')), findsOneWidget);
      expect(find.byKey(const Key('child-report-r-new')), findsNothing);

      // Ba mẹ không bấm gì: chỉ đợi hết nhịp hỏi, báo cáo mới tự xuất hiện.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(calls.length, greaterThanOrEqualTo(2));
      expect(calls[0], 0, reason: 'lần đầu lấy đủ trang');
      expect(calls[1], oldReportAt,
          reason: 'nhịp sau chỉ hỏi phần mới hơn báo cáo đang có');
      expect(find.byKey(const Key('child-report-r-new')), findsOneWidget);
      expect(find.byKey(const Key('child-report-r-old')), findsOneWidget);

      // Dọn widget để timer định kỳ được huỷ trong `dispose`.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con chưa có dữ liệu → nói thật, không hiện thẻ trực tiếp',
        (tester) async {
      FamilyService.debugProgressFetcher = (userId, since) async =>
          const ChildProgress();

      await pumpScreen(tester, child);
      expect(find.byKey(const Key('child-live-card')), findsNothing);
      expect(find.byKey(const Key('child-no-live-card')), findsOneWidget);
      expect(find.text('Con chưa có tiến độ trực tiếp'), findsOneWidget);
      expect(find.text('Trực tiếp'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('mất mạng → giữ trạng thái cũ và nói chưa kết nối được',
        (tester) async {
      FamilyService.debugProgressFetcher = (userId, since) async => null;

      await pumpScreen(tester, child);
      expect(find.textContaining('Chưa kết nối được máy chủ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
