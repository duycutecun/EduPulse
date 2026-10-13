// Test cho `family_logic.js` — chạy bằng `node --test` (không cần Supabase).
// Mục đích: có lưới an toàn TRƯỚC khi tách tiếp `family.js` (kế hoạch P1-3).
const test = require('node:test');
const assert = require('node:assert/strict');

const logic = require('./family_logic');

test('newCode: luôn là chuỗi 8 chữ số', () => {
  for (let i = 0; i < 50; i++) {
    const code = logic.newCode();
    assert.match(code, /^\d{8}$/);
    const n = Number(code);
    assert.ok(n >= 10000000 && n <= 99999999);
  }
});

test('toMillis: ISO hợp lệ → ms; rỗng/sai → 0', () => {
  assert.equal(logic.toMillis('2026-01-02T03:04:05.000Z'), Date.parse('2026-01-02T03:04:05.000Z'));
  assert.equal(logic.toMillis(''), 0);
  assert.equal(logic.toMillis(null), 0);
  assert.equal(logic.toMillis(undefined), 0);
  assert.equal(logic.toMillis('không phải ngày'), 0);
});

test('topicFor: 32 hex, ổn định, đổi theo uid và theo khoá', () => {
  const prev = process.env.SUPABASE_SERVICE_ROLE_KEY;
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'secret-a';
  const a1 = logic.topicFor('user-1');
  const a2 = logic.topicFor('user-1');
  const b = logic.topicFor('user-2');
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'secret-b';
  const withOtherKey = logic.topicFor('user-1');
  if (prev === undefined) delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  else process.env.SUPABASE_SERVICE_ROLE_KEY = prev;

  assert.match(a1, /^[0-9a-f]{32}$/);
  assert.equal(a1, a2, 'cùng uid + cùng khoá → cùng topic');
  assert.notEqual(a1, b, 'khác uid → khác topic');
  assert.notEqual(a1, withOtherKey, 'khác khoá → khác topic');
});

test('evalGoal: weekly_minutes đạt và chưa đạt', () => {
  const goal = { metric: 'weekly_minutes', target: 300 };
  assert.deepEqual(logic.evalGoal(goal, { insights: { weekMinutes: 350 } }), {
    current: 350,
    target: 300,
    met: true,
  });
  assert.deepEqual(logic.evalGoal(goal, { insights: { weekMinutes: 120 } }), {
    current: 120,
    target: 300,
    met: false,
  });
});

test('evalGoal: streak đọc đúng trường', () => {
  const ev = logic.evalGoal({ metric: 'streak', target: 7 }, { insights: { streak: 10 } });
  assert.deepEqual(ev, { current: 10, target: 7, met: true });
});

test('evalGoal: mock_avg lấy trung bình 3 điểm gần nhất', () => {
  const goal = { metric: 'mock_avg', target: 8 };
  const payload = {
    insights: { mockSeries: [{ score: 4 }, { score: 7 }, { score: 8 }, { score: 9 }] },
  };
  // 3 điểm cuối: 7, 8, 9 → 8.0
  assert.deepEqual(logic.evalGoal(goal, payload), { current: 8, target: 8, met: true });
});

test('evalGoal: readiness parse từ items "NN/100"', () => {
  const goal = { metric: 'readiness', target: 80 };
  const payload = { items: [{ key: 'readiness', value: 'sẵn sàng 76/100' }] };
  assert.deepEqual(logic.evalGoal(goal, payload), { current: 76, target: 80, met: false });
});

test('evalGoal: target không hợp lệ hoặc thiếu dữ liệu → null', () => {
  assert.equal(logic.evalGoal({ metric: 'streak', target: 0 }, { insights: { streak: 5 } }), null);
  assert.equal(logic.evalGoal({ metric: 'streak', target: -3 }, { insights: { streak: 5 } }), null);
  assert.equal(logic.evalGoal({ metric: 'streak', target: 7 }, {}), null);
  assert.equal(logic.evalGoal({ metric: 'mock_avg', target: 8 }, { insights: { mockSeries: [] } }), null);
  assert.equal(logic.evalGoal({ metric: 'readiness', target: 80 }, { items: [] }), null);
});

test('goalAlertMessage: có tiêu đề, loại cảnh báo và tên con', () => {
  const msg = logic.goalAlertMessage(
    { metric: 'weekly_minutes', target: 300 },
    { current: 120 },
    'Minh'
  );
  assert.equal(msg.title, 'Mục tiêu cùng con');
  assert.equal(msg.kind, 'alert');
  assert.match(msg.body, /Minh/);
  assert.match(msg.body, /300/);
});

test('goalAlertMessage: tên trống → mặc định "Con"', () => {
  const msg = logic.goalAlertMessage({ metric: 'streak', target: 7 }, { current: 2 }, '   ');
  assert.match(msg.body, /^Con /);
});

test('cleanMessage: trim và cắt tối đa 500 ký tự', () => {
  assert.equal(logic.cleanMessage('  xin chào  '), 'xin chào');
  assert.equal(logic.cleanMessage(''), '');
  assert.equal(logic.cleanMessage(null), '');
  assert.equal(logic.cleanMessage('a'.repeat(600)).length, 500);
});

test('digestHtml: rỗng dữ liệu → null (không gửi email trống)', () => {
  assert.equal(logic.digestHtml({ student_name: 'Minh' }, { items: [] }), null);
  assert.equal(logic.digestHtml({ student_name: 'Minh' }, null), null);
});

test('digestHtml: dựng tên, item, checkin và bảng insights', () => {
  const html = logic.digestHtml(
    { student_name: 'Minh' },
    {
      checkin: 'Hôm nay hơi mệt',
      items: [{ title: 'Toán', value: '2 giờ', detail: 'hàm số' }],
      insights: { weekMinutes: 480, streak: 5, mockSeries: [{ subject: 'Lý', score: 8 }] },
    }
  );
  assert.ok(html.includes('<b>Minh</b>'));
  assert.ok(html.includes('Hôm nay hơi mệt'));
  assert.ok(html.includes('<b>Toán:</b> 2 giờ — hàm số'));
  assert.ok(html.includes('Phút tập trung tuần này'));
  assert.ok(html.includes('Chuỗi ngày học'));
  assert.ok(html.includes('Lý: 8/10'));
});

test('hằng số: metrics và nhãn khớp nhau', () => {
  assert.deepEqual(logic.GOAL_METRICS, ['weekly_minutes', 'streak', 'mock_avg', 'readiness']);
  for (const m of logic.GOAL_METRICS) {
    assert.ok(logic.GOAL_LABELS[m], `thiếu nhãn cho ${m}`);
  }
  assert.equal(logic.ALERT_COOLDOWN_MS, 20 * 60 * 60 * 1000);
  assert.equal(logic.MAX_REPORTS_PER_STUDENT, 12);
});
