import '../../features/exams/domain/models/exam_model.dart';
import '../utils/storage_service.dart';

class GeneratedTask {
  final String title;
  final String subject;
  final String topic;
  final int minutes;
  final String priority;

  GeneratedTask(this.title, this.subject, this.topic, this.minutes, this.priority);
}

class SmartTaskGenerator {
  static List<GeneratedTask> generateFromExam(String examType, {DateTime? now}) {
    final exams = _readExams();
    if (exams.isEmpty) return [];

    final primaryId = StorageService.getPrimaryExamId();
    ExamModel? main;
    if (primaryId != null) {
      for (final e in exams) {
        if (e.id == primaryId) {
          main = e;
          break;
        }
      }
    }
    main ??= exams.first;
    final syllabus = _getSyllabus(examType);
    final tasks = <GeneratedTask>[];

    for (final entry in syllabus.entries) {
      final subject = entry.key;
      final topics = entry.value;
      final weight = _getSubjectWeight(subject, examType);

      for (final topic in topics) {
        final priority = weight >= 0.8 ? 'high' : weight >= 0.5 ? 'medium' : 'low';
        final minutes = weight >= 0.8 ? 45 : 30;
        tasks.add(GeneratedTask(
          topic,
          subject,
          topic,
          minutes,
          priority,
        ));
      }
    }

    tasks.sort((a, b) => _priorityRank(b.priority).compareTo(_priorityRank(a.priority)));
    return tasks;
  }

  static Map<String, List<String>> _getSyllabus(String examType) {
    final lower = examType.toLowerCase();
    if (lower.contains('thptqg') || lower.contains('thpt')) {
      return {
        'Toán': ['Hàm số', 'Tích phân', 'Hình họng gian', 'Xác suất thống kê'],
        'Vật lý': ['Cơ học', 'Điện từ', 'Quang học', 'Nguyên tử'],
        'Hóa học': ['Hóa vô cơ', 'Hóa hữu cơ', 'Hóa phân tích'],
        'Sinh học': ['Di truyền', 'Tiến hóa', 'Sinh thái', 'Tế bào'],
        'Ngữ văn': ['Nghị luận', 'Thơ', 'Văn học'],
        'Tiếng Anh': ['Ngữ pháp', 'Từ vựng', 'Đọc hiểu'],
      };
    }
    if (lower.contains('tsa') || lower.contains('hsa')) {
      return {
        'Toán': ['Đại số', 'Hình học', 'Tổ hợp', 'Xác suất'],
        'Vật lý': ['Cơ học', 'Điện từ', 'Nhiệt học'],
        'Hóa học': ['Hóa vô cơ', 'Hóa hữu cơ'],
      };
    }
    return {
      'Toán': ['Ôn tổng hợp'],
      'Vật lý': ['Ôn tổng hợp'],
      'Hóa học': ['Ôn tổng hợp'],
    };
  }

  static double _getSubjectWeight(String subject, String examType) {
    final lower = subject.toLowerCase();
    if (lower.contains('toán')) return 1.0;
    if (lower.contains('vật lý') || lower.contains('lý')) return 0.9;
    if (lower.contains('hóa')) return 0.8;
    if (lower.contains('sinh')) return 0.7;
    if (lower.contains('tiếng anh') || lower.contains('anh')) return 0.6;
    if (lower.contains('ngữ văn') || lower.contains('văn')) return 0.5;
    return 0.5;
  }

  static int _priorityRank(String p) {
    switch (p) {
      case 'high':
        return 0;
      case 'low':
        return 2;
      default:
        return 1;
    }
  }

  static List<ExamModel> _readExams() {
    final ids = StorageService.getExamIds();
    final out = <ExamModel>[];
    for (final id in ids) {
      final raw = StorageService.getExamJson(id);
      if (raw == null) continue;
      try {
        out.add(ExamModel.fromJsonString(raw));
      } catch (_) {}
    }
    return out;
  }
}
