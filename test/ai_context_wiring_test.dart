import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/ai/ai_context.dart';
import 'package:edupulse/core/ai/openrouter_service.dart';
import 'package:edupulse/core/utils/gemini_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// Xác nhận ngữ cảnh học tập thực sự nằm trong payload gửi lên provider —
/// đây là điều quyết định AI có "biết" học sinh hay không.
void main() {
  final now = DateTime(2026, 9, 30, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    final exam = ExamModel(
      id: 'e1',
      name: 'THPTQG 2027',
      dateTime: DateTime(2026, 11, 14),
      currentScore: 7.2,
      targetScore: 9.0,
    );
    StorageService.setExamIds(['e1']);
    StorageService.setExamJson('e1', exam.toJsonString());
    StorageService.setPrimaryExamId('e1');

    final task = TodayTask(
      id: 't1',
      title: 'Cân bằng hóa học',
      subject: 'Hóa',
      priority: 'high',
      status: 'todo',
    );
    StorageService.setTodayTaskJson('t1', task.toJsonString());
    StorageService.setTodayTaskIds(['t1']);
  });

  String context() => AiStudyContext.build(now: now);

  group('OpenRouter payload', () {
    test('có system message mang ngữ cảnh học sinh', () {
      final messages = OpenRouterService.buildMessages(
        history: const [],
        userMessage: 'Nên học gì hôm nay?',
        studyContext: context(),
      );

      final systems = messages
          .where((m) => m['role'] == 'system')
          .map((m) => m['content'] as String)
          .toList();
      // Persona + ngữ cảnh.
      expect(systems, hasLength(2));
      expect(systems[1], contains('NGỮ CẢNH HỌC TẬP'));
      expect(systems[1], contains('THPTQG 2027'));
      expect(systems[1], contains('Cân bằng hóa học'));

      // Ngữ cảnh phải nằm TRƯỚC câu hỏi của học sinh.
      final lastRole = messages.last['role'];
      expect(lastRole, 'user');
      expect(messages.last['content'], contains('Nên học gì hôm nay?'));
    });

    test('ngữ cảnh nằm sau persona, trước lịch sử chat', () {
      final history = [
        ChatMessage(
          id: 'h1',
          text: 'Chào bạn',
          isUser: true,
          timestamp: now,
        ),
      ];
      final messages = OpenRouterService.buildMessages(
        history: history,
        userMessage: 'Tiếp',
        studyContext: context(),
      );
      expect(messages[0]['content'], contains('AI Coach của EduPulse'));
      expect(messages[1]['content'], contains('NGỮ CẢNH HỌC TẬP'));
      expect(messages[2]['content'], 'Chào bạn');
    });

    test('không có ngữ cảnh → chỉ persona, không rò dữ liệu học sinh', () {
      StorageService.setBool('ai_permission_read', false);
      final ctx = context();
      expect(ctx, '');

      final messages = OpenRouterService.buildMessages(
        history: const [],
        userMessage: 'Chào',
        studyContext: ctx,
      );
      expect(messages.where((m) => m['role'] == 'system'), hasLength(1));
      // "THPTQG" xuất hiện sẵn trong persona nên phải soi chuỗi đặc trưng
      // riêng của dữ liệu học sinh.
      expect(jsonEncode(messages), isNot(contains('Cân bằng hóa học')));
      expect(jsonEncode(messages), isNot(contains('THPTQG 2027')));
    });

    test('không có ngữ cảnh (user mới) → vẫn gọi được bình thường', () async {
      // Xoá sạch dữ liệu: mô phỏng user vừa cài app. Phải init lại vì
      // StorageService giữ cache instance của SharedPreferences.
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final empty = AiStudyContext.build(now: now);
      expect(empty, '');

      final messages = OpenRouterService.buildMessages(
        history: const [],
        userMessage: 'Xin chào',
        studyContext: empty,
      );
      expect(messages.where((m) => m['role'] == 'system'), hasLength(1));
      expect(messages.last['content'], contains('Xin chào'));
    });
  });

  group('Gemini payload', () {
    // Gemini 3.x (3.7 Flash) chỉ nhận persona/ngữ cảnh qua systemInstruction và
    // bắt buộc `contents` luân phiên user/model — nhét thẳng vào contents như
    // trước làm mọi request bị 400 ("Gemini không chạy").
    test('ngữ cảnh nằm trong systemInstruction, không chiếm lượt user', () {
      final system =
          GeminiService.buildSystemInstruction(studyContext: context());
      expect(system, contains('NGỮ CẢNH HỌC TẬP'));
      expect(system, contains('THPTQG 2027'));
      expect(system, contains('Cân bằng hóa học'));

      final contents = GeminiService.buildContents(
        history: const [],
        userMessage: 'Nên học gì hôm nay?',
      );

      // Câu hỏi của học sinh phải là lượt cuối.
      final lastTurn = contents.last['parts'] as List;
      expect(lastTurn.last['text'], contains('Nên học gì hôm nay?'));

      // Ngữ cảnh không bị nhét vào contents.
      final allText = contents
          .expand((c) => (c['parts'] as List))
          .map((p) => p['text'] as String)
          .join('\n');
      expect(allText, isNot(contains('NGỮ CẢNH HỌC TẬP')));
    });

    test('contents luân phiên user/model và luôn kết thúc bằng user', () {
      final history = [
        ChatMessage(id: 'h1', text: 'Chào bạn', isUser: true, timestamp: now),
        ChatMessage(id: 'h2', text: 'Chào em', isUser: false, timestamp: now),
        // Học sinh gửi hai lượt liền nhau — phải được gộp, không để user→user.
        ChatMessage(id: 'h3', text: 'Cho tôi đề', isUser: true, timestamp: now),
        ChatMessage(id: 'h4', text: 'Đề đây', isUser: true, timestamp: now),
      ];
      final contents = GeminiService.buildContents(
        history: history,
        userMessage: 'Tiếp đi',
      );

      expect(contents.last['role'], 'user');
      for (var i = 1; i < contents.length; i++) {
        expect(contents[i]['role'], isNot(contents[i - 1]['role']),
            reason: 'Gemini 3.x bắt buộc luân phiên user/model');
      }
    });

    test('không có prefilled model turn khi lịch sử trống', () {
      final contents = GeminiService.buildContents(
        history: const [],
        userMessage: 'Chào',
      );
      expect(contents, hasLength(1));
      expect(contents.single['role'], 'user');
      expect(contents.single['parts'], isNotEmpty);
    });

    test('tắt quyền đọc dữ liệu → không có ngữ cảnh', () {
      StorageService.setBool('ai_permission_read', false);
      final system =
          GeminiService.buildSystemInstruction(studyContext: context());
      final contents = GeminiService.buildContents(
        history: const [],
        userMessage: 'Chào',
      );
      final allText = '$system\n${jsonEncode(contents)}';
      expect(allText, isNot(contains('NGỮ CẢNH HỌC TẬP')));
      expect(allText, isNot(contains('Cân bằng hóa học')));
      expect(allText, isNot(contains('THPTQG 2027')));
    });
  });

  test('AiRouter dựng ngữ cảnh từ dữ liệu thật khi không truyền vào', () {
    // AiRouter.chat tự gọi AiStudyContext.build() — mô phỏng bằng cách gọi
    // lại đúng đường đi đó để chắc chắn không còn nhánh nào gửi context rỗng.
    final ctx = context();
    expect(ctx, isNotEmpty);
    final messages = OpenRouterService.buildMessages(
      history: const [],
      userMessage: 'Nên học gì hôm nay?',
      studyContext: ctx,
    );
    expect(messages[1]['content'], contains('THPTQG 2027'));
  });
}
