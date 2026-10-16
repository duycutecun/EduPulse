# BẢN THAY ĐỔI V2 — EduPulse

**Ngày:** 2026-10-16 · **Nguồn:** `KE_HOACH_PHAT_TRIEN_THOA_THUAN.md` + `KPI_BENCHMARK.md` (v1) và quyết định vòng 2 (BOSS/DEV/UI/USER/KHÁCH HÀNG/GIÁO VIÊN).

## A. Bảng thay đổi v1 → v2

| Hạng mục | v1 (cũ) | v2 (mới) | Nhường/lấy | Vai chốt | Trích lý do |
|---|---|---|---|---|---|
| Phiên mặc định | 25 phút | 10 phút; mốc 10/20/35; hết 10 phút hỏi "thêm 10 phút?" | USER lấy | BOSS+UI+USER | "từng bấm Pomodoro cho có" |
| KPI đếm phiên | Đếm phiên bắt đầu | Đếm phiên xong | USER lấy | BOSS+GV | app không phân biệt "học thật" vs "bấm cho có" |
| Pilot | 10 đứa ngoan × 7 ngày | Cả lớp trong giờ tự học, máy phổ thông | BOSS/DEV nhường | GV+BOSS | mẫu "đứa ngoan" không thật |
| Thi đua ẩn danh M3 | Có (thay leaderboard) | Bỏ hẳn; không màn nào hiện số/tên người khác — kể cả ẩn danh — tới hết M3 | UI nhường | BOSS+GV | "đã thấy đứa khóc vì tụt 3 bậc" |
| Nhãn môn yếu (báo cáo PH) | Có | Cắt, trừ con tự chọn chia sẻ | KH nhường | KHÁCH HÀNG | sợ con bị gắn nhãn |
| Gamification | Nút "tắt toàn bộ" | "Chế độ yên lặng": dữ liệu vẫn ghi (registerStudyActivity, hook XP, streak), chỉ ẩn chip; 3 công tắc (màu đỏ streak/mascot/âm thanh) | UI đổi | BOSS+UI | tắt hiển thị, không tắt dữ liệu |
| Phản tư | Mỗi phiên + nhật ký 3 câu | 1 câu 2 nút; 4 giây im lặng → ghi "chưa rõ"; 3 chip chỉ khi bấm "Chưa hiểu" | USER/UI lấy | BOSS+UI+GV | "cần dữ liệu hành vi, không phải dữ liệu khai" |
| Nhắc ngủ 22:30 | Nhắc + chặn | Nhường phiên đang chạy; sau autosave đúng một câu rồi im hẳn | KH lấy | BOSS+KH | không khoá máy, không báo về cho bà |
| Banner hôm qua | "Hôm qua chưa xong gì" | "Còn 3 việc mở từ hôm qua" | USER lấy | BOSS+UI | không dọa "trễ 7 việc" |
| Dark mode | Theo lịch + hệ thống, bật từ Cá nhân | Theo hành động phiên học (bật/kết thúc phiên); nếu chỉ một chỗ thì màn Phiên học | UI nhường | BOSS+UI | bỏ "theo lịch" |
| Xoá dữ liệu | Local 1 chạm (M1) | 7 ngày đếm ngược + cron dọn cloud/backup cũ; export JSON thêm timeline phiên + freeze + data_schema_version (M2) | — | DEV+USER/KH | USER muốn "hoàn tác 30 ngày" (mục E) |
| Ảnh đề | SharedPreferences | File store có trần dung lượng; chỉ cache có TTL | DEV lấy | DEV+UI | không phồng SharedPreferences |
| Gate M1→M2 | ≥120 test pass | Nav/notification 0 fail + golden diff 0 | BOSS nhượng | BOSS+DEV | đã có 934 test |
| Sync M3 | 500 kịch bản | 50 kịch bản có xung đột + harness 2 thiết bị | DEV lấy | DEV+BOSS | 500 không đo được "0 sync fail" |
| Cloud | Theo roadmap M3 | Không cloud trước RLS (`family_v4.sql`/`email_codes.sql`) + CRON_SECRET 3h sáng; đổi AI lấy RLS (1,5–2 ngày từ ngân sách AI) | AI nhường | BOSS+DEV+KH | "outbox không lên, banner vẫn xanh" |

