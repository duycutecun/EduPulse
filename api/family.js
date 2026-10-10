// "Cửa sổ tin cậy" — liên kết tài khoản phụ huynh ↔ học sinh.
//
// VÌ SAO CẦN ENDPOINT RIÊNG (không gọi thẳng Supabase từ app):
//   App đăng nhập bằng FIREBASE còn RLS của Supabase so với `auth.uid()`
//   (Supabase Auth) → luôn NULL → chặn trắng. Ở đây server xác thực ID token
//   bằng Firebase REST (getFirebaseUser) rồi ghi bằng
//   SUPABASE_SERVICE_ROLE_KEY, và TỰ KIỂM SOÁT QUYỀN:
//     • Chỉ học sinh tạo được mã mời của chính mình.
//     • Chỉ người nhập đúng mã mới thành phụ huynh của học sinh đó.
//     • Phụ huynh CHỈ đọc được báo cáo của con đã liên kết, và chỉ những báo
//       cáo con chủ động gửi.
//     • Ngắt liên kết ⇒ mất quyền ngay (mọi truy vấn đều kiểm tra lại liên kết).
//
// Route: POST /api/family.js  (Firebase ID token trong body `idToken`)
//   action = 'invite'        → học sinh tạo mã mời 8 chữ số (mã cũ bị thay)
//   action = 'my_family'     → trạng thái của tôi: mã đang chờ / ba mẹ đã nối /
//                              các con đã nối (kèm mốc báo cáo, bản trực tiếp,
//                              nhãn riêng, tuỳ chọn thông báo)
//   action = 'redeem'        → phụ huynh nhập mã để liên kết
//   action = 'unlink'        → ngắt liên kết (cả hai phía đều gọi được)
//   action = 'share_report'  → học sinh gửi báo cáo tuần cho gia đình
//   action = 'child_reports' → phụ huynh đọc báo cáo con đã gửi (+ trạng thái
//                              trực tiếp; lọc `since`/`from`/`to`)
//   action = 'share_live'    → học sinh đẩy "trạng thái trực tiếp" cho ba mẹ
//   action = 'set_child_label' → phụ huynh đặt tên riêng cho một con
//   action = 'notify_pref'   → phụ huynh bật/tắt nhận thông báo cho một con
//   action = 'push_token'    → phụ huynh đăng ký/huỷ token Web Push
//   action = 'push_info'     → trả khoá công khai VAPID để app đăng ký push
//
// BẢN CHẤT (đã đổi): ba mẹ là người ĐỒNG HÀNH nên khi đã liên kết sẽ thấy toàn
// bộ tiến độ con cập nhật — không còn để con tự quyết từng hạng mục. Giao kèo
// còn lại: ba mẹ chỉ thấy tiến độ học tập (không đọc dữ liệu riêng tư khác).
//
// VÌ SAO CÓ `share_live`:
//   Ba mẹ muốn thấy tiến độ cập nhật liên tục, không phải chờ con bấm gửi.
//   App của con tự đẩy báo cáo mỗi khi số liệu đổi; ngắt liên kết là dừng.
const crypto = require('crypto');
const {
  getFirebaseUser,
  getSupabase,
  readJson,
  ok,
  fail,
} = require('./_lib');

const LINK_TABLE = 'family_links';
const REPORT_TABLE = 'family_reports';
const LIVE_TABLE = 'family_live';
const NOTIF_TABLE = 'family_notif_tokens';

/// Mã mời sống 2 ngày. Đủ để con đọc cho ba mẹ nhập, đủ ngắn để một mã lọt ra
/// ngoài không còn dùng được sau vài hôm.
const CODE_TTL_MS = 2 * 24 * 60 * 60 * 1000;

/// Giữ tối đa 12 báo cáo mỗi học sinh (~3 tháng báo cáo tuần). Cũ hơn bị dọn
/// để bảng không phình vô hạn — ba mẹ xem lịch sử gần đây là đủ.
const MAX_REPORTS_PER_STUDENT = 12;

/// Số báo cáo trả về một lần cho phụ huynh.
const REPORTS_PAGE = 8;

function newCode() {
  return String(Math.floor(10000000 + Math.random() * 90000000));
}

function toMillis(value) {
  const t = Date.parse(value || '');
  return Number.isNaN(t) ? 0 : t;
}

