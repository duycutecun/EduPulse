#!/usr/bin/env node
// ============================================================================
// EduPulse — công cụ backfill ánh xạ dữ liệu cloud cũ (keyed Firebase UID)
// sang Supabase UUID mới, ghép theo EMAIL.
//
// BỐI CẢNH: app đã bỏ Firebase, đăng nhập bằng Supabase Auth. Dữ liệu cũ trên
// Supabase vẫn khoá theo Firebase UID 28 ký tự (không gạch) — token Firebase
// đã chết nên dòng cũ thành dữ liệu chết. Script này:
//   1. Lấy danh sách user Supabase Auth (admin API, service_role) → email→uuid.
//   2. Dựng map old_uid→email từ `email_codes` (purpose='verify') + `family_links`
//      (parent_user_id↔parent_email).
//   3. Giao hai map ⇒ cặp (old_uid, new_uuid). Dry-run mặc định: CHỈ in kế hoạch
//      và đếm số dòng mỗi bảng; KHÔNG ghi gì cả.
//   4. Apply (chỉ khi env BACKFILL_APPLY=1): PATCH/Delete+Insert theo thứ tự.
//   5. In tổng kết + danh sách uid mồ côi/mâu thuẫn để Owner xem tay.
//
// CÁCH CHẠY:
//   node scripts/backfill_firebase_uid.mjs            (dry-run, mặc định)
//   node scripts/backfill_firebase_uid.mjs --dry-run  (dry-run rõ ràng)
//   BACKFILL_APPLY=1 node scripts/backfill_firebase_uid.mjs   (bash)
//   PowerShell:  $env:BACKFILL_APPLY='1'; $env:SUPABASE_URL='...'; `
//                $env:SUPABASE_SERVICE_ROLE_KEY='...'; node scripts/...
//
// ZERO-DEPENDENCY: dùng fetch mở sẵn của Node 20+, không supabase-js.
// KHÔNG hardcode key — mọi khoá lấy từ env (xem supabase/BACKFILL_UID_RUNBOOK.md).
// ============================================================================

import {
  buildUidEmailMap,
  buildEmailUuidMap,
  buildPairPlan,
  rewriteBlobId,
  snapshotDecision,
  blobDecision,
  isFirebaseUid,
} from './backfill_uid_logic.mjs';

// ── Cấu hình bảng/cột cần dời ────────────────────────────────────────────────
// Mỗi mục: PATCH ?<col|uid>=eq.<old> SET {<col|uid>: <new>}. `pk` đánh dấu
// cột là khóa chính (vẫn PATCH được — PostgREST cho phép UPDATE giá trị PK).
const PATCH_PLAN = [
  { table: 'user_profiles',      cols: [{ col: 'user_id', pk: true }] },
  { table: 'exams',              cols: [{ col: 'user_id' }] },
  { table: 'today_tasks',        cols: [{ col: 'user_id' }] },
  { table: 'study_logs',         cols: [{ col: 'user_id' }] },
  { table: 'family_goals',       cols: [{ col: 'student_user_id' }, { col: 'parent_user_id' }] },
  { table: 'family_messages',    cols: [{ col: 'student_user_id' }, { col: 'parent_user_id' }] },
  { table: 'family_reports',     cols: [{ col: 'student_user_id' }] },
  { table: 'family_live',        cols: [{ col: 'student_user_id', pk: true }] },
  { table: 'family_links',       cols: [{ col: 'student_user_id' }, { col: 'parent_user_id' }] },
  { table: 'family_notif_tokens',cols: [{ col: 'user_id' }] },
  { table: 'email_codes',        cols: [{ col: 'uid' }] },
];

const ADMIN_PAGE_SIZE = 200;      // GET /auth/v1/admin/users?per_page=200
const REST_PAGE_SIZE = 1000;      // phân trang PostgREST bằng limit/offset

// ── HTTP helpers (thuần fetch) ───────────────────────────────────────────────

function die(msg, code = 1) {
  console.error(`\n[LỖI] ${msg}`);
  process.exit(code);
}

