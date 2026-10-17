# Checklist chuyển xác thực từ Firebase → Supabase Auth (việc tay của OWNER)

> Sau migration Flutter, Firebase Auth đã được gỡ khỏi app (`pubspec.yaml` không còn
> `firebase_core`/`firebase_auth`). Toàn bộ đăng nhập chạy trên **Supabase Auth**
> (`supabase_flutter`), danh tính dữ liệu là **UUID Supabase**. Checklist dưới đây
> liệt kê cấu hình cần làm tay trên Supabase / Vercel / điều cần kiểm tra khi
> phát hành — phần code đã xong, phần này là cấu hình hệ thống.

---

## 1. Supabase Dashboard (https://supabase.com/dashboard)

### 1.1 Bật Email/Password
- [ ] `Authentication → Providers → Email`: **Enable = ON** (mặc định đã ON).
- [ ] `Authentication → Sign In / Up`:
  - **"Confirm email"** — hai lựa chọn đều chạy đúng với app:
    - **ON (khuyến nghị)**: đăng ký xong Supabase chưa cấp session → app chuyển
      sang màn "Nhập mã xác minh 8 chữ số" (đúng như luồng Firebase cũ).
    - OFF: đăng ký xong được cấp session ngay → app coi là đã xác minh.
      Trong trường hợp này `/api/send_verification` + `verify_email` vẫn hoạt
      động bình thường nếu muốn xác minh thủ công sau.

### 1.2 SMTP cho serverless API gửi mã
- App gửi mã 8 chữ số qua các serverless function (`/api/send_verification`,
  `/api/send_reset_code`) — **không** dùng email nội bộ của Supabase. Chỉ cần
  đảm bảo các biến SMTP mà hai function đó đọc vẫn tồn tại trong Vercel
  (xem mục 2). Không cần cấu hình SMTP trong Supabase trừ phi muốn dùng
  email hệ thống (reset link kiểu cũ không còn dùng).

### 1.3 Google OAuth
- [ ] `Authentication → Providers → Google`: **Enable = ON**, dán
  **Client ID** + **Client Secret** của Google OAuth 2.0
  (Google Cloud Console → APIs & Services → Credentials).
- [ ] **Authorized redirect URIs của Google Cloud Console** phải chứa:
  `https://nygkogzdemplbfydhspd.supabase.co/auth/v1/callback`
- [ ] `Authentication → URL Configuration`:
  - **Redirect URLs** (whitelist) thêm:
    - `https://<domain-web-app>/*` — ví dụ
      `https://edu-pulse-five-gamma.vercel.app/*`
      (và `https://minh1507.github.io/edupulse/*` nếu dùng GitHub Pages).
    - `io.supabase.flutter://login-callback` — deep link quay lại app
      iOS/Android khi đăng nhập Google native.

## 2. iOS / Android — Google OAuth native

- [ ] `ios/Runner/Info.plist` — **đã thêm sẵn trong migration**:
  scheme `io.supabase.flutter` (CFBundleURLTypes, URL name
  `supabase-auth-callback`). Không cần chỉnh thêm.
- [ ] Android (`android/app/src/main/AndroidManifest.xml`): nếu test Google
  OAuth trên Android, thêm intent-filter với scheme `io.supabase.flutter`
  (mục này CHƯA có tự động — thêm tay khi cần).
- [ ] ⚠️ **Chưa test được** Google OAuth native trong quá trình migration
  (cần device thật + Google Console + dashboard Supabase cấu hình đúng).
  Khi build/test lần đầu, kiểm tra: mở app → "Tiếp tục với Google" → trình
  duyệt mở → consent Google → quay lại app đã đăng nhập.
- Web không cần làm gì thêm: `signInWithOAuth` redirect về chính trang web,
  session được nạp từ URL.

## 3. Vercel (máy chủ app + API)

- [ ] Giữ nguyên: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, SMTP keys,
  `SUPABASE_SERVICE_ROLE_KEY` (server), khoá AI `OPENROUTER_API_KEY`,
  `GEMINI_API_KEY` và (mới 10/2026) `GROQ_API_KEY` — key Groq tạo miễn phí
  tại console.groq.com/keys, không cần thẻ; chi tiết ở `docs/AI_GROQ.md`.