// ── Realtime: báo cho máy ba mẹ biết con vừa cập nhật ───────────────────────
//
// Cùng cách làm với `/api/backup.js`: broadcast REST của Supabase Realtime,
// KHÔNG dùng `postgres_changes` (nó lọc theo RLS + cần Supabase session, mà app
// đăng nhập bằng Firebase nên sẽ âm thầm không gửi gì). Tín hiệu đi trên kênh
// riêng của TỪNG người nhận và CHỈ mang con số thời gian — payload học tập vẫn
// phải kéo qua API có xác thực, không đi qua kênh broadcast (kênh không mã hoá).
//
// Topic = hash('family:' + uid + service_role_key) ⇒ không đoán được nếu không
// biết cả uid lẫn key; khác topic của `/api/backup` nên hai kênh không lẫn nhau.

function topicFor(uid) {
  return crypto
    .createHash('sha256')
    .update('family:' + uid + (process.env.SUPABASE_SERVICE_ROLE_KEY || ''))
    .digest('hex')
    .slice(0, 32);
}

/**
 * Bắn một tín hiệu. LUÔN trả về, không bao giờ ném lỗi ra ngoài: bỏ được thì
 * dữ liệu vẫn đã lưu, máy ba mẹ chỉ chậm hơn tới chu kỳ hỏi định kỳ — hỏng cả
 * thao tác lưu chỉ vì tín hiệu là sai lầm.
 */
async function broadcast(topic, event, payload) {
  const base = String(process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!base || !key) return false;
  try {
    const resp = await fetch(
      `${base}/realtime/v1/api/broadcast/${topic}/events/${event}`,
      {
        method: 'POST',
        headers: { apikey: key, 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }
    );
    return resp.ok;
  } catch (_) {
    return false;
  }
}

/** Tài khoản ba mẹ đang liên kết với một học sinh (kèm tuỳ chọn thông báo). */
async function linkedParents(supabase, studentUserId) {
  try {
    const { data } = await supabase
      .from(LINK_TABLE)
      .select('parent_user_id, notify_on')
      .eq('student_user_id', studentUserId)
      .eq('status', 'linked');
    return (data || []).filter((r) => r.parent_user_id);
  } catch (_) {
    return [];
  }
}

// ── Web Push (thông báo khi ba mẹ đã đóng app) ─────────────────────────────
//
// Dùng VAPID; thư viện `web-push` là optional — cài rồi mà thiếu khoá thì bỏ
// qua êm, không làm hỏng thao tác lưu. Token không còn hiệu lực (404/410) bị
// xoá để bảng không đọng rác.
let webpush = null;
try {
  webpush = require('web-push');
} catch (_) {
  webpush = null;
}

function pushConfigured() {
  return !!(
    webpush &&
    process.env.VAPID_PUBLIC_KEY &&
    process.env.VAPID_PRIVATE_KEY &&
    process.env.VAPID_SUBJECT
  );
}

async function sendPushTo(supabase, parentId, message) {
  if (!pushConfigured()) return;
  try {
    webpush.setVapidDetails(
      process.env.VAPID_SUBJECT,
      process.env.VAPID_PUBLIC_KEY,
      process.env.VAPID_PRIVATE_KEY
    );
  } catch (_) {
    return;
  }
  const { data: tokens } = await supabase
    .from(NOTIF_TABLE)
    .select('token')
    .eq('user_id', parentId);
  const body = JSON.stringify({
    title: message.title,
    body: message.body,
    at: message.at || Date.now(),
    kind: message.kind || 'live',
  });
  for (const row of tokens || []) {
    try {
      await webpush.sendNotification(JSON.parse(row.token), body);
    } catch (e) {
      const status = e && e.statusCode;
      if (status === 404 || status === 410) {
        await supabase.from(NOTIF_TABLE).delete().eq('token', row.token);
      }
    }
  }
}

/** Báo cho mọi ba mẹ đã liên kết rằng con vừa có gì đó mới. */
async function notifyParents(supabase, studentUserId, payload, studentName) {
  const parents = await linkedParents(supabase, studentUserId);
  const name = (studentName || 'Con').trim() || 'Con';
  const kind = payload && payload.kind;
  let message = null;
  if (kind === 'report') {
    message = { title: 'Báo cáo tuần mới', body: `${name} vừa gửi báo cáo tuần cho ba mẹ.` };
  } else if (kind === 'live') {
    message = { title: 'Con vừa cập nhật', body: `${name} vừa cập nhật tiến độ học tập.` };
  }
  for (const parent of parents) {
    await broadcast(topicFor(parent.parent_user_id), 'family', payload);
    if (message && parent.notify_on !== false) {
      await sendPushTo(supabase, parent.parent_user_id, { ...message, at: payload.at, kind });
    }
  }
  return parents.length;
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return fail(res, 405, 'Chỉ hỗ trợ POST.');
  }

  let body = {};
  try {
    body = (await readJson(req, 1e6)) || {};
  } catch (e) {
    return fail(res, 400, e.message || 'Dữ liệu gửi lên không hợp lệ.');
  }

  let idToken = String(body.idToken || '').trim();
  if (!idToken) {
    const authHeader = String(req.headers.authorization || '');
    if (/^Bearer\s+/i.test(authHeader)) {
      idToken = authHeader.replace(/^Bearer\s+/i, '').trim();
    }
  }
  if (!idToken) return fail(res, 401, 'Chưa đăng nhập — hãy đăng nhập rồi thử lại.');

  let user;
  try {
    user = await getFirebaseUser(idToken);
  } catch (e) {
    return fail(res, 401, e.message || 'Phiên đăng nhập đã hết hạn.');
  }

  let supabase;
  try {
    supabase = getSupabase();
  } catch (e) {
    return fail(res, 500, e.message || 'Máy chủ chưa cấu hình Supabase.');
  }

  const action = String(body.action || '').trim();
  try {
    switch (action) {
      case 'invite':
        return await invite(supabase, user, body, res);
      case 'my_family':
        return await myFamily(supabase, user, res);
      case 'redeem':
        return await redeem(supabase, user, body, res);
      case 'unlink':
        return await unlink(supabase, user, body, res);
      case 'share_report':
        return await shareReport(supabase, user, body, res);
      case 'share_live':
        return await shareLive(supabase, user, body, res);
      case 'child_reports':
        return await childReports(supabase, user, body, res);
      case 'set_child_label':
        return await setChildLabel(supabase, user, body, res);
      case 'notify_pref':
        return await notifyPref(supabase, user, body, res);
      case 'push_token':
        return await pushToken(supabase, user, body, res);
      case 'push_info':
        return ok(res, {
          ok: true,
          vapidPublicKey: process.env.VAPID_PUBLIC_KEY || '',
        });
      default:
        return fail(res, 400, 'Hành động không hợp lệ.');
    }
  } catch (e) {
    return fail(res, 500, e.message || 'Có lỗi xảy ra. Thử lại sau.');
  }
};

