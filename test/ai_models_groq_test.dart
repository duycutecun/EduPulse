// Test cấu hình AI mặc định sau khi Groq trở thành nhà cung cấp chính
// (BAN_THAY_DOI V2 M3.4): model mặc định là Groq gpt-oss-20b, Groq 120b là
// tùy chọn mạnh hơn, Gemini/OpenRouter vẫn giữ nguyên cho người dùng cũ.
import 'package:edupulse/core/ai/ai_models.dart';
import 'package:edupulse/core/ai/groq_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Model mặc định Groq (M3.4)', () {
    test('Người dùng chưa chọn model → Groq gpt-oss-20b (nhanh nhất)', () {
      expect(AIModel.defaultModel.slug, 'groq/openai/gpt-oss-20b');
      // fromSlug rỗng = chưa ghim → về mặc định, không phải 'openrouter/free'.
      expect(AIModel.fromSlug('').slug, 'groq/openai/gpt-oss-20b');
      expect(AIModel.fromSlug(null).slug, 'groq/openai/gpt-oss-20b');
    });

    test('Groq 120b có trong danh sách là tùy chọn mạnh hơn', () {
      final slugs = AIModel.definitions.map((m) => m.slug).toList();
      expect(slugs, contains('groq/openai/gpt-oss-120b'));
      expect(slugs.first, 'groq/openai/gpt-oss-20b'); // mặc định lên đầu
    });

    test('Đọc ảnh KHÔNG rời Gemini — Groq model free đều không vision', () {
      for (final m
          in AIModel.definitions.where((m) => GroqService.isGroqSlug(m.slug))) {
        expect(m.supportsVision, isFalse,
            reason: '${m.slug} chạy Groq free — không nhận image input');
      }
      expect(
        AIModel.definitions
            .where((m) => m.slug.startsWith('gemini/'))
            .every((m) => m.supportsVision),
        isTrue,
        reason: 'Ảnh vẫn cần model Gemini đọc được (decided)',
      );
    });

    test('Người dùng đã ghim model cũ không bị đổi theo mặc định', () {
      // Giả định model cũ người dùng chọn — fromSlug phải tôn trọng nó.
      const pinned = 'nvidia/nemotron-3-super-120b-a12b:free';
      expect(AIModel.fromSlug(pinned).slug, pinned);
      const gemini = 'gemini/gemini-3.7-flash';
      expect(AIModel.fromSlug(gemini).slug, gemini);
    });
  });

  group('GroqService helper', () {
    test('isGroqSlug chỉ nhận prefix groq/', () {
      expect(GroqService.isGroqSlug('groq/openai/gpt-oss-20b'), isTrue);
      expect(GroqService.isGroqSlug('openai/gpt-oss-20b:free'), isFalse);
      expect(GroqService.isGroqSlug('gemini/gemini-3.7-flash'), isFalse);
    });

    test('nativeModel bỏ prefix; model mạnh hơn vẫn đúng', () {
      expect(GroqService.nativeModel('groq/openai/gpt-oss-120b'),
          GroqService.strongModel);
      expect(GroqService.nativeModel('groq/'), GroqService.defaultModel);
    });
  });
}
