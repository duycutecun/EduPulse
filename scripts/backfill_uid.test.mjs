// Test thuần logic (không cần mạng/credentials) — chạy:
//
//   node --test scripts/backfill_uid.test.mjs
//
// Bao phủ 4 điểm rủi ro nhất của backfill:
//   (a) dựng map uid→email từ email_codes + family_links, tách uid mâu thuẫn;
//   (b) bỏ uid/email thiếu một trong hai map ⇒ không tạo cặp ảo;
//   (c) rewrite key blob `<oldUid>__task__att` → `<newUuid>__task__att`;
//   (d) quyết định trùng dòng khi user mới đã có sẵn (snapshot + blob).
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildUidEmailMap,
  buildEmailUuidMap,
  buildPairPlan,
  isFirebaseUid,
  normalizeEmail,
  rewriteBlobId,
  snapshotDecision,
  blobDecision,
} from './backfill_uid_logic.mjs';

const OLD_A = 'aaaa1111aaaa1111aaaa1111aaaa'; // 28 ký tự là đúng hình dáng Firebase UID
const OLD_B = 'bbbb2222bbbb2222bbbb2222bbbb';
const OLD_C = 'cccc3333cccc3333cccc3333cccc';
const UUID_A = '11111111-1111-4111-8111-111111111111';
const UUID_B = '22222222-2222-4222-8222-222222222222';
const UUID_C = '33333333-3333-4333-8333-333333333333';

// ----------------------------------------------------------------------------
// (a) Map từ email_codes + family_links
// ----------------------------------------------------------------------------
test('buildUidEmailMap: gộp email_codes + family_links theo email', () => {
  const { uidEmail, ambiguousUids } = buildUidEmailMap(
    [{ email: 'Student@Example.com ', uid: OLD_A, purpose: 'verify' },
     // purpose khác 'verify' vẫn được nhận: lọc theo purpose là việc của bước
     // truy vấn PostgREST, logic thuần không chặn lại (dữ liệu đã lọc sẵn).
     { email: 'parent.home@gmail.com', uid: OLD_B }],
    [{ parent_user_id: OLD_C, parent_email: 'BaMe@gmail.Com' }]
  );
  assert.equal(uidEmail.size, 3);
  assert.deepEqual(
    [...uidEmail.entries()].sort(),
    [
      [OLD_A, 'student@example.com'],
      [OLD_B, 'parent.home@gmail.com'],
      [OLD_C, 'bame@gmail.com'],
    ]
  );
  assert.equal(ambiguousUids.size, 0);
});

test('buildUidEmailMap: 1 uid khớp 2 email khác nhau ⇒ uid mâu thuẫn, loại khỏi map', () => {
  const { uidEmail, ambiguousUids } = buildUidEmailMap(
    [{ email: 'a@x.com', uid: OLD_A }, { email: 'b@x.com', uid: OLD_A },
     { email: 'ok@x.com', uid: OLD_B }],
    []
  );
  assert.equal(uidEmail.size, 1); // chỉ còn OLD_B
  assert.deepEqual(uidEmail.get(OLD_B), 'ok@x.com');
  assert.deepEqual(ambiguousUids.get(OLD_A), ['a@x.com', 'b@x.com']);
});

test('buildUidEmailMap: uid sai hình dáng (uuid mới / rỗng) bị loại', () => {
  const uuid = UUID_A; // 36 ký tự, có gạch ngang — hình dáng uuid Supabase mới
  const { uidEmail } = buildUidEmailMap(
    [{ email: 'nope@x.com', uid: uuid }, { email: 'x@x.com', uid: '' },
     { email: 'y@x.com', uid: OLD_A }],
    [{ parent_user_id: 'short', parent_email: 'z@x.com' }]
  );
  assert.equal(uidEmail.size, 1);
  assert.equal(uidEmail.get(OLD_A), 'y@x.com');
});

test('buildUidEmailMap: cùng email (khác hoa/thường/trail space) gộp là 1', () => {
  const { uidEmail } = buildUidEmailMap(
    [{ email: 'A@X.com ', uid: OLD_A }, { email: 'a@x.com', uid: OLD_A }],
    []
  );
  assert.equal(uidEmail.size, 1);
  assert.equal(uidEmail.get(OLD_A), 'a@x.com');
});