/** Học sinh tạo mã mời mới. Mã đang chờ cũ bị xoá để chỉ có MỘT mã hiệu lực. */
async function invite(supabase, user, body, res) {
  const name = String(body.studentName || '').slice(0, 80);

  // Xoá mã 'pending' cũ của chính mình (tạo mã mới = mã cũ hết hiệu lực).
  const { error: clearError } = await supabase
    .from(LINK_TABLE)
    .delete()
    .eq('student_user_id', user.uid)
    .eq('status', 'pending');
  if (clearError) return fail(res, 500, 'Không tạo được mã mời.');

  // `code` bị ràng buộc UNIQUE (family_links_code_key). Trùng mã 8 chữ số rất
  // hiếm nhưng có thể xảy ra — thử lại vài lần thay vì trả lỗi 500 cho người
  // dùng vừa bấm nút.
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newCode();
    const { error } = await supabase.from(LINK_TABLE).insert({
      code,
      student_user_id: user.uid,
      student_name: name,
      status: 'pending',
      created_at: new Date().toISOString(),
    });
    if (!error) {
      return ok(res, {
        ok: true,
        code,
        expiresAt: Date.now() + CODE_TTL_MS,
      });
    }
    // error.code === '23505' = duplicate key (mã trùng) → thử mã khác.
    if (error.code !== '23505') {
      return fail(res, 500, 'Không tạo được mã mời.');
    }
  }
  return fail(res, 500, 'Không tạo được mã mời.');
}

