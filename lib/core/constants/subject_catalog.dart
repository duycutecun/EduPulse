import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Một môn học trong danh mục chuẩn của EduPulse.
///
/// Vì sao cần catalog (phát hiện ở Sprint 2): `subject` từng tồn tại **hai
/// chuẩn song song** — `'📐 Toán'` (quick_add_parser, preset_exams, study_screen,
/// AddTaskDialog) và `'Toán'` (TaskEditSheet). Hai chuỗi này là hai môn khác
/// nhau với mọi `groupBy(subject)`, khiến biểu đồ tiến độ theo môn (Sprint 5)
/// và màu chip trên TaskCard bị sai.
///
/// Dạng chuẩn hoá: **luôn có emoji, luôn viết hoa chữ cái đầu môn chính**.
class AppSubject {
  /// Tên đầy đủ dùng lưu trữ, ví dụ `'📐 Toán'`.
  final String name;

  /// Tên không emoji, dùng cho tìm kiếm/gom nhóm/thống kê.
  final String plainName;

  final IconData icon;
  final Color color;

  const AppSubject({
    required this.name,
    required this.plainName,
    required this.icon,
    required this.color,
  });

  String get initial => plainName.isEmpty ? '?' : plainName[0].toUpperCase();
}

/// Danh mục môn học chuẩn — nguồn duy nhất cho form chọn môn.
abstract class AppSubjects {
  static const AppSubject toan = AppSubject(
      name: '📐 Toán',
      plainName: 'Toán',
      icon: Icons.functions,
      color: AppColors.blue);
  static const AppSubject ly = AppSubject(
      name: '⚡ Lý',
      plainName: 'Lý',
      icon: Icons.bolt,
      color: Color(0xFF6A1B9A));
  static const AppSubject hoa = AppSubject(
      name: '🧪 Hóa',
      plainName: 'Hóa',
      icon: Icons.science,
      color: Color(0xFFC2185B));
  static const AppSubject van = AppSubject(
      name: '📖 Văn',
      plainName: 'Văn',
      icon: Icons.menu_book,
      color: Color(0xFFE65100));
  static const AppSubject anh = AppSubject(
      name: '🇬🇧 Anh',
      plainName: 'Anh',
      icon: Icons.translate,
      color: Color(0xFF2E7D32));
  static const AppSubject sinh = AppSubject(
      name: '🧬 Sinh',
      plainName: 'Sinh',
      icon: Icons.biotech,
      color: Color(0xFF00897B));
  static const AppSubject su = AppSubject(
      name: '🏛️ Sử',
      plainName: 'Sử',
      icon: Icons.account_balance,
      color: Color(0xFF8D6E63));
  static const AppSubject dia = AppSubject(
      name: '🗺️ Địa',
      plainName: 'Địa',
      icon: Icons.public,
      color: Color(0xFF00ACC1));
  static const AppSubject gdcd = AppSubject(
      name: '⚖️ GDCD',
      plainName: 'GDCD',
      icon: Icons.balance,
      color: Color(0xFF00838F));
  static const AppSubject tin = AppSubject(
      name: '💻 Tin',
      plainName: 'Tin',
      icon: Icons.computer,
      color: Color(0xFF3949AB));
  static const AppSubject khac = AppSubject(
      name: '💡 Khác',
      plainName: 'Khác',
      icon: Icons.lightbulb_outline,
      color: AppColors.primary);

  /// Thứ tự hiển thị trong form chọn môn.
  static const List<AppSubject> all = [
    toan,
    ly,
    hoa,
    van,
    anh,
    sinh,
    su,
    dia,
    gdcd,
    tin,
    khac,
  ];

  /// Danh sách chuỗi chuẩn (dùng khi ghi vào model).
  static List<String> get names => all.map((s) => s.name).toList();

