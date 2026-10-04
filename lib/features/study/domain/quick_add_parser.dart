/// Quick Add bằng ngôn ngữ tự nhiên (đặc tả mục 25).
///
/// Ví dụ đặc tả: "Mai 19h học toán hàm số 45 phút"
/// → AI parse → preview → confirm.
///
/// Parser này là **rule-based thuần function** chạy offline — AI Coach có
/// thể hỗ trợ câu phức tạp hơn, nhưng những mẫu câu phổ biến nhất phải xử
/// lý được tức thì, không đợi mạng (Fast principle, mục 43).
///
/// Hỗ trợ:
/// - Thời gian: "mai", "mốt", "thứ 3", "chủ nhật", "19h", "19h30",
///   "7h tối", giờ mặc định = 19:00 nếu chỉ nói ngày.
/// - Thời lượng: "45 phút", "1 giờ", "1.5 giờ", "90p" — mặc định 45 phút.
/// - Môn: Toán, Lý, Hóa, Văn, Anh, Sinh, Sử, Địa + emoji tương ứng.
/// - Tiêu đề: phần text còn lại sau khi bóc các token trên.
class QuickAddParseResult {
  final String title;
  final String subject;
  final int minutes;
  final DateTime scheduledAt;
  final String priority;

  const QuickAddParseResult({
    required this.title,
    required this.subject,
    required this.minutes,
    required this.scheduledAt,
    required this.priority,
  });
}