/** Trạng thái gia đình của người đang gọi — dùng chung cho cả hai vai. */
async function myFamily(supabase, user, res) {
  const { data, error } = await supabase
    .from(LINK_TABLE)
    .select(
      'id, code, student_user_id, student_name, parent_user_id, parent_name, parent_label, notify_on, status, created_at, linked_at'
    )
    .or(`student_user_id.eq.${user.uid},parent_user_id.eq.${user.uid}`);
  if (error) return fail(res, 500, 'Không đọc được liên kết gia đình.');

  const rows = data || [];
  const parents = rows
    .filter((r) => r.student_user_id === user.uid && r.status === 'linked')
    .map((r) => ({
      linkId: r.id,
      userId: r.parent_user_id,
      name: r.parent_name || 'Phụ huynh',
      linkedAt: toMillis(r.linked_at),
    }));

  const pendingRow = rows.find(
    (r) => r.student_user_id === user.uid && r.status === 'pending'
  );
  let invite = null;
  if (pendingRow) {
    const created = toMillis(pendingRow.created_at);
    const expiresAt = created + CODE_TTL_MS;
    // Mã quá hạn thì coi như không có — đừng hiện mã chết cho học sinh đọc.
    if (expiresAt > Date.now()) {
      invite = { code: pendingRow.code, expiresAt };
    }
  }

  const children = rows
    .filter((r) => r.parent_user_id === user.uid && r.status === 'linked')
    .map((r) => ({
      linkId: r.id,
      userId: r.student_user_id,
      // Nhãn ba mẹ đặt riêng được ưu tiên hơn tên thật của con.
      name: r.parent_label || r.student_name || 'Con',
      parentLabel: r.parent_label || '',
      notifyOn: r.notify_on !== false,
      linkedAt: toMillis(r.linked_at),
      latestReportAt: 0,
      // Có "trạng thái trực tiếp" = con đã cập nhật (0 = chưa).
      liveAt: 0,
    }));

  // Mốc báo cáo mới nhất + mốc cập nhật trực tiếp của từng con — một truy vấn
  // cho mỗi loại, không hỏi từng con một.
  if (children.length) {
    const ids = children.map((c) => c.userId);
    const { data: reports } = await supabase
      .from(REPORT_TABLE)
      .select('student_user_id, created_at')
      .in('student_user_id', ids)
      .order('created_at', { ascending: false });
    const latest = {};
    for (const r of reports || []) {
      const at = toMillis(r.created_at);
      if (!latest[r.student_user_id] || at > latest[r.student_user_id]) {
        latest[r.student_user_id] = at;
      }
    }
    for (const c of children) c.latestReportAt = latest[c.userId] || 0;

    const { data: liveRows } = await supabase
      .from(LIVE_TABLE)
      .select('student_user_id, payload, updated_at')
      .in('student_user_id', ids);
    const liveAt = {};
    const liveSummary = {};
    const liveCheckin = {};
    for (const r of liveRows || []) {
      liveAt[r.student_user_id] = toMillis(r.updated_at);
      const payload = r.payload && typeof r.payload === 'object' ? r.payload : {};
      const items = Array.isArray(payload.items) ? payload.items : [];
      const summary = {};
      for (const item of items) {
        if (item && item.key && item.value != null) {
          summary[item.key] = String(item.value);
        }
      }
      liveSummary[r.student_user_id] = summary;
      if (payload.checkin) liveCheckin[r.student_user_id] = String(payload.checkin);
    }
    for (const c of children) {
      c.liveAt = liveAt[c.userId] || 0;
      c.liveSummary = liveSummary[c.userId] || {};
      c.liveCheckin = liveCheckin[c.userId] || '';
    }
  }

  // `topic` = kênh Realtime của CHÍNH người đang gọi. App dùng nó để nghe tín
  // hiệu "con vừa cập nhật" thay vì chờ hết chu kỳ hỏi định kỳ.
  return ok(res, {
    ok: true,
    invite,
    parents,
    children,
    topic: topicFor(user.uid),
  });
}

