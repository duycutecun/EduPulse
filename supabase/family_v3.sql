-- "Cửa sổ tin cậy" — mở rộng cho ba mẹ (giai đoạn 3): mục tiêu, cảnh báo,
-- lời nhắn động viên, email tổng kết, thông báo đẩy native.
--
-- Chạy một lần trên Supabase (SQL editor) SAU khi đã chạy `family.sql` và
-- `family_v2.sql`. An toàn khi chạy lại (IF NOT EXISTS / DEFAULT).

-- 1) Liên kết: giữ email ba mẹ (để gửi tổng kết) + bật/tắt cảnh báo mục tiêu.
alter table family_links
  add column if not exists parent_email text;
alter table family_links
  add column if not exists alert_on boolean default true;

-- 2) Mục tiêu ba mẹ đặt cho con (một dòng cho mỗi metric).
--    metric ∈ { weekly_minutes, streak, mock_avg, readiness }.
create table if not exists family_goals (
  id               text primary key,
  link_id          text not null,
  student_user_id  text not null,
  parent_user_id   text not null,
  metric           text not null,
  target           numeric not null,
  last_alert_at    timestamptz,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

create unique index if not exists family_goals_unique
  on family_goals (parent_user_id, student_user_id, metric);

create index if not exists family_goals_student_idx
  on family_goals (student_user_id);

-- 3) Lời nhắn động viên hai chiều giữa ba mẹ và con.
--    from_role ∈ { parent, child }.
create table if not exists family_messages (
  id               text primary key,
  link_id          text not null,
  student_user_id  text not null,
  parent_user_id   text not null,
  from_role        text not null,
  body             text not null,
  created_at       timestamptz default now(),
  read_at          timestamptz
);

create index if not exists family_messages_link_idx
  on family_messages (link_id, created_at desc);

-- 4) Token thông báo đẩy: phân biệt Web Push (VAPID) và FCM (native).
--    kind ∈ { web, fcm }.
alter table family_notif_tokens
  add column if not exists kind text default 'web';
