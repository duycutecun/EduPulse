// ============================================================================
// EduPulse — logic thuần cho backfill ánh xạ Firebase UID cũ → Supabase UUID.
//
// Tách khỏi `backfill_firebase_uid.mjs` để có thể kiểm bằng `node --test`
// không cần mạng (cùng pattern với `api/_*_logic.js`).
// Mọi hàm ở đây là THUẦN: không fetch, không env, không I/O.
// ============================================================================

export const FIREBASE_UID_RE = /^[A-Za-z0-9]{28}$/;

/** Chuẩn hoá email: trim + lowercase. Trả về '' nếu đầu vào rỗng. */
export function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

/** Firebase UID cũ: 28 ký tự alphanumeric, KHÔNG có gạch ngang (khác UUID). */
export function isFirebaseUid(s) {
  return typeof s === 'string' && FIREBASE_UID_RE.test(s);
}

/**
 * Bước 2 — dựng map `old_uid → email` từ hai nguồn:
 *  (1) `email_codes` (purpose='verify', uid != null) — nguồn chính;
 *  (2) `family_links` (parent_user_id + parent_email cùng dòng).
 *
 * Quy tắc:
 *  - Chỉ nhận uid đúng "hình dáng Firebase" (isFirebaseUid) — loại trừ uuid mới.
 *  - Cùng nhiều email khác nhau cho 1 uid ⇒ uid MÂU THUẪN (ambiguous): loại khỏi
 *    map và trả về danh sách để báo cáo cho Owner xem tay.
 *
 * @param {Array<{email?: string, uid?: string}>} emailCodeRows
 * @param {Array<{parent_user_id?: string, parent_email?: string}>} familyLinkRows
 * @returns {{uidEmail: Map<string, string>, ambiguousUids: Map<string, string[]>}}
 */
export function buildUidEmailMap(emailCodeRows, familyLinkRows) {
  const perUid = new Map(); // uid → Set(email chuẩn hoá)

  const add = (uid, email) => {
    if (!isFirebaseUid(String(uid || ''))) return; // không phải uid cũ → bỏ qua
    const norm = normalizeEmail(email);
    if (!norm) return;
    if (!perUid.has(uid)) perUid.set(uid, new Set());
    perUid.get(uid).add(norm);
  };

  for (const row of emailCodeRows || []) {
    add(row && row.uid, row && row.email);
  }
  for (const row of familyLinkRows || []) {
    add(row && row.parent_user_id, row && row.parent_email);
  }

  const uidEmail = new Map();
  const ambiguousUids = new Map();
  for (const [uid, emails] of perUid) {
    if (emails.size === 1) {
      uidEmail.set(uid, [...emails][0]);
    } else {
      ambiguousUids.set(uid, [...emails].sort());
    }
  }
  return { uidEmail, ambiguousUids };
}

/**
 * Bước 1 hỗ trợ — dựng map `email → uuid` từ danh sách user Supabase Auth
 * (admin API). Email trùng nhau giữa 2 user (hiếm, nhưng dữ liệu bẩn có thể)
 * ⇒ loại cả nhóm và báo về `duplicateEmails` để Owner xử tay.
 *
 * @param {Array<{email?: string, id: string}>} users
 * @returns {{emailUuid: Map<string, string>, duplicateEmails: string[]}}
 */
export function buildEmailUuidMap(users) {
  const seen = new Map(); // email → Set(uuid)
  for (const u of users || []) {
    const norm = normalizeEmail(u && u.email);
    if (!norm || !u.id) continue;
    if (!seen.has(norm)) seen.set(norm, new Set());
    seen.get(norm).add(u.id);
  }
  const emailUuid = new Map();
  const duplicateEmails = [];
  for (const [email, ids] of seen) {
    if (ids.size === 1) emailUuid.set(email, [...ids][0]);
    else duplicateEmails.push(email);
  }
  return { emailUuid, duplicateEmails: duplicateEmails.sort() };
}

/**
 * Bước 3 — giao hai map ⇒ cặp (old_uid, email, new_uuid).
 *
 * Chỉ ghép cặp khi:
 *  - uid có đúng 1 email (không mâu thuẫn), và
 *  - email khớp đúng 1 user Supabase (không trùng), và
 *  - 1 uuid mới KHÔNG được nhận từ 2+ old_uid khác nhau — loại ALL các cặp của
 *    uuid đó (rất nguy hiểm với bảng PK/unique: hai nguồn dồn vào một user ⇒
 *    mất dữ liệu) và trả về `multiSourceConflicts` cho Owner xem tay.
 *
 * @returns {{
 *   pairs: Array<{oldUid: string, email: string, newUuid: string}>,
 *   orphansNoUser: Array<{oldUid: string, email: string}>,
 *   multiSourceConflicts: Array<{newUuid: string, sources: string[]}>
 * }}
 */