/** Phụ huynh nhập mã mời để liên kết với tài khoản của con. */
async function redeem(supabase, user, body, res) {
  const code = String(body.code || '').trim();
  if (!/^\d{8}$/.test(code)) {
    return fail(res, 400, 'Mã mời gồm 8 chữ số.');
  }
  const parentName = String(body.parentName || '').slice(0, 80);

  const { data, error } = await supabase
    .from(LINK_TABLE)
    .select('*')
    .eq('code', code)
    .limit(1);
  if (error) return fail(res, 500, 'Không kiểm tra được mã mời.');

  const row = data && data[0];
  if (!row) {
    return fail(res, 404, 'Mã mời không đúng. Kiểm tra lại 8 chữ số nhé.');
  }
  if (row.parent_user_id === user.uid && row.status === 'linked') {
    // Nhập lại mã cũ trên cùng tài khoản = đã liên kết, không phải lỗi.
    return ok(res, { ok: true, alreadyLinked: true, studentName: row.student_name || 'Con' });
  }
  if (row.status === 'linked') {
    return fail(res, 409, 'Mã mời này đã được dùng rồi.');
  }
  if (row.student_user_id === user.uid) {
    return fail(res, 400, 'Không thể tự liên kết với tài khoản của chính mình.');
  }
  const created = toMillis(row.created_at);
  if (created && Date.now() - created > CODE_TTL_MS) {
    return fail(res, 410, 'Mã mời đã hết hạn — nhờ con tạo mã mới nhé.');
  }

  // Chỉ cập nhật khi dòng VẪN ở trạng thái 'pending': hai phụ huynh cùng nhập
  // mã một lúc thì người đến sau không ghi đè người đến trước.
  const { error: updateError } = await supabase
    .from(LINK_TABLE)
    .update({
      parent_user_id: user.uid,
      parent_name: parentName,
      status: 'linked',
      linked_at: new Date().toISOString(),
    })
    .eq('id', row.id)
    .eq('status', 'pending');
  if (updateError) return fail(res, 500, 'Không liên kết được. Thử lại sau.');

  // Đọc lại để chắc chắn mình là người thắng trong cuộc đua (hai phụ huynh
  // cùng nhập một mã): nếu `parent_user_id` không phải mình thì đã bị người
  // khác nối trước.
  const { data: after } = await supabase
    .from(LINK_TABLE)
    .select('parent_user_id, student_name')
    .eq('id', row.id)
    .maybeSingle();
  if (!after || after.parent_user_id !== user.uid) {
    return fail(res, 409, 'Mã mời này vừa được dùng.');
  }

  return ok(res, {
    ok: true,
    studentName: after.student_name || row.student_name || 'Con',
  });
}

/**
 * Ngắt liên kết. Người gọi phải là một trong hai phía của liên kết đó —
 * nếu không, ai biết linkId cũng ngắt được liên kết của người khác.
 */
async function unlink(supabase, user, body, res) {
  const linkId = String(body.linkId || '').trim();
  if (!linkId) return fail(res, 400, 'Thiếu liên kết cần ngắt.');

  const { data, error } = await supabase
    .from(LINK_TABLE)
    .select('id, student_user_id, parent_user_id')
    .eq('id', linkId)
    .maybeSingle();
  if (error) return fail(res, 500, 'Không đọc được liên kết.');
  if (!data) return ok(res, { ok: true }); // đã ngắt rồi thì thôi

  const mine =
    data.student_user_id === user.uid || data.parent_user_id === user.uid;
  if (!mine) return fail(res, 403, 'Bạn không phải thành viên của liên kết này.');

  const { error: deleteError } = await supabase
    .from(LINK_TABLE)
    .delete()
    .eq('id', linkId);
  if (deleteError) return fail(res, 500, 'Không ngắt được liên kết.');

  // Không còn ba mẹ nào liên kết ⇒ bản "cập nhật trực tiếp" của con không còn
  // ai đọc. Xoá luôn cho khỏi đọng dữ liệu trên cloud (dọn dẹp là việc
  // tốt-nhất: hỏng bước này cũng không ảnh hưởng việc ngắt liên kết).
  try {
    const { data: rest } = await supabase
      .from(LINK_TABLE)
      .select('id')
      .eq('student_user_id', data.student_user_id)
      .eq('status', 'linked')
      .limit(1);
    if (!rest || !rest.length) {
      await supabase
        .from(LIVE_TABLE)
        .delete()
        .eq('student_user_id', data.student_user_id);
    }
  } catch (_) {}

  return ok(res, { ok: true });
}

/**
 * Học sinh gửi báo cáo tuần cho gia đình.
 *
 * Báo cáo do app của con dựng (WeeklyReportData) — server KHÔNG tự tổng hợp
 * thêm gì từ dữ liệu riêng tư, nên ba mẹ chỉ thấy đúng phần con đã chọn chia sẻ.
 */
