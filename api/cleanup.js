// API cron dọn dữ liệu theo chính sách lưu trữ (RETENTION).
//
// Kích hoạt bởi Vercel Cron (GET /api/cleanup). Yêu cầu CRON_SECRET trong header
// Authorization: Bearer <CRON_SECRET> hoặc không bật nếu chưa cấu hình; tuy nhiên
// tốt nhất nên bảo vệ bằng CRON_SECRET khi deploy production.
const { getSupabase, ok, fail } = require('./_lib');
const { RETENTION_CLEANUP } = require('./cleanup_logic');

module.exports = async function handler(req, res) {
  // Chỉ cho phép cron gọi GET
  if (req.method !== 'GET') {
    return fail(res, 405, 'Chỉ hỗ trợ GET.');
  }

  // Bảo vệ đơn giản bằng CRON_SECRET (tùy cấu hình Vercel)
  const secret = process.env.CRON_SECRET || '';
  const auth = String(req.headers.authorization || '');
  if (secret) {
    if (!/^Bearer\s+/i.test(auth) || auth.replace(/^Bearer\s+/i, '').trim() !== secret) {
      return fail(res, 401, 'Không hợp lệ.');
    }
  }

  let supabase;
  try {
    supabase = getSupabase();
  } catch (e) {
    return fail(
      res,
      500,
      e.message || 'Máy chủ chưa cấu hình (SUPABASE_SERVICE_ROLE_KEY).',
    );
  }

  const now = Date.now();
  const result = { deleted: {}, errors: [] };

  for (const cfg of RETENTION_CLEANUP) {
    try {
      let q = supabase
        .from(cfg.table)
        .delete()
        .lt(cfg.column, new Date(now - cfg.ttlMs).toISOString())
        .select('id');

      if (cfg.filter) {
        for (const k of Object.keys(cfg.filter)) {
          q = q.eq(k, cfg.filter[k]);
        }
      }

      const { data, error } = await q;
      if (error) {
        result.errors.push({ cfg: cfg.name, table: cfg.table, error: error.message });
        continue;
      }
      const key = `${cfg.table}.${cfg.column}(${cfg.name})`;
      result.deleted[key] = (result.deleted[key] || 0) + (Array.isArray(data) ? data.length : 0);
    } catch (e) {
      result.errors.push({ cfg: cfg.name, table: cfg.table, error: String(e) });
    }
  }

  return ok(res, { ok: result.errors.length === 0, now, ...result });
};
