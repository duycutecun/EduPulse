# Quyền riêng tư & thời hạn lưu dữ liệu

Tài liệu này mô tả **dữ liệu nào được lưu ở đâu**, **thời hạn lưu/cache** và
**cơ chế xoá dữ liệu cá nhân** của EduPulse. Nguồn đặc tả: `docs/KE_HOACH_CAI_TO_APP.md`
mục 8 (Bảo mật và quyền riêng tư, dòng 208–214) và mục 7.1.

> Nguyên tắc xuyên suốt: app **không** thu nội dung học tập/chat thô; dữ liệu
> học tập thuộc về người học và nằm trên thiết bị là chính; cloud chỉ là bản
> sao lưu do người dùng kiểm soát.

## 1. Dữ liệu lưu ở đâu

| Loại dữ liệu | Nơi lưu chính | Ghi chú |
| --- | --- | --- |
| Cấu hình giao diện, cờ onboarding, đồng ý analytics | `SharedPreferences` (local) | nhẹ, có version |
| Nhiệm vụ, phiên học, điểm thử, ghi chú, nhật ký | `SharedPreferences` (local) | schema + migration (`data_schema_version`) |
| Bản sao lưu toàn bộ (snapshot), ảnh đề bài | Supabase `user_snapshots`, `user_blobs` | chỉ qua `/api/backup`, server kiểm soát quyền |
| Liên kết/báo cáo/mục tiêu/lời nhắn gia đình | Supabase `family_*` | chỉ server (`/api/family`) đọc/ghi; RLS bật, **không policy** |
| Token thông báo đẩy (ba mẹ) | Supabase `family_notif_tokens` | theo `user_id`; RLS bật qua `supabase/family_v4.sql` |
| Mã OTP xác minh email / đặt lại mật khẩu | Supabase `email_codes` | chỉ server (`/api/*`); RLS bật qua `supabase/email_codes.sql` |
| Cache AI / lịch sử trò chuyện trên máy | `SharedPreferences` (local) | xoá được bằng nút trong "Tôi" |

Không có API key của chủ hệ thống trong binary/bundle: AI managed đi qua backend
(`/api/openrouter`, `/api/gemini`, `/api/search`) với xác thực Firebase, rate limit,
**quota theo ngày** và audit log đã lọc dữ liệu nhạy cảm (`api/_guard.js`).

## 2. Thời hạn lưu / cache

Hằng số nguồn: `api/account_logic.js` (`RETENTION`). Trả cho client qua
`GET /api/account` và hiển thị ở màn **Tôi → Quyền riêng tư & dữ liệu**.

| Loại | Thời hạn tối đa | Ghi chú |
| --- | --- | --- |
| Ảnh đề bài đính kèm (`user_blobs`) | 180 ngày | ảnh nặng, giữ ngắn để tiết kiệm |
| Lịch sử trò chuyện với AI | 30 ngày | cache, không phải nguồn dữ liệu thật |
| Báo cáo tuần gửi gia đình (`family_reports`) | 90 ngày | cũng bị dọn theo trần 12 báo cáo/học sinh |
| Bản sao lưu dữ liệu (`user_snapshots`) | tới khi người dùng xoá | là bản back-up của chính người dùng |

Hàm `isExpired(updatedAtMs, ttlMs, nowMs)` trong `account_logic.js` là điểm móc
sẵn cho tác vụ dọn định kỳ. Việc dọn tự động **đã được triển khai** bằng cron:
`api/cleanup.js` + `api/cleanup_logic.js` (`RETENTION_CLEANUP`), lịch chạy
`0 3 * * *` trong `vercel.json`. Cron xoá:

- `user_blobs` quá 180 ngày (theo `updated_at`) — ảnh đề bài trên máy chủ;
- `family_reports` quá 90 ngày (theo `created_at`);
- `email_codes` đã hết hạn (mã OTP hết hạn không giữ lại).

Lịch sử trò chuyện AI (30 ngày) chỉ nằm **cục bộ trên máy** — client tự dọn, không
có bản sao trên máy chủ để cron xoá.

> **Bắt buộc đặt `CRON_SECRET` trên Vercel.** Cron *fail closed*: không có biến
> này thì `/api/cleanup` từ chối chạy (503) thay vì để ai cũng xoá được dữ liệu.

## 3. Cơ chế xoá dữ liệu cá nhân

Endpoint: **`POST /api/account`** (`api/account.js`)
– xác thực Firebase ID token, server dùng service_role, **mỗi lệnh xoá đều ràng
buộc `.eq(cột, uid)`** (không bao giờ xoá rộng).

