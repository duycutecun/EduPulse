// API sao lưu toàn bộ dữ liệu EduPulse (snapshot) — nguồn linking giữa bản gốc
// trên máy và bản sao lưu trên cloud, dùng chung cho MỌI thiết bị.
//
// VÌ SAO CẦN ENDPOINT RIÊNG (không gọi thẳng Supabase từ app):
//  - App đăng nhập bằng FIREBASE, còn policy RLS trong schema.sql lại so sánh
//    `user_id = auth.uid()` (Supabase Auth). Không có session Supabase thì
//    auth.uid() = NULL → mọi select rỗng, mọi upsert bị từ chối, lỗi bị try/catch
//    nuốt nên app "đồng bộ" xong nhưng không có gì được lưu. Đây chính là lý do
//    bản gốc và bản sao lưu không có linking.
//  - Ở đây server xác thực ID token bằng Firebase REST (getFirebaseUser) rồi dùng
//    SUPABASE_SERVICE_ROLE_KEY — bỏ qua RLS, tự kiểm soát quyền: mỗi người chỉ
//    chạm được đúng dòng `user_id` = uid của chính họ.
//
// CƠ CHẾ "BẢN MỚI NHẤT THẮNG" (last-write-wins) — server là đồng hồ chuẩn:
//  - Mỗi lần ghi, server đóng dấu `updated_at = now()` (không tin đồng hồ máy
//    người dùng, tránh lệch giờ làm mất dữ liệu).
//  - Client gửi kèm `baseUpdatedAt` = mốc server mà client đã biết.
//    • baseUpdatedAt = 0  → client chưa từng sync (thiết bị mới): ghi thẳng.
//    • server có bản MỚI HƠN baseUpdatedAt → KHÔNG ghi đè, trả ngược bản cloud
//      về cho client (`applied: false`) để client lấy theo yêu cầu "luôn ưu tiên
//      bản sao lưu gần nhất".
//    • ngược lại → ghi, trả mốc server mới.
//  - Hai máy cùng lúc sửa: máy đến sau thấy server đã mới hơn mình biết → nhận
//    bản của máy kia. Hai máy luôn hội tụ về cùng một trạng thái.
//
// ẢNH ĐÍNH KÈM: base64 nặng nên nằm bảng riêng `user_blobs`, chỉ gửi khi
// checksum đổi — snapshot không bị phình theo dung lượng ảnh.
//
// Route (tất cả đều cần header/Firebase ID token trong body):
//   GET  /api/backup            → toàn bộ snapshot + chỉ mục ảnh đính kèm
//   GET  /api/backup?meta=1     → chỉ { exists, updatedAt, revision } (nhẹ, để
//                                 client hỏi "cloud có mới hơn máy không?")
//   GET  /api/backup?blob=KEY   → tải một ảnh đính kèm (base64)
//   POST /api/backup            → đẩy snapshot + ảnh mới/đã đổi + xoá ảnh
const {
  getFirebaseUser,
  getSupabase,
  readJson,
  ok,
  fail,
} = require('./_lib');

const crypto = require('crypto');

const SNAPSHOT_TABLE = 'user_snapshots';
const BLOB_TABLE = 'user_blobs';

// Vercel chặn body > 4.5MB. Để dưới ngưỡng để chắc chắn.
const MAX_BODY = 4 * 1024 * 1024;
// Số ảnh gửi kèm mỗi lần đẩy. Vượt số này client giữ lại gửi ở vòng sau, nên
// không bao giờ vượt giới hạn body dù người dùng gắn nhiều ảnh.
const MAX_BLOBS_PER_PUSH = 4;

const KEY_SEP = '__';

function blobKey(taskId, attachmentId) {
  return `${taskId}${KEY_SEP}${attachmentId}`;
}

function parseBlobKey(key) {
  const i = String(key).indexOf(KEY_SEP);
  if (i <= 0) return null;
  return {
    taskId: key.slice(0, i),
    attachmentId: key.slice(i + KEY_SEP.length),
  };
}

