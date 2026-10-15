// Logic thuần cho cron dọn dữ liệu theo RETENTION (mục 2 chính sách lưu trữ).
//
// Chỉ xoá dữ liệu có thể xác định quá hạn bằng cột thời gian trên server.
// Các loại cache cục bộ (SharedPreferences) được xoá ở client khi vượt TTL.
const DAY_MS = 24 * 60 * 60 * 1000;

const RETENTION_CLEANUP = [
  {
    name: 'user_blobs_image',
    table: 'user_blobs',
    column: 'updated_at',
    ttlMs: 180 * DAY_MS,
    filter: { kind: 'image' },
  },
  {
    name: 'user_blobs_chat',
    table: 'user_blobs',
    column: 'updated_at',
    ttlMs: 30 * DAY_MS,
    filter: { kind: 'ai_chat' },
  },
  {
    name: 'family_reports',
    table: 'family_reports',
    column: 'created_at',
    ttlMs: 90 * DAY_MS,
  },
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
