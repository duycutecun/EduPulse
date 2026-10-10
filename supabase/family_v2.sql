-- "Cửa sổ tin cậy" — nâng cấp cho chế độ phụ huynh mở rộng.
--
-- Chạy một lần trên Supabase (SQL editor) sau khi đã có `family.sql`.
-- An toàn khi chạy lại (IF NOT EXISTS / DEFAULT).

-- 1) Tên riêng ba mẹ đặt cho con (chỉ hiển thị phía phụ huynh).
alter table family_links
  add column if not exists parent_label text;

-- 2) Tuỳ chọn nhận thông báo của ba mẹ cho từng con (mặc định: bật).
alter table family_links
  add column if not exists notify_on boolean default true;

-- 3) Token Web Push của từng thiết bị ba mẹ (một tài khoản có thể nhiều máy).
create table if not exists family_notif_tokens (
  token      text primary key,
  user_id    text not null,
  created_at timestamptz default now()
);

create index if not exists family_notif_tokens_user_id_idx
  on family_notif_tokens (user_id);
