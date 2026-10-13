// Logic thuần của API `family.js` — tách riêng để test bằng Node mà KHÔNG cần
// Supabase/Firebase hay biến môi trường. Chỉ tính toán và soạn chuỗi, không
// gọi mạng. `family.js` require lại các hàm/hằng ở đây để hành vi không đổi.
const crypto = require('crypto');

/// Mục tiêu hợp lệ ba mẹ đặt cho con. Ngoài danh sách này bị chối (tránh ghi
/// rác vào bảng).
const GOAL_METRICS = ['weekly_minutes', 'streak', 'mock_avg', 'readiness'];

/// Nhãn tiếng Việt của từng mục tiêu — dùng khi soạn cảnh báo/email.
const GOAL_LABELS = {
  weekly_minutes: 'Thời gian tập trung mỗi tuần (phút)',
  streak: 'Chuỗi ngày học liên tiếp',
  mock_avg: 'Điểm thi thử trung bình',
  readiness: 'Chỉ số sẵn sàng',
};

/// Không nhắc lại một mục tiêu đang chưa đạt trước khoảng này (tránh dội thông
/// báo mỗi nhịp con cập nhật).
const ALERT_COOLDOWN_MS = 20 * 60 * 60 * 1000;

/// Giới hạn số lời nhắn trả về một lần.
const MESSAGES_PAGE = 50;

/// Mã mời sống 2 ngày. Đủ để con đọc cho ba mẹ nhập, đủ ngắn để một mã lọt ra
/// ngoài không còn dùng được sau vài hôm.
const CODE_TTL_MS = 2 * 24 * 60 * 60 * 1000;

/// Giữ tối đa 12 báo cáo mỗi học sinh (~3 tháng báo cáo tuần). Cũ hơn bị dọn
/// để bảng không phình vô hạn — ba mẹ xem lịch sử gần đây là đủ.
const MAX_REPORTS_PER_STUDENT = 12;

/// Số báo cáo trả về một lần cho phụ huynh.
const REPORTS_PAGE = 8;

function newCode() {
  return String(Math.floor(10000000 + Math.random() * 90000000));
}

function toMillis(value) {
  const t = Date.parse(value || '');
  return Number.isNaN(t) ? 0 : t;
}

// Topic = hash('family:' + uid + service_role_key) ⇒ không đoán được nếu không
// biết cả uid lẫn key; khác topic của `/api/backup` nên hai kênh không lẫn nhau.
function topicFor(uid) {
  return crypto
    .createHash('sha256')
    .update('family:' + uid + (process.env.SUPABASE_SERVICE_ROLE_KEY || ''))
    .digest('hex')
    .slice(0, 32);
}

/** So sánh một mục tiêu với bản cập nhật của con. null = chưa đủ dữ liệu. */
function evalGoal(goal, payload) {
  const insights = payload && payload.insights;
  const target = Number(goal.target);
  if (!Number.isFinite(target) || target <= 0) return null;
  let current = null;
  switch (goal.metric) {
    case 'weekly_minutes':
      current = insights && Number(insights.weekMinutes);
      break;
    case 'streak':
      current = insights && Number(insights.streak);
      break;
    case 'mock_avg': {
      const series =
        insights && Array.isArray(insights.mockSeries)
          ? insights.mockSeries
          : [];
      if (series.length) {
        const recent = series.slice(-3);
        current =
          recent.reduce((sum, s) => sum + Number(s.score), 0) / recent.length;
      }
      break;
    }
    case 'readiness': {
      const items = Array.isArray(payload.items) ? payload.items : [];
      const r = items.find((i) => i && i.key === 'readiness');
      const m = r && /(\d+(?:\.\d+)?)\s*\/\s*100/.exec(String(r.value || ''));
      if (m) current = Number(m[1]);
      break;
    }
  }
  if (current == null || !Number.isFinite(current)) return null;
  return { current, target, met: current >= target };
}

/** Chuỗi ngữ cảnh cho thông báo "con chưa đạt mục tiêu". */
function goalAlertMessage(goal, ev, studentName) {
  const name = (studentName || 'Con').trim() || 'Con';
  const label = GOAL_LABELS[goal.metric] || goal.metric;
  const short =
    goal.metric === 'weekly_minutes'
      ? 'phút/tuần'
      : goal.metric === 'streak'
        ? 'ngày'
        : goal.metric === 'mock_avg'
          ? '/10'
          : '/100';
  const cur = Math.round(ev.current * 100) / 100;
  return {
    title: 'Mục tiêu cùng con',
    body: `${name} đang ở ${cur}${short === 'phút/tuần' ? ' phút' : ''}${short === '/10' || short === '/100' ? short : ''}${short === 'ngày' ? ' ngày' : ''} — mục tiêu ${goal.metric === 'streak' ? 'tối thiểu' : 'là'} ${goal.target}${short === '/10' || short === '/100' ? '' : short}. Nhẹ nhàng động viên con nhé.`,
    kind: 'alert',
  };
}

/** Giữ lời nhắn gọn — bỏ qua chuỗi rỗng/quá dài. */
function cleanMessage(value) {
  return String(value || '').trim().slice(0, 500);
}

/** Dựng HTML tổng kết (không có dữ liệu thì trả null — không gửi email rỗng). */
function digestHtml(child, payload) {
  const name = (child.student_name || 'Con').trim() || 'Con';
  const hasItems = payload && Array.isArray(payload.items) && payload.items.length;
  const checkin = payload && payload.checkin ? String(payload.checkin) : '';
  const insights = payload && payload.insights;

  let body = `<p>Đây là bản tổng kết <b>${name}</b> từ EduPulse — tiến độ con chia sẻ với ba mẹ.</p>`;
  if (!hasItems) {
    body += `<p>Con chưa có dữ liệu mới trong báo cáo này.</p>`;
    return null;
  }
  if (checkin) body += `<blockquote style="border-left:3px solid #7C4DFF;margin:12px 0;padding:6px 14px;color:#444;">💬 ${checkin}</blockquote>`;
  body += `<ul>`;
  for (const item of payload.items) {
    if (!item || !item.title) continue;
    body += `<li style="margin:7px 0;"><b>${item.title}:</b> ${item.value}${item.detail ? ' — ' + item.detail : ''}</li>`;
  }
  body += `</ul>`;
  if (insights && typeof insights === 'object') {
    const rows = [];
    if (insights.weekMinutes != null) rows.push(['Phút tập trung tuần này', insights.weekMinutes]);
    if (insights.streak != null) rows.push(['Chuỗi ngày học', `${insights.streak} ngày`]);
    if (Array.isArray(insights.mockSeries) && insights.mockSeries.length) {
      const last = insights.mockSeries[insights.mockSeries.length - 1];
      if (last) rows.push(['Điểm thi thử mới nhất', `${last.subject}: ${last.score}/10`]);
    }
    if (rows.length) {
      body += `<table style="border-collapse:collapse;margin-top:14px;">`;
      for (const [k, v] of rows) {
        body += `<tr><td style="padding:5px 14px 5px 0;color:#666;">${k}</td><td style="padding:5px 0;font-weight:700;">${v}</td></tr>`;
      }
      body += `</table>`;
    }
  }
  return body;
}

module.exports = {
  GOAL_METRICS,
  GOAL_LABELS,
  ALERT_COOLDOWN_MS,
  MESSAGES_PAGE,
  CODE_TTL_MS,
  MAX_REPORTS_PER_STUDENT,
  REPORTS_PAGE,
  newCode,
  toMillis,
  topicFor,
  evalGoal,
  goalAlertMessage,
  cleanMessage,
  digestHtml,
};
