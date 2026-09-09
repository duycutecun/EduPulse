import 'dart:convert';

/// Một câu hỏi trắc nghiệm do AI sinh ra từ ảnh/văn bản.
class QuizQuestion {
  final String question;
  final List<String> options; // luôn 4 đáp án
  final int correctIndex; // 0-based
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

/// Prompt yêu cầu AI đọc ảnh và sinh quiz trắc nghiệm dạng JSON.
String buildQuizPrompt() {
  return '''
Bạn là giáo viên luyện thi. Hãy đọc kỹ nội dung trong ảnh (trang sách / đề / vở) và tạo 5 câu hỏi trắc nghiệm kiểm tra hiểu biết về nội dung đó.

Yêu cầu:
- Trả về ĐÚNG định dạng JSON, KHÔNG kèm markdown, KHÔNG kèm text khác.
- JSON dạng: {"questions":[{"question":"...","options":["A...","B...","C...","D..."],"correctIndex":0,"explanation":"..."}]}
- Đúng 4 đáp án mỗi câu (options), correctIndex là số thứ tự 0–3 của đáp án đúng.
- Câu hỏi từ dễ đến khó, bám sát kiến thức trong ảnh, kèm giải thích ngắn gọn cho đáp án đúng.
''';
}

/// Parse JSON do AI trả về thành danh sách câu hỏi quiz.
///
/// Xử lý linh hoạt giống [parseAiPlan]: bóc ```json```, cắt JSON từ ngoặc
/// nhọn, bỏ câu hỏi thiếu field bắt buộc.
List<QuizQuestion> parseQuiz(String raw) {
  var text = raw.trim();

  final fenceStart = text.indexOf('```');
  if (fenceStart != -1) {
    final fenceEnd = text.indexOf('```', fenceStart + 3);
    if (fenceEnd != -1) {
      text = text.substring(fenceStart + 3, fenceEnd);
      final nl = text.indexOf('\n');
      if (nl != -1 &&
          text.substring(0, nl).trim().toLowerCase().contains('json')) {
        text = text.substring(nl + 1);
      }
    }
  }
  text = text.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    text = text.substring(start, end + 1);
  }

  try {
    final data = jsonDecode(text);
    final list = (data is Map<String, dynamic> ? data['questions'] : data);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(_questionFromJson)
        .whereType<QuizQuestion>()
        .toList();
  } catch (_) {
    return const [];
  }
}

QuizQuestion? _questionFromJson(Map<String, dynamic> j) {
  final question = (j['question'] as String?)?.trim() ?? '';
  if (question.isEmpty) return null;

  final rawOptions = j['options'];
  final options = rawOptions is List
      ? rawOptions
          .map((o) => o?.toString().trim() ?? '')
          .where((o) => o.isNotEmpty)
          .toList()
      : <String>[];
  if (options.length < 2) return null;

  final correctIndex = (j['correctIndex'] as num?)?.toInt() ?? 0;
  final safeIndex = correctIndex.clamp(0, options.length - 1);

  return QuizQuestion(
    question: question,
    options: options,
    correctIndex: safeIndex,
    explanation: (j['explanation'] as String?)?.trim() ?? '',
  );
}