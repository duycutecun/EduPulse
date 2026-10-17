# RUNBOOK — Backfill dữ liệu cloud cũ (keyed Firebase UID) sang Supabase UUID mới

> **Chỉ Owner** (người giữ khoá `service_role`) mới được chạy tool này. Khoá
> admin chạm được toàn bộ bảng dữ liệu người dùng — một lần apply chạy sai là
> ảnh hưởng tới mọi user, nên đọc hết tài liệu này trước khi bấm chạy.

## 1. Vì sao cần có bước này

App đã bỏ Firebase, đăng nhập bằng **Supabase Auth**. Dữ liệu cũ trên Supabase
vẫn khoá theo **Firebase UID** (28 ký tự alphanumeric, không gạch ngang) trong
các cột `user_id` / `student_user_id` / `parent_user_id` / `uid`:

| Bảng | Cột cần dời | Chú ý |
|---|---|---|
| `user_profiles` | `user_id` | **PK** (PATCH được giá trị PK trực tiếp) |
| `exams` | `user_id` | |
| `today_tasks` | `user_id` | |
| `study_logs` | `user_id` | |
| `family_goals` | `student_user_id`, `parent_user_id` | 2 cột, unique index `(parent_user_id, student_user_id, metric)` |
| `family_messages` | `student_user_id`, `parent_user_id` | 2 cột |
| `family_reports` | `student_user_id` | |
| `family_live` | `student_user_id` | **PK** + unique index |
| `family_links` | `student_user_id`, `parent_user_id` | 2 cột, PATCH mỗi cột một lần |
| `family_notif_tokens` | `user_id` | |
| `email_codes` | `uid` | chỉ dùng dòng `purpose='verify'`, `uid != null` |
| `user_snapshots` | `user_id` | **PK** — dùng Delete+Insert (đổi PK trực tiếp rủi ro hơn) |
| `user_blobs` | `id` = `<oldUid>__<taskId>__<attachmentId>` **và** `user_id` | **Delete+Insert**, phải REWRITE key id |

Sau migration Auth, token Firebase chết ⇒ những dòng keyed Firebase UID cũ thành
**dữ liệu chết**. Script ghép `old_uid ↔ new_uuid` **qua EMAIL**:

- map `old_uid → email`:
  - nguồn chính: `email_codes` (purpose='verify', uid != null) — mỗi mã xác minh
    gắn email đã xác minh với một Firebase UID;
  - nguồn bù: `family_links` (dòng có `parent_user_id` + `parent_email`).
- map `email → new_uuid`: danh sách user từ **Supabase Auth admin API**
  (`GET /auth/v1/admin/users`, paginate 200/page, gọi bằng `service_role`).
- Cặp chỉ được tạo khi email xuất hiện ở **CẢ hai map** (và mỗi email chỉ khớp
  đúng một uid, một user).

## 2. Bước 0 — BẮT BUỘC: backup trước khi bật `BACKFILL_APPLY`

Có backup xong mới được nghĩ tới apply:

1. Vào **Supabase dashboard → Database → Backups** (gói Pro có snapshot tự động).
2. Tạo snapshot thủ công NGAY TRƯỚC khi chạy apply (snapshot "gần nhất" có thể
   đã cũ hơn những gì app vừa ghi).
3. Xác nhận bản backup hiển thị trong danh sách, thế mới chạy tiếp.

Script chỉ sửa dữ liệu trong các bảng §1, không đụng schema, không đụng
RLS/policy. Nhưng đây là thao tác ghi ngoài, quy tắc sắt:
**CHƯA backup → KHÔNG apply.**

## 3. Cách chạy

### 3.1 Thiết lập biến môi trường (PowerShell)

> Khoá `service_role` lấy ở Supabase dashboard → Project Settings → API.
> KHÔNG hardcode key vào file nào — script chỉ đọc env.

```powershell
$env:SUPABASE_URL              = 'https://<project-ref>.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY = '<khoá service_role>'

# Dry-run (mặc định) — KHÔNG ghi gì cả:
node scripts/backfill_firebase_uid.mjs
# hoặc rõ ràng:
node scripts/backfill_firebase_uid.mjs --dry-run
```

Trong bash:

```bash
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/backfill_firebase_uid.mjs
```

### 3.2 Dry-run (LUÔN chạy trước)

Script in ra:

- số user Supabase đọc được từ admin API (bao nhiêu email làm được map),
- số dòng `email_codes` (purpose='verify') và `family_links` dùng để dựng map,
- số cặp `(old_uid → new_uuid)` ghép được,
- với **mỗi cặp**: số dòng bị tác động của từng bảng/từng cột (đếm bằng `HEAD`
  PostgREST `Prefer: count=exact` — chỉ đọc, không ghi),
