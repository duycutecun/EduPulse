// POST /api/reset_password
// Bước 2 quên mật khẩu (HỢP ĐỒNG MỚI): kiểm tra mã 8 chữ số (purpose='reset')
// rồi đặt mật khẩu mới NGAY TẠI ĐÂY bằng Admin API của Supabase — client Flutter
// không còn nhận link đặt lại mật khẩu như thời cũ (đã bỏ Firebase).
//
// Body: { email, code, newPassword } — KHÔNG cần token (người quên mật khẩu
// không đăng nhập).
//
// Thao tác đổi mật khẩu phải dùng service_role key (đã có sẵn server-side):
//   ① `auth.admin.listUsers({ page, perPage })` — lặp từng trang, lọc email
//     phía JS (GoTrue admin API không có filter email trực tiếp).
//   ② `auth.admin.updateUserById(userId, { password })`.
//   ③ Xoá dòng `email_codes` vừa dùng để tránh dùng lại.
// Mật khẩu mới yếu (< 8 ký tự) → 400; mã sai/hết hạn → 400 kèm thông báo
// tiếng Việt; thành công → 200 `{ ok: true }`. KHÔNG còn oobCode/continueUrl
// (thời còn Firebase).
const { getSupabase, readJson, ok, fail } = require('./_lib');
const { guard } = require('./_guard');

/** Độ dài tối thiểu của mật khẩu mới (khớp thông báo tiếng Việt). */
const MIN_PASSWORD_LEN = 8;
/** Kích thước trang khi lặp listUsers (GoTrue trả theo per_page). */
const LIST_PAGE_SIZE = 200;
/** Tran trang an toàn: đủ cho hàng chục nghìn người dùng, tránh lặp vô hạn. */
const MAX_PAGES = 50;

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return fail(res, 405, 'Chỉ hỗ trợ POST.');
  // Chống dò mã/email hàng loạt: giới hạn theo IP (người quên mật khẩu chưa
  // đăng nhập nên không có uid để khoá theo tài khoản).
  if (!(await guard(req, res, { endpoint: '/api/reset_password', limit: 10, quota: 30 }))) {
    return;
  }
  try {
    const body = await readJson(req);
    const email = String(body.email || '').trim().toLowerCase();
    const code = String(body.code || '').trim();
    const newPassword = String(body.newPassword || '');

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      return fail(res, 400, 'Email không hợp lệ.');
    }
    if (!/^\d{8}$/.test(code)) return fail(res, 400, 'Mã gồm 8 chữ số.');
    if (newPassword.length < MIN_PASSWORD_LEN) {
      return fail(res, 400, 'Mật khẩu mới phải có ít nhất 8 ký tự.');
    }

    const supabase = getSupabase();
    const { data: rows, error } = await supabase
      .from('email_codes')
      .select('id, code, expires_at')
      .eq('email', email)
      .eq('purpose', 'reset')
      .order('created_at', { ascending: false })
      .limit(1);
    if (error) return fail(res, 500, 'Không đọc được mã đặt lại mật khẩu.');

    const row = rows && rows[0];
    if (!row) return fail(res, 400, 'Mã không tồn tại. Hãy nhấn "Gửi mã".');

    if (new Date(row.expires_at).getTime() < Date.now()) {
      await supabase.from('email_codes').delete().eq('id', row.id);
      return fail(res, 400, 'Mã đã hết hạn. Hãy nhấn "Gửi mã".');
    }

    if (row.code !== code) {
      return fail(res, 400, 'Mã không đúng. Kiểm tra lại!');
    }

    // ① Tìm user theo email trong Supabase Auth (service_role → admin scope).
    let userId = null;
    try {
      for (let page = 1; page <= MAX_PAGES && !userId; page++) {
        const { data, error: listError } = await supabase.auth.admin.listUsers({
          page,
          perPage: LIST_PAGE_SIZE,
        });
        if (listError) break;
        const users = (data && data.users) || [];
        if (!users.length) break;
        const hit = users.find((u) => String(u.email || '').toLowerCase() === email);
        if (hit) userId = hit.id;
        if (users.length < LIST_PAGE_SIZE) break; // hết danh sách
      }
    } catch (_) {
      userId = null;
    }
    if (!userId) {
      return fail(res, 400, 'Email này chưa đăng ký tài khoản EduPulse.');
    }

    // ② Đặt mật khẩu mới bằng Admin API.
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userId,
      { password: newPassword }
    );
    if (updateError) {
      return fail(res, 500, 'Không đổi được mật khẩu. Thử lại sau.');
    }

    // ③ Xoá mã vừa dùng: một mã chỉ đổi được mật khẩu một lần.
    await supabase.from('email_codes').delete().eq('id', row.id);

    return ok(res, {
      ok: true,
      message: 'Đã đổi mật khẩu thành công. Hãy đăng nhập lại bằng mật khẩu mới.',
    });
  } catch (e) {
    return fail(res, e.status || 500, e.message || 'Xác minh mã thất bại. Thử lại sau.');
  }
};