## B. M1 phục ban (3 tuần)

**Thêm so với M1 cũ:** (1) phiên Pomodoro **timestamp-based** (`startedAt`/`pausedAccumMs`) — sống qua kill/restart/chuyển app trên cả PWA và mobile; (2) test "kill app giữa phiên, mở lại còn đúng thời gian"; (3) **golden 3 màn** (Hôm nay/Phiên học/Phản tư) × state, diff = 0; (4) sticky bar "Bắt đầu · 10 phút", màn đồng hồ hiện việc đang làm; (5) banner trung tính 1 việc; (6) ghi nhận im lặng (`registerStudyActivity` + hook XP + streak data) để chế độ yên lặng chỉ ẩn chip.

**Bớt so với M1 cũ:** nhật ký 3 câu; hiển thị streak cạnh tranh (chỉ còn dữ liệu nền cho lá bùa, "tuần này X phiên"); mốc "≥120 test" không còn là gate.

**Gate M1→M2 viết lại (DEV đo, 0đ):** ① nav + notification **0 fail** (test viết trước khi sửa); ② golden 3 màn **diff = 0**; ③ kill app giữa phiên → mở lại **đúng thời gian** (PWA + mobile); ④ RLS harness: fixture 2 thiết bị + restore xanh → **0 sync fail với RLS bật**; ⑤ Home render <150ms, ≤2 chạm tới phiên, mở app → phiên <15s; ⑥ crash-free ≥99,5%, **0 mất phiên** trên cả lớp giờ tự học. BOSS tự ký gate "không mất phiên" — ký không được thì dừng.

### Trạng thái kỷ thuật sau đợt này (2026-10-16)

| Gate | Cách kiểm trong repo | Trạng thái |
|---|---|---|
| ② golden 3 màn | `test/nav_screen_contract_test.dart` — hợp đồng 3 màn (Hôm nay / Phiên học / Phản tư) × 3 trạng thái | ✅ 9/9
| ③ kill app giữa phiên | `test/active_session_kill_restart_test.dart` + `FocusClock` neo timestamp | ✅
| ④ RLS bật | `test/rls_coverage_test.dart` — mọi bảng API truy cập và mọi bảng `supabase/*.sql` tạo ra đều phải có `enable row level security` | ✅ (việc **áp** `family_v4.sql`/`email_codes.sql` lên Supabase vẫn là thao tác tay — xem `CHECKLIST_PHAT_HANH.md` mục 2b) |
| ⑤ ≤2 chạm tới phiên | thanh "Bắt đầu · 10 phút" dính đáy màn Hôm nay (`start_session_bar.dart` + `test/home_start_session_bar_test.dart`) | ✅ test; **số render <150ms và <15s cần đo trên máy thật** |
| — | Phiên 10 phút + "thêm 10 phút?" | ✅ `test/focus_session_ten_minutes_test.dart` (8 test)
| — | Phản tư 1 câu 2 nút + im lặng 4 giây | ✅ `test/post_focus_reflection_test.dart`

**Golden ảnh: đổi cách làm, có lý do.** CI chạy `ubuntu-latest` còn máy dev là Windows; ảnh golden phụ thuộc cách hệ điều hành vẽ chữ nên baseline sinh ở một nền tảng sẽ đỏ ở nền tảng kia — baseline đỏ vì nền tảng thì sớm muộn cũng bị tắt, và lúc đó cổng coi như không tồn tại. Bản dùng trong repo khoá đúng thứ cổng cần bắt (đúng màn, đúng khối, đúng key) theo cách chạy giống nhau ở mọi nền tảng.

## C. M2 phục ban (3 tuần)

