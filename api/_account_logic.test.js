// Test cho `_account_logic.js` — chạy bằng `node --test` (không cần Firebase).
// Bao phủ: danh sách bảng cần xoá theo uid, thứ tự xoá con-trước-cha, chính
// sách lưu trữ và hàm kiểm tra hết hạn.
const test = require('node:test');
const assert = require('node:assert/strict');

const logic = require('./_account_logic');

test('DAY_MS là 24 giờ', () => {
  assert.equal(logic.DAY_MS, 24 * 60 * 60 * 1000);
});

test('deletionTargets: uid rỗng/không hợp lệ → không có lệnh xoá', () => {
  assert.deepEqual(logic.deletionTargets(''), []);
  assert.deepEqual(logic.deletionTargets('   '), []);
  assert.deepEqual(logic.deletionTargets(null), []);
  assert.deepEqual(logic.deletionTargets(undefined), []);
});

test('deletionTargets: mỗi mục gắn đúng uid, đủ số bảng', () => {
  const targets = logic.deletionTargets('user-1');
  assert.equal(targets.length, logic.DELETION_SPECS.length);
  for (const t of targets) {
    assert.equal(t.value, 'user-1');
    assert.ok(t.table);
    assert.ok(t.column);
  }
});

test('deletionTargets: phủ cả vai trò học sinh lẫn phụ huynh', () => {
  const targets = logic.deletionTargets('u');
  const pairs = targets.map((t) => `${t.table}.${t.column}`);
  // Học sinh
  assert.ok(pairs.includes('family_links.student_user_id'));
  assert.ok(pairs.includes('family_reports.student_user_id'));
  assert.ok(pairs.includes('family_messages.student_user_id'));
  // Phụ huynh
  assert.ok(pairs.includes('family_links.parent_user_id'));
  assert.ok(pairs.includes('family_goals.parent_user_id'));
  assert.ok(pairs.includes('family_notif_tokens.user_id'));
  // Bản sao lưu + ảnh
  assert.ok(pairs.includes('user_snapshots.user_id'));
  assert.ok(pairs.includes('user_blobs.user_id'));
});

test('deletionTargets: xoá bảng con (messages/goals) trước bảng cha (links)', () => {
  const targets = logic.deletionTargets('u');
  const pairs = targets.map((t) => `${t.table}.${t.column}`);
  const idxMessages = pairs.indexOf('family_messages.student_user_id');
  const idxGoals = pairs.indexOf('family_goals.student_user_id');
  const idxLinks = pairs.indexOf('family_links.student_user_id');
  assert.ok(idxMessages >= 0 && idxGoals >= 0 && idxLinks >= 0);
  assert.ok(idxMessages < idxLinks, 'messages phải trước links');
  assert.ok(idxGoals < idxLinks, 'goals phải trước links');
});

test('retentionPolicy: có đủ nhóm, ttlDays đúng, bản sao lưu giữ vô thời hạn', () => {
  const policy = logic.retentionPolicy();
  const byKey = Object.fromEntries(policy.map((p) => [p.key, p]));
  assert.equal(byKey.image.ttlDays, 180);
  assert.equal(byKey.chat.ttlDays, 30);
  assert.equal(byKey.familyReport.ttlDays, 90);
  assert.equal(byKey.snapshot.ttlDays, null);
  for (const p of policy) assert.ok(p.label && p.label.length > 0);
});

test('isExpired: ttl null không bao giờ hết hạn', () => {
  assert.equal(logic.isExpired(0, null, 1e12), false);
});

test('isExpired: trong hạn → false, quá hạn → true', () => {
  const now = 1_000_000_000;
  const ttl = 1000;
  assert.equal(logic.isExpired(now - 500, ttl, now), false);
  assert.equal(logic.isExpired(now - 1000, ttl, now), false); // đúng biên
  assert.equal(logic.isExpired(now - 1001, ttl, now), true);
});

test('isExpired: mốc cập nhật không hợp lệ → giữ lại (không xoá nhầm)', () => {
  const now = 1_000_000_000;
  assert.equal(logic.isExpired(undefined, 1000, now), false);
  assert.equal(logic.isExpired(null, 1000, now), false);
  assert.equal(logic.isExpired(NaN, 1000, now), false);
});

test('deletionTargets: có mã xác minh email (email_codes.uid)', () => {
  const pairs = logic.deletionTargets('u').map((t) => `${t.table}.${t.column}`);
  assert.ok(pairs.includes('email_codes.uid'));
});
