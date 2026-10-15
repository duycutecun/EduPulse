// API "quyền riêng tư & dữ liệu cá nhân" cho EduPulse (đặc tả mục 8, dòng 214).
//
//   GET  /api/account?retention=1 → chính sách lưu trữ/cache (công khai)
//   POST /api/account             → xoá dữ liệu cá nhân của chính người gọi
//                                    body: { action: 'delete_my_data', confirm: true }
//
// VÌ SAO CẦN: người dùng phải có cơ chế xoá dữ liệu cá nhân rõ ràng. Dữ liệu
// nằm rải ở nhiều bảng (snapshot, ảnh, liên kết gia đình, báo cáo, mục tiêu,
// lời nhắn, token thông báo), và người dùng có thể là HỌC SINH hoặc PHỤ HUYNH —
// nên việc xoá phải phủ cả hai vai trò.
//
// QUYỀN: server xác thực Firebase ID token rồi dùng SUPABASE_SERVICE_ROLE_KEY,
// bỏ qua RLS, nhưng MỖI lệnh xoá đều ràng buộc `.eq(column, uid)` — không bao
// giờ xoá rộng. Danh sách bảng/cột ở `_account_logic.js` (có test `node --test`).
const {
  getFirebaseUser,
  getSupabase,
  readJson,
  ok,
  fail,
} = require('./_lib');

const { deletionTargets, retentionPolicy } = require('./_account_logic');

const MAX_BODY = 64 * 1024; // body nhỏ — chỉ có cờ hành động, không có payload.

module.exports = async function handler(req, res) {
  // Chính sách lưu trữ là công khai — không cần đăng nhập.
  if (req.method === 'GET') {
    return ok(res, { ok: true, retention: retentionPolicy() });
  }

  if (req.method !== 'POST') {
    return fail(res, 405, 'Chỉ hỗ trợ GET và POST.');
  }

  let idToken = '';
  const authHeader = String(req.headers.authorization || '');
  if (/^Bearer\s+/i.test(authHeader)) {
    idToken = authHeader.replace(/^Bearer\s+/i, '').trim();
  }

  let body;
  try {
    body = (await readJson(req, MAX_BODY)) || {};
  } catch (e) {
    return fail(res, 400, e.message || 'Dữ liệu gửi lên không hợp lệ.');
  }
  if (!idToken) idToken = String(body.idToken || '').trim();

  if (!idToken) {
    return fail(res, 401, 'Chưa đăng nhập — không xoá được dữ liệu.');
  }

  // Yêu cầu xác nhận rõ ràng để tránh xoá nhầm do gọi thiếu tham số.
  if (body.action !== 'delete_my_data' || body.confirm !== true) {
    return fail(
      res,
      400,
      'Thiếu xác nhận. Gửi { action: "delete_my_data", confirm: true } để xoá.',
    );
  }

  let user;
  try {
    user = await getFirebaseUser(idToken);
  } catch (e) {
    return fail(res, 401, e.message || 'Phiên đăng nhập đã hết hạn.');
  }
  const uid = user.uid;

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

  const targets = deletionTargets(uid);
  if (targets.length === 0) {
    return fail(res, 400, 'Không xác định được dữ liệu cần xoá.');
  }

  const deleted = {};
  try {
    for (const t of targets) {
      const { data, error } = await supabase
        .from(t.table)
        .delete()
        .eq(t.column, t.value)
        .select('id');
      if (error) {
        // Ghi nhận bảng đã xoá thành công trước đó rồi dừng ở bảng lỗi, để
        // người vận hành biết chính xác đã tới đâu (idempotent: chạy lại an toàn).
        return fail(
          res,
          500,
          `Xoá dữ liệu dở dang ở bảng ${t.table}. Hãy thử lại.`,
        );
      }
      const key = `${t.table}.${t.column}`;
      deleted[key] = (deleted[key] || 0) + (Array.isArray(data) ? data.length : 0);
    }
  } catch (e) {
    return fail(res, 500, e.message || 'Xoá dữ liệu thất bại. Thử lại sau.');
  }

  return ok(res, { ok: true, deleted });
};
