import 'ai_context.dart';

class ContextOptimizer {
  static String optimize(String context, AiContextLevel level) {
    if (context.isEmpty) return context;

    final lines = context.split('\n');
    final priority = _priorityLines(lines);
    final secondary = _secondaryLines(lines);

    final buffer = StringBuffer();
    var currentLength = 0;
    final cap = _capFor(level);

    for (final line in priority) {
      if (currentLength + line.length > cap) break;
      buffer.writeln(line);
      currentLength += line.length;
    }

    for (final line in secondary) {
      if (currentLength + line.length > cap) break;
      buffer.writeln(line);
      currentLength += line.length;
    }

    return buffer.toString().trimRight();
  }

  static List<String> _priorityLines(List<String> lines) {
    final priorityKeywords = [
      'SẴN SÀNG THI',
      'NHIỆM VỤ',
      'ĐIỂM THI THỬ',
      'KỲ THI CHÍNH',
      'PHIÊN FOCUS',
      'HỌC SINH',
      'ĐỘNG LỰC',
    ];
    return lines.where((line) {
      return priorityKeywords.any((k) => line.contains(k));
    }).toList();
  }

  static List<String> _secondaryLines(List<String> lines) {
    final priorityKeywords = [
      'SẴN SÀNG THI',
      'NHIỆM VỤ',
      'ĐIỂM THI THỬ',
      'KỲ THI CHÍNH',
      'PHIÊN FOCUS',
      'HỌC SINH',
      'ĐỘNG LỰC',
    ];
    return lines.where((line) {
      return !priorityKeywords.any((k) => line.contains(k));
    }).toList();
  }

  static int _capFor(AiContextLevel level) {
    switch (level) {
      case AiContextLevel.none:
        return 0;
      case AiContextLevel.task:
        return 1200;
      case AiContextLevel.today:
        return 1500;
      case AiContextLevel.learningProfile:
        return 2000;
      case AiContextLevel.full:
        return 2500;
    }
  }

  static AiContextLevel suggestLevel(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('bài này') || lower.contains('bài học')) {
      return AiContextLevel.task;
    }
    if (lower.contains('hôm nay') || lower.contains('bây giờ')) {
      return AiContextLevel.today;
    }
    if (lower.contains('kế hoạch') || lower.contains('phân tích')) {
      return AiContextLevel.full;
    }
    return AiContextLevel.learningProfile;
  }
}
