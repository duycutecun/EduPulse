const BASE = 'https://api.tavily.com/search';

// Fixed-window rate limit đơn giản (in-memory).
// Chạy trong serverless/multi-instance nên chỉ là mức ngăn cơ bản, không phải
// hàng rào bảo mật cứng. Đủ để chặn spam/thăm dò liên tục từ một IP.
const MAX_QUERY_LEN = 200;
const WINDOW_MS = 60 * 1000; // 1 phút
const MAX_REQ_PER_WINDOW = 15;

const rateBuckets = new Map(); // key = ip, value = { count, resetAt }

function getClientIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  if (fwd) {
    return String(fwd).split(',')[0].trim();
  }
  return req.socket && req.socket.remoteAddress
    ? String(req.socket.remoteAddress)
    : 'unknown';
}

function isRateLimited(ip, now) {
  const nowMs = now.getTime();
  const b = rateBuckets.get(ip);
  if (!b || b.resetAt <= nowMs) {
    rateBuckets.set(ip, { count: 1, resetAt: nowMs + WINDOW_MS });
    return false;
  }
  b.count += 1;
  if (b.count > MAX_REQ_PER_WINDOW) {
    return true;
  }
  return false;
}

// Dọn bucket cũ để tránh rò rỉ bộ nhớ (gọi thỉnh thoảng).
function pruneBuckets(now) {
  const nowMs = now.getTime();
  for (const [k, b] of rateBuckets) {
    if (b.resetAt <= nowMs) {
      rateBuckets.delete(k);
    }
  }
}

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const now = new Date();
  pruneBuckets(now);

  const ip = getClientIp(req);
  if (isRateLimited(ip, now)) {
    res.setHeader('Retry-After', '60');
    return res.status(429).json({ error: 'Too many requests. Try again later.' });
  }

  const apiKey = process.env.TAVILY_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'TAVILY_API_KEY not configured' });
  }

  const rawQuery = (req.query.q || '').toString().trim();
  if (!rawQuery) {
    return res.status(400).json({ error: 'Missing query' });
  }
  if (rawQuery.length > MAX_QUERY_LEN) {
    return res.status(400).json({ error: 'Query too long' });
  }

  try {
    const r = await fetch(BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: apiKey,
        query: rawQuery,
        max_results: 3,
        search_depth: 'basic',
        include_answer: true,
      }),
      signal: AbortSignal.timeout(15000),
    });

    const data = await r.json();
    if (!r.ok) {
      return res.status(r.status).json({ error: data && data.detail ? data.detail : 'Tavily error' });
    }

    let title = 'Tavily';
    let extract = (data.answer || '').trim();
    let pageUrl = 'https://tavily.com';

    if (!extract && Array.isArray(data.results) && data.results.length > 0) {
      const first = data.results[0];
      extract = (first.content || '').trim();
      title = (first.title || 'Kết quả').trim();
      pageUrl = (first.url || '').trim() || pageUrl;
    }

    if (!extract) {
      return res.status(404).json({ error: 'No results' });
    }

    return res.status(200).json({ title, extract, pageUrl });
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    return res.status(502).json({ error: msg });
  }
};