1. **Onboarding 3 ngày** (chưa làm): kế hoạch 3 ngày + "Bắt đầu ngay", sửa được ≤3 chạm.
2. **Phiên 10 phút** ✅: mốc 10/20/35; hết 10 phút hỏi "thêm 10 phút?"; đồng hồ hiện việc đang làm. (Gate hẹp: chỉ hỏi ở phiên ngắn mặc định — phiên 20/35 hoặc phiên vào từ một nhiệm vụ có thời lượng riêng thì kết thúc là kết thúc, không thêm một cửa sổ phải bấm trước bước phản tư.)
3. **Phản tư** ✅: một màn tổng kết, một câu "Phiến 10 phút xong. Hiểu chưa?" — 2 nút to Hiểu rồi/Chưa hiểu; không bấm 4 giây → ghi "chưa rõ" rồi biến; chỉ "Chưa hiểu" mới hỏi 3 chip (quá khó/hết giờ/làm việc khác) → đề xuất chia nhỏ/đổi lịch ≤2 chạm; có nút "không muốn nói gì" to bằng nút lưu; bỏ nhật ký dài.
4. **Chế độ yên lặng** ✅: 3 công tắc nhỏ (màu đỏ streak/mascot/âm thanh), báo cáo phụ huynh đi riêng.
5. **Export JSON + xoá**: timeline phiên + lịch sử freeze + `data_schema_version`; cron dọn cloud + backup cũ; hoàn tác/thùng rác 30 ngày (nếu mục E chốt theo USER).
6. **Báo cáo phụ huynh 3 dòng** (chưa làm): con mở app mấy buổi / một câu con tự viết / "tuần này bỏ qua mấy lần"; bỏ số phút, điểm, xếp hạng, bảng "hôm nay 0 phút"; xin phép con trước khi bật + nút hoàn tác; gửi tự động.
7. **Nhắc ngủ đúng một câu** ("Hôm nay bạn đã x phiên — thế là đủ."; bản đầy đủ cho PH), đúng giờ con chọn, cron trễ thì không gửi.
8. **Dark màn Phiên học** (điều kiện: màn Phiên trong đợt đầu M2); đo ở textScale 200%, cấm bar che việc ưu tiên.

**Gate M2→M3:** sửa/hoãn ≤3 chạm; dark AA ở chữ 200%; file <900 dòng; export JSON mở lại đủ dữ liệu cũ (bằng chứng streak); ≥8/10 HS nói "biết sửa lịch khi trượt việc".

## D. M3 phục ban (4 tuần)

1. **Bỏ thi đua ẩn danh**; không màn nào hiện số/tên người khác — rà tay + test tự động; kỷ lục cá nhân giữ.
2. **Pilot cả lớp** trong giờ tự học, máy phổ thông + mạng yếu; đo D1/D7 trên **phiên xong**.
3. **Sync 50 kịch bản xung đột** (bỏ 500) qua harness 2 thiết bị; "0 sync fail với RLS bật".
4. **AI**: 2 điểm ngữ cảnh (tạo task có preview / tổng kết phiên) + fallback rule-based; token <5s, fallback ≥99%/30 ngày.
5. **Chế độ hậu kỳ thi**: thay đếm ngược bằng dấu đã qua ("tuần này ôn xong 5/20 đề"); không ép streak; câu app tự nói "hôm nay thế là đủ rồi".
6. Nhắc ngủ giờ con chọn (CRON_SECRET 3h sáng); cửa sổ phụ huynh hoàn chỉnh (chỉ xem).

**Gate phát hành:** 50/50 kịch bản sync xanh; D7 ≥35%; crash-free ≥99,5%; AI fallback ≥99%/30 ngày; 0 màn hiện người khác.

## E. Xung đột CÒN LẠI chưa chốt

1. **7 ngày đếm ngược vs hoàn tác 30 ngày.** USER (18 tuổi) bực vì đếm ngược; KH giữ quyền "con không biến mất im lặng". *Đề xuất:* xoá chạm một → dữ liệu vào **thùng rác 30 ngày** (không đếm ngược ép); hết hạn xoá thật + cron dọn cloud/backup; xuất JSON (streak + timeline) trước khi rời thùng rác để cài lại không mất 47 ngày. USER xoá được ngay, KH vẫn không mất con im lặng.
2. **Dòng xác nhận gửi phụ huynh khi con định biến mất.** KH muốn gửi bà một dòng; USER sợ bị canh chừng. *Đề xuất:* chỉ gửi **sau khi** hết 30 ngày thùng rác, đúng một dòng trung tính ("dữ liệu đã xoá theo yêu cầu của con"), con xem trước nội dung và có công tắc tắt — giữ đúng MỘT quyền của KH mà không thành giám sát.
3. **Đồng hồ khi tắt màn.** USER chỉ chọn "chuyển app" nếu làm 1 trong 3 nhưng muốn team hứa "khởi động lại". *Đề xuất:* **không hứa** khởi động lại ở M1–M2; hẹn native notification ở M3 (đang hoãn M2–M3); nếu M3 trượt thì nói rõ "chưa làm được" — "hứa mà không giữ được thì đừng hứa".