  /// Regex khớp ký tự emoji + variation selector (dùng `unicode: true` vì
  /// emoji nằm ngoài BMP nên cần escape dạng codepoint, không phải surrogate).
  static final RegExp _emojiPattern = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{20E3}]',
    unicode: true,
  );

  /// Bỏ ký tự emoji và khoảng trắng thừa ở đầu chuỗi.
  static String stripEmoji(String value) {
    return value
        .replaceAll(_emojiPattern, '')
        .replaceAll(RegExp(r'^\s+|\s+$'), '')
        .trim();
  }

  /// Bảng bỏ dấu tiếng Việt — khai báo bằng **cặp chữ cái gốc ↔ biến thể** thay
  /// vì hai chuỗi `from`/`to` đếm tay (dễ lệch chỉ số và map sai âm bội, ví dụ
  /// `ý → a` khiến "Vật lý" không khớp "⚡ Lý").
  static final Map<String, String> _diacritics = _buildDiacritics();

  static Map<String, String> _buildDiacritics() {
    // Liệt kê ĐẦY ĐỦ mọi biến thể có dấu của từng nguyên âm tiếng Việt.
    // Thiếu một biến thể (vd 'ế', 'ậ') thì "Tiếng Anh"/"Vật Lý" sẽ không khớp.
    const groups = <List<String>>[
      [
        'a', // a
        'à', 'á', 'ả', 'ã', 'ạ', // à á ả ã ạ
        'ă', 'ằ', 'ắ', 'ẳ', 'ẵ', 'ặ', // ă ằ ắ ẳ ẵ ặ
        'â', 'ầ', 'ấ', 'ẩ', 'ẫ', 'ậ', // â ầ ấ ẩ ẫ ậ
      ],
      [
        'e', // e
        'è', 'é', 'ẻ', 'ẽ', 'ẹ', // è é ẻ ẽ ẹ
        'ê', 'ề', 'ế', 'ể', 'ễ', 'ệ', // ê ề ế ể ễ ệ
      ],
      [
        'i', // i
        'ì', 'í', 'ỉ', 'ĩ', 'ị', // ì í ỉ ĩ ị
      ],
      [
        'o', // o
        'ò', 'ó', 'ỏ', 'õ', 'ọ', // ò ó ỏ õ ọ
        'ô', 'ồ', 'ố', 'ổ', 'ỗ', 'ộ', // ô ồ ố ổ ỗ ộ
        'ơ', 'ờ', 'ớ', 'ở', 'ỡ', 'ợ', // ơ ờ ớ ở ỡ ợ
      ],
      [
        'u', // u
        'ù', 'ú', 'ủ', 'ũ', 'ụ', // ù ú ủ ũ ụ
        'ư', 'ừ', 'ứ', 'ử', 'ữ', 'ự', // ư ừ ứ ử ữ ự
      ],
      [
        'y', // y
        'ỳ', 'ý', 'ỷ', 'ỹ', 'ỵ', // ỳ ý ỷ ỹ ỵ
      ],
      [
        'd', // d
        'đ', // đ
      ],
    ];
    final map = <String, String>{};
    for (final group in groups) {
      final base = group.first;
      for (final variant in group.skip(1)) {
        map[variant] = base;
      }
    }
    return Map.unmodifiable(map);
  }

  /// Bỏ dấu + lowercase + bỏ khoảng trắng thừa, để so khớp không phụ thuộc
  /// dấu tiếng Việt lẫn cách người dùng/AI gõ ("vật lí", "Vật Lý", "vat ly").
  static String foldDiacritics(String value) {
    final lower = stripEmoji(value).toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_diacritics[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Bảng đồ bí danh → tên chuẩn (khoá đã bỏ dấu, lowercase, giữ khoảng trắng).
  static final Map<String, String> _aliases = {
    'toan': toan.name,
    'math': toan.name,
    'maths': toan.name,
    'ly': ly.name,
    'vat ly': ly.name,
    'vat li': ly.name,
    'physics': ly.name,
    'hoa': hoa.name,
    'hoa hoc': hoa.name,
    'chemistry': hoa.name,
    'van': van.name,
    'ngu van': van.name,
    'literature': van.name,
    'anh': anh.name,
    'tieng anh': anh.name,
    'english': anh.name,
    'sinh': sinh.name,
    'sinh hoc': sinh.name,
    'biology': sinh.name,
    'su': su.name,
    'lich su': su.name,
    'history': su.name,
    'dia': dia.name,
    'dia ly': dia.name,
    'geography': dia.name,
    'gdcd': gdcd.name,
    'gdcd hoc': gdcd.name,
    'citizenship': gdcd.name,
    'tin': tin.name,
    'tin hoc': tin.name,
    'it': tin.name,
    'khac': khac.name,
    'other': khac.name,
  };

  /// Khoá tra cứu: mỗi bí danh được đăng ký thêm bản **không khoảng trắng** để
  /// "vậtlý", "vatly", "vật lí"… đều ra một kết quả.
  static final Map<String, String> _aliasLookup = {
    for (final entry in _aliases.entries) ...{
      entry.key: entry.value,
      entry.key.replaceAll(' ', ''): entry.value,
    },
  };

  /// Chuẩn hoá một chuỗi subject bất kỳ về tên chuẩn có emoji.
  ///
  /// Không nhận ra → trả nguyên đầu vào đã trim, **không tự bịa môn học**
  /// (nguyên tắc §10 "No fabricated data").
  static String normalize(String? value) {
    if (value == null || value.trim().isEmpty) return khac.name;
    final raw = value.trim();
    final folded = foldDiacritics(raw);
    final aliased =
        _aliasLookup[folded] ?? _aliasLookup[folded.replaceAll(' ', '')];
    if (aliased != null) return aliased;

    // Đã đúng chuẩn rồi (có emoji khớp danh mục).
    for (final subject in all) {
      if (raw == subject.name) return subject.name;
    }
    return raw;
  }

  /// Tìm mô tả trong catalog (không chuẩn hoá), để tô màu chip theo môn.
  static AppSubject? find(String? value) {
    if (value == null) return null;
    final canonical = normalize(value);
    for (final subject in all) {
      if (subject.name == canonical) return subject;
    }
    return null;
  }

  /// Màu nhận diện theo môn; môn lạ → màu chủ đạo.
  static Color colorOf(String? value) =>
      find(value)?.color ?? AppColors.primary;

  /// Icon theo môn; môn lạ → icon chung.
  static IconData iconOf(String? value) =>
      find(value)?.icon ?? Icons.lightbulb_outline;

  /// Danh sách tên hiển thị cho chip chọn môn.
  static String displayName(String value) {
    final plain = stripEmoji(value);
    return plain.isEmpty ? value : plain;
  }
}
