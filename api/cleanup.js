// API cron dọn dữ liệu theo chính sách lưu trữ (RETENTION).
//
// Kích hoạt bởi Vercel Cron (GET /api/cleanup) với header
// `Authorization: Bearer <CRON_SECRET>`. KHÔNG cấu hình CRON_SECRET ⇒ endpoint
// từ chối chạy (fail closed): đây là thao tác xoá dữ liệu vĩnh viễn, thà cron
// không chạy còn hơn để bất kỳ ai gọi URL cũng xoá được dữ liệu người dùng.
const { createHash, timingSafeEqual } = require('node:crypto');
const { getSupabase, ok, fail } = require('./_lib');
const { RETENTION_CLEANUP } = require('./_cleanup_logic');

/** So sánh chuỗi bí mật hằng thời gian (băm trước để độ dài luôn bằng nhau). */
function secretMatches(actual, expected) {
  const a = createHash('sha256').update(String(actual)).digest();
  const b = createHash('sha256').update(String(expected)).digest();
  return timingSafeEqual(a, b);
}

module.exports = async function handler(req, res) {
  // Chỉ cho phép cron gọi GET
  if (req.method !== 'GET') {
    return fail(res, 405, 'Chỉ hỗ trợ GET.');
  }

  // Bảo vệ BẮT BUỘC bằng CRON_SECRET (xem ghi chú đầu file).
  const secret = process.env.CRON_SECRET || '';
  if (!secret) {
    return fail(res, 503, 'Máy chủ chưa cấu hình CRON_SECRET — cron bị từ chối.');
  }
  const auth = String(req.headers.authorization || '');
  const token = /^Bearer\s+/i.test(auth)
    ? auth.replace(/^Bearer\s+/i, '').trim()
    : '';
  if (!token || !secretMatches(token, secret)) {
    return fail(res, 401, 'Không hợp lệ.');
  }

  let supabase;
  try {
    supabase = getSupabase();
  } catch (e) {
    return fail(res, 500, 'Máy chủ chưa cấu hình đầy đủ.');
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
        // KHÔNG trả chi tiết lỗi DB ra ngoài (lộ tên bảng/cột); chỉ báo mã lỗi.
        result.errors.push({ cfg: cfg.name, table: cfg.table, error: 'delete_failed' });
        continue;
      }
      const key = `${cfg.table}.${cfg.column}(${cfg.name})`;
      result.deleted[key] = (result.deleted[key] || 0) + (Array.isArray(data) ? data.length : 0);
    } catch (e) {
      result.errors.push({ cfg: cfg.name, table: cfg.table, error: 'delete_failed' });
    }
  }

  return ok(res, { ok: result.errors.length === 0, now, ...result });
};
