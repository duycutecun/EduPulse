import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/utils/supabase_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';

/// Chốt lỗi mất dữ liệu khi đồng bộ kỳ thi.
///
/// Trước đây `syncExams` chỉ gửi `name/date_time/emoji/type/description/
/// is_primary`. Ba trường còn lại — điểm hiện tại, điểm mục tiêu và mục tiêu
/// theo từng môn — bị bỏ sót, nên **mỗi lần bấm đồng bộ là mất dữ liệu thật**.
///
/// Vì bảng `exams` trên cloud là dữ liệu của chính người dùng và hàm đẩy lên
/// chỉ chạy khi đã cấu hình Supabase, bộ test này kiểm tra **phần dựng dòng**
/// (`examRow`) — nơi quyết định dữ liệu có được gửi đi hay không.
void main() {
  ExamModel full() => ExamModel(
        id: 'e1',
        name: 'Kỳ thi liên khu',
        dateTime: DateTime(2026, 6, 15, 8),
        emoji: '📚',
        description: 'Ghi chú',
        currentScore: 7.5,
        targetScore: 9.0,
        subjectTargets: const {'📐 Toán': 9.0, '🧪 Hóa': 8.5},
      );

  group('Exam sync — không được bỏ sót trường nào', () {
    test('dòng gửi lên có ĐỦ điểm hiện tại / điểm mục tiêu / mục tiêu môn', () {
      final row = SupabaseService.examRow(full(), 'e1');

      expect(row['current_score'], 7.5);
      expect(row['target_score'], 9.0);
      // Trường này là lý do chính của bản sửa.
      expect(row.containsKey('subject_targets'), isTrue,
          reason: 'thiếu khoá này là mất mục tiêu điểm theo môn');
      expect(row['subjects'], isNotEmpty);
    });

    test('subject_targets giữ đúng cả khoá lẫn giá trị sau vòng JSON', () {
      final row = SupabaseService.examRow(full(), null);
      final decoded =
          jsonDecode(row['subject_targets'] as String) as Map<String, dynamic>;

      expect(decoded, {'📐 Toán': 9.0, '🧪 Hóa': 8.5});
    });

    test('kỳ thi không có mục tiêu vẫn gửi khoá rỗng, không được bỏ trường',
        () {
      final row = SupabaseService.examRow(
        ExamModel(
            id: 'e2', name: 'Không mục tiêu', dateTime: DateTime(2026, 1, 1)),
        null,
      );

      expect(row.containsKey('subject_targets'), isTrue);
      expect(row['current_score'], isNull);
      expect(row['target_score'], isNull);
      expect(row['is_primary'], false);
    });

    test('đánh dấu kỳ thi chính đúng theo primaryId', () {
      expect(SupabaseService.examRow(full(), 'e1')['is_primary'], true);
      expect(SupabaseService.examRow(full(), 'khac')['is_primary'], false);
    });

    test('id gửi lên có tiền tố user để nhiều máy không đụng nhau', () {
      final row = SupabaseService.examRow(full(), null);
      expect(row['id'], endsWith('_e1'));
      expect(row['id'], isNot('e1'));
    });
  });
}
