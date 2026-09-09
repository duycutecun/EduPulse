import 'dart:convert';

/// Một nhiệm vụ do AI sinh ra trong lộ trình học tuần.
class AiPlanTask {
  final String title;
  final String subject;
  final String priority; // 'high' | 'medium' | 'low'
  final int minutes;

  const AiPlanTask({
    required this.title,
    required this.subject,
    required this.priority,
    required this.minutes,
  });
}

/// Prompt yêu cầu AI sinh lộ trình học tuần dưới dạng JSON.
String buildAiPlanPrompt({
  required String examName,
  required int daysLeft,
  required int dailyMinutes,
  required int planDays,
}) {
  return '''
Bạn là chuyên gia luyện thi cho sĩ tử Việt Nam. Hãy lập LỘ TRÌNH HỌC $planDays NGÀY cho kỳ thi "$examName" (còn $daysLeft ngày), mỗi ngày có quỹ thời gian khoảng $dailyMinutes phút.

Yêu cầu:
- Trả về ĐÚNG định dạng JSON, KHÔNG kèm markdown, KHÔNG kèm text khác.
- JSON có dạng: {"tasks":[{"title":"...","subject":"📐 Toán","priority":"high|medium|low","minutes":30}]}
- Mỗi ngày 2–4 nhiệm vụ, tổng thời gian mỗi ngày sát $dailyMinutes phút.
- Nhiệm vụ cụ thể, hành động được (VD: "Giải 1 đề Toán", "Ôn 30 từ vựng Anh"), subject dùng emoji (📐 Toán, ⚡ Lý, 🧪 Hóa, 📖 Văn, 🇬🇧 Anh, 🧬 Sinh, 💡 Khác).
- Ưu tiên môn yếu/thang điểm cao, xen kẽ môn để tránh nhàm chán.
''';
}

/// Parse JSON do AI trả về thành danh sách nhiệm vụ.
///
/// Xử lý linh hoạt: bỏ qua khối ```json ... ```, mỗi phần tử phải có `title`;
/// các phần tử thiếu field sẽ dùng giá trị mặc định; phần tử hỏng bị bỏ qua.
List<AiPlanTask> parseAiPlan(String raw) {
  var text = raw.trim();

  // Bóc khối ```json ... ``` nếu có.
  final fenceStart = text.indexOf('```');
  if (fenceStart != -1) {
    final fenceEnd = text.indexOf('```', fenceStart + 3);
    if (fenceEnd != -1) {
      text = text.substring(fenceStart + 3, fenceEnd);
      final nl = text.indexOf('\n');
      if (nl != -1 && text.substring(0, nl).trim().toLowerCase().contains('json')) {
        text = text.substring(nl + 1);
      }
    }
  }
  text = text.trim();
  // Nếu vẫn còn text thừa quanh JSON, cắt từ ngoặc nhọn đầu.
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    text = text.substring(start, end + 1);
  }

  try {
    final data = jsonDecode(text);
    final list = (data is Map<String, dynamic> ? data['tasks'] : data);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(_taskFromJson)
        .whereType<AiPlanTask>()
        .toList();
  } catch (_) {
    return const [];
  }
}

AiPlanTask? _taskFromJson(Map<String, dynamic> j) {
  final title = (j['title'] as String?)?.trim() ?? '';
  if (title.isEmpty) return null;

  var priority = (j['priority'] as String?)?.trim() ?? 'medium';
  if (!['high', 'medium', 'low'].contains(priority)) priority = 'medium';

  var minutes = (j['minutes'] as num?)?.toInt() ?? 45;
  if (minutes <= 0 || minutes > 480) minutes = 45; // giá trị vô lý → mặc định

  return AiPlanTask(
    title: title,
    subject: (j['subject'] as String?)?.trim() ?? '💡 Khác',
    priority: priority,
    minutes: minutes,
  );
}