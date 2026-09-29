// POST /api/verify_email
// Kiểm tra mã 8 chữ số rồi đánh dấu email đã xác minh trong user_profiles.
// Body: { idToken, code } — Google tự xác thực token, không cần service account.
const { getFirebaseUser, getSupabase, readJson, ok, fail } = require('./_lib');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return fail(res, 405, 'Chỉ hỗ trợ POST.');
  try {
    // Đọc body MỘT lần duy nhất — đọc 2 lần cùng một stream sẽ treo vĩnh viễn.
    const body = await readJson(req);
    const code = String(body.code || '').trim();
    if (!/^\d{8}$/.test(code)) return fail(res, 400, 'Mã xác minh gồm 8 chữ số.');

    const idToken = String(body.idToken || '');
    if (!idToken) return fail(res, 400, 'Thiếu token đăng nhập.');

    const user = await getFirebaseUser(idToken);
    const email = user.email;
    if (!email) return fail(res, 400, 'Tài khoản này không có email để xác minh.');

    if (user.emailVerified) return ok(res, { ok: true });

    const supabase = getSupabase();
    const { data: rows, error } = await supabase
      .from('email_codes')
      .select('id, code, uid, expires_at')
      .eq('email', email)
      .eq('purpose', 'verify')
      .order('created_at', { ascending: false })
      .limit(1);
    if (error) return fail(res, 500, 'Không đọc được mã xác minh.');

    const row = rows && rows[0];
    if (!row) return fail(res, 400, 'Mã xác minh không tồn tại. Hãy nhấn "Gửi lại mã".');

    if (new Date(row.expires_at).getTime() < Date.now()) {
      await supabase.from('email_codes').delete().eq('id', row.id);
      return fail(res, 400, 'Mã xác minh đã hết hạn. Hãy nhấn "Gửi lại mã".');
    }

    if (row.code !== code) {
      return fail(res, 400, 'Mã xác minh không đúng. Kiểm tra lại!');
    }

    // Mã phải thuộc về đúng người dùng đang gọi (không nhận mã của email khác).
    if (row.uid !== user.uid) {
      return fail(res, 400, 'Mã xác minh không thuộc tài khoản này. Gửi lại mã nhé!');
    }

    // Đánh dấu đã xác minh trong user_profiles (không đụng Firebase emailVerified).
    const { data: updated } = await supabase
      .from('user_profiles')
      .update({ is_email_verified: true })
      .eq('user_id', user.uid)
      .select('user_id');
    if (!updated || !updated.length) {
      await supabase.from('user_profiles').insert({
        user_id: user.uid,
        name: '',
        is_email_verified: true,
      });
    }

    await supabase.from('email_codes').delete().eq('id', row.id);
    return ok(res, { ok: true });
  } catch (e) {
    return fail(res, 500, e.message || 'Xác minh thất bại. Thử lại sau.');
  }
};