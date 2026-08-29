/// Tạo chuỗi ngữ cảnh ngày/giờ hiện tại để AI biết hôm nay là ngày thứ mấy.
///
/// Dùng danh sách tên thứ/dấu âm cứng (tiếng Việt) để không phụ thuộc vào
/// date-symbol data của package `intl` — tránh lỗi "locale not found".
class NowContext {
  static const List<String> _weekdays = [
    'Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7',
  ];

  /// Trả về câu như: "Hôm nay là Thứ 4, ngày 29 tháng 8 năm 2026 (14:30)."
  static String build([DateTime? now]) {
    final t = now ?? DateTime.now();
    final weekday = _weekdays[t.weekday % 7]; // DateTime.weekday: 1=Mon..7=Sun
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Hôm nay là $weekday, ngày ${t.day} tháng ${t.month} năm ${t.year}, hiện là $hh:$mm.';
  }
}
