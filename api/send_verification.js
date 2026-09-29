// POST /api/send_verification
// Gửi email xác minh mới chứa mã 8 chữ số cho người dùng đang đăng nhập.
// Body: { idToken: "<Firebase ID token>" } — Google tự xác thực token, không cần
// service account (org policy của project chặn tạo service account key).
const { requireFirebaseUser, getSupabase, getTransporter, newCode, CODE_TTL_MS, ok, fail } = require('./_lib');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return fail(res, 405, 'Chỉ hỗ trợ POST.');
  try {
    const user = await requireFirebaseUser(req);
    const email = user.email;
    if (!email) return fail(res, 400, 'Tài khoản này không có email để gửi mã.');

    // Đã xác minh rồi thì không cần gửi nữa.
    if (user.emailVerified) return ok(res, { ok: true, alreadyVerified: true });

    const code = newCode();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + CODE_TTL_MS);

    const supabase = getSupabase();
    // Dọn các mã xác minh cũ của email này rồi lưu mã mới (purpose='verify').
    await supabase.from('email_codes').delete().eq('email', email).eq('purpose', 'verify');
    const { error: insertErr } = await supabase.from('email_codes').insert({
      email,
      uid: user.uid,
      code,
      purpose: 'verify',
      expires_at: expiresAt.toISOString(),
      created_at: now.toISOString(),
    });
    if (insertErr) return fail(res, 500, 'Không lưu được mã xác minh.');

    const transporter = getTransporter();
    await transporter.sendMail({
      from: `"EduPulse" <${process.env.SMTP_USER}>`,
      to: email,
      subject: `Mã xác minh EduPulse của bạn là ${code}`,
      text: `Mã xác minh tài khoản EduPulse của bạn là: ${code}\n\nMã có hiệu lực trong 15 phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.`,
      html: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;border:1px solid #e5e7eb;border-radius:12px">
        <h2 style="color:#58CC02;margin:0 0 8px">EduPulse</h2>
        <p>Chào bạn,</p>
        <p>Dùng mã bên dưới để kích hoạt tài khoản EduPulse của bạn:</p>
        <p style="font-size:34px;font-weight:700;letter-spacing:8px;color:#58CC02;text-align:center;margin:20px 0">${code}</p>
        <p style="color:#737373;font-size:13px">Mã có hiệu lực trong <b>15 phút</b>. Nếu bạn không yêu cầu, hãy bỏ qua email này.</p>
      </div>`,
    });
    return ok(res, { ok: true });
  } catch (e) {
    return fail(res, 500, e.message || 'Không gửi được mã xác minh.');
  }
};