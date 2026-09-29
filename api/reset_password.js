// POST /api/reset_password
// Bước 2 quên mật khẩu: kiểm tra mã 8 chữ số (purpose='reset'). Nếu đúng, kích
// hoạt email đặt lại mật khẩu Firebase (PASSWORD_RESET) ngay lúc đó để người
// dùng bấm link đặt mật khẩu mới.
// Body: { email, code } — KHÔNG cần đăng nhập.
// Không xài firebase-admin (org policy chặn tạo service account key); chỉ gọi
// REST accounts:sendOobCode với API key công khai như các endpoint khác.
const { getSupabase, readJson, ok, fail } = require('./_lib');

const SEND_RESET_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=' +
  encodeURIComponent(process.env.FIREBASE_API_KEY || '');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return fail(res, 405, 'Chỉ hỗ trợ POST.');
  try {
    const body = await readJson(req);
    const email = String(body.email || '').trim().toLowerCase();
    const code = String(body.code || '').trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      return fail(res, 400, 'Email không hợp lệ.');
    }
    if (!/^\d{8}$/.test(code)) return fail(res, 400, 'Mã gồm 8 chữ số.');

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

    // Mã đúng → kích hoạt email đặt lại mật khẩu Firebase gửi về đúng email này.
    // continueUrl trỏ về chính app để khi người dùng bấm link, app nhận được
    // oobCode và hiện màn hình "Đặt mật khẩu mới" (đặt ngay trong app).
    const proto = String(req.headers['x-forwarded-proto'] || 'https')
      .split(',')[0]
      .trim();
    const host = req.headers['x-forwarded-host'] || req.headers.host || '';
    const origin = `${proto}://${host}`;
    const continueUrl = `${origin}/auth/reset?email=${encodeURIComponent(email)}`;
    const resp = await fetch(SEND_RESET_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requestType: 'PASSWORD_RESET',
        email,
        continueUrl,
      }),
    });
    const data = await resp.json().catch(() => ({}));

    // Xoá mã vừa dùng trong mọi trường hợp để tránh dùng lại.
    await supabase.from('email_codes').delete().eq('id', row.id);

    if (!resp.ok) {
      const msg =
        data.error && data.error.message === 'EMAIL_NOT_FOUND'
          ? 'Email này chưa đăng ký tài khoản EduPulse.'
          : 'Không gửi được email đặt lại mật khẩu. Thử lại sau.';
      return fail(res, 400, msg);
    }

    return ok(res, {
      ok: true,
      message: 'Mã chính xác! Email đặt lại mật khẩu đã được gửi.',
    });
  } catch (e) {
    return fail(res, 500, e.message || 'Xác minh mã thất bại. Thử lại sau.');
  }
};