// Bảo vệ chung cho các proxy AI (`/api/openrouter`, `/api/gemini`, `/api/search`).
//
// LÝ DO: trước đây các endpoint này mở công khai — bất kỳ ai biết URL cũng gọi
// được, đốt hạn mức key của chủ app mà không để lại dấu vết. Module này thêm ba
// lớp phòng vệ tối thiểu nhưng không phá vỡ luồng ẩn danh:
//
//   1. **Định danh (tuỳ chọn nhưng ưu tiên).** Nếu client gửi `Authorization:
//      Bearer <Firebase ID token>`, xác thực token và dùng `uid` làm khoá hạn
//      mức. Không có token (người dùng chưa đăng nhập, ví dụ lúc onboarding) thì
//      rơi về IP — vẫn hoạt động, chỉ bị giới hạn theo IP.
//   2. **Giới hạn tần suất theo cửa sổ trượt** (mặc định 30 phút tuỳ chỉnh).
//      Bộ đếm trong RAM của instance; Vercel tái dùng instance ấm nên có tác
//      dụng thực, nhưng đây chỉ là tầng "best-effort" — không phải hàng rào
//      duy nhất. Nên đặt thêm hạn mức ở cấp nhà cung cấp (OpenRouter/Gemini/
//      Tavily) trong bảng điều khiển của họ.
//   3. **Quota theo NGÀY** — trần tổng lượt/ngày mỗi uid (hoặc IP ẩn danh), chặn
//      kiểu rải request đều đặn suốt ngày để đốt key. Logic thuần ở
//      `_guard_logic.js` (có test `node --test`).
//   4. **Nhật ký kiểm toán đã khử nhạy cảm** — chỉ ghi endpoint, uid/IP rút gọn,
//      trạng thái và mô hình. KHÔNG bao giờ ghi key, prompt hay nội dung body.
//
// Env vars liên quan: FIREBASE_API_KEY (để xác thực token), xem `_lib.js`.
// Có thể tuỳ chỉnh quota/endpoint qua env: AI_DAILY_QUOTA, AI_DAILY_QUOTA_ANON.

const { getFirebaseUser } = require('./_lib');
const {
  quotaKey,
  quotaLimitFor,
  checkQuota,
  quotaMessage,
} = require('./_guard_logic');

const WINDOW_MS = 60 * 1000; // cửa sổ trượt 1 phút

/// Trần mặc định mỗi phút khi caller quên truyền `limit` — không bao giờ để
/// hở chế độ "không giới hạn" (so sánh với undefined luôn sai).
const DEFAULT_RATE_LIMIT = 30;

/// Ngưỡng dọn Map: vượt ngưỡng thì quét bỏ entry hết hạn/không có resetAt.
const MAX_MAP_ENTRIES = 5000;

// uid/IP → { count, resetAt }
const _hits = new Map();

// uid/IP → { count, resetAt } cho quota theo ngày (cửa sổ 24h).
const _quota = new Map();

/** Dọn entry hết hạn khi Map phình to (instance ấm sống lâu — tránh rò rỉ RAM). */
function _sweep(map, now) {
  if (map.size <= MAX_MAP_ENTRIES) return;
  for (const [k, v] of map) {
    if (!v || now >= (v.resetAt || 0)) map.delete(k);
  }
}

/** Đọc trần quota từ env (chuỗi số dương) — dùng cho cấu hình vận hành. */
function _envQuota(name) {
  const raw = Number(process.env[name]);
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : undefined;
}

/** IP của người gọi, ưu tiên header proxy của Vercel. */
function clientIp(req) {
  const xff = req.headers && req.headers['x-forwarded-for'];
  const raw = Array.isArray(xff) ? xff[0] : xff;
  if (typeof raw === 'string' && raw.length) {
    return raw.split(',')[0].trim();
  }
  return (req.socket && req.socket.remoteAddress) || 'unknown';
}

/**
 * Xác thực header `Authorization: Bearer <idToken>` nếu có.
 *
 * Trả về `{ uid, email }` khi hợp lệ, `null` khi không có token. Ném lỗi khi
 * token CÓ nhưng không hợp lệ — lúc đó phải từ chối, không được âm thầm hạ cấp
 * xuống IP (kẻ tấn công chỉ cần gửi token rác để rơi vào nhánh IP).
 */
