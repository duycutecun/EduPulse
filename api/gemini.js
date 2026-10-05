// Proxy cho Gemini (Google Generative Language API) — trung gian giữa
// Flutter web và generativelanguage.googleapis.com.
//
// LÝ DO TỒN TẠI: tránh lộ GEMINI_API_KEY trong bundle client và tránh lỗi
// request/vùng CORS khi chạy từ browser. Key chỉ đọc từ
// process.env.GEMINI_API_KEY phía server.
//
// - POST /api/gemini → :generateContent. Body nhận:
//     { model, contents, tools?, generationConfig? }
//   (model là tên sau prefix "gemini/", mặc định gemini-3.7-flash)
const BASE = 'https://generativelanguage.googleapis.com/v1beta';

module.exports = async function handler(req, res) {
  // Health check: mở thẳng /api/gemini trên trình duyệt để biết máy chủ đã có
  // key chưa. Chỉ trả boolean — KHÔNG bao giờ trả giá trị key.
  if (req.method === 'GET') {
    return res.status(200).json({
      ok: true,
      configured: Boolean(process.env.GEMINI_API_KEY),
      model: 'gemini-3.7-flash',
    });
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'GEMINI_API_KEY not configured' });
  }

  let raw;
  try {
    raw = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
  } catch (e) {
    return res.status(400).json({ error: 'Invalid JSON body' });
  }

  const model = typeof raw.model === 'string' && raw.model.trim()
    ? raw.model.trim()
    : 'gemini-3.7-flash';
  if (!Array.isArray(raw.contents) || raw.contents.length === 0) {
    return res.status(400).json({ error: 'Missing contents' });
  }

  // Bỏ field 'model' khỏi body gửi lên API (model nằm trong URL).
  const { model: _model, ...payload } = raw;

  try {
    let attempt = 0;
    let r;
    while (true) {
      attempt += 1;
      r = await fetch(
        `${BASE}/models/${encodeURIComponent(model)}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(45000),
        }
      );
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