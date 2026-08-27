-- =============================================================
-- EduPulse - Supabase schema
-- Dán toàn bộ script này vào Supabase Console → SQL Editor → Run.
--
-- Tạo các bảng mà lib/core/utils/supabase_service.dart dùng đến
-- để đồng bộ dữ liệu (backup/restore + bảng xếp hạng).
--
-- LƯU Ý bảo mật:
--  - Tất cả bảng đều bật Row Level Security (RLS).
--  - Policy cho phép mỗi user chỉ đọc/ghi dữ liệu của chính mình
--    (user_id = auth.uid()).
--  - Bảng leaderboard phải đọc được CHO MỌI NGƯỜI (bảng điểm chung),
--    nên thêm policy SELECT cho anon/authenticated.
-- =============================================================

-- ── user_profiles ───────────────────────────────────────────────
create table if not exists public.user_profiles (
  user_id       text primary key,
  name          text,
  target_school text,
  streak        int default 0,
  streak_record int default 0,
  updated_at    timestamptz default now()
);

alter table public.user_profiles enable row level security;

create policy "profiles_own" on public.user_profiles
  for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ── exams ───────────────────────────────────────────────────────
create table if not exists public.exams (
  id          text primary key,
  user_id     text,
  name        text,
  date_time   timestamptz,
  emoji       text,
  type        text,
  description text,
  is_primary  boolean default false
);

alter table public.exams enable row level security;

create policy "exams_own" on public.exams
  for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ── today_tasks ─────────────────────────────────────────────────
create table if not exists public.today_tasks (
  id               text primary key,
  user_id          text,
  title            text,
  subject          text,
  priority         text,
  estimate_minutes int default 45,
  is_done          boolean default false
);

alter table public.today_tasks enable row level security;

create policy "tasks_own" on public.today_tasks
  for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ── study_logs ──────────────────────────────────────────────────
create table if not exists public.study_logs (
  id        text primary key,
  user_id   text,
  subject   text,
  hours     numeric default 1.0,
  note      text,
  logged_at timestamptz default now()
);

alter table public.study_logs enable row level security;

create policy "logs_own" on public.study_logs
  for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- ── leaderboard ─────────────────────────────────────────────────
-- Bảng điểm chung: đọc công khai (không cần đăng nhập).
create table if not exists public.leaderboard (
  id           uuid primary key default gen_random_uuid(),
  name         text,
  target       text,
  streak       int default 0,
  weekly_hours numeric default 0,
  emoji        text default '🦁',
  badge        text default '🔥 Sĩ tử',
  cheers       int default 0,
  updated_at   timestamptz default now()
);

alter table public.leaderboard enable row level security;

-- Cho phép mọi người (kể cả anon) đọc bảng xếp hạng.
create policy "leaderboard_public_select" on public.leaderboard
  for select using (true);

-- Chỉ user đã đăng nhập mới được ghi vào bảng xếp hạng.
create policy "leaderboard_auth_insert_update" on public.leaderboard
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ── helper: xoá user khi cần ────────────────────────────────────
-- delete from public.exams where user_id = '...';
-- delete from public.today_tasks where user_id = '...';
-- delete from public.study_logs where user_id = '...';
-- delete from public.user_profiles where user_id = '...';
