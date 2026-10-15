-- Mục 8 (bảo mật): bật RLS cho các bảng gia đình còn thiếu.
--
-- `family_v2.sql` / `family_v3.sql` tạo bảng nhưng CHƯA bật Row Level Security.
-- Khoá `anon` công khai nằm trong bản build web/ứng dụng, nên nếu không bật RLS,
-- bất kỳ ai cũng đọc/ghi được chat phụ huynh↔con, mục tiêu và token thông báo
-- qua PostgREST — trái với chính sách riêng tư công bố.
--
-- Bật RLS mà KHÔNG tạo policy ⇒ `anon`/`authenticated` bị chặn hoàn toàn
-- (deny-by-default); API server dùng `service_role` vẫn chạy bình thường vì
-- service_role bỏ qua RLS. Đây là mô hình giống family_links/family_reports/
-- family_live trong `family.sql`.
alter table if exists public.family_notif_tokens enable row level security;
alter table if exists public.family_goals enable row level security;
alter table if exists public.family_messages enable row level security;
