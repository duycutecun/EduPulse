// POST /api/send_reset_code
// Bước 1 quên mật khẩu: gửi email chứa mã 8 chữ số tới hộp thư.
// Body: { email } — KHÔNG cần đăng nhập (người quên mật khẩu thì không có token).
// Dùng SMTP Gmail, lưu mã vào bảng email_codes với purpose='reset'.
// Kiểm tra email tồn tại được thực hiện ở bước 2 (reset_password) vì Firebase
// REST không phân biệt "sai email" và "sai mật khẩu" để bảo mật thông tin.
const { getSupabase, getTransporter, newCode, CODE_TTL_MS, readJson, ok, fail } = require('./_lib');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return fail(res, 405, 'Chỉ hỗ trợ POST.');
  try {
    const body = await readJson(req);
    const email = String(body.email || '').trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      return fail(res, 400, 'Email không hợp lệ.');
    }

    const code = newCode();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + CODE_TTL_MS);

    const supabase = getSupabase();
    // Dọn mã reset cũ của email này rồi lưu mã mới. (uid để NULL vì chưa đăng nhập.)
    await supabase.from('email_codes').delete().eq('email', email).eq('purpose', 'reset');
    const { error: insertErr } = await supabase.from('email_codes').insert({
      email,
      code,
      purpose: 'reset',
      expires_at: expiresAt.toISOString(),
      created_at: now.toISOString(),
    });
    if (insertErr) return fail(res, 500, 'Không lưu được mã đặt lại mật khẩu.');

    const transporter = getTransporter();
    await transporter.sendMail({
      from: `"EduPulse" <${process.env.SMTP_USER}>`,
      to: email,
      subject: `Mã đặt lại mật khẩu EduPulse của bạn là ${code}`,
      text: `Mã đặt lại mật khẩu tài khoản EduPulse của bạn là: ${code}\n\nMã có hiệu lực trong 15 phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.`,
      html: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;border:1px solid #e5e7eb;border-radius:12px">
        <h2 style="color:#58CC02;margin:0 0 8px">EduPulse</h2>
        <p>Chào bạn,</p>
        <p>Dùng mã bên dưới để nhận liên kết đặt lại mật khẩu EduPulse:</p>
        <p style="font-size:34px;font-weight:700;letter-spacing:8px;color:#58CC02;text-align:center;margin:20px 0">${code}</p>
        <p style="color:#737373;font-size:13px">Mã có hiệu lực trong <b>15 phút</b>. Nếu bạn không yêu cầu, hãy bỏ qua email này.</p>
      </div>`,
    });
    return ok(res, { ok: true });
  } catch (e) {
    return fail(res, 500, e.message || 'Không gửi được mã đặt lại mật khẩu.');
  }
};