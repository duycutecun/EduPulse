/// Tiện ích định dạng ngày/giờ dùng chung (không phụ thuộc `intl`).
class AppDate {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Định dạng: `dd.MM.yyyy`
  static String formatDate(DateTime dt) =>
      '${_two(dt.day)}.${_two(dt.month)}.${dt.year}';

  /// Định dạng: `dd.MM.yyyy • HH:mm`
  static String formatDateTime(DateTime dt) =>
      '${formatDate(dt)} • ${_two(dt.hour)}:${_two(dt.minute)}';
}
