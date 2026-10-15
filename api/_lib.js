// Shared helpers for EduPulse serverless API (send/verify email OTP).
//
// KHÔNG dùng firebase-admin (vì org policy chặn tạo service account key).
// Xác thực người dùng bằng Firebase REST `accounts:lookup` — Google tự kiểm
// tra ID token với API key công khai của project.
//
// Env vars (đặt trong Vercel — chỉ phía server, không bao giờ lộ ra client):
//   FIREBASE_API_KEY           — API key của Firebase web app (công khai)
//   SUPABASE_URL               — https://nygkogzdemplbfydhspd.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY  — service_role key (chỉ dùng server-side)
//   SMTP_USER / SMTP_PASS      — Gmail app-password để gửi email mã xác minh

// Mã OTP/bí mật phải dùng nguồn ngẫu nhiên mật mã (không dùng Math.random —
// trạng thái bộ sinh có thể bị khôi phục từ vài mẫu output).
const { randomInt } = require('node:crypto');

const LOOKUP_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' +
  encodeURIComponent(process.env.FIREBASE_API_KEY || '');

/** Error kèm HTTP status để handler trả đúng mã (401 khi thiếu/hết hạn token). */
function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

let _supabase;
let _transporter;
let _initError;

/** Xác thực ID token bằng Firebase REST, trả về { uid, email, emailVerified }. */
async function getFirebaseUser(idToken) {
  if (!process.env.FIREBASE_API_KEY) {
    throw new Error('FIREBASE_API_KEY chưa được cấu hình.');
  }
  const resp = await fetch(LOOKUP_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok || !data.users || !data.users.length) {
    throw httpError(401, 'Token đăng nhập không hợp lệ hoặc đã hết hạn.');
  }
  const u = data.users[0];
  return {
    uid: u.localId,
    email: (u.email || '').trim().toLowerCase(),
    emailVerified: !!u.emailVerified,
    providerId: ((u.providerUserInfo || []).map((p) => p.providerId) || []),
  };
}

/** Gửi request có idToken; trả về response parse sẵn + status. */
function requireFirebaseUser(req) {
  return new Promise((resolve, reject) => {
    readJson(req)
      .then(async (body) => {
        const idToken = String(body.idToken || '');
        if (!idToken) {
          reject(httpError(401, 'Thiếu token đăng nhập.'));
          return;
        }
        try {
          resolve(await getFirebaseUser(idToken));
        } catch (e) {
          reject(e);
        }
      })
      .catch(reject);
  });
}

function getSupabase() {
  if (_supabase) return _supabase;
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY chưa được cấu hình.');
  }
  // eslint-disable-next-line global-require
  const { createClient } = require('@supabase/supabase-js');
  _supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );
  return _supabase;
}

function getTransporter() {
  if (_transporter) return _transporter;
  if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
    throw new Error('SMTP_USER/SMTP_PASS chưa được cấu hình.');
  }
  // eslint-disable-next-line global-require
  const nodemailer = require('nodemailer');
  _transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  return _transporter;
}

function newCode() {
  // 8 chữ số, nguồn ngẫu nhiên mật mã (kể cả khi dùng để chống đoán).
  return String(randomInt(10000000, 100000000));
}

const CODE_TTL_MS = 15 * 60 * 1000; // mã hiệu lực 15 phút

function readJson(req, maxBytes) {
  // `maxBytes` cho phép endpoint nào đó nhận payload lớn hơn (sao lưu toàn bộ
  // dữ liệu kèm ảnh đính kèm). Mặc định giữ 1MB như trước.
  //
  // Đo bằng BYTE (không phải ký tự) để tiếng Việt/emoji không lách trần; khi
  // vượt trần thì drain nốt request để kết nối không bị treo giữa chừng.
  const limit = maxBytes || 1e6;
  return new Promise((resolve, reject) => {
    let body = '';
    let bytes = 0;
    let rejected = false;
    req.on('data', (c) => {
      if (rejected) return;
      bytes += Buffer.byteLength(c);
      if (bytes > limit) {
        rejected = true;
        reject(new Error('Payload quá lớn.'));
        req.resume(); // đọc bỏ phần còn lại thay vì đệm thêm vào RAM
        return;
      }
      body += c;
    });
    req.on('end', () => {
      if (rejected) return;
      if (!body) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error('JSON không hợp lệ.'));
      }
    });
  });
}

function ok(res, data) {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(data));
}

function fail(res, status, message) {
  res.statusCode = status || 500;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ ok: false, error: message }));
}

module.exports = {
  getFirebaseUser,
  requireFirebaseUser,
  getSupabase,
  getTransporter,
  newCode,
  CODE_TTL_MS,
  readJson,
  ok,
  fail,
  httpError,
};
