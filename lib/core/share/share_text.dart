/// Nội dung chia sẻ dựng sẵn — **thuần Dart, không phụ thuộc nền tảng** nên
/// kiểm thử được, và nhờ vậy app/web luôn chia sẻ cùng một giọng văn.
///
/// Việc "gửi đi đâu" do `ShareService` lo (share sheet hệ thống trên app,
/// Web Share API/clipboard trên web).
class ShareText {
  ShareText._();

  /// Link giới thiệu app — người nhận mở là vào được bản web.
  static const String appLink = 'https://edu-pulse-five-gamma.vercel.app';

  /// Chữ ký cuối mỗi đoạn chia sẻ.
  static const String signature = '— Học cùng EduPulse 📚';

  /// Tóm tắt tiến độ tuần: thời gian, tỉ lệ hoàn thành, streak, đếm ngược thi.
  ///
  /// Chỉ đưa vào những dòng có số liệu thật, tránh chia sẻ toàn số 0.
  static String progressSummary({
    required double weekHours,
    required int completionRatePercent,
    required int streakDays,
    String? examName,
    int? daysToExam,
  }) {
    final lines = <String>['📊 Tiến độ học tuần này của mình:'];

    lines.add('• Thời gian học: ${weekHours.toStringAsFixed(1)} giờ');
    lines.add('• Hoàn thành nhiệm vụ: ${completionRatePercent.clamp(0, 100)}%');
    if (streakDays > 0) {
      lines.add('• Chuỗi ngày học: 🔥 $streakDays ngày liên tiếp');
    }
    if (examName != null &&
        examName.trim().isNotEmpty &&
        daysToExam != null &&
        daysToExam >= 0) {
      lines.add('• ${examName.trim()}: còn $daysToExam ngày');
    }

    lines.add('');
    lines.add(signature);
    return lines.join('\n');
  }

  /// Tóm tắt một nhiệm vụ để gửi cho bạn học cùng nhóm.
  static String taskSummary({
    required String title,
    required String subject,
    int? estimateMinutes,
  }) {
    final lines = <String>['📝 Nhiệm vụ học tập: ${title.trim()}'];
    if (subject.trim().isNotEmpty) {
      lines.add('• Môn: ${subject.trim()}');
    }
    if (estimateMinutes != null && estimateMinutes > 0) {
      lines.add('• Dự kiến: $estimateMinutes phút');
    }
    lines.add('');
    lines.add(signature);
    return lines.join('\n');
  }

  /// Lời mời cài app — dùng cho nút "Giới thiệu EduPulse".
  static String appInvite() {
    return [
      'Mình đang dùng EduPulse để đếm ngược kỳ thi và giữ nhịp học mỗi ngày 🎯',
      'Bạn thử xem nhé: $appLink',
      '',
      signature,
    ].join('\n');
  }
}
