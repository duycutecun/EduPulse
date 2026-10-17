// Logic thuần của `_guard.js` — tách riêng để test bằng `node --test` mà KHÔNG
// cần mạng/Supabase hay biến môi trường. Chỉ tính toán, không gọi mạng.
//
// Vì sao cần quota theo NGÀY (ngoài rate limit theo phút): rate limit chỉ chặn
// burst trong 1 phút, nhưng một client vẫn có thể rải đều 30 req/phút suốt ngày
// và đốt hạn mức key của chủ app. Quota đặt trần tổng số lượt/ngày cho mỗi
// uid (đã đăng nhập) hoặc IP (ẩn danh, ví dụ lúc onboarding).

/// Cửa sổ quota: 24 giờ.
const QUOTA_WINDOW_MS = 24 * 60 * 60 * 1000;

/// Trần lượt gọi AI mỗi ngày cho một tài khoản đã đăng nhập. Đủ rộng cho học
/// sinh dùng thật, đủ chặt để một uid bị lộ không đốt hết key trong ngày.
const DEFAULT_QUOTA_PER_DAY = 200;

/// Trần lượt gọi AI mỗi ngày cho một IP ẩn danh (chưa đăng nhập). Thấp hơn
/// nhiều vì IP dùng chung (wifi trường, NAT nhà mạng) và không truy vết được.
const DEFAULT_QUOTA_PER_DAY_ANON = 40;

/** Khoá quota: ưu tiên uid, không có thì theo IP. */
function quotaKey(id, ip) {
  return id ? `uid:${id}` : `ip:${ip}`;
}

/**
 * Trần quota cho một định danh. `override` (tuỳ chọn theo endpoint) chỉ được
 * dùng khi là số dương; ngược lại rơi về mặc định theo loại định danh.
 */
function quotaLimitFor(id, override) {
  if (Number.isFinite(override) && override > 0) return Math.floor(override);
  return id ? DEFAULT_QUOTA_PER_DAY : DEFAULT_QUOTA_PER_DAY_ANON;
}

/**
 * Kiểm tra và tăng bộ đếm quota trong `store` (Map) cho `key`.
 *
 * Trả về `{ allowed, remaining, retryAfterSec }` cùng dạng với `rateLimit`
 * trong `_guard.js`. `nowMs` truyền vào để test được thời gian.
 */
function checkQuota(store, key, nowMs, limit) {
  const entry = store.get(key);
  if (!entry || nowMs >= entry.resetAt) {
    store.set(key, { count: 1, resetAt: nowMs + QUOTA_WINDOW_MS });
    return { allowed: true, remaining: limit - 1, retryAfterSec: 0 };
  }
  if (entry.count >= limit) {
    return {
      allowed: false,
      remaining: 0,
      retryAfterSec: Math.max(1, Math.ceil((entry.resetAt - nowMs) / 1000)),
    };
  }
  entry.count += 1;
  return { allowed: true, remaining: limit - entry.count, retryAfterSec: 0 };
}

/** Thông báo tiếng Việt khi vượt quota — khớp ĐÚNG ngữ nghĩa cửa sổ trượt 24h
 * (không hứa "ngày mai" vì hạn mức tự mở lại sau 24 giờ kể từ lượt đầu). */
function quotaMessage() {
  return 'Bạn đã dùng hết lượt AI miễn phí trong 24 giờ qua. Vui lòng thử lại sau.';
}

module.exports = {
  QUOTA_WINDOW_MS,
  DEFAULT_QUOTA_PER_DAY,
  DEFAULT_QUOTA_PER_DAY_ANON,
  quotaKey,
  quotaLimitFor,
  checkQuota,
  quotaMessage,
};
