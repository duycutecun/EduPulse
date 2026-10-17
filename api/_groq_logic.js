// Logic thuần của `api/groq.js` — tách riêng để test bằng `node --test` mà
// KHÔNG cần mạng hay biến môi trường. Chỉ tính toán/định dạng, không gọi mạng.
//
// Groq free tier (`console.groq.com`) có giới hạn đáng kể hơn OpenRouter:
//  - ~30 RPM, ~1000 req/ngày, ~8K tokens/phút (tính CẢ `max_tokens` của
//    request). Vì thế `max_tokens` mặc định của proxy này đặt khiêm tốn
//    (~1200) thay vì 2048 như `/api/openrouter` — request bị từ chối vì
//    vượt TPM chỉ tổ đốt lượt rồi phải thử lại.
//
// Export các hàm thuần để `groq.js` dùng và `_groq_logic.test.js` kiểm.

const MAX_MESSAGES = 60;
const MAX_HISTORY_TEXT_LEN = 20000;

const DEFAULT_TEMPERATURE = 0.6;
const DEFAULT_MAX_TOKENS = 1200;
// Trần cứng của request từ client — modest cho tốc độ và hạn mức TPM free.
const MAX_TOKENS_CEILING = 4000;
const MIN_TOKENS = 1;

/** Độ dài nội dung của một message, kể cả khi content là object/mảng. */
function contentLength(m) {
  return typeof m.content === 'string'
    ? m.content.length
    : JSON.stringify(m.content || '').length;
}

/** Cắt bớt và chuẩn hoá danh sách messages — bỏ phần tử rác, chặn payload
 * khổng lồ từ client lạ (giống hành vi của `/api/openrouter`). */
function sanitizeMessages(messages, maxHistoryTextLen) {
  return messages.slice(0, MAX_MESSAGES).map((m) => {
    const len = contentLength(m);
    if (len > maxHistoryTextLen) {
      return { ...m, content: JSON.stringify(m.content).slice(0, maxHistoryTextLen) };
    }
    return m;
  });
}

/**
 * Chuẩn hoá body POST của `/api/groq`.
 *
 * Nhận `{model, messages, temperature?, max_tokens? | maxTokens?}` (người gọi
 * có thể dùng camelCase `maxTokens` như hợp đồng trong tài liệu, hoặc
 * snake_case chuẩn OpenAI). Trả `{ok: true, model, messages, temperature,
 * max_tokens}` hoặc `{ok: false, status, error}` (400) khi body sai.
 */
function normalizeChatRequest(raw) {
  const { model, messages, temperature } = raw || {};
  if (typeof model !== 'string' || model.trim() === '') {
    return { ok: false, status: 400, error: 'Missing model' };
  }
  if (!Array.isArray(messages) || messages.length === 0) {
    return { ok: false, status: 400, error: 'Missing messages' };
  }

  // Chấp nhận cả hai dạng tên field.
  const requestedTokens = Number.isFinite(raw.max_tokens)
    ? raw.max_tokens
    : raw.maxTokens;
  const maxTokens = Number.isFinite(requestedTokens)
    ? Math.min(Math.max(Math.round(requestedTokens), MIN_TOKENS), MAX_TOKENS_CEILING)
    : DEFAULT_MAX_TOKENS;
  const temp = Number.isFinite(temperature)
    ? Math.min(Math.max(temperature, 0), 2)
    : DEFAULT_TEMPERATURE;

  return {
    ok: true,
    model: model.trim(),
    messages: sanitizeMessages(messages, MAX_HISTORY_TEXT_LEN),
    temperature: temp,
    max_tokens: maxTokens,
  };
}

module.exports = {
  MAX_MESSAGES,
  MAX_HISTORY_TEXT_LEN,
  DEFAULT_TEMPERATURE,
  DEFAULT_MAX_TOKENS,
  MAX_TOKENS_CEILING,
  normalizeChatRequest,
  sanitizeMessages,
};
