// Test phần THUẦN của `_guard.js` (không gọi mạng, không cần Supabase).
// Trọng tâm: `rateLimit` — caller quên truyền `limit` KHÔNG được rơi vào chế
// độ vô hạn (so sánh với `undefined` luôn sai ⇒ mọi request đều lọt).
const test = require('node:test');
const assert = require('node:assert/strict');

const { rateLimit, DEFAULT_RATE_LIMIT } = require('./_guard');

function uniqueKey(tag) {
  return `ip:${tag}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

test('rateLimit: thiếu limit → dùng trần mặc định, không vô hạn', () => {
  const key = uniqueKey('a');
  for (let i = 0; i < DEFAULT_RATE_LIMIT; i++) {
    const r = rateLimit(key, undefined);
    assert.equal(r.allowed, true, `lượt ${i + 1} phải được phép`);
  }
  const blocked = rateLimit(key, undefined);
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.remaining, 0);
  assert.ok(blocked.retryAfterSec > 0);
});

test('rateLimit: limit = 0 hoặc NaN cũng rơi về mặc định', () => {
  const key = uniqueKey('b');
  for (let i = 0; i < DEFAULT_RATE_LIMIT; i++) {
    assert.equal(rateLimit(key, 0).allowed, true);
  }
  assert.equal(rateLimit(key, 0).allowed, false);

  const key2 = uniqueKey('c');
  for (let i = 0; i < DEFAULT_RATE_LIMIT; i++) {
    assert.equal(rateLimit(key2, NaN).allowed, true);
  }
  assert.equal(rateLimit(key2, NaN).allowed, false);
});

test('rateLimit: limit hợp lệ được tôn trọng', () => {
  const key = uniqueKey('d');
  assert.equal(rateLimit(key, 2).allowed, true);
  assert.equal(rateLimit(key, 2).allowed, true);
  assert.equal(rateLimit(key, 2).allowed, false);
});
