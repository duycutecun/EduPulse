import 'package:edupulse/core/ai/smart_note_linker.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';

StudyNote note(String id, String title, String body,
        {String? subject, List<String> tags = const []}) =>
    StudyNote(
      id: id,
      title: title,
      body: body,
      subject: subject,
      tags: tags,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  test('prefers notes from the same subject with shared concepts', () {
    final source = note('a', 'Đạo hàm', 'Công thức đạo hàm hàm số',
        subject: 'Toán', tags: ['giải tích']);
    final sameSubject = note(
        'b', 'Tích phân', 'Ôn công thức tích phân và đạo hàm',
        subject: 'Toán');
    final other = note('c', 'Hóa hữu cơ', 'Phản ứng và liên kết hóa học', subject: 'Hóa');

    final links = SmartNoteLinker.relatedTo(source, [sameSubject, other]);

    expect(links, hasLength(1));
    expect(links.single.note.id, 'b');
    expect(links.single.reason, contains('Cùng môn Toán'));
  });

  test('does not link unrelated notes', () {
    final source = note('a', 'Đạo hàm', 'Hàm số giới hạn', subject: 'Toán');
    final unrelated = note(
        'b', 'Cách mạng tháng tám', 'Sự kiện lịch sử Việt Nam',
        subject: 'Sử');

    expect(SmartNoteLinker.relatedTo(source, [unrelated]), isEmpty);
  });
}
