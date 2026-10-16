# KPI & Benchmark — EduPulse

> **PHIÊN BẢN V2 (2026-10-16):** Sau thảo luận sâu, bộ 20 KPI bên dưới **được thu về 8 KPI đo bên ngoài + 3 KPI người dùng**, đổi phiên mặc định 25→10 phút, gate "≥120 test" bị bỏ, thêm gate "kill app giữa phiên" và "RLS+CRON_SECRET". **Bộ KPI V2 nằm ở cuối file này (mục G) và trong `BAN_THAY_DOI_V2.md` mục F.** Bảng 20 KPI dưới đây giữ làm tham khảo lịch sử — các mục bị V2 thay thế được đánh dấu ❌.

**Nguồn:** `KE_HOACH_PHAT_TRIEN_THOA_THUAN.md` (ngày 2026-10-15)  
**Mục đích:** đo các gate trước khi M1→M2, M2→M3 và trước khi phát hành. Không đạt gate → dừng, sửa, không mở rộng phạm vi.  
**Nguyên tắc:** đo được trên thiết bị thật (máy phổ thông, RAM 3GB, mạng yếu) — không đo trên máy dev.

---

## 1. Bảng KPI theo mốc

| # | KPI | Định nghĩa đo | Mục tiêu | Cách đo (0 chi phí) | Đo ở mốc |
|---|---|---|---|---|---|
| 1 | Home render | Từ khi app khởi động tới khung Home đầu tiên hiển thị | **< 150ms** (render local), app mở → nội dung hiện < 1,5s | Flutter DevTools timeline + `flutter run --profile`; stopwatch quay màn hình 10 lần lấy trung vị | M1, M3 |
| 2 | Mở app → phiên học | Số chạm (tap) từ lúc mở app đến khi Pomodoro đang chạy | **≤ 2 chạm**, thời gian **< 15 giây** | Đếm tap + quay màn hình; thử với 5 người chưa dùng | M1 |
| 3 | Offline luồng Hôm nay | Xem nhiệm vụ → bắt đầu → hoàn thành → cập nhật kế hoạch với mạng tắt hoàn toàn | **100%** các bước chạy được | Airplane mode, chạy script 10 bước trên 3 máy | M1, M3 |
| 4 | Test pass | `flutter test` xanh + `flutter analyze` không lỗi | **≥ 120 test**, 0 lỗi analyze | CI GitHub Actions (2000 phút/tháng free) | M1, mỗi mốc |
| 5 | Navigation regression | Push/pop đúng màn, notification tap mở đúng đích | **0 fail** | Test tự động cho route map + `NotificationTapHandler` (viết TRƯỚC khi sửa) | M1 |
| 6 | Golden 5 màn × 3 state | Màn Hôm nay/Kế hoạch/Cá nhân/Phiên học/Phản tư × loading/empty/error | 5×3 golden đóng băng, diff = 0 | `flutter test --update-goldens` lần đầu, sau đó so diff | M1 |
| 7 | Mất phiên học | Pilot 10 HS × 7 ngày: số lần phiên/session bị mất hoặc lỗi lưu | **0 lần** | Log cục bộ (crash counter + session autosave) + phỏng vấn ngắn sau 7 ngày | M1 (gate M1→M2) |
| 8 | Streak freeze + phản tư | Unit test luật freeze & form 15 giây | **100% pass** | `flutter test` 2 nhóm test riêng | M1 |
| 9 | Sửa/hoãn/chia nhiệm vụ | Số chạm tối đa để đổi lịch 1 nhiệm vụ | **≤ 3 chạm** | Thử nghiệm 5 người, quay màn hình | M2 |
| 10 | Dark mode tương phản | Toàn bộ text/icon trong 5 màn chính | **WCAG AA ≥ 4.5:1**, chữ 200% không vỡ | Script kiểm tra token màu (contrast ratio tự tính) + ảnh chụp 2 cỡ chữ | M2 |
| 11 | Frame time | Scroll + chuyển màn trên máy phổ thông | **p95 < 16ms** (không jank) | Flutter DevTools Performance, đo 3 lần lấy p95 | M2 |
| 12 | Kích thước file nguồn | `study_screen.dart`, `home_screen.dart`, `account_screen.dart`, `onboarding_screen.dart` | **< 900 dòng/file** (từ ~1850/1816/1466/1316) | `wc -l` / cloc trong CI | M2 |
| 13 | AI preview | Đề xuất AI (tạo task) có xem trước, huỷ/chỉnh được | **100%** đường AI có nút huỷ/chỉnh; token đầu **< 5s** | Test tự động + đo latency 20 prompt | M2 |
| 14 | Quiz lưu kết quả | Mỗi lần chơi quiz từ ảnh tạo bản ghi + gợi ý ôn lại | **100%** phiên có lưu; không mất khi khởi động lại app | Test migrate + restore fixture | M2 |
| 15 | Xóa toàn bộ dữ liệu | 1 chạm ở Cài đặt → Quyền riêng tư, local + cloud đều xóa sạch | **100%** khoá/cache/biến liên quan bị xoá, restore không hồi lại | Test wipe + kiểm `SharedPreferences` + backup server | M2 (local) → M2/M3 (cloud) |
| 16 | Sync bất biến | 500 kịch bản offline→online (gồm xung đột, mất mạng giữa chừng, 2 thiết bị) | **≥ 99% không mất dữ liệu**, có log kiểm chứng | Harness test `sync_outbox_v1` + `backup_service` | M3 |
| 17 | Crash-free | Pilot 50 người × 30 ngày, máy phổ thông, mạng yếu | **≥ 99,5%** | Counter crash local + báo cáo tuần (không gửi server bên thứ 3) | M3 |
| 18 | AI fallback | Khi free tier lỗi/hết quota | Token quay về **< 5s**, fallback rule-based trả được kế hoạch dùng được; **≥ 99%/30 ngày** | Tắt key AI → chạy 30 ngày đếm tỷ lệ fallback thành công | M3 |
| 19 | Giữ chân | D1 (mở lại ngày thứ 2) và D7 (mở lại sau 7 ngày) | **D7 ≥ 35%** | Đếm cục bộ, thuê bao tự nguyện; không gửi đi ngoài máy | M3 |
| 20 | Lý do mở lại/tuần | Số tuần có ≥1 lý do episodic mở app (nhắc việc tồn, gợi ý ôn) | **≥ 1 lý do/tuần/người dùng** | Log sự kiện local | M3 |

