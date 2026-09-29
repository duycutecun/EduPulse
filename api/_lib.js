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

const LOOKUP_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' +
  encodeURIComponent(process.env.FIREBASE_API_KEY || '');

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
    throw new Error('Token đăng nhập không hợp lệ hoặc đã hết hạn.');
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
          reject(new Error('Thiếu token đăng nhập.'));
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
  return String(Math.floor(10000000 + Math.random() * 90000000));
}

const CODE_TTL_MS = 15 * 60 * 1000; // mã hiệu lực 15 phút

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (c) => {
      body += c;
      if (body.length > 1e6) reject(new Error('Payload quá lớn.'));
    });
    req.on('end', () => {
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
};