function envRequired() {
  const url = (process.env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
  const key = (process.env.SUPABASE_SERVICE_ROLE_KEY || '').trim();
  if (!url || !key) {
    console.error(
      'THIẾU BIẾN MÔI TRƯỜNG — cần CẢ HAI (không hardcode vào source):\n' +
      '  SUPABASE_URL                 — ví dụ https://xxxx.supabase.co\n' +
      '  SUPABASE_SERVICE_ROLE_KEY    — khoá service_role (Settings → API)\n\n' +
      'Chạy:\n' +
      '  bash:     SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/backfill_firebase_uid.mjs\n' +
      '  PowerShell:\n' +
      "    $env:SUPABASE_URL='https://xxxx.supabase.co'\n" +
      "    $env:SUPABASE_SERVICE_ROLE_KEY='eyJ...'\n" +
      '    node scripts/backfill_firebase_uid.mjs          # dry-run (mặc định)\n' +
      '    $env:BACKFILL_APPLY=\'1\'; node scripts/backfill_firebase_uid.mjs  # ghi thật (SAU KHI BACKUP)'
    );
    process.exit(1);
  }
  return { url, key, apply: process.env.BACKFILL_APPLY === '1' };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * fetch trực tiếp với timeout + retry (429/5xx).
 * @returns {Promise<Response>}
 */
async function http(method, url, { key, headers = {}, body, retries = 3 } = {}) {
  let lastErr = null;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, {
        method,
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          ...headers,
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(60_000),
      });
      // 429 / 5xx: chờ rồi thử lại.
      if (res.status === 429 || res.status >= 500) {
        lastErr = new Error(`HTTP ${res.status}`);
        if (attempt < retries) {
          await sleep(800 * attempt);
          continue;
        }
      }
      return res;
    } catch (err) {
      lastErr = err;
      if (attempt < retries) await sleep(800 * attempt);
    }
  }
  throw lastErr;
}

/** POST/GET một thân JSON; lỗi HTTP ⇒ throw với thông điệp cả thân. */
async function jsonHttp(method, url, opts) {
  const res = await http(method, url, opts);
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`${method} ${url} → HTTP ${res.status}: ${text.slice(0, 500)}`);
  }
  return text ? JSON.parse(text) : null;
}

/** Đếm dòng bằng HEAD với `Prefer: count=exact` (đọc Content-Range). */
async function countRows(restUrl, key, table, search) {
  const url = `${restUrl}/${table}?${search}&select=`;
  const res = await http('HEAD', url, {
    key,
    headers: {
      Prefer: 'count=exact',
      'Head-Request': 'true',
    },
  });
  if (!res.ok) {
    throw new Error(`HEAD ${table}?${search} → HTTP ${res.status}`);
  }
  const range = res.headers.get('content-range') || '';
  const m = /\/(\d+|\*)$/.exec(range);
  return m && m[1] !== '*' ? Number(m[1]) : null;
}

/** Phân trang PostgREST bằng limit/offset (bảng đẹp, dùng index). */
async function getTableRows(restUrl, key, table, search, order) {
  const rows = [];
  for (let offset = 0; ; offset += REST_PAGE_SIZE) {
    const page = await jsonHttp(
      'GET',
      `${restUrl}/${table}?${search}&order=${order}&limit=${REST_PAGE_SIZE}&offset=${offset}`,
      { key }
    );
    const list = Array.isArray(page) ? page : [];
    rows.push(...list);
    if (list.length < REST_PAGE_SIZE) break;
  }
  return rows;
}

// ── Bước 1: danh sách user Supabase Auth ────────────────────────────────────

async function fetchAdminUsers(baseUrl, key) {
  const users = [];
  for (let page = 1; page <= 500; page++) {
    const res = await jsonHttp(
      'GET',
      `${baseUrl}/auth/v1/admin/users?page=${page}&per_page=${ADMIN_PAGE_SIZE}`,
      { key }
    );
    const list = Array.isArray(res && res.users) ? res.users : [];
    users.push(...list);
    if (list.length < ADMIN_PAGE_SIZE) break;
  }
  return users;
}

// ── Bước 2: map old_uid → email ─────────────────────────────────────────────

