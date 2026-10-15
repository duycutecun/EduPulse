-- Bảng mã xác minh email / đặt lại mật khẩu.
--
-- API (`send_verification.js`, `send_reset_code.js`, `verify_email.js`,
-- `reset_password.js`) và cron dọn dẹp (`cleanup_logic.js`) đều dùng bảng này,
-- nhưng trước đây không có DDL nào trong repo (bảng được tạo thủ công). Nếu
-- bảng tồn tại mà chưa bật RLS, khoá `anon` công khai có thể đọc mã OTP của bất
-- kỳ email nào ⇒ chiếm tài khoản. Tệp này chuẩn hoá schema + bật RLS
-- (không policy ⇒ chỉ `service_role` của API đọc/ghi được).
create table if not exists public.email_codes (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  uid text,
  code text not null,
  purpose text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists email_codes_email_purpose_idx
  on public.email_codes (email, purpose);

alter table public.email_codes enable row level security;
