const BASE = 'https://api.tavily.com/search';

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.TAVILY_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'TAVILY_API_KEY not configured' });
  }

  const query = (req.query.q || '').toString().trim();
  if (!query) {
    return res.status(400).json({ error: 'Missing query' });
  }

  try {
    const r = await fetch(BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: apiKey,
        query,
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