async function shareReport(supabase, user, body, res) {
  const payload =
    body.payload && typeof body.payload === 'object' ? body.payload : null;
  if (!payload) return fail(res, 400, 'Thiếu nội dung báo cáo.');

  const { data: links, error: linkError } = await supabase
    .from(LINK_TABLE)
    .select('id')
    .eq('student_user_id', user.uid)
    .eq('status', 'linked');
  if (linkError) return fail(res, 500, 'Không kiểm tra được liên kết.');
  const parentCount = (links || []).length;

  const { error } = await supabase.from(REPORT_TABLE).insert({
    student_user_id: user.uid,
    student_name: String(body.studentName || '').slice(0, 80),
    payload,
    created_at: new Date().toISOString(),
  });
  if (error) return fail(res, 500, 'Không gửi được báo cáo.');

  // Dọn báo cáo cũ: giữ 12 bản gần nhất, xoá phần dư.
  try {
    const { data: rows } = await supabase
      .from(REPORT_TABLE)
      .select('id')
      .eq('student_user_id', user.uid)
      .order('created_at', { ascending: false });
    const stale = (rows || []).slice(MAX_REPORTS_PER_STUDENT).map((r) => r.id);
    if (stale.length) {
      await supabase.from(REPORT_TABLE).delete().in('id', stale);
    }
  } catch (_) {
    // Dọn dẹp là việc tốt-nhất: không dọn được thì báo cáo vẫn đã gửi xong.
  }

  // Ba mẹ đang mở app thấy ngay báo cáo vừa gửi, không phải kéo làm mới.
  await notifyParents(supabase, user.uid, {
    at: Date.now(),
    kind: 'report',
  }, body.studentName);

  return ok(res, { ok: true, sentTo: parentCount });
}

/**
 * "Cập nhật trực tiếp": con bật công tắc ⇒ app của con tự đẩy trạng thái mới
 * nhất mỗi khi số liệu đổi; ba mẹ thấy tiến độ cập nhật liên tục.
 *
 * Bảng `family_live` chỉ giữ MỘT dòng/học sinh (không phải lịch sử), nên bấm
 * gửi trực tiếp 100 lần cũng không làm ngập lịch sử báo cáo tuần.
 */
async function shareLive(supabase, user, body, res) {
  const name = String(body.studentName || '').slice(0, 80);

  if (body.enabled === false) {
    // Tắt công tắc ⇒ xoá hẳn: ba mẹ không còn thấy bản cũ sót lại.
    const { error } = await supabase
      .from(LIVE_TABLE)
      .delete()
      .eq('student_user_id', user.uid);
    if (error) return fail(res, 500, 'Không tắt được cập nhật trực tiếp.');
    await notifyParents(supabase, user.uid, { at: Date.now(), kind: 'off' }, name);
    return ok(res, { ok: true, live: false });
  }

  const payload =
    body.payload && typeof body.payload === 'object' ? body.payload : null;
  if (!payload) return fail(res, 400, 'Thiếu nội dung cập nhật.');

  const updatedAt = new Date().toISOString();
  const { error } = await supabase.from(LIVE_TABLE).upsert(
    {
      student_user_id: user.uid,
      student_name: name,
      payload,
      updated_at: updatedAt,
    },
    { onConflict: 'student_user_id' }
  );
  if (error) return fail(res, 500, 'Không cập nhật được trạng thái trực tiếp.');

  const at = toMillis(updatedAt) || Date.now();
  await notifyParents(supabase, user.uid, { at, kind: 'live' }, name);
  return ok(res, { ok: true, live: true, updatedAt: at });
}

