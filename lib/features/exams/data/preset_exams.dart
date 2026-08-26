import '../domain/models/exam_model.dart';

class PresetExams {
  static List<ExamModel> get all => [
    ExamModel(
      id: 'thptqg-2027',
      name: 'THPT Quốc Gia 2027',
      dateTime: DateTime(2027, 6, 25, 7, 30),
      type: ExamType.preset,
      priority: ExamPriority.watching,
      description: 'Kỳ thi THPT Quốc Gia — cửa vào đại học',
      emoji: '🎓',
    ),
    ExamModel(
      id: 'tsa-2027',
      name: 'TSA 2027 (Đánh giá tư duy)',
      dateTime: DateTime(2027, 3, 22, 8, 0),
      type: ExamType.preset,
      priority: ExamPriority.watching,
      description: 'Kỳ thi Đánh giá Tư duy — ĐH Bách Khoa, ĐH Kinh tế',
      emoji: '🧠',
    ),
    ExamModel(
      id: 'hsa-2027',
      name: 'HSA 2027 (Đánh giá năng lực)',
      dateTime: DateTime(2027, 3, 30, 8, 0),
      type: ExamType.preset,
      priority: ExamPriority.watching,
      description: 'Kỳ thi Đánh giá Năng lực — ĐHQG Hà Nội',
      emoji: '📐',
    ),
    ExamModel(
      id: 'hsa-hcm-2027',
      name: 'HSA HCM 2027',
      dateTime: DateTime(2027, 4, 13, 8, 0),
      type: ExamType.preset,
      priority: ExamPriority.watching,
      description: 'Kỳ thi Đánh giá Năng lực — ĐHQG TP.HCM',
      emoji: '🏙️',
    ),
    ExamModel(
      id: 'hsg-tinh-2027',
      name: 'HSG Quốc Gia 2027',
      dateTime: DateTime(2027, 1, 10, 7, 30),
      type: ExamType.preset,
      priority: ExamPriority.watching,
      description: 'Kỳ thi Học Sinh Giỏi Quốc Gia các môn',
      emoji: '🏆',
    ),
    ExamModel(
      id: 'giua-hk1-2026',
      name: 'Giữa HK1 2026-2027',
      dateTime: DateTime(2026, 10, 20, 7, 0),
      type: ExamType.preset,
      priority: ExamPriority.watching,
      description: 'Kiểm tra giữa học kỳ 1 năm học 2026-2027',
      emoji: '📝',
    ),
    ExamModel(
      id: 'cuoi-hk1-2026',
      name: 'Cuối HK1 2026-2027',
      dateTime: DateTime(2026, 12, 20, 7, 0),
      type: ExamType.preset,
      priority: ExamPriority.watching,
      description: 'Kiểm tra cuối học kỳ 1 năm học 2026-2027',
      emoji: '📝',
    ),
  ];
}
