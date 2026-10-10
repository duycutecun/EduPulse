-- ============================================================================
-- EduPulse — "Cửa sổ tin cậy": liên kết tài khoản phụ huynh ↔ học sinh
-- (dán vào Supabase Console → SQL Editor → Run)
--
-- VÌ SAO KHÔNG CÓ POLICY RLS NÀO:
--   App đăng nhập bằng FIREBASE, còn `auth.uid()` là danh tính của Supabase
--   Auth — hai thứ khác nhau. Policy kiểu `user_id = auth.uid()` vì thế luôn
--   NULL và chặn trắng mọi truy cập (đúng lỗi đã làm hỏng luồng sync cũ).
--   Ở đây quyền do SERVER kiểm soát: `/api/family.js` tự xác thực Firebase ID
--   token rồi ghi bằng `SUPABASE_SERVICE_ROLE_KEY`. RLS bật nhưng KHÔNG policy
--   ⇒ client (anon key) không đọc/ghi được dòng nào, kể cả dữ liệu của chính họ.
--
-- NGUYÊN TẮC RIÊNG TƯ (đúng tinh thần "Cửa sổ tin cậy"):
--   • Học sinh là chủ: mã mời do con tạo, con đọc cho ba mẹ.
--   • Ba mẹ CHỈ thấy báo cáo con đã chủ động gửi — không đọc được dữ liệu thô
--     của con, không tự xem được gì khi con chưa gửi.
--   • Ngắt liên kết là xoá dòng liên kết ⇒ mọi quyền truy cập mất ngay.
-- ============================================================================

-- ── family_links ─────────────────────────────────────────────────────────
-- Một dòng = một lời mời. `status = 'pending'` khi con vừa tạo mã và chưa ai
-- nhập; `'linked'` khi ba mẹ đã nhập đúng mã.
--
-- `code` là DUY NHẤT: mã 8 chữ số trùng nhau sẽ khiến ba mẹ liên kết nhầm con
-- của người khác — ràng buộc unique là tuyến phòng thủ ở tầng dữ liệu.
create table if not exists public.family_links (
  id              uuid primary key default gen_random_uuid(),
  code            text unique,
  student_user_id text not null,
  student_name    text,
  parent_user_id  text,
  parent_name     text,
  status          text not null default 'pending',
  created_at      timestamptz not null default now(),
  linked_at       timestamptz
);

-- Chạy lại script nhiều lần cũng an toàn (idempotent) — thêm cột mới nếu bảng
-- đã tồn tại từ lần chạy trước.
alter table public.family_links add column if not exists code text;
alter table public.family_links add column if not exists student_user_id text;
alter table public.family_links add column if not exists student_name text;
alter table public.family_links add column if not exists parent_user_id text;
alter table public.family_links add column if not exists parent_name text;
alter table public.family_links add column if not exists status text not null default 'pending';
alter table public.family_links add column if not exists created_at timestamptz not null default now();
alter table public.family_links add column if not exists linked_at timestamptz;

create index if not exists family_links_student_idx
  on public.family_links (student_user_id);
create index if not exists family_links_parent_idx
  on public.family_links (parent_user_id);

alter table public.family_links enable row level security;
-- KHÔNG tạo policy: chỉ service_role (server) chạm được bảng này.

-- ── family_reports ───────────────────────────────────────────────────────
-- Báo cáo tuần mà HỌC SINH gửi cho gia đình. `payload` là JSON do chính app
-- của con dựng (WeeklyReportData) — ba mẹ chỉ đọc lại đúng thứ con đã gửi,
-- không suy diễn thêm từ dữ liệu thô.
--
-- Tách khỏi `user_snapshots` có chủ đích: bảng kia là bản sao lưu riêng tư của
-- từng tài khoản, còn đây là phần con CHỦ ĐỘNG công khai cho gia đình.
create table if not exists public.family_reports (
  id              uuid primary key default gen_random_uuid(),
  student_user_id text not null,
  student_name    text,
  payload         jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

alter table public.family_reports add column if not exists student_user_id text;
alter table public.family_reports add column if not exists student_name text;
alter table public.family_reports add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.family_reports add column if not exists created_at timestamptz not null default now();

create index if not exists family_reports_student_idx
  on public.family_reports (student_user_id, created_at desc);

alter table public.family_reports enable row level security;
-- KHÔNG tạo policy: chỉ service_role (server) chạm được bảng này.

-- ── family_live ─────────────────────────────────────────────────────────
-- "Trạng thái trực tiếp": MỘT dòng cho mỗi học sinh đã BẬT cập nhật trực tiếp.
--
-- Khác `family_reports` (mỗi lần con bấm gửi là một dòng lịch sử), bảng này
-- chỉ giữ bản MỚI NHẤT để ba mẹ thấy tiến độ cập nhật liên tục mà không phải
-- chờ con bấm gửi. Vẫn là báo cáo do app của con dựng — ba mẹ không đọc được
-- dữ liệu thô nào.
--
-- Con TẮT công tắc ⇒ server xoá dòng ⇒ ba mẹ không thấy nữa (không có bản cũ
-- sót lại).
create table if not exists public.family_live (
  student_user_id text primary key,
  student_name    text,
  payload         jsonb not null default '{}'::jsonb,
  updated_at      timestamptz not null default now()
);

alter table public.family_live add column if not exists student_user_id text;
alter table public.family_live add column if not exists student_name text;
alter table public.family_live add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.family_live add column if not exists updated_at timestamptz not null default now();

-- Một dòng / một học sinh — upsert của server dựa vào ràng buộc này.
create unique index if not exists family_live_student_uidx
  on public.family_live (student_user_id);

alter table public.family_live enable row level security;
-- KHÔNG tạo policy: chỉ service_role (server) chạm được bảng này.

-- ── dọn tay khi cần ──────────────────────────────────────────────────────
-- delete from public.family_links where student_user_id = '...';
-- delete from public.family_reports where student_user_id = '...';
-- delete from public.family_live where student_user_id = '...';
