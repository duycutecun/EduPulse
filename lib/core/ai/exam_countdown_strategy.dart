/// Hướng ưu tiên học theo khoảng cách tới kỳ thi.
///
/// Đây là lớp quy tắc nhỏ, minh bạch, giúp mọi bề mặt AI nói cùng một chiến
/// lược trước cả khi mô hình ngôn ngữ được gọi.
enum ExamStudyPhase {
  foundation,
  practice,
  revision,
  crunch,
  examDay,
  completed
}

class ExamCountdownStrategy {
  const ExamCountdownStrategy._();

  static ExamStudyPhase phaseForDaysLeft(int daysLeft) {
    if (daysLeft < 0) return ExamStudyPhase.completed;
    if (daysLeft == 0) return ExamStudyPhase.examDay;
    if (daysLeft < 7) return ExamStudyPhase.crunch;
    if (daysLeft <= 14) return ExamStudyPhase.revision;
    if (daysLeft <= 30) return ExamStudyPhase.practice;
    return ExamStudyPhase.foundation;
  }

  static String guidanceForDaysLeft(int daysLeft) {
    switch (phaseForDaysLeft(daysLeft)) {
      case ExamStudyPhase.foundation:
        return 'Xây nền: học lý thuyết trọng tâm, tạo flashcard và duy trì nhịp đều.';
      case ExamStudyPhase.practice:
        return 'Luyện đề: tăng bài tập, phân tích lỗi sai và ưu tiên môn còn yếu.';
      case ExamStudyPhase.revision:
        return 'Tổng ôn: hệ thống hóa kiến thức, không mở quá nhiều nội dung mới.';
      case ExamStudyPhase.crunch:
        return 'Nước rút bình tĩnh: rà công thức, phản xạ nhanh, ngủ đủ; tránh tạo áp lực bằng kế hoạch quá tải.';
      case ExamStudyPhase.examDay:
        return 'Ngày thi: ưu tiên bình tĩnh, checklist cần thiết và nghỉ ngơi; không nhồi kiến thức mới.';
      case ExamStudyPhase.completed:
        return 'Kỳ thi đã qua: ghi nhận điều đã làm được và chỉ lập mục tiêu tiếp theo khi sẵn sàng.';
    }
  }
}
