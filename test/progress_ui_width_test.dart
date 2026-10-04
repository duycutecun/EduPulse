import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/exam_repository.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/progress/presentation/screens/progress_screen.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/models/task_state.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// QA — Kiểm thử bề rộng màn Tiến độ (FE-5.1/FE-5.2).
///
/// Lần trước header thẻ "Nhận định tiến độ" tràn 50px ở 390px khi *có* AI
/// insight. Test cũ chỉ đi qua tab Tiến độ với dữ liệu **rỗng**, nên không bắt
/// được lỗi đó. Ở đây nạp dữ liệu thật (nhiều môn, môn bỏ quên, kỳ thi) rồi
/// render ở loạt bề rộng mobile — mọi overflow sẽ ném lỗi và bị bắt bởi
/// `takeException`.
void main() {
  // Thứ Tư 18/03/2026 — tuần bắt đầu Thứ Hai 16/03.
  final now = DateTime(2026, 3, 18, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Future<void> seedSession(
    DateTime at, {
    required String subject,
    required int minutes,
  }) {
    return StudySessionRepository.instance.save(StudySession(
      id: 's-${at.microsecondsSinceEpoch}-$subject',
      completedAt: at,
      subject: subject,
      plannedMinutes: minutes,
      actualMinutes: minutes,
    ));
  }

  Future<void> seedData() async {
    // Nhiều môn trong tuần — có môn tên dài để thử co giãn dòng.
    await seedSession(DateTime(2026, 3, 16, 19, 0),
        subject: '📐 Toán', minutes: 120);
    await seedSession(DateTime(2026, 3, 17, 19, 0),
        subject: '🧪 Hóa học', minutes: 90);
    await seedSession(DateTime(2026, 3, 18, 8, 0),
        subject: '📖 Ngữ văn', minutes: 45);
    // Tuần trước — để có chỉ số so sánh (delta).
    await seedSession(DateTime(2026, 3, 10, 19, 0),
        subject: '📐 Toán', minutes: 60);
    // Môn bỏ quên: học cách đây 12 ngày → hiện banner cảnh báo.
    await seedSession(DateTime(2026, 3, 6, 19, 0),
        subject: '🌍 Tiếng Anh', minutes: 40);

    // Kỳ thi chính để hiện thẻ đếm ngược.
    final exam = ExamModel(
      id: 'exam-1',
      name: 'Kỳ thi tốt nghiệp THPT',
      dateTime: DateTime(2026, 6, 26, 7, 30),
      type: ExamType.custom,
      emoji: '🎓',
    );
    ExamRepository.instance.save(exam);
    ExamRepository.instance.setPrimary(exam.id);

    // Vài nhiệm vụ để có tỉ lệ hoàn thành theo môn.
    TaskRepository.instance.createTask(TodayTask(
      id: 't1',
      title: 'Hàm số',
      subject: '📐 Toán',
      status: TaskStatus.completed.name,
      scheduledAt: DateTime(2026, 3, 16),
    ));
  }

  Widget host({double textScale = 1.0}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: ProgressScreen(clock: () => now)),
      ),
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    double width, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(textScale: textScale));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Mọi khối chính của màn Tiến độ đều phải render và không tràn.
  void expectNoOverflow(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(find.text('Tuần này'), findsOneWidget);
    expect(find.text('Tiến độ theo môn'), findsOneWidget);
    expect(find.text('Nhận định tiến độ'), findsOneWidget);
  }

  for (final width in <double>[320, 360, 390, 414, 480, 768]) {
    testWidgets('có dữ liệu đầy đủ — không tràn ở ${width.toInt()}px',
        (tester) async {
      await seedData();
      await pumpAt(tester, width);
      expectNoOverflow(tester);
    });
  }

  testWidgets('chịu được mức chữ lớn (1.3x) ở 320px', (tester) async {
    await seedData();
    await pumpAt(tester, 320, textScale: 1.3);
    expectNoOverflow(tester);
  });

  testWidgets('chịu được mức chữ lớn nhất (1.4x) ở 390px', (tester) async {
    await seedData();
    await pumpAt(tester, 390, textScale: 1.4);
    expectNoOverflow(tester);
  });

  testWidgets('tuần trắng ở 320px — vẫn không tràn', (tester) async {
    await pumpAt(tester, 320);
    expect(tester.takeException(), isNull);
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(find.text('Nhận định tiến độ'), findsOneWidget);
  });
}
