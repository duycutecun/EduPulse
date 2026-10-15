// Test chống MẤT DỮ LIỆU khi sửa ghi chú đã có: bấm back/gesture mà chưa lưu
// phải hiện hộp thoại hỏi (Lưu / Bỏ thay đổi / Ở lại) thay vì đóng âm thầm.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/notes/presentation/widgets/note_editor_view.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudyNote baseNote;

  /// Kết quả editor trả về (ghi trong onPressed của nút mở).
  StudyNote? pushedResult;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    pushedResult = null;
    final now = DateTime(2026, 10, 15, 9);
    baseNote = StudyNote(
      id: 'note-1',
      title: 'Ghi chú gốc',
      body: 'nội dung gốc',
      createdAt: now,
      updatedAt: now,
    );
  });

  /// Mở editor qua Navigator.push để bắt được kết quả trả về.
  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                pushedResult = await Navigator.push<StudyNote>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NoteEditorView(note: baseNote)),
                );
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'sửa nội dung rồi back → hỏi thay vì mất âm thầm; chọn Lưu trả '
      'bản mới', (WidgetTester tester) async {
    await openEditor(tester);

    // TextField thứ 3 là phần thân ghi chú (sau tiêu đề và nhãn).
    await tester.enterText(find.byType(TextField).at(2), 'nội dung đã sửa');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Thay đổi chưa lưu'), findsOneWidget,
        reason: 'phải hỏi trước khi đóng');

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Lưu'),
    ));
    await tester.pumpAndSettle();

    expect(pushedResult, isNotNull,
        reason: 'chọn Lưu phải trả ghi chú đã cập nhật');
    expect(pushedResult!.body, 'nội dung đã sửa');
    expect(pushedResult!.id, 'note-1');
    expect(find.byType(NoteEditorView), findsNothing);
  });

  testWidgets('back khi KHÔNG có thay đổi → đóng ngay, không hỏi',
      (WidgetTester tester) async {
    await openEditor(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Thay đổi chưa lưu'), findsNothing);
    expect(find.byType(NoteEditorView), findsNothing);
    expect(pushedResult, isNull, reason: 'không lưu gì thì trả về null');
  });
}