function toMillis(value) {
  const t = Date.parse(value || '');
  return Number.isNaN(t) ? 0 : t;
}

// ── Realtime: báo cho máy khác biết có bản mới ─────────────────────────────
//
// Mục tiêu: thêm nhiệm vụ trên máy tính thì máy điện thoại nhảy ngay, không
// phải chờ hết chu kỳ poll.
//
// VÌ SAO ĐI QUA REST BROADCAST MÀ KHÔNG DÙNG `postgres_changes`:
//   `postgres_changes` lọc theo RLS của Supabase và cần một Supabase session.
//   App đăng nhập bằng FIREBASE nên không có session đó, `user_snapshots` lại
//   bật RLO không policy — tức là `postgres_changes` sẽ âm thầm không gửi gì,
//   y hệt lỗi đã làm hỏng luồng sync cũ.
//
//   REST broadcast thì khác: nó đi thẳng ra máy chủ Realtime bằng HTTP, không
//   qua RLS, không cần WebSocket phía server (serverless không giữ được socket).
//   Nội dung gửi đi CHỈ là con số `revision` — client nhận xong tự gọi
//   `GET /api/backup` kéo payload thật. Nhờ vậy dữ liệu không bao giờ đi qua
//   kênh broadcast (vốn không mã hoá).
//
// KÊNH CÓ CẦN GIẤU KHÔNG:
//   Topic đặt bằng hash(uid + service_role_key) → người ngoài không đoán được
//   (phải biết uid VÀ key), và topic chỉ được trả cho chính người đó sau khi
//   xác thực Firebase. Client dùng kênh public vì không có Supabase session;
//   nhưng kênh public + topic không đoán được = an toàn tương đương private.

function topicFor(uid) {
  return crypto
    .createHash('sha256')
    .update(uid + (process.env.SUPABASE_SERVICE_ROLE_KEY || ''))
    .digest('hex')
    .slice(0, 32);
}

/**
 * Bắn một tin nhắn broadcast. LUÔN trả về, không bao giờ ném lỗi ra ngoài:
 * bỏ được thì ghi bản sao lưu vẫn thành công, máy khác chỉ chậm thêm vài giây
 * tới chu kỳ poll — hỏng cả thao tác lưu chỉ vì thông báo là sai lầm.
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
      },
    );
    return resp.ok;
  } catch (_) {
    return false;
  }
}

/** Chỉ mục ảnh đính kèm: [{ key, name, sizeBytes, checksum, updatedAt }]. */
async function blobIndex(supabase, uid) {
  const { data, error } = await supabase
    .from(BLOB_TABLE)
    .select('id, name, size_bytes, checksum, updated_at')
    .eq('user_id', uid)
    .order('updated_at', { ascending: true });
  if (error) return [];
  return (data || []).map((r) => {
    const parsed = parseBlobKey(r.id.slice(uid.length + KEY_SEP.length));
    return {
      key: parsed ? `${parsed.taskId}${KEY_SEP}${parsed.attachmentId}` : r.id,
      name: r.name || '',
      sizeBytes: Number(r.size_bytes) || 0,
      checksum: r.checksum || '',
      updatedAt: toMillis(r.updated_at),
    };
  });
}

/** Đọc payload của request một lần duy nhất (đọc 2 lần sẽ treo stream). */
function readBody(req) {
  if (req.body !== undefined && req.body !== null && req.body !== '') {
    if (typeof req.body === 'string') {
      try {
        return Promise.resolve(JSON.parse(req.body));
      } catch {
        return Promise.reject(new Error('JSON không hợp lệ.'));
      }
    }
    return Promise.resolve(req.body);
  }
  return readJson(req, MAX_BODY);
}

