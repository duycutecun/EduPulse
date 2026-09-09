/// Danh mục kỳ thi mẫu dùng cho onboarding lần đầu.
///
/// Ngày mặc định dựa trên lịch công bố / thông lệ:
/// - THPTQG: 11–12/06 hằng năm (theo Quyết định 2308/QĐ-BGDĐT).
/// - TSA (ĐHQGHN) & HSA (ĐHQG TP.HCM): thi nhiều đợt trong năm,
///   mặc định ~2 tháng kể từ hôm nay, user có thể chỉnh sau.
/// - HSG: theo lịch từng tỉnh, mặc định ~3 tháng.
class PresetExam {
  final String id;
  final String name;
  final String emoji;
  final String description;

  /// Sinh ngày thi mặc định tính từ hôm nay.
  final DateTime Function() defaultDate;

  /// Nhiệm vụ mẫu seed vào danh sách nhiệm vụ hôm nay.
  final List<({String title, String subject, String priority, int minutes})>
      sampleTasks;

  const PresetExam({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.defaultDate,
    required this.sampleTasks,
  });
}

class PresetExams {
  static DateTime _nextFixed(int month, int day) {
    final now = DateTime.now();
    var d = DateTime(now.year, month, day);
    if (!d.isAfter(now)) d = DateTime(now.year + 1, month, day);
    return d;
  }

  static final List<PresetExam> all = [
    PresetExam(
      id: 'thptqg',
      name: 'Tốt nghiệp THPT',
      emoji: '🎓',
      description: 'Kỳ thi quốc gia 11–12/06 — môn Toán, Văn, Ngoại ngữ + tổ hợp.',
      defaultDate: () => _nextFixed(6, 11),
      sampleTasks: [
        (title: 'Giải 1 đề Toán THPTQG (50 câu)', subject: '📐 Toán', priority: 'high', minutes: 90),
        (title: 'Luyện đọc hiểu tiếng Anh 30 phút', subject: '🇬🇧 Anh', priority: 'medium', minutes: 30),
        (title: 'Ôn nghị luận xã hội — dàn ý + viết mở bài', subject: '📖 Văn', priority: 'medium', minutes: 45),
      ],
    ),
    PresetExam(
      id: 'tsa',
      name: 'Đánh giá năng lực (TSA)',
      emoji: '🧠',
      description: 'Kỳ thi ĐHQG Hà Nội — Tư duy định lượng, định tính, khoa học.',
      defaultDate: () => DateTime.now().add(const Duration(days: 60)),
      sampleTasks: [
        (title: 'Luyện phần Tư duy định lượng (30 câu)', subject: '📐 Toán', priority: 'high', minutes: 60),
        (title: 'Đọc hiểu nhanh 2 bài + trả lời câu hỏi', subject: '📖 Văn', priority: 'medium', minutes: 30),
        (title: 'Ôn tư duy khoa học: bài tập Vật Lý', subject: '⚡ Lý', priority: 'low', minutes: 30),
      ],
    ),
    PresetExam(
      id: 'hsa',
      name: 'Đánh giá năng lực (HSA)',
      emoji: '🎯',
      description: 'Kỳ thi ĐHQG TP.HCM — Toán học, tư duy khoa học, Tiếng Việt.',
      defaultDate: () => DateTime.now().add(const Duration(days: 60)),
      sampleTasks: [
        (title: 'Luyện 1 đề HSA phần Toán học', subject: '📐 Toán', priority: 'high', minutes: 75),
        (title: 'Ôn tư duy khoa học: Hóa hữu cơ', subject: '🧪 Hóa', priority: 'medium', minutes: 45),
        (title: 'Luyện phần Tiếng Việt & Văn học', subject: '📖 Văn', priority: 'medium', minutes: 30),
      ],
    ),
    PresetExam(
      id: 'hsg',
      name: 'Học sinh giỏi',
      emoji: '🏆',
      description: 'Kỳ thi HSG cấp tỉnh/thành — môn chuyên, kiến thức nâng cao.',
      defaultDate: () => DateTime.now().add(const Duration(days: 90)),
      sampleTasks: [
        (title: 'Giải 5 bài tập nâng cao môn chuyên', subject: '📐 Toán', priority: 'high', minutes: 60),
        (title: 'Hệ thống lại lý thuyết trọng tâm', subject: '⚡ Lý', priority: 'medium', minutes: 45),
        (title: 'Làm đề thi HSG năm trước', subject: '💡 Khác', priority: 'medium', minutes: 90),
      ],
    ),
  ];
}