export function buildPairPlan(
  uidEmail,
  ambiguousUids,
  emailUuid,
  duplicateEmails = []
) {
  const dupSet = new Set(duplicateEmails);
  const candidatePairs = [];
  const orphansNoUser = [];

  for (const [oldUid, email] of uidEmail) {
    if (ambiguousUids.has(oldUid)) continue; // đã loại ở bước dựng map
    if (dupSet.has(email)) {
      orphansNoUser.push({ oldUid, email });
      continue;
    }
    const newUuid = emailUuid.get(email);
    if (!newUuid) {
      orphansNoUser.push({ oldUid, email }); // không có email nào bản Supabase mới
      continue;
    }
    candidatePairs.push({ oldUid, email, newUuid });
  }

  // 1 uuid nhận từ nhiều old_uid ⇒ nguồn > 1 ⇒ không tự động hóa, xem tay.
  const byUuid = new Map();
  for (const p of candidatePairs) {
    if (!byUuid.has(p.newUuid)) byUuid.set(p.newUuid, []);
    byUuid.get(p.newUuid).push(p);
  }
  const pairs = [];
  const multiSourceConflicts = [];
  for (const [newUuid, group] of byUuid) {
    if (group.length > 1) {
      multiSourceConflicts.push({
        newUuid,
        sources: group.map((g) => g.oldUid).sort(),
      });
    } else {
      pairs.push(group[0]);
    }
  }
  pairs.sort((a, b) => a.oldUid.localeCompare(b.oldUid) || a.email.localeCompare(b.email));
  multiSourceConflicts.sort((a, b) => a.newUuid.localeCompare(b.newUuid));
  orphansNoUser.sort((a, b) => a.oldUid.localeCompare(b.oldUid));
  return { pairs, orphansNoUser, multiSourceConflicts };
}

/**
 * Bước 4a — viết lại key blob: `<oldUid>__<taskId>__<attachmentId>` →
 * `<newUuid>__<taskId>__<attachmentId>`. Chỉ đổi PHẦN TIỀN TỐ, giữ nguyên
 * phần sau. Trả về null nếu key không khớp tiền tố (dữ liệu lạ ⇒ báo xem tay).
 *
 * @returns {string | null}
 */
export function rewriteBlobId(id, oldUid, newUuid) {
  const s = String(id || '');
  if (!(oldUid && newUuid)) return null;
  if (!isFirebaseUid(oldUid)) return null;
  if (!s.startsWith(oldUid + '__')) return null;
  return newUuid + s.slice(oldUid.length);
}

/**
 * Bước 4b — quyết định cho `user_snapshots` khi user mới ĐÃ có sẵn dòng:
 *  - chưa có dòng mới ⇒ 'insert' (chép nguyên + đổi user_id);
 *  - dòng mới CŨ hơn (updated_at nhỏ hơn) ⇒ 'overwrite' (cập nhật dòng mới
 *    bằng nội dung/revision/updated_at của dòng cũ);
 *  - dòng mới MỚI hơn hoặc bằng ⇒ 'skip' (giữ nguyên cả hai để xem tay).
 *
 * @param {{updated_at?: string} | null} oldRow
 * @param {{updated_at?: string} | null} existingNewRow
 * @returns {'insert' | 'overwrite' | 'skip'}
 */
export function snapshotDecision(oldRow, existingNewRow) {
  if (!existingNewRow) return oldRow ? 'insert' : 'skip';
  if (!oldRow) return 'skip';
  const oldT = Date.parse(oldRow.updated_at || '');
  const newT = Date.parse(existingNewRow.updated_at || '');
  if (Number.isNaN(oldT) || Number.isNaN(newT)) return 'skip'; // không tin được mốc ⇒ giữ nguyên
  return oldT > newT ? 'overwrite' : 'skip';
}

/**
 * Bước 4c — quyết định cho một key blob đã tồn tại ở user mới:
 *  - chưa có   ⇒ 'insert' (chen dòng mới, sau đó xoá dòng cũ);
 *  - có sẵn, dòng cũ MỚI hơn ⇒ 'upsert' (ghi đè nội dung của dòng mới);
 *  - còn lại / mốc không tin được ⇒ 'skip' (giữ cả hai để xem tay, không mất gì).
 *
 * @param {{updated_at?: string} | null} oldRow
 * @param {{updated_at?: string} | null} existingNewRow
 * @returns {'insert' | 'upsert' | 'skip'}
 */
export function blobDecision(oldRow, existingNewRow) {
  if (!oldRow) return 'skip';
  if (!existingNewRow) return 'insert';
  const oldT = Date.parse(oldRow.updated_at || '');
  const newT = Date.parse(existingNewRow.updated_at || '');
  if (Number.isNaN(oldT) || Number.isNaN(newT)) return 'skip';
  return oldT > newT ? 'upsert' : 'skip';
}