async function authenticate(req) {
  const header = req.headers && req.headers['authorization'];
  const value = Array.isArray(header) ? header[0] : header;
  if (!value || typeof value !== 'string') return null;
  const match = value.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  return getFirebaseUser(match[1].trim());
}

/**
 * Kiểm tra hạn mức cho `key` (uid hoặc IP) trong cửa sổ [WINDOW_MS].
 * Trả về `{ allowed, remaining, retryAfterSec }`.
 */
function rateLimit(key, limit) {
  const now = Date.now();
  _sweep(_hits, now);
  const max =
    Number.isFinite(limit) && limit > 0 ? Math.floor(limit) : DEFAULT_RATE_LIMIT;
  const entry = _hits.get(key);
  if (!entry || now >= entry.resetAt) {
    _hits.set(key, { count: 1, resetAt: now + WINDOW_MS });
    return { allowed: true, remaining: max - 1, retryAfterSec: 0 };
  }
  if (entry.count >= max) {
    return {
      allowed: false,
      remaining: 0,
      retryAfterSec: Math.max(1, Math.ceil((entry.resetAt - now) / 1000)),
    };
  }
  entry.count += 1;
  return { allowed: true, remaining: max - entry.count, retryAfterSec: 0 };
}

/** Rút gọn định danh để log mà không phơi toàn bộ uid/IP. */
function shortId(id) {
  const s = String(id || '');
  if (s.length <= 8) return s;
  return `${s.slice(0, 6)}…`;
}

/** Nhật ký kiểm toán một dòng, đã khử nhạy cảm. */
function audit(endpoint, { id, ip, status, model, note } = {}) {
  const parts = [`[ai-audit] ${endpoint}`, `status=${status}`];
  if (id) parts.push(`id=${shortId(id)}`);
  if (ip) parts.push(`ip=${shortId(ip)}`);
  if (model) parts.push(`model=${model}`);
  if (note) parts.push(`note=${note}`);
  // eslint-disable-next-line no-console
  console.log(parts.join(' '));
}

/**
 * Chạy trọn bộ bảo vệ: xác thực (tuỳ chọn) → hạn mức/phút → quota/ngày → ghi log.
 *
 * Trả về `{ id, ip }` khi được phép đi tiếp; ngược lại tự gửi 401/429 và trả
 * `null` (caller chỉ cần `if (!guard) return;`).
 *
 * `quota` (tuỳ chọn) đặt trần lượt/ngày riêng cho endpoint; bỏ trống thì dùng
 * mặc định theo loại định danh (xem `_guard_logic.js`).
 */
async function guard(req, res, { endpoint, limit, quota, model } = {}) {
  const ip = clientIp(req);
  let id = null;
  try {
    const user = await authenticate(req);
    if (user) id = user.uid;
  } catch (e) {
    audit(endpoint, { ip, status: 401, note: 'bad-token' });
    res.status(401).json({ error: 'Token đăng nhập không hợp lệ.' });
    return null;
  }

  const key = id ? `uid:${id}` : `ip:${ip}`;
  const rl = rateLimit(key, limit);
  if (!rl.allowed) {
    res.setHeader('Retry-After', String(rl.retryAfterSec));
    audit(endpoint, { id, ip, status: 429, note: 'rate-limit' });
    res.status(429).json({
      error: 'Quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.',
    });
    return null;
  }

  const qKey = quotaKey(id, ip);
  const qLimit = quotaLimitFor(
    id,
    quota ?? (id ? _envQuota('AI_DAILY_QUOTA') : _envQuota('AI_DAILY_QUOTA_ANON'))
  );
  _sweep(_quota, Date.now());
  const q = checkQuota(_quota, qKey, Date.now(), qLimit);
  if (!q.allowed) {
    res.setHeader('Retry-After', String(q.retryAfterSec));
    audit(endpoint, { id, ip, status: 429, note: 'daily-quota' });
    res.status(429).json({ error: quotaMessage() });
    return null;
  }

  audit(endpoint, { id, ip, status: 200, model });
  return { id, ip };
}

module.exports = { guard, authenticate, rateLimit, clientIp, audit, DEFAULT_RATE_LIMIT };

