// Test cho `_groq_logic.js` — chạy bằng `node --test` (không cần mạng/key).
// Bao phủ chuẩn hoá body của proxy `/api/groq` trước khi Ủy lên Groq API.
const test = require('node:test');
const assert = require('node:assert/strict');

const logic = require('./_groq_logic');

const validRaw = {
  model: 'openai/gpt-oss-20b',
  messages: [{ role: 'user', content: 'Xin chào' }],
};

test('max_tokens: chấp nhận cả maxTokens (camelCase) (đặc tả hợp đồng API)', () => {
  for (const key of ['max_tokens', 'maxTokens']) {
    const raw = { ...validRaw, [key]: 2000 };
    const out = logic.normalizeChatRequest(raw);
    assert.equal(out.ok, true);
    assert.equal(out.max_tokens, 2000);
  }
});

test('normalizeChatRequest: body chuẩn đi qua nguyên vẹn', () => {
  const out = logic.normalizeChatRequest({
    model: 'openai/gpt-oss-120b',
    messages: [
      { role: 'system', content: 'system-msg' },
      { role: 'user', content: 'một câu hỏi' },
    ],
    temperature: 0.3,
    max_tokens: 1500,
  });
  assert.equal(out.ok, true);
  assert.equal(out.model, 'openai/gpt-oss-120b');
  assert.equal(out.temperature, 0.3);
  assert.equal(out.max_tokens, 1500);
  assert.equal(out.messages.length, 2);
});

test('max_tokens: mặc định + trần khiêm tốn đúng giới hạn free của Groq', () => {
  // Thiếu → mặc định ~1200 (TPM free chỉ ~8K, tính cả max_tokens của request).
  assert.equal(logic.normalizeChatRequest(validRaw).max_tokens, logic.DEFAULT_MAX_TOKENS);
  assert.equal(logic.DEFAULT_MAX_TOKENS, 1200);
  // Rất lớn → bị kẹp về trần, không gửi khối lượng vượt hạn mức.
  const big = logic.normalizeChatRequest({ ...validRaw, max_tokens: 100000 });
  assert.equal(big.max_tokens, logic.MAX_TOKENS_CEILING);
  // Nhỏ/âm/NaN → khép về biên hợp lệ.
  assert.equal(
    logic.normalizeChatRequest({ ...validRaw, max_tokens: -5 }).max_tokens, 1);
  assert.equal(
    logic.normalizeChatRequest({ ...validRaw, max_tokens: 'nhiều' }).max_tokens,
    logic.DEFAULT_MAX_TOKENS);
});

test('temperature: mặc định 0.6, kẹp biên 0..2', () => {
  assert.equal(
    logic.normalizeChatRequest(validRaw).temperature, logic.DEFAULT_TEMPERATURE);
  assert.equal(
    logic.normalizeChatRequest({ ...validRaw, temperature: 3 }).temperature, 2);
  assert.equal(
    logic.normalizeChatRequest({ ...validRaw, temperature: -1 }).temperature, 0);
});

test('Lỗi body: thiếu model / thiếu messages / sai kiểu trả đúng status', () => {
  assert.deepEqual(
    logic.normalizeChatRequest({ messages: [{ role: 'user', content: 'x' }] }),
    { ok: false, status: 400, error: 'Missing model' });
  assert.deepEqual(
    logic.normalizeChatRequest({ model: 'openai/gpt-oss-20b' }),
    { ok: false, status: 400, error: 'Missing messages' });
  assert.deepEqual(
    logic.normalizeChatRequest({ model: 'm', messages: 'chưa phải mảng' }),
    { ok: false, status: 400, error: 'Missing messages' });
});

test('sanitizeMessages: cắt bớt message/text quá dài', () => {
  const long = 'x'.repeat(21000);
  const out = logic.sanitizeMessages(
      [{ role: 'user', content: long }], 20000);
  assert.equal(out.length, 1);
  assert.equal(out[0].content.length, 20000); // text bị cắt đúng trần
});

test('sanitizeMessages: content object giữ nguyên khi dưới trần', () => {
  const parts = [{ type: 'text', text: 'giải giúp' }];
  const msg = { role: 'user', content: parts };
  const out = logic.sanitizeMessages([msg], 20000);
  // Dưới trần: content giữ nguyên dạng object/mảng (giống /api/openrouter).
  assert.deepEqual(out[0].content, parts);
});
