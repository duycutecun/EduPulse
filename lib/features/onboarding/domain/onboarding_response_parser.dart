/// Bộ hiểu câu trả lời onboarding chạy ngay trên thiết bị.
/// Chỉ trích xuất các trường rõ ràng, không cố suy đoán nếu câu trả lời mơ hồ.
class OnboardingResponseParser {
  OnboardingResponseParser._();

  static int? dailyMinutes(String input) {
    final normalized = input.toLowerCase().replaceAll(',', '.');
    final minute =
        RegExp(r'(\d{1,3})\s*(phút|phut|min)').firstMatch(normalized);
    if (minute != null) return _validMinutes(int.tryParse(minute.group(1)!));
    final hour = RegExp(r'(\d+(?:\.\d+)?)\s*(giờ|gio|tiếng|tieng|h)')
        .firstMatch(normalized);
    if (hour != null) {
      final value = double.tryParse(hour.group(1)!);
      return value == null ? null : _validMinutes((value * 60).round());
    }
    // Dạng một con số trần chỉ chấp nhận ở khoảng hợp lý cho quỹ học/ngày.
    final bare = int.tryParse(normalized.trim());
    return _validMinutes(bare);
  }

  static DateTime? examDate(String input, {DateTime? now}) {
    final match =
        RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(input);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    final candidate = DateTime(year, month, day);
    // DateTime tự chuẩn hóa 31/02, vì vậy xác nhận lại phần người dùng nhập.
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) return null;
    return candidate;
  }

  static double? score(String input) {
    final match =
        RegExp(r'(?<!\d)(10(?:[.,]0)?|\d(?:[.,]\d+)?)(?!\d)').firstMatch(input);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    return value != null && value >= 0 && value <= 10 ? value : null;
  }

  static int? _validMinutes(int? value) =>
      value != null && value >= 15 && value <= 480 ? value : null;
}