```json
{ "action": "delete_my_data", "confirm": true }
```

Xoá dữ liệu ở cả hai vai trò (người dùng có thể là học sinh **hoặc** phụ huynh):

- `family_messages`, `family_goals` (theo `student_user_id` và `parent_user_id`)
- `family_reports`, `family_live` (theo `student_user_id`)
- `family_links` (theo `student_user_id` và `parent_user_id`)
- `family_notif_tokens` (theo `user_id`)
- `user_blobs`, `user_snapshots` (theo `user_id`)
- `email_codes` (theo `uid`; mã quên mật khẩu không gắn uid — tự hết hạn sau 15
  phút và được cron dọn)

Thứ tự xoá (bảng con trước bảng cha) và danh sách bảng nằm ở
`account_logic.js` → `deletionTargets()` (có test `node --test`).

**Giao diện:** màn **Tôi → Quyền riêng tư & dữ liệu**
(`privacy_data_screen.dart`) yêu cầu gõ "XÓA" để xác nhận. Xoá dữ liệu máy chủ
**không** động tới dữ liệu học tập cục bộ trên thiết bị.

Xoá dữ liệu cục bộ (nhiệm vụ, ghi chú, phiên, kỳ thi, nhật ký) là thao tác riêng:
**Tôi → Xuất / nhập dữ liệu → Xóa dữ liệu học cục bộ**.

## 4. Nguyên tắc riêng tư khác

- **Analytics là opt-in, mặc định TẮT** (`analytics_consent`). Chỉ sự kiện sản
  phẩm ẩn danh, buffer cục bộ, không tự gửi đi đâu (`ProductAnalytics`).
- **AI không tự ý đổi kế hoạch, xoá dữ liệu hay gửi dữ liệu gia đình.** Mọi hành
  động AI đều qua preview + xác nhận của người dùng (`AiPlanPreviewSheet`, undo…).
- **Phân quyền gia đình do server kiểm soát** (`api/family.js`), không tin role
  hay consent chỉ từ client. RLS bật nhưng không policy ⇒ anon key không đọc/ghi được.
- **BYOK:** nếu người dùng tự dán khoá AI, khoá không bao giờ bị ghi log, và có
  nút xoá khoá ngay. Khoá được lưu trong **kho an toàn của hệ điều hành**
  (Keychain/Keystore/DPAPI/WebCrypto) qua `lib/core/utils/secure_store.dart`,
  không để lại plaintext trong `SharedPreferences` (xem mục 5).
- Báo cáo phụ huynh chỉ chứa trường học sinh đã chọn chia sẻ; có màn xem trước và
  **nhật ký thay đổi quyền chia sẻ** (`lib/core/privacy/share_audit_log.dart`,
  lưu cục bộ, chỉ ghi hành động bật/tắt, xem ở màn Quyền riêng tư & dữ liệu).

## 5. Ghi chú & việc cần làm ở hạ tầng

- Cấu hình tác vụ dọn theo `RETENTION` (mục 2): **đã triển khai** `api/cleanup.js`
  + `api/cleanup_logic.js` + cron `0 3 * * *` trong `vercel.json`. **Bắt buộc đặt
  `CRON_SECRET` trên Vercel** — cron fail-closed khi thiếu biến này.
- Áp migration RLS còn thiếu trên Supabase (chạy trong SQL editor):
  `supabase/family_v4.sql` (bật RLS cho `family_goals`, `family_messages`,
  `family_notif_tokens`) và `supabase/email_codes.sql` (DDL + RLS cho bảng mã OTP).
  Trước khi áp, ba bảng gia đình đầu **chưa bật RLS** — anon key công khai có thể
  đọc/ghi qua PostgREST.
- Đặt trần quota/ngày qua biến môi trường Vercel: `AI_DAILY_QUOTA` (theo uid) và
  `AI_DAILY_QUOTA_ANON` (theo IP) — mặc định 200 và 40 (`guard_logic.js`).
- Lưu khoá BYOK bằng kho bảo mật của hệ điều hành (`flutter_secure_storage`):
  `AiConfig.loadSecure()` nạp khoá vào cache lúc khởi động và **di trú** khoá cũ
  dạng plaintext từ `SharedPreferences` rồi xoá bản rõ (xem
  `docs/DU_LIEU_VA_PHIEN_BAN.md` để đối chiếu key). Nền tảng thiếu kho an toàn
  (ví dụ `flutter test`) tự dự phòng để không mất cấu hình.
