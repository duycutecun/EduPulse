import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/exam_repository.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/core/utils/supabase_service.dart';

/// Chốt lỗi nghiêm trọng: xoá kỳ thi KHÔNG được đẩy lên cloud.
///
/// `syncExams` chỉ upsert danh sách **đang có**, nên khoá bản ghi đã xoá ở
/// máy vẫn nằm trên cloud. Bấm "Khôi phục" là kỳ thi **quay lại** — người
/// dùng tưởng đã xoá sạch, thực ra chưa.
///
/// Nguyên nhân gốc: với UPSERT, lần sync sau tự suy ra được phải gửi gì. Với
/// XOÁ thì không — phải nhớ ý định xoá trong một hàng đợi cho tới khi nổi
/// lên thành công.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_name': 'Minh'});
    await StorageService.init();
  });

  ExamModel exam(String id) => ExamModel(
        id: id,
        name: 'Kỳ thi $id',
        dateTime: DateTime.now().add(const Duration(days: 30)),
      );

  group('Xoá kỳ thi — phải nhớ để đẩy lên cloud', () {
    test('xoá xong id được ghi vào hàng đợi chờ', () {
      final repo = ExamRepository.instance;
      repo.save(exam('e-del'));
      expect(repo.getById('e-del'), isNotNull);

      repo.delete('e-del');

      // Xoá khỏi máy ngay…
      expect(repo.getById('e-del'), isNull);
      // …nhưng ý định xoá phải còn lại để đẩy lên cloud sau.
      expect(StorageService.getStringList('exam_pending_deletes'),
          contains('e-del'));
    });

    test('hàng đợi sống qua lần khởi động app (đọc lại từ storage)', () {
      final repo = ExamRepository.instance;
      repo.save(exam('e-offline'));
      repo.delete('e-offline');

      // Giả lập app bị giết rồi mở lại: hàng đợi phải còn nguyên, không
      // được nằm trong RAM.
      expect(StorageService.getStringList('exam_pending_deletes'),
          contains('e-offline'));
    });

    test('xoá cùng id nhiều lần chỉ ghi một lần', () {
      final repo = ExamRepository.instance;
      repo.save(exam('e-dup'));
      repo.delete('e-dup');
      repo.delete('e-dup');
      repo.delete('e-dup');

      final pending =
          StorageService.getStringList('exam_pending_deletes') ?? [];
      expect(pending.where((id) => id == 'e-dup').length, 1,
          reason: 'lặp lại không được nhân bản hàng đợi');
    });

    test('lưu lại sau khi xoá thì gỡ id khỏi hàng đợi', () {
      final repo = ExamRepository.instance;
      repo.save(exam('e-restore'));
      repo.delete('e-restore');
      expect(StorageService.getStringList('exam_pending_deletes'),
          contains('e-restore'));

      // Khôi phục (ví dụ bấm “Hoàn tác”) → không còn ý định xoá.
      repo.save(exam('e-restore'));
      expect(StorageService.getStringList('exam_pending_deletes') ?? [],
          isNot(contains('e-restore')),
          reason: 'đã khôi phục thì không được còn nằm trong hàng đợi xoá');
    });
  });

  group('updatedAt — dấu mốc để phát hiện xung đột', () {
    test('lưu thì đóng dấu mốc thời gian', () {
      final repo = ExamRepository.instance;
      repo.save(exam('e-ts'));

      final saved = repo.getById('e-ts');
      expect(saved, isNotNull);
      expect(saved!.updatedAt, isNotNull,
          reason: 'không có mốc sửa thì không so được với cloud');
    });

    test('mốc thời gian sống sót qua serialize', () {
      final repo = ExamRepository.instance;
      repo.save(exam('e-json'));

      final saved = repo.getById('e-json')!;
      final round = ExamModel.fromJsonString(saved.toJsonString());
      expect(round.updatedAt, isNotNull);
      expect(round.updatedAt!.isAtSameMomentAs(saved.updatedAt!), isTrue);
    });

    test('kỳ thi tạo trước khi có trường này vẫn đọc được (null)', () {
      final legacy = ExamModel.fromJson({
        'id': 'legacy',
        'name': 'Kỳ thi cũ',
        'dateTime': DateTime.now().toIso8601String(),
      });
      expect(legacy.updatedAt, isNull,
          reason:
              'dữ liệu cũ không có mốc — phải đọc được, không được ném lỗi');
      expect(legacy.name, 'Kỳ thi cũ');
    });
  });

  group('Payload đẩy lên cloud có mang dấu mốc', () {
    test('updated_at có trong dòng gửi đi', () {
      final repo = ExamRepository.instance;
      repo.save(exam('e-push'));
      final row = SupabaseService.examRow(repo.getById('e-push')!, null);

      expect(row.containsKey('updated_at'), isTrue);
      expect(row['updated_at'], isNotNull,
          reason:
              'thiếu cột này thì lần khôi phục sau không so được phiên bản');
    });
  });
}