- [ ] **Có thể xoá** (không còn code nào đọc): 
  `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`,
  `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`,
  `FIREBASE_APP_ID`, `FIREBASE_IOS_APP_ID`.
  - Việc để thừa là vô hại: build.sh/local_env.sh đã không còn truyền
    `FIREBASE_*` vào dart-define, code Flutter đọc `String.fromEnvironment`
    không cần khai báo.
- [ ] Re-deploy web (`build.sh`) sau khi merge để bản web mất Firebase.

## 4. GitHub Actions

- `ios-ipa.yml`: đã bỏ 7 input/secret `FIREBASE_*` — chỉ còn
  `SUPABASE_URL`, `SUPABASE_ANON_KEY` (input hoặc secrets).
- `build.yml` / `deploy.yml` / `ci.yml`: không cần đổi (chỉ truyền Supabase).
  Lưu ý `FIREBASE_TOKEN`/`FIREBASE_*_APP_ID` trong build.yml là của
  **App Distribution** (phát hành bản test), KHÔNG liên quan Auth — giữ nguyên.

## 5. Dữ liệu cũ — backfill Firebase UID → Supabase UUID (1 lần, tùy chọn)

⚠️ **Cảnh báo mất dữ liệu đã đồng bộ**: người dùng cũ đăng nhập sau migration
sẽ có **UUID Supabase mới** (khác Firebase UID cũ). Dữ liệu cloud đã lưu theo
`user_id = Firebase UID` (vd `user_blobs`, lịch sử backup) sẽ **không tự ghép**
về tài khoản mới của họ; lần đồng bộ đầu app sẽ đẩy dữ liệu cục bộ lên cloud
dưới UUID mới và dùng nó là chuẩn. Dữ liệu theo Firebase UID cũ vẫn nằm trong
cloud (không bị xoá) nhưng không liên kết với tài khoản — **nếu không backfill
thì coi như "mất khỏi app"** dù bản ghi cũ vẫn tồn tại trên database.

Script SQL **đề xuất** (chạy 1 lần trong Supabase SQL Editor sau khi có
danh sách Firebase UID + email; cần `service_role`/SQL console):

```sql
-- 1. Tạo map: Firebase UID cũ ↔ UUID Supabase mới, khớp theo email.
create table if not exists public.uid_migration_map (
  firebase_uid   text primary key,
  supabase_uuid  uuid not null unique,
  email          text
);

-- Nguồn Firebase UID cũ: bảng có (firebase_uid, email) được export trước từ
-- hệ thống cũ (server-side; agent phụ trách api/*.js sẽ cung cấp). Sau khi
-- chèn dữ liệu, ghép với auth.users của Supabase:
insert into public.uid_migration_map (firebase_uid, supabase_uuid, email)
select m.firebase_uid, u.id, lower(m.email)
from <bảng_map_firebase_uid> m          -- tên bảng nguồn do bạn tự nạp trước
join auth.users u on lower(u.email) = lower(m.email)
on conflict (firebase_uid) do nothing;

-- 2. Đổi dữ liệu cũ sang UUID mới (ví dụ với bảng snapshot):
-- update public.snapshots s
-- set user_id = md.supabase_uuid
-- from public.uid_migration_map md
-- where s.user_id = md.firebase_uid;
```

Vì bảng `_bảng_map_firebase_uid` chưa có, bước này ở dạng **gợi ý** — chạy khi
đã export được danh sách UID Firebase + email từ hệ thống cũ.
KHÔNG bắt buộc để release; chỉ cần KHÔNG xoá dữ liệu cũ trên cloud.

## 6. Kiểm tra sau khi phát hành (smoke)

- [ ] Web: đăng ký email mới → nhận mã 8 chữ số → nhập mã → vào app.
- [ ] Web: quên mật khẩu → mã 8 chữ số → đặt mật khẩu mới → tự đăng nhập lại.
- [ ] Web: Google OAuth → quay lại trang, đã đăng nhập.
- [ ] iOS: đăng nhập email/password; sao lưu mới được push lên dưới UUID Supabase.
- [ ] iOS: link reset kiểu cũ của Firebase (`?mode=resetPassword&oobCode=…`)
  mở app KHÔNG crash — vào đúng màn nhập mã + mật khẩu mới.
- [ ] App phụ huynh: đăng nhập → thẳng bảng theo dõi con (dữ liệu cùng người
  chia sẻ cũ vẫn thấy nhờ server tự kiểm quyền theo token mới).