test('isFirebaseUid: đúng 28 ký tự alphanumeric, từ chối uuid/rỗng/28-không-phải', () => {
  assert.equal(isFirebaseUid(OLD_A), true);
  assert.equal(isFirebaseUid(UUID_A), false);
  assert.equal(isFirebaseUid(''), false);
  assert.equal(isFirebaseUid(null), false);
  assert.equal(isFirebaseUid('short'), false);
});

test('normalizeEmail: trim + lowercase, đầu vào rỗng ⇒ ""', () => {
  assert.equal(normalizeEmail('  Foo@Bar.COM '), 'foo@bar.com');
  assert.equal(normalizeEmail(null), '');
  assert.equal(normalizeEmail(''), '');
});

test('buildEmailUuidMap: email → uuid; email trùng 2 user ⇒ báo và loại', () => {
  const { emailUuid, duplicateEmails } = buildEmailUuidMap([
    { email: 'A@x.com', id: UUID_A },
    { email: 'b@X.com', id: UUID_B },
    { email: 'a@x.com', id: UUID_C }, // trùng A@x.com
  ]);
  assert.equal(emailUuid.get('b@x.com'), UUID_B);
  assert.equal(emailUuid.has('a@x.com'), false);
  assert.deepEqual(duplicateEmails, ['a@x.com']);
});

// ----------------------------------------------------------------------------
// (b) Giao map: chỉ cặp có ở CẢ hai nguồn mới được đưa vào kế hoạch
// ----------------------------------------------------------------------------
test('buildPairPlan: uid có email nhưng thiếu user Supabase ⇒ orphan, không cặp', () => {
  const { uidEmail } = buildUidEmailMap([{ email: 'tok@x.com', uid: OLD_A }], []);
  const { emailUuid } = buildEmailUuidMap([{ email: 'another@x.com', id: UUID_B }]);
  const { ambiguousUids } = buildUidEmailMap([], []);
  const plan = buildPairPlan(uidEmail, ambiguousUids, emailUuid);
  assert.deepEqual(plan.pairs, []);
  assert.deepEqual(plan.orphansNoUser, [{ oldUid: OLD_A, email: 'tok@x.com' }]);
});

test('buildPairPlan: email có cả hai map ⇒ 1 cặp (old uid, new uuid)', () => {
  const { uidEmail, ambiguousUids } = buildUidEmailMap(
    [{ email: 'Main@X.com', uid: OLD_A }], []);
  const { emailUuid, duplicateEmails } = buildEmailUuidMap([
    { email: 'main@x.com', id: UUID_A },
  ]);
  const plan = buildPairPlan(uidEmail, ambiguousUids, emailUuid, duplicateEmails);
  assert.deepEqual(plan.pairs, [{ oldUid: OLD_A, email: 'main@x.com', newUuid: UUID_A }]);
  assert.deepEqual(plan.orphansNoUser, []);
  assert.deepEqual(plan.multiSourceConflicts, []);
});

test('buildPairPlan: email trùng trong bảng user ⇒ cặp không được tạo', () => {
  const { uidEmail, ambiguousUids } = buildUidEmailMap(
    [{ email: 'dup@x.com', uid: OLD_A }], []);
  const { emailUuid, duplicateEmails } = buildEmailUuidMap([
    { email: 'dup@x.com', id: UUID_A }, { email: 'dup@x.com', id: UUID_B },
  ]);
  const plan = buildPairPlan(uidEmail, ambiguousUids, emailUuid, duplicateEmails);
  assert.deepEqual(plan.pairs, []);
  assert.deepEqual(plan.orphansNoUser, [{ oldUid: OLD_A, email: 'dup@x.com' }]);
});

test('buildPairPlan: 1 uuid nhận từ 2 old_uid ⇒ loại ALL (chống mất dữ liệu)', () => {
  const { uidEmail, ambiguousUids } = buildUidEmailMap(
    [{ email: 'same@x.com', uid: OLD_A }, { email: 'same@x.com', uid: OLD_B }], []);
  const { emailUuid, duplicateEmails } = buildEmailUuidMap([
    { email: 'same@x.com', id: UUID_A } // một user cho 2 old_uid
  ]);
  const plan = buildPairPlan(uidEmail, ambiguousUids, emailUuid, duplicateEmails);
  assert.deepEqual(plan.pairs, []);
  assert.deepEqual(plan.multiSourceConflicts, [{
    newUuid: UUID_A,
    sources: [OLD_A, OLD_B],
  }]);
});

