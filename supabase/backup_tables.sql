-- ============================================================================
-- EduPulse — bảng sao lưu toàn diện (dán vào Supabase Console → SQL Editor → Run)
--
-- Tách riêng khỏi `schema.sql` vì đây là phần duy nhất phải chạy SAU, và phần
-- duy nhất app cần để sao lưu hoạt động. Chạy xong script này là đủ.
--
-- VÌ SAO CẦN (và vì sao bảng cũ không dùng được):
--  - `exams` / `today_tasks` / `study_logs` trong `schema.sql` bị RLS chặn
--    trắng: policy so `user_id = auth.uid()` (Supabase Auth) còn app đăng nhập
--    bằng Firebase → `auth.uid()` NULL → không đọc/đẩy được gì. Và chúng chỉ
--    chứa 3 loại dữ liệu, còn lại (ghi chú, phiên học, XP, streak, linh vật,
--    cài đặt, ảnh đính kèm…) không có chỗ nào lưu.
--  - Hai bảng dưới đây do `api/backup.js` đọc/ghi bằng `SUPABASE_SERVICE_ROLE_KEY`
--    sau khi đã tự xác thực Firebase ID token, nên **RLS bật nhưng không policy
--    nào cho client**: mọi truy cập trực tiếp bằng anon key đều bị từ chối.
--    Quyền do server kiểm soát, không phải bằng policy.
--
-- Sau khi chạy xong, nhớ đặt env `SUPABASE_SERVICE_ROLE_KEY` trên Vercel rồi
-- redeploy — thiếu key thì app báo "Chưa sao lưu được", dữ liệu trên máy vẫn an toàn.
-- ============================================================================

-- ── user_snapshots ───────────────────────────────────────────────────────
-- Một dòng cho mỗi tài khoản, chứa TOÀN BỘ dữ liệu app dưới dạng JSON.
--
-- `updated_at` do SERVER đóng dấu (`new Date().toISOString()`), không tin
-- đồng hồ máy người dùng — nếu tin thì lệch múi giờ là mất dữ liệu.
-- `revision` tăng mỗi lần nội dung thật sự đổi (dùng để tra cứu/log).
create table if not exists public.user_snapshots (
  user_id    text primary key,
  device_id  text,
  payload    jsonb not null default '{}'::jsonb,
  revision   bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- Chạy lại script nhiều lần cũng an toàn (idempotent) — nếu bảng đã có từ lần
-- trước nhưng thiếu cột mới.
alter table public.user_snapshots add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.user_snapshots add column if not exists revision bigint not null default 0;
alter table public.user_snapshots add column if not exists device_id text;
alter table public.user_snapshots add column if not exists updated_at timestamptz not null default now();

alter table public.user_snapshots enable row level security;
-- KHÔNG cố tạo policy: không có policy nào nghĩa là client (anon key) không đọc
-- được, chỉ service_role mới chạm được. Đúng ý — endpoint tự kiểm tra uid.

-- ── user_blobs ───────────────────────────────────────────────────────────
-- Ảnh/tệp đính kèm của nhiệm vụ (base64).
--
-- Tách riêng khỏi snapshot là có chủ đích: mỗi ảnh tối đa 250KB và mỗi nhiệm vụ
-- tối đa 3 ảnh, nhồi vào `payload` sẽ làm mỗi lần đẩi phình theo dung lượng ảnh.
-- `checksum` để chỉ gửi lại ảnh thật sự đổi thay vì tải lại tất cả.
--
-- `id` theo định dạng "<uid>__<taskId>__<attachmentId>" — uid ở đầu để chỉ cần
-- so khớp tiền tố là lọc được dữ liệu của một người.
create table if not exists public.user_blobs (
  id            text primary key,
  user_id       text not null,
  task_id       text,
  attachment_id text,
  name          text,
  size_bytes    int default 0,
  checksum      text,
  data          text,
  updated_at    timestamptz not null default now()
);

alter table public.user_blobs add column if not exists checksum text;
alter table public.user_blobs add column if not exists data text;
alter table public.user_blobs add column if not exists size_bytes int default 0;
alter table public.user_blobs add column if not exists updated_at timestamptz not null default now();

create index if not exists user_blobs_user_idx
  on public.user_blobs (user_id);

alter table public.user_blobs enable row level security;

-- ── Kiểm tra sau khi chạy ─────────────────────────────────────────────────
-- Hai lệnh này phải trả về 2 hàng (số bảng đã tạo). Nếu không, xem lại log lỗi.
-- select tablename from pg_tables
--  where schemaname = 'public' and tablename in ('user_snapshots', 'user_blobs');