module.exports = async function handler(req, res) {
  let idToken = '';
  // Ưu tiên header để curl kiểm tra nhanh được; app gửi trong body.
  const authHeader = String(req.headers.authorization || '');
  if (/^Bearer\s+/i.test(authHeader)) {
    idToken = authHeader.replace(/^Bearer\s+/i, '').trim();
  }

  let body = {};
  if (req.method === 'POST') {
    try {
      body = (await readBody(req)) || {};
    } catch (e) {
      return fail(res, 400, e.message || 'Dữ liệu gửi lên không hợp lệ.');
    }
    if (!idToken) idToken = String(body.idToken || '').trim();
  }

  if (!idToken) {
    return fail(
      res,
      401,
      'Chưa đăng nhập — không sao lưu được. Hãy đăng nhập rồi thử lại.',
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
      e.message || 'Máy chủ sao lưu chưa cấu hình (SUPABASE_SERVICE_ROLE_KEY).',
    );
  }

  try {
    if (req.method === 'GET') return await handleGet(supabase, uid, req, res);
    if (req.method === 'POST') return await handlePost(supabase, uid, body, res);
    return fail(res, 405, 'Chỉ hỗ trợ GET và POST.');
  } catch (e) {
    return fail(res, 500, e.message || 'Sao lưu lỗi. Thử lại sau.');
  }
};

async function handleGet(supabase, uid, req, res) {
  // Tải một ảnh đính kèm.
  const blobKeyParam = req.query && req.query.blob;
  if (blobKeyParam) {
    const { data, error } = await supabase
      .from(BLOB_TABLE)
      .select('id, name, size_bytes, checksum, data')
      .eq('id', `${uid}${KEY_SEP}${blobKeyParam}`)
      .maybeSingle();
    if (error) return fail(res, 500, 'Không tải được tệp đính kèm.');
    if (!data) return fail(res, 404, 'Tệp đính kèm không tồn tại trên cloud.');
    return ok(res, {
      ok: true,
      key: blobKeyParam,
      name: data.name || '',
      sizeBytes: Number(data.size_bytes) || 0,
      checksum: data.checksum || '',
      data: data.data || '',
    });
  }

  const { data: row, error } = await supabase
    .from(SNAPSHOT_TABLE)
    .select('payload, updated_at, revision')
    .eq('user_id', uid)
    .maybeSingle();
  if (error) return fail(res, 500, 'Không đọc được bản sao lưu.');

  const updatedAt = row ? toMillis(row.updated_at) : 0;
  const topic = topicFor(uid);

  // Chỉ hỏi mốc mới nhất — nhẹ hơn nhiều so với tải cả snapshot.
  if (req.query && req.query.meta === '1') {
    return ok(res, {
      ok: true,
      exists: !!row,
      updatedAt,
      revision: row ? Number(row.revision) || 0 : 0,
      topic,
    });
  }

  return ok(res, {
    ok: true,
    exists: !!row,
    updatedAt,
    revision: row ? Number(row.revision) || 0 : 0,
    topic,
    payload: row ? row.payload || {} : {},
    blobs: await blobIndex(supabase, uid),
  });
}

