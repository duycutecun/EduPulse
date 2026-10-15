// Logic thuần của API `account.js` — tách riêng để test bằng `node --test` mà
// KHÔNG cần Firebase/Supabase. Chỉ soạn danh sách việc cần xoá và mô tả chính
// sách lưu trữ; handler thực thi bằng service_role.
//
// BỐI CẢNH (đặc tả mục 8, dòng 214): ảnh đề bài, lịch sử chat và dữ liệu AI
// cần có thời hạn lưu/cache rõ ràng VÀ cơ chế xoá dữ liệu cá nhân. Tệp này là
// nguồn duy nhất mô tả hai thứ đó ở tầng server.

const DAY_MS = 24 * 60 * 60 * 1000;

/// Chính sách lưu trữ/cache công bố cho người dùng. `ttlMs` = thời gian sống
/// tối đa của loại dữ liệu đó; null = giữ tới khi người dùng xoá.
const RETENTION = {
  image: { ttlMs: 180 * DAY_MS, label: 'Ảnh đề bài đính kèm' },
  chat: { ttlMs: 30 * DAY_MS, label: 'Lịch sử trò chuyện với AI' },
  familyReport: { ttlMs: 90 * DAY_MS, label: 'Báo cáo tuần gửi gia đình' },
  snapshot: { ttlMs: null, label: 'Bản sao lưu dữ liệu học tập' },
};

/// Các bảng chứa dữ liệu cá nhân gắn với uid, theo (bảng, cột-khoá).
///
/// THỨ TỰ QUAN TRỌNG: xoá bảng con trước bảng cha (messages/goals trước links)
/// để không vi phạm khoá ngoại nếu schema bật ràng buộc. `user_id` phủ cả vai
/// trò học sinh (family_*.student_user_id) lẫn phụ huynh (parent_user_id,
/// family_notif_tokens.user_id) — người dùng có thể là một trong hai.
const DELETION_SPECS = [
  { table: 'family_messages', column: 'student_user_id' },
  { table: 'family_messages', column: 'parent_user_id' },
  { table: 'family_goals', column: 'student_user_id' },
  { table: 'family_goals', column: 'parent_user_id' },
  { table: 'family_reports', column: 'student_user_id' },
  { table: 'family_live', column: 'student_user_id' },
  { table: 'family_notif_tokens', column: 'user_id' },
  { table: 'family_links', column: 'student_user_id' },
  { table: 'family_links', column: 'parent_user_id' },
  { table: 'user_blobs', column: 'user_id' },
  { table: 'user_snapshots', column: 'user_id' },
  // Mã xác minh email gắn uid (mã reset quên mật khẩu không có uid — tự hết
  // hạn 15 phút và bị cron dọn, xem `cleanup_logic.js`).
  { table: 'email_codes', column: 'uid' },
];

/// Danh sách việc xoá cho một uid. Rỗng nếu uid không hợp lệ (không bao giờ
/// trả về lệnh xoá không có điều kiện — tránh xoá nhầm cả bảng).
function deletionTargets(uid) {
  const id = String(uid || '').trim();
  if (!id) return [];
  return DELETION_SPECS.map((s) => ({
    table: s.table,
    column: s.column,
    value: id,
  }));
}

/// Mô tả chính sách lưu trữ để trả cho client/trang thông báo quyền riêng tư.
function retentionPolicy() {
  return Object.keys(RETENTION).map((key) => ({
    key,
    label: RETENTION[key].label,
    ttlDays:
      RETENTION[key].ttlMs == null
        ? null
        : Math.round(RETENTION[key].ttlMs / DAY_MS),
  }));
}

/// Dữ liệu có quá hạn chưa? `ttlMs == null` = không bao giờ hết hạn.
function isExpired(updatedAtMs, ttlMs, nowMs) {
  if (ttlMs == null) return false;
  if (updatedAtMs == null) return false;
  const updated = Number(updatedAtMs);
  if (!Number.isFinite(updated)) return false;
  return nowMs - updated > ttlMs;
}

module.exports = {
  DAY_MS,
  RETENTION,
  DELETION_SPECS,
  deletionTargets,
  retentionPolicy,
  isExpired,
};