- nhóm **UID MỒ CÔI / MÂU THUẪN — XEM TAY**: uid không tìm thấy user Supabase
  mới, uid gắn 2+ email, email trùng nhiều user, 1 uuid nhận từ 2+ old_uid.

Đọc kỹ phần "xem tay" trước khi sang apply — đây là phần script **cố ý không tự
quyết** (xem chính sách §5).

### 3.3 Apply (chỉ khi đã backup theo §2 và đã đọc dry-run)

```powershell
node scripts/backfill_firebase_uid.mjs        # chạy lại dry-run lần cuối (tùy)
$env:BACKFILL_APPLY = '1'
node scripts/backfill_firebase_uid.mjs        # LẦN NÀY MỚI GHI THẬT
```

Trong bash:

```bash
BACKFILL_APPLY=1 SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
  node scripts/backfill_firebase_uid.mjs
```

Chỉ khi env `BACKFILL_APPLY` bằng đúng chữ `1` mới bật ghi. Đặt `='true'`, đặt
thiếu, hay đặt trống thì vẫn là dry-run — thiết kế an toàn theo hướng "cửa đóng".

### 3.4 Thiếu env ⇒ thoát sạch, không chạy nửa vời

Thiếu `SUPABASE_URL` hoặc `SUPABASE_SERVICE_ROLE_KEY` ⇒ exit code **1** kèm hướng
dẫn tiếng Việt. Script không bao giờ hardcode key.

## 4. Thứ tự apply (một cặp một lượt)

Với **mỗi cặp** `(old_uid → new_uuid)`, script làm theo thứ tự:

1. **PATCH từng cột** của các bảng thường: `user_profiles` (PK — PATCH trực tiếp
   được), `exams`, `today_tasks`, `study_logs`, `family_goals` × 2 cột,
   `family_messages` × 2 cột, `family_reports`, `family_live` (PK),
   `family_links` × 2 cột, `family_notif_tokens`, `email_codes`. PATCH PostgREST
   là UPDATE một câu theo filter `?col=eq.<old>`; nếu dính 409 (vi phạm
   unique/PK) cả câu UPDATE bị database từ chối nguyên khối, dòng cũ nguyên vẹn.
2. **`user_snapshots`**: Select dòng cũ và dòng mới (nếu có), rồi quyết theo §5:
   - user mới chưa có dòng ⇒ Insert copy của dòng cũ với `user_id` mới, rồi
     Delete dòng cũ;
   - user mới đã có dòng ⇒ so `updated_at`, "mới hơn thắng".
3. **`user_blobs`**: Select hết dòng có `user_id = old`, với từng dòng:
   - Rewrite key: `<oldUid>__<taskId>__<attachmentId>` →
     `<newUuid>__<taskId>__<attachmentId>` (chỉ thay tiền tố, `__taskId__attId`
     giữ nguyên);
   - Delete+Insert (id là PK): Insert dòng với `id`/`user_id` mới, rồi Delete
     dòng cũ. Key mới đã tồn tại ⇒ so `updated_at` (§5).
   - Key không bắt đầu đúng tiền tố ⇒ bỏ qua + cảnh báo (dữ liệu lạ).

## 5. Chính sách conflict (đã chọn — "mới hơn thắng theo updated_at")

Cả snapshot lẫn blob đều so sánh theo `updated_at` (server đóng dấu, không tin
đồng hồ máy — đúng nguyên tắc của `backup_tables.sql`):

| Ngữ cảnh | Xử lý |
|---|---|
| `user_snapshots` — user mới chưa có dòng | Copy nguyên, đổi `user_id`, Delete dòng cũ |
| `user_snapshots` — cả hai có, **dòng cũ mới hơn** | PATCH dòng mới bằng nội dung dòng cũ (`device_id`, `payload`, `revision`, `updated_at`), Delete dòng cũ |
| `user_snapshots` — cả hai có, dòng mới mới hơn **hoặc bằng** | BỎ QUA (giữ cả hai, cảnh báo để xem tay) |
| `user_snapshots` — `updated_at` không đọc được / sai định dạng | BỎ QUA (không dám quyết) |
| `user_blobs` — id mới chưa tồn tại | Insert dòng mới, Delete dòng cũ |
| `user_blobs` — id mới có, **dòng cũ mới hơn** | Upsert (`resolution=merge-duplicates`) nội dung dòng cũ lên dòng mới, Delete dòng cũ |
| `user_blobs` — id mới có, dòng mới mới hơn hoặc bằng | BỎ QUA (giữ cả hai) |
| PATCH dính **409** (`family_goals`, `family_live`, `user_profiles` nếu unique/PK vướng) | BỎ QUA câu PATCH, giữ dòng cũ, cảnh báo |
| 1 `new_uuid` ghép được từ **2+ old_uid** | Loại **toàn bộ nhóm** khỏi apply, đẩy về xem tay |
| `old_uid` gắn 2+ email khác nhau | Loại khỏi map, đẩy về xem tay |
| Email trùng nhiều user trong Auth | Loại khỏi map, đẩy về xem tay |
| `user_blobs.id` không có tiền tố `<oldUid>__` | BỎ QUA dòng, cảnh báo |