async function handlePost(supabase, uid, body, res) {
  const payload =
    body.payload && typeof body.payload === 'object' ? body.payload : {};
  const baseUpdatedAt = Number(body.baseUpdatedAt) || 0;

  const { data: current, error: readError } = await supabase
    .from(SNAPSHOT_TABLE)
    .select('payload, updated_at, revision')
    .eq('user_id', uid)
    .maybeSingle();
  if (readError) return fail(res, 500, 'Không đọc được bản sao lưu.');

  const currentUpdatedAt = current ? toMillis(current.updated_at) : 0;

  // Bản trên cloud mới hơn thứ client biết → trả ngược về cho client lấy,
  // KHÔNG ghi đè (đây là "ưu tiên bản sao lưu gần nhất" ở tầng server).
  if (current && baseUpdatedAt > 0 && currentUpdatedAt > baseUpdatedAt) {
    return ok(res, {
      ok: true,
      applied: false,
      reason: 'cloud_moi_hon',
      updatedAt: currentUpdatedAt,
      revision: Number(current.revision) || 0,
      topic: topicFor(uid),
      payload: current.payload || {},
      blobs: await blobIndex(supabase, uid),
    });
  }

  // Nội dung y hệt bản đang có thì không ghi lại (tránh đổi mốc `updated_at`
  // mỗi lần poll và tránh hai máy đẩy liên hồi đè lên nhau).
  const unchanged =
    current &&
    JSON.stringify(current.payload || {}) === JSON.stringify(payload);

  let updatedAt = currentUpdatedAt;
  let revision = current ? Number(current.revision) || 0 : 0;

  if (!unchanged) {
    revision += 1;
    updatedAt = Date.now();
    const record = {
      user_id: uid,
      device_id: String(body.deviceId || ''),
      payload,
      revision,
      updated_at: new Date(updatedAt).toISOString(),
    };
    const { error } = await supabase
      .from(SNAPSHOT_TABLE)
      .upsert(record, { onConflict: 'user_id' });
    if (error) return fail(res, 500, 'Không lưu được bản sao lưu.');

    // Báo các máy khác ngay: thêm nhiệm vụ trên máy tính thì điện thoại kéo
    // bản mới trong ~1 giây thay vì chờ hết chu kỳ poll.
    //
    // Chỉ bắn khi nội dung THẬT SỰ đổi: `unchanged` là trường hợp poll định
    // kỳ mà không có gì mới, bắn lúc đó là nhiễu vô ích (và mỗi lần bắn đều tốn
    // 1 lượt trong hạn mức 100 tin/giây của Realtime).
    await broadcast(topicFor(uid), 'snapshot', { revision });
  }

  // Ảnh đính kèm: chỉ gửi phần client thấy là mới/đổi.
  const incoming = Array.isArray(body.blobs) ? body.blobs : [];
  const accepted = [];
  for (const b of incoming.slice(0, MAX_BLOBS_PER_PUSH)) {
    if (!b || typeof b !== 'object') continue;
    const taskId = String(b.taskId || '');
    const attachmentId = String(b.attachmentId || '');
    const data = String(b.base64 || '');
    if (!taskId || !attachmentId || !data) continue;
    const { error } = await supabase.from(BLOB_TABLE).upsert(
      {
        id: `${uid}${KEY_SEP}${blobKey(taskId, attachmentId)}`,
        user_id: uid,
        task_id: taskId,
        attachment_id: attachmentId,
        name: String(b.name || ''),
        size_bytes: Number(b.sizeBytes) || 0,
        checksum: String(b.checksum || ''),
        data,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'id' },
    );
    if (error) return fail(res, 500, 'Không lưu được ảnh đính kèm.');
    accepted.push(blobKey(taskId, attachmentId));
  }

  // Ảnh đã xoá trên máy này thì xoá luôn trên cloud — nếu không, lần khôi
  // phục sau ảnh cũ sẽ "sống lại" (đúng lỗi từng xảy ra với kỳ thi).
  const removed = Array.isArray(body.deletedBlobs) ? body.deletedBlobs : [];
  const removeIds = removed
    .slice(0, 200)
    .map((k) => `${uid}${KEY_SEP}${String(k)}`);
  if (removeIds.length) {
    const { error } = await supabase
      .from(BLOB_TABLE)
      .delete()
      .eq('user_id', uid)
      .in('id', removeIds);
    if (error) return fail(res, 500, 'Không xoá được ảnh đính kèm trên cloud.');
  }

  return ok(res, {
    ok: true,
    applied: true,
    changed: !unchanged,
    updatedAt,
    revision,
    topic: topicFor(uid),
    acceptedBlobs: accepted,
    removedBlobs: removeIds.length,
    remainingBlobs: Math.max(
      0,
      incoming.length - Math.min(incoming.length, MAX_BLOBS_PER_PUSH),
    ),
  });
}
