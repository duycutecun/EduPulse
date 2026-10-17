// Proxy cho Groq — AI chính của EduPulse (miễn phí & nhanh nhất).
//
// LÝ DO TỒN TẠI: giống `/api/openrouter` — key `GROQ_API_KEY` chỉ nằm phía
// server (process.env.GROQ_API_KEY), không bị nhúng vào bundle client, và
// request đi qua cùng origin nên không vướng vấn đề gọi API từ browser.
//
// BẠC HẠNG (spec M3.4 / BAN_THAY_DOI V2):
//  - Groq là provider MẶC ĐỊNH cho câu hỏi chỉ-text (first-token ~0.35s).
//  - KHÔNG dùng cho đọc ảnh: model free của Groq không nhận image input —
//    ảnh vẫn đi đường Gemini (client đã giữ nguyên nhánh `gemini/`).
//  - Khi Groq 429 / 5xx / timeout, client (AiRouter) tự thử model kế tiếp rồi
//    Gemini trong danh sách ứng viên — proxy này KHÔNG tự retry quá 1 lần
//    (chống vươn tay đốt hạn mức free ~30 RPM / ~1000 req/ngày).
//
// - GET  /api/groq → health check (trả `configured` boolean, KHÔNG lộ key).
// - POST /api/groq → Ủy https://api.groq.com/openai/v1/chat/completions
//   (chuẩn OpenAI-compatible), body nhận `{model, messages, max_tokens? |
//   maxTokens?, temperature?}`.
const BASE = 'https://api.groq.com/openai/v1';

const { guard } = require('./_guard');
const { normalizeChatRequest } = require('./_groq_logic');

const RATE_LIMIT_PER_MIN = 30;

module.exports = async function handler(req, res) {
  // Health check: mở thẳng /api/groq trên trình duyệt để biết máy chủ đã có
  // key chưa. Chỉ trả boolean — KHÔNG bao giờ trả giá trị key.
  if (req.method === 'GET') {
    return res.status(200).json({
      ok: true,
      configured: Boolean(process.env.GROQ_API_KEY),
      model: 'openai/gpt-oss-20b',
    });
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'GROQ_API_KEY not configured' });
  }

  const allowed = await guard(req, res, {
    endpoint: '/api/groq',
    limit: RATE_LIMIT_PER_MIN,
  });
  if (!allowed) return undefined;

  let raw;
  try {
    raw = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
  } catch (e) {
    return res.status(400).json({ error: 'Invalid JSON body' });
  }

  const parsed = normalizeChatRequest(raw);
  if (!parsed.ok) {
    return res.status(parsed.status).json({ error: parsed.error });
  }
  const { model, messages, temperature, max_tokens } = parsed;

  try {
    let attempt = 0;
    let r;
    while (true) {
      attempt += 1;
      r = await fetch(`${BASE}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages,
          temperature,
          max_tokens,
        }),
        signal: AbortSignal.timeout(45000),
      });
      if ((r.status === 500 || r.status === 502 || r.status === 503 || r.status === 504) && attempt < 2) {
        await sleep(1200);
        continue;
      }
      break;
    }
    const data = await r.text();
    res.status(r.status);
    res.setHeader('Content-Type', 'application/json');
    return res.send(data);
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    return res.status(502).json({ error: msg });
  }
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
