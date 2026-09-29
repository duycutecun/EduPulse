// Proxy cho OpenRouter — trung gian giữa Flutter web và OpenRouter API.
//
// LÝ DO TỒN TẠI: OpenRouter chặn CORS từ trình duyệt (giới hạn chính thức của họ),
// nên Flutter web không thể gọi https://openrouter.ai trực tiếp. Qua endpoint cùng
// origin này (giống /api/search cho Tavily), key OpenRouter chỉ nằm phía server
// (process.env.OPENROUTER_API_KEY), không bị lộ trong bundle client.
//
// - GET  /api/openrouter → danh sách model (Ủy OpenRouter /api/v1/models).
// - POST /api/openrouter → chat completions (Ủy /api/v1/chat/completions).
const BASE = 'https://openrouter.ai/api/v1';

const MAX_MESSAGES = 60;
const MAX_HISTORY_TEXT_LEN = 20000;

async function forwardChat(req, res) {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'OPENROUTER_API_KEY not configured' });
  }

  let raw;
  try {
    raw = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
  } catch (e) {
    return res.status(400).json({ error: 'Invalid JSON body' });
  }

  const { model, messages, temperature, max_tokens } = raw || {};
  if (typeof model !== 'string' || model.trim() === '') {
    return res.status(400).json({ error: 'Missing model' });
  }
  if (!Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'Missing messages' });
  }

  // Giới hạn lỏng phòng trường hợp client lạ gửi payload khổng lồ.
  const safeMessages = messages.slice(0, MAX_MESSAGES).map((m) => {
    const textLen = typeof m.content === 'string'
      ? m.content.length
      : JSON.stringify(m.content || '').length;
    return {
      ...m,
      content: textLen > MAX_HISTORY_TEXT_LEN ? JSON.stringify(m.content).slice(0, MAX_HISTORY_TEXT_LEN) : m.content,
    };
  });
  const maxTokens = Number.isFinite(max_tokens)
    ? Math.min(Math.max(Math.round(max_tokens), 1), 4096)
    : 2048;
  const temp = Number.isFinite(temperature) ? Math.min(Math.max(temperature, 0), 2) : 0.6;

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
          'HTTP-Referer': 'https://edu-pulse-five.vercel.app',
          'X-Title': 'EduPulse',
        },
        body: JSON.stringify({
          model,
          messages: safeMessages,
          temperature: temp,
          max_tokens: maxTokens,
        }),
        signal: AbortSignal.timeout(50000),
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
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function forwardModels(req, res) {
  try {
    const r = await fetch(`${BASE}/models`, {
      signal: AbortSignal.timeout(15000),
    });
    const data = await r.text();
    res.status(r.status);
    res.setHeader('Content-Type', 'application/json');
    return res.send(data);
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    return res.status(502).json({ error: msg });
  }
}

module.exports = async function handler(req, res) {
  if (req.method === 'GET') return forwardModels(req, res);
  if (req.method === 'POST') return forwardChat(req, res);
  return res.status(405).json({ error: 'Method not allowed' });
};