QuickAddParseResult? parseQuickAdd(String input, DateTime now) {
  var text = input.trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();

  // ------------------------------------------------------------------
  // 1. Ngày
  // ------------------------------------------------------------------
  var day = DateTime(now.year, now.month, now.day);
  var hasDay = false;

  if (RegExp(r'\bmai\b').hasMatch(lower)) {
    day = day.add(const Duration(days: 1));
    hasDay = true;
  } else if (RegExp(r'\bmốt\b|\bmo(\s)?t\b|kia\b').hasMatch(lower)) {
    day = day.add(const Duration(days: 2));
    hasDay = true;
  } else {
    // "thứ 2" ... "thứ 7", "chủ nhật" — tìm lần xuất hiện kế tiếp.
    final weekdayNames = <String, int>{
      'thứ 2': DateTime.monday,
      'thứ 3': DateTime.tuesday,
      'thứ 4': DateTime.wednesday,
      'thứ 5': DateTime.thursday,
      'thứ 6': DateTime.friday,
      'thứ 7': DateTime.saturday,
      'thứ hai': DateTime.monday,
      'thứ ba': DateTime.tuesday,
      'thứ tư': DateTime.wednesday,
      'thứ năm': DateTime.thursday,
      'thứ sáu': DateTime.friday,
      'thứ bảy': DateTime.saturday,
      'chủ nhật': DateTime.sunday,
      'cn': DateTime.sunday,
    };
    for (final entry in weekdayNames.entries) {
      if (lower.contains(entry.key)) {
        var delta = entry.value - now.weekday;
        if (delta <= 0) delta += 7; // tuần kế tiếp nếu đã qua
        day = day.add(Duration(days: delta));
        hasDay = true;
        break;
      }
    }
  }

  // ------------------------------------------------------------------
  // 2. Giờ
  // ------------------------------------------------------------------
  var hour = 19;
  var minute = 0;
  var hasTime = false;

  final timeMatch = RegExp(r'(\d{1,2})\s*[h:]\s*(\d{2})?').firstMatch(lower);
  if (timeMatch != null) {
    hour = int.parse(timeMatch.group(1)!);
    minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      hasTime = true;
      // "7h sáng/tối/chiều" — điều chỉnh buổi.
      if (hour < 12) {
        if (RegExp(r'(tối|đêm|chiều)').hasMatch(lower) && hour + 12 <= 23) {
          hour += 12;
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // 3. Thời lượng — "giờ" viết rõ được ưu tiên để không nhầm với giờ
  // trong ngày ("8h tối ... 1 giờ" → 60 phút).
  // ------------------------------------------------------------------
  var minutes = 45;
  final minMatch =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(phút|p\b|minute)').firstMatch(lower);
  final hourExplicit =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(giờ|hour)').firstMatch(lower);
  final hourShort = RegExp(r'(\d+(?:[.,]\d+)?)\s*h\b').firstMatch(lower);
  final hasDuration = minMatch != null || hourExplicit != null;
  if (minMatch != null) {
    minutes = double.parse(minMatch.group(1)!.replaceAll(',', '.')).round();
  } else if (hourExplicit != null) {
    final h = double.parse(hourExplicit.group(1)!.replaceAll(',', '.'));
    minutes = (h * 60).round();
  } else if (hourShort != null && !hasTime) {
    // "2h học" không kèm giờ trong ngày — coi là thời lượng.
    minutes =
        (double.parse(hourShort.group(1)!.replaceAll(',', '.')) * 60).round();
  }
  if (minutes <= 0) minutes = 45;
  if (minutes > 480) minutes = 480;

  // ------------------------------------------------------------------
  // 4. Môn
  // ------------------------------------------------------------------
  const subjectMap = <String, String>{
    'toán': '📐 Toán',
    'lý': '⚡ Lý',
    'hóa': '🧪 Hóa',
    'anh': '🇬🇧 Anh',
    'văn': '📖 Văn',
    'sinh': '🧬 Sinh',
    'sử': '📜 Sử',
    'địa': '🌍 Địa',
  };
  var subject = '💡 Khác';
  var subjectFound = false;
  for (final entry in subjectMap.entries) {
    // Tách từ: "toán" nhưng không khớp giữa từ khác.
    if (RegExp('\\b${entry.key}').hasMatch(lower)) {
      subject = entry.value;
      subjectFound = true;
      break;
    }
  }

  // ------------------------------------------------------------------
  // 5. Ưu tiên: "quan trọng/quan trọng" → high, "nhẹ" → low
  // ------------------------------------------------------------------
  var priority = 'medium';
  if (RegExp(r'quan trọng|gấp|urgent').hasMatch(lower)) {
    priority = 'high';
  } else if (RegExp(r'nhẹ|nếu kịp').hasMatch(lower)) {
    priority = 'low';
  }

  // ------------------------------------------------------------------
  // 6. Tiêu đề: bóc token đã xử lý khỏi text gốc
  // ------------------------------------------------------------------
  var title = text
      .replaceAll(RegExp(r'\bmai\b|\bmốt\b|\bkia\b', caseSensitive: false), '')
      .replaceAll(
          RegExp(
              r'chủ nhật|thứ hai|thứ ba|thứ tư|thứ năm|thứ sáu|thứ bảy|thứ [2-7]|\bcn\b',
              caseSensitive: false),
          '')
      .replaceAll(
          RegExp(r'\d{1,2}\s*[h:]\s*(\d{2})?', caseSensitive: false), '')
      .replaceAll(
          RegExp(r'(sáng|trưa|chiều|tối|đêm)', caseSensitive: false), '')
      .replaceAll(
          RegExp(r'\d+(?:[.,]\d+)?\s*(phút|giờ|p\b|h\b|minute|hour)',
              caseSensitive: false),
          '')
      .replaceAll(
          RegExp(r'\b(quan trọng|gấp|urgent|nhẹ|nếu kịp)\b',
              caseSensitive: false),
          '')
      // Môn đã thể hiện qua chip subject — bỏ khỏi tiêu đề để tránh lặp.
      .replaceAll(RegExp(r'\b(học|ôn|luyện|làm)\b', caseSensitive: false), '')
      .trim();
  // Gom khoảng trắng thừa.
  title = title.replaceAll(RegExp(r'\s{2,}'), ' ');

  // Cần ít nhất một tín hiệu (ngày/giờ/thời lượng/môn) — nếu không có
  // gì cả thì không tạo task rác.
  if (!hasDay && !hasTime && !hasDuration && !subjectFound) return null;

  if (title.isEmpty) {
    title = 'Học $subject';
  }

  return QuickAddParseResult(
    title: title,
    subject: subject,
    minutes: minutes,
    scheduledAt: DateTime(day.year, day.month, day.day, hour, minute),
    priority: priority,
  );
}