/** Phụ huynh đọc báo cáo con đã gửi. Bắt buộc còn liên kết mới đọc được. */
async function childReports(supabase, user, body, res) {
  const studentUserId = String(body.studentUserId || '').trim();
  if (!studentUserId) return fail(res, 400, 'Thiếu tài khoản của con.');

  const { data: link, error: linkError } = await supabase
    .from(LINK_TABLE)
    .select('id')
    .eq('student_user_id', studentUserId)
    .eq('parent_user_id', user.uid)
    .eq('status', 'linked')
    .maybeSingle();
  if (linkError) return fail(res, 500, 'Không kiểm tra được liên kết.');
  if (!link) {
    return fail(res, 403, 'Tài khoản này chưa liên kết với bạn.');
  }

  // `since` (epoch ms) cho vòng hỏi định kỳ / tín hiệu Realtime: chỉ kéo phần
  // MỚI hơn cái đã có, không tải lại cả trang mỗi 30 giây.
  const since = Number(body.since) || 0;
  const from = Number(body.from) || 0;
  const to = Number(body.to) || 0;
  let query = supabase
    .from(REPORT_TABLE)
    .select('id, student_name, payload, created_at')
    .eq('student_user_id', studentUserId)
    .order('created_at', { ascending: false })
    .limit(REPORTS_PAGE);
  if (since > 0) query = query.gt('created_at', new Date(since).toISOString());
  if (from > 0) query = query.gte('created_at', new Date(from).toISOString());
  if (to > 0) query = query.lte('created_at', new Date(to).toISOString());

  const { data, error } = await query;
  if (error) return fail(res, 500, 'Không đọc được báo cáo của con.');

  // "Trạng thái trực tiếp" (nếu con đang bật) — bản mới nhất, đọc kèm luôn để
  // ba mẹ không phải chờ thêm một vòng mạng nữa.
  const { data: liveRow } = await supabase
    .from(LIVE_TABLE)
    .select('student_name, payload, updated_at')
    .eq('student_user_id', studentUserId)
    .maybeSingle();

  return ok(res, {
    ok: true,
    serverTime: Date.now(),
    live: liveRow
      ? {
          studentName: liveRow.student_name || 'Con',
          updatedAt: toMillis(liveRow.updated_at),
          payload: liveRow.payload || {},
        }
      : null,
    reports: (data || []).map((r) => ({
      id: r.id,
      studentName: r.student_name || 'Con',
      createdAt: toMillis(r.created_at),
      payload: r.payload || {},
    })),
  });
}

/** Phụ huynh đặt tên riêng cho một con (chỉ hiển thị phía phụ huynh). */
async function setChildLabel(supabase, user, body, res) {
  const linkId = String(body.linkId || '').trim();
  const label = String(body.label || '').trim().slice(0, 24);
  if (!linkId) return fail(res, 400, 'Thiếu liên kết cần đổi tên.');

  const { data, error } = await supabase
    .from(LINK_TABLE)
    .select('id, parent_user_id')
    .eq('id', linkId)
    .maybeSingle();
  if (error) return fail(res, 500, 'Không đọc được liên kết.');
  if (!data || data.parent_user_id !== user.uid) {
    return fail(res, 403, 'Bạn không phải phụ huynh của liên kết này.');
  }

  const { error: updateError } = await supabase
    .from(LINK_TABLE)
    .update({ parent_label: label })
    .eq('id', linkId);
  if (updateError) return fail(res, 500, 'Không đổi được tên hiển thị.');
  return ok(res, { ok: true, label });
}

/** Phụ huynh bật/tắt nhận thông báo khi một con cập nhật. */
async function notifyPref(supabase, user, body, res) {
  const studentUserId = String(body.studentUserId || '').trim();
  const on = body.on !== false;
  if (!studentUserId) return fail(res, 400, 'Thiếu tài khoản của con.');

  const { error } = await supabase
    .from(LINK_TABLE)
    .update({ notify_on: on })
    .eq('student_user_id', studentUserId)
    .eq('parent_user_id', user.uid);
  if (error) return fail(res, 500, 'Không lưu được tuỳ chọn thông báo.');
  return ok(res, { ok: true, on });
}

/** Đăng ký / huỷ token Web Push của thiết bị này cho tài khoản đang đăng nhập. */
async function pushToken(supabase, user, body, res) {
  const token = String(body.token || '').trim();
  if (!token) return fail(res, 400, 'Thiếu token thiết bị.');

  if (body.remove === true) {
    const { error } = await supabase
      .from(NOTIF_TABLE)
      .delete()
      .eq('token', token)
      .eq('user_id', user.uid);
    if (error) return fail(res, 500, 'Không huỷ được token.');
    return ok(res, { ok: true });
  }

  const { error } = await supabase.from(NOTIF_TABLE).upsert(
    {
      token,
      user_id: user.uid,
      created_at: new Date().toISOString(),
    },
    { onConflict: 'token' }
  );
  if (error) return fail(res, 500, 'Không đăng ký được thông báo đẩy.');
  return ok(res, { ok: true });
}