## 2. Không đạt gate thì làm gì

| Gate rơi | Hành động bắt buộc |
|---|---|
| Home render > 150ms | Tìm điểm rebuild nặng (provider/subscription quá rộng), lazy theo lazy tab trước khi thêm tối ưu |
| Nav/notification 0 fail | M1 chưa đóng — chặn mọi việc khác, quay lại test route map |
| Mất phiên học trong pilot | Autosave + resume state vào P0, không sang M2 |
| Dark mode trượt AA | Chưa bake dark cho tab đó (giữ force light), điều chỉnh token rồi đo lại |
| File vẫn > 900 dòng | Tách tiếp theo lát hành vi trước khi thêm tính năng mới vào file |
| AI fallback thất bại | Đóng băng mốc AI ngữ cảnh; chỉ giữ rule-based cho tới khi đạt 99% |
| D7 < 35% trên pilot 50 người | Không phát hành rộng; phỏng vấn 10 người rời app, sửa đúng điểm rời rồi pilot lại |

## 3. Cách thu thập dữ liệu phù hợp người dùng thật

- **Pilot nội bộ rẻ:** nhóm 10 HS (boss/dev tuyển) dùng PWA/APK build test 7 ngày trước M2; nhóm 50 người trước M3, bắt buộc: ≥3 dòng máy khác nhau (RAM 3GB, Android 10, mạng 4G yếu).
- **Metric cục bộ, không server thu thập:** counter lưu `SharedPreferences`, chỉ báo cáo khi người dùng bấm "chia sẻ báo cáo cải thiện".
- **Phỏng vấn 2 vòng** (USER/KH yêu cầu): vòng 1 sau 7 ngày, vòng 2 sau 30 ngày — 5 câu chung: "việc đầu tiên bạn làm khi mở app", "lần gần nhất bạn định xoá app vì sao", "có lúc nào không biết sửa lịch?", "điểm nào bạn muốn tắt?", "báo cáo phụ huynh có chỗ nào làm bạn phiền?".

## 4. Template ghi nhận mỗi lần đo

```
Mốc:          [M1 | M2 | M3 | Phát hành]
Ngày đo:       YYYY-MM-DD
Thiết bị:      <model>, RAM <n>GB, Android <v>, mạng <loại>
KPI #:         [số từ mục 1]
Giá trị đo:    <số + đơn vị>
Mục tiêu:      <ngưỡng>
PASS/FAIL:     [P | F]
Nếu FAIL:      <hành động theo mục 2 + PR/commit sửa>
Người đo:      <tên vai>
```

## 5. Liên kết tài liệu