async function fetchUidEmailSources(restUrl, key) {
  // email_codes chỉ lược mục đích 'verify' và uid có mặt — nguồn chính.
  const emailCodeRows = await getTableRows(
    restUrl, key, 'email_codes',
    'purpose=eq.verify&uid=not.is.null&select=email,uid',
    'created_at.id'
  );
  // family_links: dòng ba mẹ đã lưu email cùng parent_user_id.
  const familyLinkRows = await getTableRows(
    restUrl, key, 'family_links',
    'parent_user_id=not.is.null&parent_email=not.is.null&select=parent_user_id,parent_email',
    'created_at.id'
  );
  return { emailCodeRows, familyLinkRows };
}

// ── Bước 4: apply ───────────────────────────────────────────────────────────

/** PATCH một cột của bảng: mọi dòng có giá trị cũ trở thành giá trị mới. */
async function patchColumn(restUrl, key, table, col, oldVal, newVal) {
  const search = `${col}=eq.${encodeURIComponent(oldVal)}`;
  const res = await http('PATCH', `${restUrl}/${table}?${search}`, {
    key,
    headers: { 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: { [col]: newVal },
  });
  if (res.status === 409) {
    return { ok: false, conflict: true }; // vi phạm unique/PK — xử riêng
  }
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`PATCH ${table}?${search} → HTTP ${res.status}: ${text.slice(0, 300)}`);
  }
  return { ok: true };
}

/** Chọn 1 dòng theo filter; trả về null nếu không có. */
async function getOneRow(restUrl, key, table, search, selectCols) {
  const rows = await jsonHttp(
    'GET',
    `${restUrl}/${table}?${search}&select=${selectCols}&limit=2`,
    { key }
  );
  if (!Array.isArray(rows) || rows.length === 0) return null;
  if (rows.length > 1) console.warn(`[CẢNH BÁO] ${table}?${search} trả về >1 dòng, dùng dòng đầu.`);
  return rows[0];
}

