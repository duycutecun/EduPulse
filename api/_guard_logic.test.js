// Test cho `_guard_logic.js` — chạy bằng `node --test` (không cần mạng/Supabase).
// Bao phủ quota theo ngày: khoá, trần mặc định, tăng/đếm, chặn và reset cửa sổ.
const test = require('node:test');
const assert = require('node:assert/strict');

const logic = require('./_guard_logic');

test('hằng số: cửa sổ 24h và trần mặc định', () => {
  assert.equal(logic.QUOTA_WINDOW_MS, 24 * 60 * 60 * 1000);
  assert.equal(logic.DEFAULT_QUOTA_PER_DAY, 200);
  assert.equal(logic.DEFAULT_QUOTA_PER_DAY_ANON, 40);
});

test('quotaKey: ưu tiên uid, không có thì theo IP', () => {
  assert.equal(logic.quotaKey('abc', '1.2.3.4'), 'uid:abc');
  assert.equal(logic.quotaKey(null, '1.2.3.4'), 'ip:1.2.3.4');
  assert.equal(logic.quotaKey('', '1.2.3.4'), 'ip:1.2.3.4');
});

test('quotaLimitFor: mặc định theo loại định danh', () => {
  assert.equal(logic.quotaLimitFor('uid-1'), logic.DEFAULT_QUOTA_PER_DAY);
  assert.equal(logic.quotaLimitFor(null), logic.DEFAULT_QUOTA_PER_DAY_ANON);
});

test('quotaLimitFor: override hợp lệ được ưu tiên, giá trị xấu bị bỏ', () => {
  assert.equal(logic.quotaLimitFor('uid-1', 5), 5);
  assert.equal(logic.quotaLimitFor('uid-1', 12.9), 12);
  assert.equal(logic.quotaLimitFor('uid-1', 0), logic.DEFAULT_QUOTA_PER_DAY);
  assert.equal(logic.quotaLimitFor('uid-1', -3), logic.DEFAULT_QUOTA_PER_DAY);
  assert.equal(logic.quotaLimitFor('uid-1', NaN), logic.DEFAULT_QUOTA_PER_DAY);
  assert.equal(logic.quotaLimitFor(null, 0), logic.DEFAULT_QUOTA_PER_DAY_ANON);
});

test('checkQuota: lần đầu cho phép, giảm remaining dần', () => {
  const store = new Map();
  const t = 1_000_000;
  const r1 = logic.checkQuota(store, 'uid:x', t, 3);
  assert.deepEqual(r1, { allowed: true, remaining: 2, retryAfterSec: 0 });
  const r2 = logic.checkQuota(store, 'uid:x', t + 1, 3);
  assert.deepEqual(r2, { allowed: true, remaining: 1, retryAfterSec: 0 });
  const r3 = logic.checkQuota(store, 'uid:x', t + 2, 3);
  assert.deepEqual(r3, { allowed: true, remaining: 0, retryAfterSec: 0 });
});

test('checkQuota: chặn khi vượt trần, đếm không tăng thêm', () => {
  const store = new Map();
  const t = 1_000_000;
  for (let i = 0; i < 3; i++) logic.checkQuota(store, 'uid:y', t + i, 3);
  const blocked = logic.checkQuota(store, 'uid:y', t + 3, 3);
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.remaining, 0);
  assert.ok(blocked.retryAfterSec > 0);
  // Bộ đếm không tăng khi đã bị chặn.
  assert.equal(store.get('uid:y').count, 3);
});

test('checkQuota: reset sau khi hết cửa sổ 24h', () => {
  const store = new Map();
  const t = 1_000_000;
  logic.checkQuota(store, 'ip:z', t, 1);
  const blocked = logic.checkQuota(store, 'ip:z', t + 1, 1);
  assert.equal(blocked.allowed, false);

  const afterWindow = t + logic.QUOTA_WINDOW_MS;
  const fresh = logic.checkQuota(store, 'ip:z', afterWindow, 1);
  assert.deepEqual(fresh, { allowed: true, remaining: 0, retryAfterSec: 0 });
});

test('checkQuota: khoá khác nhau độc lập', () => {
  const store = new Map();
  logic.checkQuota(store, 'uid:a', 1_000_000, 1);
  const other = logic.checkQuota(store, 'uid:b', 1_000_000, 1);
  assert.equal(other.allowed, true, 'uid khác không bị ảnh hưởng');
  assert.equal(store.size, 2);
});

test('quotaMessage: là chuỗi tiếng Việt có nội dung', () => {
  const msg = logic.quotaMessage();
  assert.equal(typeof msg, 'string');
  assert.ok(msg.length > 0);
  assert.match(msg, /24 giờ/);
});
