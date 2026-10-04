import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_router.dart';
import '../../../core/constants/subject_catalog.dart';
import '../../../core/pwa/pwa_service.dart';
import 'progress_engine.dart';

/// AI-5.1 — Phân tích & Nhận định Tiến độ.
///
/// Nguyên tắc: **chỉ nói điều số liệu thật chống lưng**. Prompt gửi kèm đúng
/// các con số đã tổng hợp bởi [ProgressEngine]; phần nhận định cục bộ
/// ([localInsight]) là đường dự phòng offline và cũng là mốc để so xem AI có
/// bịa thêm không.
abstract class ProgressInsights {
  /// Nhận định tức thời, không cần mạng — dựa thuần vào số liệu.
  ///
  /// Trả `null` khi chưa có gì để nói (tuần trắng) thay vì bịa một câu động viên.
  static String? localInsight(ProgressSnapshot snapshot) {
    final parts = <String>[];

    final delta = snapshot.weekDeltaPercent;
    if (delta != null && delta != 0) {
      parts.add(delta > 0
          ? 'Tuần này bạn học nhiều hơn $delta% so với tuần trước'
          : 'Tuần này bạn học ít hơn ${-delta}% so với tuần trước');
    }

    final strong = snapshot.subjects.where((s) => s.minutes > 0).toList();
    if (strong.isNotEmpty) {
      final top = strong.first;
      parts.add(
          '${AppSubjects.displayName(top.subject)} dẫn đầu với ${top.hours.toStringAsFixed(1)}h');
    }

    final neglected = snapshot.neglectedSubjects;
    if (neglected.isNotEmpty) {
      final names = neglected
          .take(2)
          .map((s) => AppSubjects.displayName(s.subject))
          .join(', ');
      parts.add('$names đã lâu chưa học lại');
    }

    if (parts.isEmpty) return null;
    return '${parts.join('. ')}.';
  }

  /// Prompt gửi AI — số liệu thật, yêu cầu nhận xét + hành động cụ thể.
  static String buildPrompt(ProgressSnapshot snapshot) {
    final buffer = StringBuffer()
      ..writeln('Bạn là AI Coach EduPulse. Dựa CHÍNH XÁC vào số liệu sau, '
          'hãy nhận xét ngắn gọn và đề xuất 2-3 hành động cụ thể cho tuần tới.')
      ..writeln()
      ..writeln('SỐ LIỆU THẬT (không được bịa thêm):')
      ..writeln('- Hôm nay: ${snapshot.today.studyMinutes} phút, hoàn thành '
          '${snapshot.today.tasksCompleted}/${snapshot.today.tasksTotal} nhiệm vụ.')
      ..writeln('- Tuần này: ${snapshot.week.totalMinutes} phút, hoàn thành '
          '${snapshot.week.tasksCompleted}/${snapshot.week.tasksTotal} nhiệm vụ.')
      ..writeln('- Tuần trước: ${snapshot.lastWeekMinutes} phút.');

    if (snapshot.subjects.isNotEmpty) {
      buffer.writeln('- Theo môn:');
      for (final s in snapshot.subjects.take(6)) {
        final understanding = s.avgUnderstanding == null
            ? ''
            : ', hiểu bài TB ${s.avgUnderstanding!.toStringAsFixed(1)}/5';
        buffer.writeln(
            '  + ${AppSubjects.displayName(s.subject)}: ${s.minutes} phút$understanding');
      }
    }

    if (snapshot.neglectedSubjects.isNotEmpty) {
      buffer.writeln('- Môn lâu chưa học: '
          '${snapshot.neglectedSubjects.map((s) => AppSubjects.displayName(s.subject)).join(', ')}.');
    }

    buffer
      ..writeln()
      ..writeln('YÊU CẦU:')
      ..writeln('- Nêu 1 nhận xét khách quan dựa trên số liệu trên.')
      ..writeln(
          '- Đề xuất 2-3 hành động điều chỉnh cụ thể, khả thi trong tuần.')
      ..writeln(
          '- Giọng nhẹ nhàng, không phán xét, không dùng số liệu không có ở trên.')
      ..writeln('- Trả lời tiếng Việt, tối đa 120 từ.');

    return buffer.toString();
  }

  /// Gọi AI lấy nhận định. Mất mạng / AI lỗi → trả `null` để UI dùng
  /// [localInsight] thay vì hiện lỗi kỹ thuật.
  static Future<String?> generate(ProgressSnapshot snapshot) async {
    if (!snapshot.hasData) return null;
    if (!PwaService.isOnline) return null;

    try {
      final raw = await AiRouter.chat(
        model: AIModel.defaultModel,
        history: const [],
        userMessage: buildPrompt(snapshot),
        searchWeb: false,
      );
      final text = raw.trim();
      if (text.isEmpty || text.startsWith('❌')) return null;
      return text;
    } catch (_) {
      return null;
    }
  }
}
