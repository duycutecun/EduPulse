// Shared helpers for EduPulse serverless API (send/verify email OTP).
//
// Xác thực người dùng bằng Supabase Auth: client gửi access token của phiên
// Supabase (`Authorization: Bearer <access_token>` hoặc body `{ idToken }` —
// giữ đúng shape body cũ), server gọi `auth.getUser(token)` qua supabase-js —
// máy chủ GoTrue của Supabase tự kiểm tra chữ ký/hạn token, không cần secret
// nào ở server ngoài service_role key đã dùng để đọc/ghi bảng.
// (Đã bỏ Firebase: ID token Firebase không còn dùng cho bất kỳ endpoint nào.)
//
// Env vars (đặt trong Vercel — chỉ phía server, không bao giờ lộ ra client):
//   SUPABASE_URL               — https://nygkogzdemplbfydhspd.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY  — service_role key (chỉ dùng server-side)
//   SMTP_USER / SMTP_PASS      — Gmail app-password để gửi email mã xác minh

// Mã OTP/bí mật phải dùng nguồn ngẫu nhiên mật mã (không dùng Math.random —
// trạng thái bộ sinh có thể bị khôi phục từ vài mẫu output).
const { randomInt } = require('node:crypto');

/** Error kèm HTTP status để handler trả đúng mã (401 khi thiếu/hết hạn token). */
function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

let _supabase;
let _transporter;

/**
 * Xác thực access token Supabase, trả về { uid, email, emailVerified }.
 * Ném lỗi 401 khi token thiếu/không hợp lệ/hết hạn (cùng chữ ký lỗi cũ).
 */
async function getSupabaseUser(idToken) {
  const token = String(idToken || '').trim();
  if (!token) {
    throw httpError(401, 'Thiếu token đăng nhập.');
  }
  // Client dùng service_role key làm apikey (đã có sẵn, chỉ server-side) —
  // GoTrue xác thực JWT trong header Authorization, không phụ thuộc apikey.
  let supabase;
  try {
    supabase = getSupabase();
  } catch (e) {
    throw httpError(500, e.message || 'Máy chủ chưa cấu hình Supabase.');
  }
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data || !data.user) {
    throw httpError(401, 'Token đăng nhập không hợp lệ hoặc đã hết hạn.');
  }
  const u = data.user;
  return {
    uid: u.id,
    email: String(u.email || '').trim().toLowerCase(),
    // Supabase User set `email_confirmed_at` khi email đã xác nhận.
    emailVerified: !!u.email_confirmed_at,
    appMetadata: u.app_metadata || {},
  };
}

/** Đọc request có `idToken` (shape body cũ — giữ cho 5 endpoint đổi verify). */
function requireSupabaseUser(req) {
  return new Promise((resolve, reject) => {
    readJson(req)
      .then(async (body) => {
        const idToken = String(body.idToken || body.token || '');
        if (!idToken) {
          reject(httpError(401, 'Thiếu token đăng nhập.'));
          return;
        }
        try {
          resolve(await getSupabaseUser(idToken));
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
  getSupabaseUser,
  requireSupabaseUser,
  getSupabase,
  getTransporter,
  newCode,
  CODE_TTL_MS,
  readJson,
  ok,
  fail,
  httpError,
};
