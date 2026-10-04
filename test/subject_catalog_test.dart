import 'package:edupulse/core/constants/subject_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chốt lại tính nhất quán của môn học — Sprint 2 phát hiện `subject` tồn tại
/// hai chuẩn song song (`'📐 Toán'` vs `'Toán'`), làm hỏng mọi `groupBy(subject)`
/// và màu chip ở Sprint 5.
void main() {
  group('AppSubjects danh mục chuẩn', () {
    test('mọi môn trong danh mục là duy nhất (không trùng tên)', () {
      final names = AppSubjects.names;
      expect(names.toSet().length, names.length);
      expect(names, isNotEmpty);
    });

    test('mọi môn đều có plainName khác tên emoji và không rỗng', () {
      for (final subject in AppSubjects.all) {
        expect(subject.name, isNotEmpty, reason: 'name rỗng');
        expect(subject.plainName, isNotEmpty, reason: subject.name);
        expect(
          AppSubjects.stripEmoji(subject.name),
          subject.plainName,
          reason: '${subject.name} → plainName không khớp',
        );
      }
    });

    test('mọi môn đều normalize về chính nó (idempotent)', () {
      for (final subject in AppSubjects.all) {
        expect(AppSubjects.normalize(subject.name), subject.name);
        expect(AppSubjects.normalize(AppSubjects.stripEmoji(subject.name)),
            subject.name);
      }
    });
  });

  group('AppSubjects.normalize — hợp nhất dữ liệu hai thế hệ', () {
    const cases = <String, String>{
      'Toán': '📐 Toán',
      'toán': '📐 Toán',
      'TOÁN': '📐 Toán',
      '📐 Toán': '📐 Toán',
      'Lý': '⚡ Lý',
      'Vật lý': '⚡ Lý',
      'vật lí': '⚡ Lý',
      'Vật Lý': '⚡ Lý',
      'Hóa': '🧪 Hóa',
      'Hoá': '🧪 Hóa',
      'hóa học': '🧪 Hóa',
      'Văn': '📖 Văn',
      'Ngữ văn': '📖 Văn',
      'Anh': '🇬🇧 Anh',
      'Tiếng Anh': '🇬🇧 Anh',
      'tiếng anh': '🇬🇧 Anh',
      'Sinh': '🧬 Sinh',
      'Sinh học': '🧬 Sinh',
      'Sử': '🏛️ Sử',
      'Lịch sử': '🏛️ Sử',
      'Địa': '🗺️ Địa',
      'Địa lý': '🗺️ Địa',
      'GDCD': '⚖️ GDCD',
      'Tin': '💻 Tin',
      'Tin học': '💻 Tin',
      'Khác': '💡 Khác',
    };

    cases.forEach((input, expected) {
      test('"$input" → "$expected"', () {
        expect(AppSubjects.normalize(input), expected);
      });
    });

    test('null / rỗng / toàn khoảng trắng → môn Khác', () {
      expect(AppSubjects.normalize(null), AppSubjects.khac.name);
      expect(AppSubjects.normalize(''), AppSubjects.khac.name);
      expect(AppSubjects.normalize('   '), AppSubjects.khac.name);
    });

    test('môn lạ không bị bịa thành môn khác (giữ nguyên dữ liệu)', () {
      // §10 "No fabricated data": tên lạ phải giữ nguyên để không mất môn.
      expect(AppSubjects.normalize('Lập trình'), 'Lập trình');
      expect(AppSubjects.normalize('🙂 Tuyệt vời'), '🙂 Tuyệt vời');
    });

    test('bỏ dấu đủ cho mọi từ tiếng Việt có dấu', () {
      // Đây là ca hồi quy: thiếu 'ế'/'ậ'/'ấ'… một lần là "Tiếng Anh" và
      // "Vật Lý" hỏng ngầm, người dùng không báo lỗi được.
      const hard = <String, String>{
        'Tiếng Anh': 'tieng anh',
        'Vật Lý': 'vat ly',
        'Luyện tập': 'luyen tap',
        'Giải tích': 'giai tich',
        'Hóa học': 'hoa hoc',
        'Ngữ văn': 'ngu van',
        'Sinh học': 'sinh hoc',
        'Địa lý': 'dia ly',
        'Lịch sử': 'lich su',
        'Nhật ký': 'nhat ky',
        'Đăng ký': 'dang ky',
        'Tuổi': 'tuoi',
        'Ưu tiên': 'uu tien',
        'Phỏng vấn': 'phong van',
        'Tiếng Việt': 'tieng viet',
        'Trắc nghiệm': 'trac nghiem',
        'Bài tập về nhà': 'bai tap ve nha',
      };
      hard.forEach((input, expected) {
        expect(
          AppSubjects.foldDiacritics(input),
          expected,
          reason: '"$input" bỏ dấu sai → môn học sẽ không hợp nhất được',
        );
      });
    });

    test('bỏ dấu bỏ qua hoa thường và khoảng trắng thừa', () {
      expect(AppSubjects.foldDiacritics('  VẬT   LÝ  '), 'vat ly');
      expect(AppSubjects.foldDiacritics('vật lí'), 'vat li');
      expect(AppSubjects.foldDiacritics('Vật\tLý'), 'vat ly');
    });

    test('khớp môn dù gõ cách khác nhau (có/không khoảng trắng, Nam bộ)', () {
      expect(AppSubjects.normalize('vật lí'), '⚡ Lý');
      expect(AppSubjects.normalize('Vật Lý'), '⚡ Lý');
      expect(AppSubjects.normalize('vatly'), '⚡ Lý');
      expect(AppSubjects.normalize('tiếnganh'), '🇬🇧 Anh');
      expect(AppSubjects.normalize('hoá học'), '🧪 Hóa');
    });
  });

  group('AppSubjects — tra cứu hiển thị', () {
    test('find trả về mô tả cho cả hai dạng tên', () {
      expect(AppSubjects.find('Toán')?.plainName, 'Toán');
      expect(AppSubjects.find('📐 Toán')?.plainName, 'Toán');
      expect(AppSubjects.find('Vật lý')?.name, '⚡ Lý');
    });

    test('môn lạ → find null, color/icon fallback về màu chủ đạo', () {
      expect(AppSubjects.find('Lập trình'), isNull);
      expect(AppSubjects.colorOf('Lập trình'), isNotNull);
      expect(AppSubjects.iconOf('Lập trình'), isNotNull);
    });

    test('màu khác nhau giữa hai môn (để chip phân biệt được)', () {
      final colors = AppSubjects.all.map((s) => s.color.toARGB32()).toSet();
      expect(colors.length, AppSubjects.all.length,
          reason: 'phải có màu riêng cho từng môn');
    });
  });

  group('AppSubjects.stripEmoji', () {
    test('bỏ emoji ở đầu và giữ lại chữ', () {
      expect(AppSubjects.stripEmoji('📐 Toán'), 'Toán');
      expect(AppSubjects.stripEmoji('🧪 Hóa'), 'Hóa');
      expect(AppSubjects.stripEmoji('💡 Khác'), 'Khác');
    });

    test('chuỗi không emoji giữ nguyên', () {
      expect(AppSubjects.stripEmoji('Toán'), 'Toán');
    });
  });
}
