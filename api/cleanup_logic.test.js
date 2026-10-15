import test from 'node:test';
import assert from 'node:assert/strict';

const { isExpired, cutoffMs } = await import('./cleanup_logic.js');

test('isExpired trả false khi ttl null', () => {
  assert.equal(isExpired(Date.now(), null), false);
});

test('isExpired trả false khi updatedAt null', () => {
  assert.equal(isExpired(null, 1000), false);
});

test('isExpired trả true khi đã quá hạn', () => {
  const now = 10_000;
  const updated = 0;
  assert.equal(isExpired(updated, 5000, now), true);
});

test('isExpired trả false khi còn trong hạn', () => {
  const now = 10_000;
  const updated = 6_000;
  assert.equal(isExpired(updated, 5000, now), false);
});

test('cutoffMs tính đúng thời điểm cắt', () => {
  const now = 10_000;
  assert.equal(cutoffMs(now, 3000), 7000);
});
