import test from 'node:test';
import assert from 'node:assert/strict';

const { isExpired, cutoffMs, RETENTION_CLEANUP } = await import('./_cleanup_logic.js');

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

test('RETENTION_CLEANUP: đúng bảng, không lọc cột không tồn tại, dọn email_codes hết hạn', () => {
  const tables = RETENTION_CLEANUP.map((c) => c.table);
  assert.ok(tables.includes('user_blobs'), 'có dọn ảnh/đính kèm quá hạn');
  assert.ok(tables.includes('family_reports'), 'có dọn báo cáo gia đình quá hạn');
  assert.ok(tables.includes('email_codes'), 'có dọn mã OTP hết hạn');
  for (const cfg of RETENTION_CLEANUP) {
    assert.ok(
      !cfg.filter || !('kind' in cfg.filter),
      `${cfg.name}: không được lọc theo cột 'kind' (không tồn tại trong schema)`
    );
    assert.ok(cfg.column && cfg.ttlMs >= 0, `${cfg.name}: thiếu cột cắt hoặc ttl`);
  }
  const codes = RETENTION_CLEANUP.find((c) => c.table === 'email_codes');
  assert.equal(codes.column, 'expires_at');
  assert.equal(codes.ttlMs, 0, 'xoá ngay khi hết hạn');
});