## F. Bộ KPI V2

Từ 20 KPI xuống **8 KPI đo bên ngoài + 3 KPI người dùng**. Nguyên tắc: đo trên máy phổ thông (RAM 3GB, Android 10, mạng 4G yếu); log local, tôn trọng `analytics_consent`; không gửi server bên thứ 3; rút metric "40% fold".

| # | KPI | Ngưỡng | Cách đo 0đ | Ai đo |
|---|---|---|---|---|
| 1 | Nav/notification fail | 0 | CI GitHub Actions free: test route map + NotificationTapHandler | DEV |
| 2 | Golden diff 3 màn | 0 | `flutter test` goldens, so diff | DEV |
| 3 | Sống qua kill app | 100% | Test "kill giữa phiên, mở lại đúng thời gian" (timestamp) trên PWA + mobile | DEV |
| 4 | Sync + RLS | 0 fail / 50 kịch bản | Harness 2 thiết bị + restore xanh | DEV |
| 5 | Mở app → việc ưu tiên | ≤2 chạm, <15s tới việc đầu tiên | Đếm tap + quay màn hình 10 HS (thay metric "40% fold") | UI + ĐIỀU PHỐI |
| 6 | Render + frame | Home <150ms; p95 <16ms | DevTools profile trên máy RAM 3GB | DEV |
| 7 | Crash-free + mất phiên | ≥99,5%; 0 mất phiên cả lớp 7 ngày | Counter local + phỏng vấn sau 7 ngày | DEV + GV |
| 8 | AI fallback | Token <5s; fallback ≥99%/30 ngày | Tắt key AI, chạy 30 ngày đếm tỷ lệ | DEV |
| 9 | **Mở–tắt 5 giây vì chán** | Phiên <5 giây giảm ≤10% giữa 2 đợt pilot | Log local (session <5s, không phản tư) + câu phỏng vấn "lần gần nhất định tắt app vì sao" | UI + USER |
| 10 | **App nói đúng về tôi** | ≥8/10 HS xác nhận con số hiển thị đúng việc mình làm | Phỏng vấn 10 HS sau 7 ngày, đối chiếu log local | GV + KH |
| 11 | **Chủ động quay lại sau bỏ giữa chừng** | ≥50% lượt bỏ giữa chừng có phiên quay lại trong 24h | Log local abandon → reopen (consent-gated); GV đọc nghĩa tín hiệu | DEV (log) + GV (nghĩa) |

---

## G. Vai trò GIÁO VIÊN (vai mới trong thảo luận sâu, toàn quyền phủ quyết)

- Soi **kế hoạch học** có vô lý không; soi **AI có dạy sai không** (AI giảng sai còn tệ hơn không có AI).
- Chỉ thấy dữ liệu khi **chính học sinh cho phép**; không phải kênh "nhà trường cứ hỏi là biết".
- **Không được đẩy áp lực lớp học vào app** — nếu có đề xuất "xếp hạng lớp dựa trên app", KHÁCH HÀNG rút con ra khỏi dự án dùng.
- GV có quyền phủ quyết mọi tính năng gây áp lực so sánh (đã dùng: chặn thi đua ẩn danh M3).
- GV đọc nghĩa KPI #11 ("chủ động quay lại sau bỏ giữa chừng") — tín hiệu duy nhất app không giả mạo được.

> Bản `KE_HOACH_PHAT_TRIEN_THOA_THUAN.md` (v1) giữ nguyên làm tài liệu lịch sử; file này là bản điều chỉnh hiện hành cho lộ trình tiếp theo.

## Liên kết

- `KE_HOACH_PHAT_TRIEN_THOA_THUAN.md` — kế hoạch 3 mốc (v1, tài liệu lịch sử)
- `KPI_BENCHMARK.md` — mục G chứa bộ KPI V2
- `LICH_SU_THAO_LUAN.md` — Phần 2 chứa đầy đủ lời từng vai trong thảo luận sâu
- `KE_HOACH_CAI_TO_APP.md` — kế hoạch cải tổ gốc
