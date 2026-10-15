// Logic thuần cho cron dọn dữ liệu theo RETENTION (mục 2 chính sách lưu trữ).
//
// Chỉ xoá dữ liệu có thể xác định quá hạn bằng cột thời gian trên server.
// Các loại cache cục bộ (SharedPreferences) được xoá ở client khi vượt TTL.
const DAY_MS = 24 * 60 * 60 * 1000;

const RETENTION_CLEANUP = [
  {
    // Ảnh/đính kèm đề bài lưu trên máy chủ (user_blobs). Bảng KHÔNG có cột
    // `kind` — trước đây lọc theo `kind` khiến lệnh xoá lỗi 42703 và TTL 180
    // ngày không bao giờ chạy; nay áp trực tiếp theo `updated_at`.
    name: 'user_blobs',
    table: 'user_blobs',
    column: 'updated_at',
    ttlMs: 180 * DAY_MS,
  },
  {
    name: 'family_reports',
    table: 'family_reports',
    column: 'created_at',
    ttlMs: 90 * DAY_MS,
  },
  {
    // Mã OTP hết hạn (xác minh email / đặt lại mật khẩu): xoá ngay khi hết hạn
    // (ttlMs = 0 ⇒ cắt tại thời điểm hiện tại).
    name: 'email_codes_expired',
    table: 'email_codes',
    column: 'expires_at',
    ttlMs: 0,
  },
  // Lịch sử chat AI chỉ lưu CỤC BỘ trên máy (SharedPreferences), không có bản
  // trên máy chủ — TTL 30 ngày do client tự dọn, không cần cron.
];

function cutoffMs(nowMs, ttlMs) {
  if (ttlMs == null) return Number.NaN;
  const now = Number(nowMs) || Date.now();
  return now - ttlMs;
}

function isExpired(updatedAtMs, ttlMs, nowMs) {
  if (ttlMs == null) return false;
  if (updatedAtMs == null) return false;
  const updated = Number(updatedAtMs);
  if (!Number.isFinite(updated)) return false;
  const now = Number(nowMs) || Date.now();
  return now - updated > ttlMs;
}

module.exports = {
  DAY_MS,
  RETENTION_CLEANUP,
  cutoffMs,
  isExpired,
};