Lý do lựa chọn "mới hơn thắng": sau migration từ Firebase, tài khoản Supabase
mới của user thường **trống trơn** (chưa lần nào backup) hoặc chỉ có vài dòng
thử; khi dòng cũ (mọi lịch sử) và dòng mới xung đột, dữ liệu cũ gần như luôn
giá trị hơn — nên chỉ khi dòng mới **thật sự mới hơn** (user đã dùng app sau
migration) script mới nhường dòng mới.

"Xem tay" = dòng cũ vẫn ở nguyên, không mất gì; Owner đọc log rồi tự quyết.

## 6. Sau apply — kiểm chứng

Trong Supabase Console → SQL Editor (thay `<old_uid>`), lặp cho từng bảng §1:

```sql
-- ví dụ với user_profiles
select count(*) from public.user_profiles where user_id = '<old_uid>';
```

**Tất cả** phải trả về `0` — trừ những uid đã bị cảnh báo "giữ để xem tay" ở §5.
Tiếp:

1. Đăng nhập bằng một tài khoản Supabase đã backfill, kiểm tra app hiện lại
   đúng dữ liệu cũ (exams, tasks, logs, ảnh đính kèm, snapshot khôi phục).
2. Giữ bản backup ít nhất 1–2 tuần trước khi xoá nó.

## 7. Rollback

Script không tự làm rollback — cơ chế dựa trên backup trước (§2) và tính idempotent:

- **Chạy hỏng dở chừng** (lỗi mạng, vài 409): dữ liệu được dời một phần — những
  gì đã chuyển sang uuid mới vẫn tốt, phần còn lại vẫn keyed old_uid.
  Chạy lại script là an toàn (PATCH lọc theo `old_uid` nên chỗ đã dời bị bỏ qua,
  chỗ còn lại được dời tiếp).
- **Cần khôi phục sạch**: Supabase dashboard → Database → Backups → chọn
  snapshot trước apply → **Restore**. Dữ liệu trở về thời điểm trước chạy; thứ
  app ghi sau thời điểm đó sẽ mất — cân nhắc, tránh restore vào giờ cao điểm.

**KHÔNG** dùng "chạy script nghịch đảo old ← new" để rollback: tool không thiết
kế cho việc đó, chạy kiểu đó sẽ rename key blob sai một cách không hồi phục.

## 8. UID mồ côi — làm gì tiếp

Phần "UID MỒ CÔI / MÂU THUẪN — XEM TAY" ở cuối dry-run + apply chia 3 nhóm:

- `old_uid` gắn 2+ email (`ambiguousUids`): Owner tra tay (SQL/backup) xem email
  nào là thật, dọn bản ghi `email_codes` / `family_links` tương ứng rồi chạy
  lại script cho nhóm này.
- Email có trong map cũ nhưng không tìm thấy user Supabase mới: người dùng chưa
  từng đăng nhập tài khoản Supabase. Chỉ cần chờ: khi user đăng nhập, email sẽ
  xuất hiện trong admin user list, chạy lại script lần nữa là data sống lại.
- 1 `new_uuid` nhận từ 2+ old_uid: phải Owner quyết (thường là một email đăng
  ký tài khoản cũ nhiều lần). Gộp dữ liệu của 2 old_uid vào 1 uuid cần SQL tay,
  không để tool tự quyết.

## 9. Những gì script KHÔNG đụng (cố ý)

- **`leaderboard`**: cũng keyed `user_id` (unique) nhưng không nằm trong kế hoạch
  PATCH của script này — bảng điểm công khai, mỗi row chỉ vài trường số; nếu
  muốn dời luôn, Owner chạy SQL tự tay:
  `update public.leaderboard set user_id = '<new>' where user_id = '<old>';`
  (nếu vướng unique vì user mới đã có row, xử nội dung trước theo tinh thần §5).
- **`auth.users`** (schema Auth): chỉ ĐỌC qua admin API, không sửa.
- Dòng **giữ để xem tay** theo §5: script không chạm thêm lần thứ hai.

## 10. Tham chiếu code

- `scripts/backfill_uid_logic.mjs` — logic thuần (map, pair, conflict, rewrite
  key blob, các quyết định "mới hơn thắng"), không gọi API — được bao phủ bởi test.
- `scripts/backfill_firebase_uid.mjs` — CLI: dry-run/apply, gọi Supabase bằng
  `fetch` thuần Node 20+ (**zero dependency**), không dùng supabase-js.
- `scripts/backfill_uid.test.mjs` — test thuần logic:

```powershell
node --test scripts/backfill_uid.test.mjs
```
