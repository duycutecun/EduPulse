-- ==============================================================================
-- EDUPULSE — SUPABASE POSTGRESQL DATABASE SCHEMA
-- Dành cho Trợ lý Sĩ tử EduPulse (THPTQG, HSA, TSA, IELTS)
-- Hướng dẫn: Copy toàn bộ nội dung file này và paste vào mục "SQL Editor" trên Supabase Dashboard, sau đó nhấn "Run".
-- ==============================================================================

-- 1. Bảng Hồ sơ Sĩ tử (user_profiles)
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL DEFAULT 'Sĩ tử 2026',
    target_school TEXT DEFAULT 'Đại học Bách Khoa Hà Nội > 27đ',
    streak INT DEFAULT 1,
    streak_record INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Bảng Danh sách Kỳ thi (exams)
CREATE TABLE IF NOT EXISTS public.exams (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    date_time TIMESTAMPTZ NOT NULL,
    emoji TEXT DEFAULT '🎯',
    type TEXT DEFAULT 'preset',
    description TEXT,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Bảng Nhiệm vụ học tập theo ngày (today_tasks)
CREATE TABLE IF NOT EXISTS public.today_tasks (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    subject TEXT DEFAULT '📐 Toán',
    priority TEXT DEFAULT 'medium',
    estimate_minutes INT DEFAULT 45,
    is_done BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Bảng Nhật ký học tập & Pomodoro (study_logs)
CREATE TABLE IF NOT EXISTS public.study_logs (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    subject TEXT NOT NULL,
    hours NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
    note TEXT,
    logged_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Bảng Vinh danh Bảng vàng Sĩ tử (leaderboard)
CREATE TABLE IF NOT EXISTS public.leaderboard (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    target TEXT NOT NULL,
    streak INT DEFAULT 0,
    weekly_hours NUMERIC(5, 2) DEFAULT 0.0,
    emoji TEXT DEFAULT '🦁',
    badge TEXT DEFAULT '🔥 Sĩ tử Bứt Phá',
    cheers INT DEFAULT 0,
    exam_tag TEXT DEFAULT 'THPTQG',
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Bật Row Level Security (RLS) cho các bảng
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.today_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;

-- Tạo chính sách cho phép truy cập công khai (Dành cho bản Demo / Anon Key)
DROP POLICY IF EXISTS "Public full access user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Public full access exams" ON public.exams;
DROP POLICY IF EXISTS "Public full access today_tasks" ON public.today_tasks;
DROP POLICY IF EXISTS "Public full access study_logs" ON public.study_logs;
DROP POLICY IF EXISTS "Public full access leaderboard" ON public.leaderboard;

CREATE POLICY "Public full access user_profiles" ON public.user_profiles FOR ALL USING (true);
CREATE POLICY "Public full access exams" ON public.exams FOR ALL USING (true);
CREATE POLICY "Public full access today_tasks" ON public.today_tasks FOR ALL USING (true);
CREATE POLICY "Public full access study_logs" ON public.study_logs FOR ALL USING (true);
CREATE POLICY "Public full access leaderboard" ON public.leaderboard FOR ALL USING (true);

-- Bảng vàng không có dữ liệu mẫu — dữ liệu thực từ người dùng thật.