- `KE_HOACH_PHAT_TRIEN_THOA_THUAN.md` — kế hoạch 3 mốc (v1, tài liệu lịch sử)
- `BAN_THAY_DOI_V2.md` — **bản điều chỉnh hiện hành** (sau thảo luận sâu)
- `LICH_SU_THAO_LUAN.md` — biên bản tranh luận đầy đủ (nguồn gốc các ngưỡng)
- `KE_HOACH_CAI_TO_APP.md` — kế hoạch cải tổ gốc
- `CHECKLIST_PHAT_HANH.md` — checklist phát hành hiện có (bổ sung mục "KPI đã đo" nếu chưa có)

---

## G. Bộ KPI V2 (thay thế bảng mục 1) — sau thảo luận sâu 2026-10-16

**Nguyên tắc V2:** đo trên máy phổ thông (RAM 3GB, Android 10, mạng 4G yếu); log local, tôn trọng `analytics_consent`; không gửi server bên thứ 3; rút metric "40% fold". **8 KPI bên ngoài + 3 KPI người dùng**:

| # | KPI | Ngưỡng | Cách đo 0đ | Ai đo |
|---|---|---|---|---|
| 1 | Nav/notification fail | 0 | CI GitHub Actions free: test route map + NotificationTapHandler | DEV |
| 2 | Golden diff 3 màn | 0 | `flutter test` goldens, so diff | DEV |
| 3 | Sống qua kill app | 100% | Test "kill giữa phiên, mở lại đúng thời gian" (timestamp-based session) trên PWA + mobile | DEV |
| 4 | Sync + RLS | 0 fail / 50 kịch bản xung đột | Harness 2 thiết bị + restore xanh, RLS đã bật | DEV |
| 5 | Mở app → việc ưu tiên | ≤2 chạm, <15s tới việc đầu tiên | Đếm tap + quay màn hình 10 HS (thay metric "40% fold") | UI + ĐIỀU PHỐI |
| 6 | Render + frame | Home <150ms; p95 <16ms | DevTools profile trên máy RAM 3GB | DEV |
| 7 | Crash-free + mất phiên | ≥99,5%; **0 mất phiên cả lớp 7 ngày** | Counter local + phỏng vấn sau 7 ngày; BOSS tự ký | DEV + GV |
| 8 | AI fallback | Token <5s; fallback ≥99%/30 ngày | Tắt key AI, chạy 30 ngày đếm tỷ lệ | DEV |
| 9 | **Mở–tắt 5 giây vì chán** ❓NEW | Phiên <5 giây giảm ≤10% giữa 2 đợt pilot | Log local (session <5s, không phản tư) + hỏi "lần gần nhất định tắt app vì sao" | UI + USER |
| 10 | **App nói đúng về tôi** ❓NEW | ≥8/10 HS xác nhận con số hiển thị đúng việc mình làm | Phỏng vấn 10 HS sau 7 ngày, đối chiếu log local | GV + KH |
| 11 | **Chủ động quay lại sau bỏ giữa chừng** ❓NEW | ≥50% lượt bỏ giữa chừng có phiên quay lại trong 24h | Log local abandon → reopen (consent-gated); GV đọc nghĩa tín hiệu | DEV (log) + GV (nghĩa) |

**Các mục bảng cũ bị V2 sửa/bỏ:**
- ❌ #4 "≥120 test pass" → thay bằng KPI #1 + #2 (nav 0 fail + golden diff 0); lý do: repo đã có ~934 test xanh, gate cũ vô nghĩa.
- ❌ #9/#13 → đo sau, quaủ đo "phiên xong" và KPI #5.
- ❌ #16 "500 kịch bản sync" → 50 kịch bản có xung đột (KPI #4).
- ❌ Pixel/token đầu <5s giữ nguyên chỉ áp cho AI KPI #8.
- ➕ Mới: KPI #9 "mở–tắt 5 giây vì chán" (GV: D7 chỉ là hệ quả — cần đo cái chán trực tiếp), #10 "app nói đúng về tôi", #11 "quay lại sau bỏ giữa chừng".
- ➕ Gate M1 mới: "kill app giữa phiên → mở lại đúng thời gian" (timestamp-based session).
- ➕ Gate chặn cloud: "0 sync fail với RLS bật" trước khi bật cửa sổ phụ huynh.

**Nếu không đạt gate V2:**
- KPI #9 tăng (buồn chán) → rà lại banner 1 việc + phiên 10 phút trước khi thêm tính năng mới; cấm "tô màu" bằng gamification.
- KPI #10 tệ → cắt nhãn môn yếu khỏi mọi hiển thị cho tới khi dữ liệu đúng.
- KPI #4 fail → đóng băng cloud (chạy local-only), không mở cửa sổ phụ huynh.