test('buildPairPlan: uid mâu thuẫn (2 email) không bao giờ vào cặp', () => {
  const { uidEmail, ambiguousUids } = buildUidEmailMap(
    [{ email: 'a@x.com', uid: OLD_A }, { email: 'b@x.com', uid: OLD_A }], []);
  const { emailUuid, duplicateEmails } = buildEmailUuidMap([
    { email: 'a@x.com', id: UUID_A }, { email: 'b@x.com', id: UUID_B },
  ]);
  const plan = buildPairPlan(uidEmail, ambiguousUids, emailUuid, duplicateEmails);
  assert.deepEqual(plan.pairs, []); // uid mâu thuẫn bị loại ngay từ map
  assert.deepEqual(plan.orphansNoUser, []); // được báo ở ambiguousUids, không ở đây
});

// ----------------------------------------------------------------------------
// (c) Tách lại key blob
// ----------------------------------------------------------------------------
test('rewriteBlobId: chỉ đổi tiền tố uid, giữ nguyên `__taskId__attachmentId`', () => {
  const key = `${OLD_A}__task-9__att-3.jpg`;
  assert.equal(rewriteBlobId(key, OLD_A, UUID_A), `${UUID_A}__task-9__att-3.jpg`);
});

test('rewriteBlobId: taskId/attachmentId có chứa `__` vẫn được giữ nguyên', () => {
  const key = `${OLD_A}__task__with__sep__att-1`;
  assert.equal(
    rewriteBlobId(key, OLD_A, UUID_B),
    `${UUID_B}__task__with__sep__att-1`
  );
});

test('rewriteBlobId: key không khớp tiền tố oldUid ⇒ null (báo xem tay)', () => {
  assert.equal(rewriteBlobId(`${UUID_A}__t__a`, OLD_A, UUID_B), null); // tiền tố là uuid mới
  assert.equal(rewriteBlobId('rác', OLD_A, UUID_B), null);
  assert.equal(rewriteBlobId(OLD_A.slice(0, 27), OLD_A, UUID_B), null);
  assert.equal(rewriteBlobId(`${OLD_A}__t__a`, '', UUID_B), null);
  assert.equal(rewriteBlobId(null, OLD_A, UUID_B), null);
});

// ----------------------------------------------------------------------------
// (d) Trùng dòng: user mới đã có snapshot / blob
// ----------------------------------------------------------------------------
test('snapshotDecision: chưa có dòng mới ⇒ insert; không có dòng cũ ⇒ skip', () => {
  assert.equal(snapshotDecision({ updated_at: '2024-01-01T00:00:00Z' }, null), 'insert');
  assert.equal(snapshotDecision(null, { updated_at: '2024-01-01T00:00:00Z' }), 'skip');
  assert.equal(snapshotDecision(null, null), 'skip');
});

test('snapshotDecision: dòng cũ MỚI hơn ⇒ overwrite; ngược lại / bằng ⇒ skip', () => {
  const oldRow = { updated_at: '2025-06-01T10:00:00Z' };
  assert.equal(
    snapshotDecision(oldRow, { updated_at: '2025-05-01T10:00:00Z' }),
    'overwrite'
  );
  assert.equal(
    snapshotDecision(oldRow, { updated_at: '2025-07-01T10:00:00Z' }),
    'skip'
  );
  assert.equal(
    snapshotDecision(oldRow, { updated_at: '2025-06-01T10:00:00Z' }),
    'skip'
  );
  // updated_at sai định dạng ⇒ không dám định đoạt ⇒ skip (an toàn)
  assert.equal(
    snapshotDecision({ updated_at: 'nonsense' }, { updated_at: '2020-01-01T00:00:00Z' }),
    'skip'
  );
});

test('blobDecision: chưa có ⇒ insert; cũ mới hơn ⇒ upsert; ngược lại ⇒ skip', () => {
  const oldRow = { updated_at: '2025-06-01T10:00:00Z' };
  assert.equal(blobDecision(oldRow, null), 'insert');
  assert.equal(blobDecision(oldRow, { updated_at: '2025-01-01T00:00:00Z' }), 'upsert');
  assert.equal(blobDecision(oldRow, { updated_at: '2025-12-01T00:00:00Z' }), 'skip');
  assert.equal(blobDecision(oldRow, { updated_at: oldRow.updated_at }), 'skip');
  assert.equal(blobDecision(null, null), 'skip');
});