async function insertRows(restUrl, key, table, rows) {
  const res = await http('POST', `${restUrl}/${table}`, {
    key,
    headers: { 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: rows,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`INSERT ${table} → HTTP ${res.status}: ${text.slice(0, 300)}`);
  }
}

async function upsertRows(restUrl, key, table, rows, onConflict) {
  const res = await http('POST', `${restUrl}/${table}?on_conflict=${onConflict}`, {
    key,
    headers: {
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: rows,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`UPSERT ${table} → HTTP ${res.status}: ${text.slice(0, 300)}`);
  }
}

async function deleteRows(restUrl, key, table, search) {
  const res = await http('DELETE', `${restUrl}/${table}?${search}`, {
    key,
    headers: { Prefer: 'return=minimal' },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DELETE ${table}?${search} → HTTP ${res.status}: ${text.slice(0, 300)}`);
  }
}

/**
 * Dời 1 dòng snapshot (Delete+Insert vì user_id là PK):
 *   - không tồn tại dòng mới ⇒ chép nguyên + đổi user_id;
 *   - dòng mới đã có ⇒ "mới hơn thắng" (giữ dòng có updated_at cao hơn),
 *     bằng/quá lạ ⇒ bỏ qua, cảnh báo để Owner xem tay.
 */
async function migrateSnapshot(restUrl, key, oldUid, newUuid, tally) {
  const oldRow = await getOneRow(
    restUrl, key, 'user_snapshots', `user_id=eq.${encodeURIComponent(oldUid)}`, '*'
  );
  if (!oldRow) return; // Dry-run đếm được nhưng lúc apply đã biến mất — bỏ qua
  const newRow = await getOneRow(
    restUrl, key, 'user_snapshots', `user_id=eq.${encodeURIComponent(newUuid)}`,
    'user_id,updated_at'
  );
  const decision = snapshotDecision(oldRow, newRow);
  tally.snapshots[decision] = (tally.snapshots[decision] || 0) + 1;

  if (decision === 'insert') {
    const copy = { ...oldRow, user_id: newUuid };
    await insertRows(restUrl, key, 'user_snapshots', [copy]);
    await deleteRows(restUrl, key, 'user_snapshots', `user_id=eq.${encodeURIComponent(oldUid)}`);
  } else if (decision === 'overwrite') {
    // Cập nhật dòng mới bằng nội dung dòng cũ (KHÔNG đụng user_id).
    const upd = {
      device_id: oldRow.device_id,
      payload: oldRow.payload,
      revision: oldRow.revision,
      updated_at: oldRow.updated_at,
    };
    const res = await http('PATCH', `${restUrl}/user_snapshots?user_id=eq.${encodeURIComponent(newUuid)}`, {
      key,
      headers: { 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: upd,
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`PATCH user_snapshots (overwrite) → HTTP ${res.status}: ${text.slice(0, 300)}`);
    }
    await deleteRows(restUrl, key, 'user_snapshots', `user_id=eq.${encodeURIComponent(oldUid)}`);
  } else {
    // skip — giữ nguyên dòng cũ (mồ côi có kiểm soát), cảnh báo bên dưới.
  }
}

/**
 * Dời blobs cho một cặp (old, new): fetch hết dòng có user_id cũ, rewrite key
 * id + user_id rồi Delete+Insert / Upsert / Skip theo "mới hơn thắng".
 */
async function migrateBlobs(restUrl, key, oldUid, newUuid, tally, warnings) {
  const oldBlobs = await getTableRows(
    restUrl, key, 'user_blobs', `user_id=eq.${encodeURIComponent(oldUid)}&select=*`, 'id'
  );
  if (oldBlobs.length === 0) return;

  for (const oldRow of oldBlobs) {
    const newId = rewriteBlobId(oldRow.id, oldUid, newUuid);
    if (!newId) {
      warnings.push(
        `user_blobs.id = ${JSON.stringify(oldRow.id)} không đọc được old_uid "${oldUid}" — ` +
        'KHÔNG dời, xem tay.'
      );
      tally.blobs.unrewritable = (tally.blobs.unrewritable || 0) + 1;
      continue;
    }
    const existing = await getOneRow(
      restUrl, key, 'user_blobs', `id=eq.${encodeURIComponent(newId)}`, 'id,updated_at'
    );
    const decision = blobDecision(oldRow, existing);
    tally.blobs[decision] = (tally.blobs[decision] || 0) + 1;
    if (decision === 'insert') {
      await insertRows(restUrl, key, 'user_blobs', [{ ...oldRow, id: newId, user_id: newUuid }]);
      await deleteRows(restUrl, key, 'user_blobs', `id=eq.${encodeURIComponent(oldRow.id)}`);
    } else if (decision === 'upsert') {
      await upsertRows(restUrl, key, 'user_blobs', [{ ...oldRow, id: newId, user_id: newUuid }], 'id');
      await deleteRows(restUrl, key, 'user_blobs', `id=eq.${encodeURIComponent(oldRow.id)}`);
    } // skip: giữ cả hai để xem tay
  }
}

// ── In kế hoạch dry-run / tổng kết ──────────────────────────────────────────

function fmtCount(n) {
  return n === null ? 'không biết đếm được' : String(n);
}

async function dryRunPlan(restUrl, key, pairs) {
  console.log('\n=== KẾ HOẠCH DỜI DỮ LIỆU (dry-run, CHƯA ghi gì cả) ===');
  console.log(`Số cặp (old_uid → new_uuid): ${pairs.length}`);
  for (const p of pairs) {
    console.log(`\n— ${p.oldUid} (email: ${p.email}) → ${p.newUuid}`);
    for (const { table, cols } of PATCH_PLAN) {
      const counts = [];
      for (const { col } of cols) {
        let search;
        if (table === 'email_codes') search = `uid=eq.${encodeURIComponent(p.oldUid)}`;
        else search = `${col}=eq.${encodeURIComponent(p.oldUid)}`;
        const n = await countRows(restUrl, key, table, search);
        counts.push(`${col}: ${fmtCount(n)}`);
      }
      if (counts.some((c) => !c.endsWith(': 0'))) {
        console.log(`   ${table}: ${counts.join(' | ')}`);
      }
    }
    const snapN = await countRows(restUrl, key, 'user_snapshots', `user_id=eq.${encodeURIComponent(p.oldUid)}`);
    const blobN = await countRows(restUrl, key, 'user_blobs', `user_id=eq.${encodeURIComponent(p.oldUid)}`);
    if ((snapN || 0) > 0 || (blobN || 0) > 0) {
      console.log(`   user_snapshots: ${fmtCount(snapN)} | user_blobs: ${fmtCount(blobN)} (quét bằng user_id; id sẽ được viết lại tiền tố)`);
    }
  }
}

function reportUnmapped(plan, ambiguousUids, duplicateEmails) {
  const uidList = [...ambiguousUids.entries()];
  if (uidList.length === 0 && plan.orphansNoUser.length === 0 &&
      plan.multiSourceConflicts.length === 0 && duplicateEmails.length === 0) return;
  console.log('\n=== CÁC UID MỒ CÔI / MÂU THUẪN — XEM TAY ===');
  if (uidList.length)
    console.log(`• old_uid gắn 2+ email khác nhau (không dám ghép cặp tự động):`);
  for (const [uid, mails] of uidList) console.log(`    ${uid}: ${mails.join(' | ')}`);
  for (const { oldUid, email } of plan.orphansNoUser) {
    console.log(`• ${oldUid} (email ${email}): không tìm thấy user Supabase mới ` +
      `(hoặc email trùng nhiều user) — dùng backup snapshot trong dashboard để phục hồi tay.`);
  }
  for (const { newUuid, sources } of plan.multiSourceConflicts) {
    console.log(`• uuid mới ${newUuid} nhận từ 2+ old_uid (${sources.join(', ')}) — ` +
      `nguy cơ dồn dữ liệu, bắt buộc xem tay trước khi dời.`);
  }
  if (duplicateEmails.length > 0) {
    console.log(`• email trùng nhiều user trong Supabase Auth: ${duplicateEmails.join(', ')}`);
  }
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main() {
  const { url, key, apply } = envRequired();
  const restUrl = `${url}/rest/v1`;

  console.log(`Supabase: ${url}`);
  console.log(`Chế độ  : ${apply ? 'APPLY (BACKFILL_APPLY=1) — SẼ GHI DỮ LIỆU THẬT' : 'DRY-RUN (mặc định — không ghi gì)'}`);
  if (apply) {
    console.log('\n*** BẠN ĐÃ BẬT GHI THẬT. Hãy chắc chắn bạn đã backup (dashboard → Database → Backups) ***\n');
  }

  // Bước 1: email → uuid mới
  console.log('\n[1/5] Lấy danh sách user Supabase Auth (admin API)...');
  const users = await fetchAdminUsers(url, key);
  console.log(`      ${users.length} user.`);
  const { emailUuid, duplicateEmails } = buildEmailUuidMap(users);
  console.log(`      ${emailUuid.size} email dùng được${duplicateEmails.length ? `, ${duplicateEmails.length} email trùng bị loại` : ''}.`);

  // Bước 2: old_uid → email
  console.log('\n[2/5] Dựng map old_uid → email từ email_codes + family_links...');
  const { emailCodeRows, familyLinkRows } = await fetchUidEmailSources(restUrl, key);
  console.log(`      email_codes (purpose='verify', có uid): ${emailCodeRows.length} dòng`);
  console.log(`      family_links (có parent_email + parent_user_id): ${familyLinkRows.length} dòng`);
  const { uidEmail, ambiguousUids } = buildUidEmailMap(emailCodeRows, familyLinkRows);
  console.log(`      ${uidEmail.size} old_uid có 1 email duy nhất` +
    `${ambiguousUids.size ? `, ${ambiguousUids.size} uid mâu thuẫn bị loại` : ''}.`);

  // Bước 3: giao hai map
  console.log('\n[3/5] Ghép cặp (chỉ email có ở CẢ hai map)...');
  const plan = buildPairPlan(uidEmail, ambiguousUids, emailUuid, duplicateEmails);
  console.log(`      ${plan.pairs.length} cặp ghép được.`);

  // Bước 4: in kế hoạch (luôn — cả apply-còn-in, để người chạy nhìn trước)
  await dryRunPlan(restUrl, key, plan.pairs);
  reportUnmapped(plan, ambiguousUids, duplicateEmails);

  if (!apply) {
    console.log('\n[OK] Dry-run xong. KHÔNG có gì bị sửa. ' +
      'Để ghi thật: set env BACKFILL_APPLY=1 rồi chạy lại (SAU KHI BACKUP).');
    return;
  }

  // ── APPLY ──
  console.log('\n[4/5] BẬT GHI: dời dữ liệu theo từng cặp...');

  // Trước khi dời: phát hiện sẵn conflict snapshot/blobs để in cảnh báo, và
  // chặn các cặp sẽ dồn 2 nguồn vào 1 uuid đã bị loại ở bước ghép.
  const tally = {
    patch: new Map(),         // table → số PATCH thành công (cột gộp chung)
    patchConflict: new Map(), // table → số PATCH dính 409 (unique/PK)
    snapshots: {},            // insert / overwrite / skip
    blobs: {},                // insert / upsert / skip / unrewritable
  };
  const warnings = [];

  for (const p of plan.pairs) {
    console.log(`\n→ Cặp ${p.oldUid} → ${p.newUuid} (${p.email})`);

    // (a) Patch đơn cột (user_profiles hơi đặc biệt: user_id là PK — PATCH
    //     đổi giá trị PK trực tiếp được).
    for (const { table, cols } of PATCH_PLAN) {
      for (const { col } of cols) {
        const res = await patchColumn(restUrl, key, table, col, p.oldUid, p.newUuid);
        if (res.ok) {
          tally.patch.set(table, (tally.patch.get(table) || 0) + 1);
        } else if (res.conflict) {
          tally.patchConflict.set(table, (tally.patchConflict.get(table) || 0) + 1);
          warnings.push(`${table}.${col}: PATCH "${p.oldUid}" → "${p.newUuid}" dính 409 ` +
            `(vướng unique/PK — dòng mới đã tồn tại). Giữ nguyên dòng cũ, xem tay.`);
        }
      }
    }

    // (b) user_snapshots: user_id là PK — Delete+Insert an toàn hơn đổi PK.
    await migrateSnapshot(restUrl, key, p.oldUid, p.newUuid, tally);

    // (c) user_blobs: id = "<uid>__<taskId>__<attachmentId>" — rewrite tiền tố.
    await migrateBlobs(restUrl, key, p.oldUid, p.newUuid, tally, warnings);
  }

  // Bước 5: tổng kết
  console.log('\n[5/5] === TỔNG KẾT ===');
  console.log(`Cặp đã xử lý: ${plan.pairs.length}`);
  for (const [table, n] of tally.patch) console.log(`  PATCH ok  ${table}: ${n}`);
  for (const [table, n] of tally.patchConflict) {
    console.log(`  PATCH 409 ${table}: ${n} (vướng unique/PK — CHƯA dời, xem tay)`);
  }
  console.log(`  user_snapshots: insert=${tally.snapshots.insert || 0}, ` +
    `overwrite=${tally.snapshots.overwrite || 0}, ` +
    `skip=${tally.snapshots.skip || 0} (giữ nguyên, xem tay)`);
  console.log(`  user_blobs: insert=${tally.blobs.insert || 0}, ` +
    `upsert=${tally.blobs.upsert || 0}, ` +
    `skip=${tally.blobs.skip || 0}, ` +
    `unrewritable=${tally.blobs.unrewritable || 0}`);

  if (warnings.length) {
    console.log(`\n=== CẢNH BÁO (${warnings.length}) ===`);
    for (const w of [...new Set(warnings)]) console.log(`• ${w}`);
  }

  // Các uid mồ côi / mâu thuẫn — đã in ở bước [3]; nhắc lại để không bỏ sót.
  reportUnmapped(plan, ambiguousUids, duplicateEmails);

  // Rà lại: còn dòng nào keyed theo old_uid không?
  console.log('\nRà lại (select count bằng old_uid trong từng bảng):');
  let remaining = 0;
  const stillMap = uidEmail.size ? [...uidEmail.keys()] : [];
  for (const p of plan.pairs) {
    if (!stillMap.includes(p.oldUid)) continue;
    for (const { table, cols } of PATCH_PLAN) {
      for (const { col } of cols) {
        const n = await countRows(restUrl, key, table, `${col}=eq.${encodeURIComponent(p.oldUid)}`);
        if (n) {
          remaining += n;
          console.log(`  ! ${table}.${col}: còn ${n} dòng theo ${p.oldUid}`);
        }
      }
    }
  }
  console.log(remaining === 0
    ? '  0 dòng còn lại gắn theo old_uid trong các bảng đã xử lý.'
    : `  Tổng ${remaining} dòng chờ xem tay.`);
}

main().catch((err) => {
  die(err && err.message ? err.message : String(err));
});
