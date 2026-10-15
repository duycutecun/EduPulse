# Kế hoạch cải tổ EduPulse

**Phiên bản:** 1.0  
**Ngày:** 2026-10-11  
**Phạm vi:** Flutter mobile, web/PWA, API Vercel và Supabase của EduPulse.

## 1. Quyết định phạm vi bắt buộc

Đợt cải tổ này **không thêm billing dưới bất kỳ hình thức nào**. Cụ thể:

- Không có subscription, gói Free/Pro/Premium, paywall, trial, hạn mức trả phí, IAP hoặc trang thanh toán.
- Không tích hợp Stripe, RevenueCat, Google Play Billing, App Store IAP, webhook thanh toán hoặc tracking doanh thu.
- Không khóa tính năng học, đồng bộ, AI, phụ huynh hay xuất báo cáo sau một bước thanh toán.
- Không thay đổi UI, điều khoản hay API theo hướng thu phí.

Nếu sau này có yêu cầu thương mại hóa, đó phải là một đề án độc lập được phê duyệt riêng; không phải phần việc của tài liệu này.

## 2. Mục tiêu cải tổ

EduPulse cần chuyển từ một ứng dụng có nhiều tính năng rời rạc sang một trợ lý học tập có nhịp sử dụng rõ ràng:

> Mỗi ngày, học sinh mở app là biết việc quan trọng cần làm, bắt đầu học ngay, và nhận được điều chỉnh kế hoạch dựa trên tiến độ thật.

Ba kết quả sản phẩm cần đạt:

1. **Rõ việc:** người dùng có kế hoạch hôm nay ngắn, khả thi và liên kết với kỳ thi/mục tiêu.
2. **Duy trì nhịp:** bắt đầu và hoàn thành phiên học nhanh, không bị phân tán bởi điều hướng hoặc cấu hình.
3. **Cải thiện có căn cứ:** tiến độ, điểm thử, mức hiểu và các lần bỏ lỡ được chuyển thành hành động tiếp theo.

## 3. Hiện trạng và vấn đề cần xử lý

Dự án đã có nhiều năng lực giá trị: nhiệm vụ, kỳ thi, Pomodoro, nhật ký học, điểm thi, AI Coach, ghi chú, đồng bộ cloud, chia sẻ phụ huynh, PWA và mobile. Tuy nhiên, số lượng năng lực này làm tăng độ phức tạp ở cả trải nghiệm lẫn mã nguồn.

Một số chỉ dấu kỹ thuật hiện có:

- Các màn hình lõi đang rất lớn: `study_screen.dart` khoảng 3.088 dòng, `home_screen.dart` khoảng 1.816 dòng, `account_screen.dart` khoảng 1.466 dòng và `main_shell.dart` khoảng 942 dòng.
- Logic AI, sync/backup, dữ liệu cục bộ và UI cùng tồn tại ở nhiều khu vực. Điều này khiến việc sửa một luồng dễ gây tác động dây chuyền.
- Ứng dụng đang dùng `SharedPreferences` cho dữ liệu offline-first; cần xác định ranh giới rõ giữa cấu hình nhỏ, cache và dữ liệu học tập có cấu trúc.
- Đã có hơn 50 tệp kiểm thử; đây là nền tảng tốt để cải tổ theo hướng có kiểm soát thay vì viết lại toàn bộ.

Các vấn đề sản phẩm cần được kiểm chứng bằng dữ liệu và phỏng vấn ngắn, không mặc định là sự thật:

- Người dùng mới có thể chưa hiểu hành động ưu tiên sau onboarding.
- AI Chat có nguy cơ trở thành điểm đến tách rời, thay vì hỗ trợ hoàn thành nhiệm vụ học.
- Những khu vực như lịch, ghi chú, thành tích, phụ huynh và cài đặt có thể đang cạnh tranh sự chú ý với luồng học hằng ngày.
- Đồng bộ, offline recovery và lỗi AI là các luồng dễ làm mất niềm tin nếu trạng thái không rõ ràng.

## 4. Người dùng và luồng ưu tiên

### 4.1. Người dùng chính

Học sinh THPT đang ôn một kỳ thi có mốc thời gian xác định; dùng điện thoại hằng ngày, thời gian tập trung hạn chế và cần biết nên học gì trước.

Người dùng phụ:

- Phụ huynh xem báo cáo mà học sinh đã chủ động chia sẻ.
- Học sinh dùng AI khi kẹt bài, cần tạo quiz, kế hoạch hoặc tóm tắt điểm yếu.

### 4.2. Vòng lặp sử dụng chính

```text
Mở app
  → xem “Việc quan trọng nhất hôm nay”
  → bắt đầu phiên học
  → hoàn thành / ghi nhận trở ngại
  → cập nhật tiến độ
  → nhận gợi ý cho lần học tiếp theo
```

Mọi tính năng được giữ lại phải hỗ trợ ít nhất một bước trong vòng lặp này, hoặc có nhóm người dùng/nhu cầu rõ ràng.

### 4.3. Điều hướng mục tiêu

Giữ tối đa ba điểm đến chính:

| Điểm đến | Mục tiêu | Nội dung chính |
| --- | --- | --- |
| **Hôm nay** | Bắt đầu hành động | nhiệm vụ ưu tiên, đếm ngược kỳ thi, phiên đang diễn ra, tiến độ ngày |
| **Kế hoạch** | Nhìn và điều chỉnh đường đi | tuần học, môn/chủ đề, lịch sử, điểm thử, xu hướng tiến độ |
| **Cá nhân** | Quản trị cá nhân | hồ sơ, đồng bộ, cài đặt, quyền riêng tư, phụ huynh, trải nghiệm thiết bị |

AI không nhất thiết là một tab chính. AI cần xuất hiện theo ngữ cảnh: bên trong nhiệm vụ, kết quả điểm thử, ghi chú, ảnh đề bài hoặc phần tổng kết phiên học. Màn chat độc lập vẫn có thể tồn tại qua nút truy cập nhanh khi người dùng thực sự cần trao đổi tự do.

## 5. Yêu cầu trải nghiệm sau cải tổ

### 5.1. Onboarding chuyển thành kế hoạch đầu tiên

Onboarding chỉ hỏi thông tin cần để tạo hành động ngày đầu:

1. Kỳ thi/mục tiêu và ngày thi.
2. Môn hoặc nhóm kiến thức ưu tiên.
3. Mức điểm hiện tại/mục tiêu, nếu người dùng sẵn sàng cung cấp.
4. Số buổi hoặc số phút học thực tế mỗi ngày.
5. Khung giờ dễ học.

Đầu ra bắt buộc là một tuần học khởi đầu có thể sửa, không chỉ là hồ sơ hoặc danh sách thiết lập. Người dùng phải nhìn thấy nhiệm vụ đầu tiên và nút **Bắt đầu ngay** trước khi rời onboarding.

### 5.2. Trang Hôm nay

Thứ tự nội dung:

1. Thẻ **việc quan trọng nhất**: một nhiệm vụ, lý do ưu tiên, thời lượng ước tính và CTA bắt đầu.
2. Danh sách tối đa ba việc tiếp theo; phần còn lại thu gọn.
3. Phiên học đang chạy hoặc nút bắt đầu Pomodoro/focus session.
4. Tiến độ hôm nay và đếm ngược kỳ thi với mức độ khẩn cấp vừa đủ.
5. AI gợi ý một hành động, không hiển thị nhiều thẻ gợi ý cạnh tranh nhau.

Quy tắc nội dung:

- Không buộc người dùng khai báo quá nhiều thuộc tính để tạo nhiệm vụ.
- Người dùng có thể hoãn, chia nhỏ hoặc đổi lịch trong một thao tác; app hỏi lý do ngắn để cải thiện kế hoạch.
- Thành tích, mascot, XP và streak là phản hồi phụ trợ, không được che CTA học.

### 5.3. Phiên học và phản tư

Một phiên học gồm ba trạng thái rõ ràng: chuẩn bị, đang tập trung, kết thúc.

Khi kết thúc, hiển thị một biểu mẫu tối đa 15 giây:

- Đã hoàn thành mục tiêu chưa?
- Mức hiểu: chưa hiểu / tạm ổn / tự tin.
- Cần ôn lại hoặc có trở ngại nào không?

Phản hồi này được lưu vào timeline và dùng để đề xuất ôn lại, chia nhỏ nhiệm vụ hoặc điều chỉnh lịch. Không yêu cầu người dùng viết nhật ký dài trong luồng mặc định.

### 5.4. Kế hoạch và tiến độ

Khu vực Kế hoạch cần trả lời bốn câu hỏi:

1. Tôi đang tiến gần kỳ thi/mục tiêu đến đâu?
2. Tuần này nên dành thời gian cho môn/chủ đề nào?
3. Điều gì đang khiến tôi chậm nhịp?
4. Bước tiếp theo cụ thể là gì?

Biểu đồ chỉ hiển thị khi kèm diễn giải và hành động. Ví dụ: “Toán đang thiếu 2 phiên so với nhịp tuần này — chuyển 25 phút từ tối thứ Năm sang thứ Sáu”.

### 5.5. AI Coach

AI chỉ được coi là thành công nếu tạo ra một hành động xác nhận được, ví dụ:

- Tạo hoặc chỉnh nhiệm vụ có preview trước khi lưu.
- Sinh quiz từ đề/ảnh, lưu kết quả và đề xuất chủ đề ôn lại.
- Giải thích nội dung kèm mức độ tin cậy, nguồn tham khảo khi có tra cứu web.
- Phân tích điểm thử hoặc nhật ký học rồi đề xuất thay đổi kế hoạch có thể chấp nhận/từ chối.

Mỗi phản hồi AI phải có trạng thái tải, lỗi dễ hiểu, nút thử lại và cách tiếp tục dùng app khi dịch vụ AI không khả dụng. Không tự động sửa kế hoạch, xóa dữ liệu hoặc gửi dữ liệu gia đình chỉ dựa trên phản hồi mô hình.

## 6. Kiến trúc mục tiêu

### 6.1. Cấu trúc theo feature

Mỗi feature quan trọng (`tasks`, `study`, `exams`, `progress`, `ai_coach`, `family`) nên có ranh giới tối thiểu:

```text
feature/
  domain/          # entity, use case, repository contract
  data/            # local/cloud datasource, mapper, repository implementation
  application/     # controller/notifier/use-case orchestration
  presentation/    # screen, widget, routing state
```

`core/` chỉ chứa khả năng dùng chung thực sự: networking, auth, crypto/secure storage, analytics, design tokens, platform adapters và error handling. Không tiếp tục đưa logic nghiệp vụ của feature mới vào `core/`.

### 6.2. Tách màn hình lớn theo lát cắt hành vi

Ưu tiên tách dần, có test bảo vệ trước mỗi bước:

1. `study_screen.dart`: session controller, daily summary, score tracking, chart section và action sheet.
2. `home_screen.dart`: today-plan controller, task list, countdown, suggestion block và mascot/gamification.
3. `main_shell.dart`: navigation shell, responsive layout, deep-link handoff và tab-specific coordinator.
4. `account_screen.dart` và `family.js`: profile/security, cloud configuration, consent/family sharing và report delivery.

Mục tiêu không phải giảm số dòng đơn thuần. Mỗi phần tách ra phải có API đầu vào/đầu ra rõ, không truy cập storage/network trực tiếp từ widget nếu không cần thiết.

### 6.3. State management và dependency

Chọn một mô hình quản lý trạng thái thống nhất cho feature mới và khu vực được cải tổ. Tiêu chí chọn:

- Có trạng thái `loading / data / empty / error` chuẩn hóa.
- Controller dễ fake trong test.
- Không khởi tạo service/network trong `build()`.
- Dễ hủy stream, timer và subscription khi rời màn hình.

Không cần chuyển toàn bộ app trong một lần. Dùng adapter để các phần cũ tiếp tục hoạt động, sau đó di chuyển feature theo từng đợt.

## 7. Dữ liệu, offline và đồng bộ

### 7.1. Phân loại dữ liệu

| Loại dữ liệu | Nơi lưu ưu tiên | Yêu cầu |
| --- | --- | --- |
| Cấu hình giao diện, cờ onboarding | local preferences | nhẹ, có version |
| Nhiệm vụ, phiên học, điểm, ghi chú | local database/repository | có schema, migration, queue sync |
| Thông tin tài khoản và liên kết gia đình | cloud + cache tối thiểu | consent, phân quyền |
| Tệp đính kèm/ảnh | file store có metadata | nén, retry, giới hạn kích thước |
| Cache AI/search | cache có TTL | xóa được, không là nguồn dữ liệu thật |

Trước khi thay đổi cơ chế lưu, cần lập inventory tất cả key `SharedPreferences`, phiên bản hóa payload và có migration idempotent. Tuyệt đối không xóa dữ liệu local của người dùng chỉ để đổi schema.

### 7.2. Hành vi sync cần xác định

- Mỗi thay đổi có `id`, `updatedAt`, `deviceId`, schema version và trạng thái pending/synced/failed.
- App hiển thị trạng thái dễ hiểu: đã lưu trên máy, đang đồng bộ, lỗi cần thử lại, hoặc xung đột cần chọn.
- Queue đồng bộ chạy lại khi có mạng; không chặn thao tác học cục bộ.
- Đặt chiến lược xung đột theo loại dữ liệu: completion event cộng dồn, chỉnh sửa nhiệm vụ ưu tiên bản có version mới hơn kèm audit tối thiểu, xóa cần tombstone nếu cần đồng bộ nhiều thiết bị.
- Có kịch bản test cho offline → sửa nhiều dữ liệu → online, đổi thiết bị, app bị tắt giữa lúc sync và backup restore.

## 8. Bảo mật và quyền riêng tư

- API key do hệ thống vận hành sở hữu không được đưa vào binary hoặc bundle web. AI managed đi qua backend với xác thực, rate limit, quota và audit log đã lọc dữ liệu nhạy cảm.
- Nếu tiếp tục hỗ trợ khóa do người dùng tự cung cấp, coi đó là BYOK: nêu rõ phạm vi, lưu an toàn theo nền tảng, không log giá trị khóa và có nút xóa khóa ngay.
- Tách dữ liệu học sinh và phụ huynh bằng policy phía server/database; không tin cậy role hoặc consent chỉ từ client.
- Báo cáo phụ huynh chỉ chứa các trường học sinh đã chọn chia sẻ; cần có màn xem trước và nhật ký thay đổi quyền chia sẻ.
- Tệp ảnh đề bài, chat history và dữ liệu AI cần có thời hạn lưu/cache rõ ràng, cơ chế xóa dữ liệu cá nhân và thông báo quyền riêng tư dễ hiểu.

## 9. Đo lường sản phẩm và chất lượng

### 9.1. Sự kiện tối thiểu

Không thu nội dung bài học hoặc chat thô trong analytics. Chỉ thu sự kiện sản phẩm đã ẩn danh/pseudonym hóa khi có sự đồng ý phù hợp:

- `onboarding_completed`
- `today_plan_viewed`
- `priority_task_started`, `priority_task_completed`, `task_rescheduled`
- `focus_session_started`, `focus_session_completed`, `focus_session_abandoned`
- `ai_action_requested`, `ai_action_applied`, `ai_action_failed`
- `sync_succeeded`, `sync_failed`, `conflict_resolved`

Đã hiện thực: `core/analytics/product_events.dart` (hằng tên sự kiện + tập `all`) và
`core/analytics/product_analytics.dart` (`ProductAnalytics` singleton — opt-in mặc
định TẮT qua key `analytics_consent`, buffer cục bộ giới hạn 200, chỉ cho phép các
thuộc tính phi-nội-dung `count/minutes/source/result/reason/kind`, cắt value ≤40 ký
tự, `setEnabled(false)` xoá buffer; không tự gửi đi đâu). Gắn tại: onboarding
(`onboarding_completed`, source plan/skip), Home (`today_plan_viewed`,
`priority_task_started/completed`, `task_rescheduled`), Study (`focus_session_started`,
`focus_session_completed` kèm phút, `focus_session_abandoned` khi ghi phiên bỏ dở), AI
(`ai_action_requested/applied` kèm loại hành động, `ai_action_failed` khi lỗi), sync
(`sync_succeeded`/`sync_failed` trong vòng sync nền). Toggle đồng ý ở màn "Tôi"
(`Số liệu cải thiện trải nghiệm`). 7 unit test cho service.

### 9.2. Chỉ số thành công

| Nhóm | Chỉ số | Mục tiêu cần chốt sau baseline |
| --- | --- | --- |
| Kích hoạt | hoàn tất onboarding và bắt đầu phiên đầu | tăng so với baseline |
| Thói quen | D1/D7 retention, phiên hoàn tất/tuần | tăng bền vững |
| Hiệu quả | tỷ lệ nhiệm vụ ưu tiên hoàn tất/hoãn có chủ đích | tăng |
| Tin cậy | sync success, crash-free sessions, lỗi AI | cải thiện |
| AI hữu ích | phản hồi AI dẫn tới action được áp dụng | tăng |

Không dùng số lượt mở chat hoặc thời gian online đơn thuần làm chỉ số thành công.

> **Baseline (9.2):** các chỉ số trên chưa có số gốc vì trước đây app không thu
> sự kiện. Từ nay baseline lấy từ `ProductAnalytics.recent()` (mục 9.1) khi người
> dùng đã bật đồng ý — cục bộ, ẩn danh; tỉ lệ như "phiên hoàn tất/tuần" hoặc
> "action được áp dụng" suy ra từ cặp `focus_session_completed`/`_abandoned` và
> `ai_action_requested`/`ai_action_applied`. Chỉ chốt mục tiêu sau khi có ≥ 2
> tuần dữ liệu; không đặt KPI trên số lượt mở chat.

> **Đã kiểm kê (7.1):** xem `docs/DU_LIEU_VA_PHIEN_BAN.md` — bảng khoá
> SharedPreferences theo loại, quy tắc phiên bản hoá qua `data_schema_version`
> + `DataMigration` (v1→v3), và checklist khi thêm dữ liệu mới.

## 10. Lộ trình 12 tuần

### Giai đoạn 0 — Chuẩn bị (Tuần 1–2)

- Viết product brief một trang: đối tượng chính, vấn đề, vòng lặp học, chỉ số.
- Audit luồng hiện có: onboarding, nhiệm vụ, focus session, sync/backup, AI, family consent.
- Thiết lập baseline về hiệu năng, lỗi và funnel; phỏng vấn 5–8 học sinh nếu có thể.
- Lập data inventory, secret inventory và danh sách local-storage migration.
- Đóng băng việc thêm tính năng không hỗ trợ luồng học hằng ngày.

**Điều kiện hoàn thành:** có bản đồ user journey hiện tại, backlog được ưu tiên, definition of done và bản backup/migration được kiểm thử.

### Giai đoạn 1 — Trải nghiệm Hôm nay (Tuần 3–5)

- Thiết kế lại information architecture và Home theo thứ tự ưu tiên ở mục 5.2.
- Cải tổ onboarding để tạo kế hoạch tuần đầu.
- Chuẩn hóa create/edit/reschedule/complete task.
- Kết nối focus session với nhiệm vụ và phản tư kết thúc phiên.
- Viết widget/integration tests cho luồng “mở app → bắt đầu → hoàn thành → thấy kế hoạch cập nhật”.

**Điều kiện hoàn thành:** người dùng mới hoàn thành luồng đầu tiên mà không cần vào tab AI, Calendar hoặc Settings.

### Giai đoạn 2 — Nền tảng kỹ thuật (Tuần 6–8)

- Tách các màn hình lớn theo mục 6.2, bắt đầu từ Study và Home.
- Chuẩn hóa state, dependency và error state.
- Xây repository/data-source contract cho task, study session, exam score và plan.
- Thêm sync queue/status và test recovery offline.
- Đặt CI bắt buộc: format, analyze, test, build web; thêm smoke test thiết bị trước release.

**Điều kiện hoàn thành:** không hồi quy các luồng chính, và widget presentation không tự gọi storage/network trực tiếp.

### Giai đoạn 3 — AI đáng tin cậy và tiến độ (Tuần 9–10)

- Đưa AI vào các thời điểm có ngữ cảnh: tạo nhiệm vụ, quiz, điểm thử, tổng kết tuần.
- Thêm preview/confirm/undo cho mọi action do AI đề xuất.
- Thiết lập API guardrail: timeout, retry có giới hạn, rate limit, error taxonomy và fallback không-AI.
- Thêm test fixture/evaluation cho các prompt quan trọng, đặc biệt parsing kế hoạch và tạo task.
- Cải tiến trang Kế hoạch để biến số liệu thành hành động.

**Điều kiện hoàn thành:** mỗi tính năng AI có hành động người dùng kiểm soát được và hoạt động cơ bản của app không phụ thuộc AI.

### Giai đoạn 4 — Beta và phát hành (Tuần 11–12)

- Mở beta theo cohort nhỏ, có kênh feedback trong app.
- Theo dõi funnel, lỗi sync, crash, thời gian phản hồi AI và feedback định tính.
- Xử lý P0/P1, tối ưu hiệu năng Home/startup và hoàn thiện accessibility/responsive layouts.
- Rà soát quyền riêng tư, family consent, migration/rollback và release notes.

**Điều kiện hoàn thành:** đạt ngưỡng chất lượng đã chốt ở giai đoạn 0, có playbook hỗ trợ lỗi sync/AI và có quyết định phát hành dựa trên dữ liệu beta.

## 11. Backlog ưu tiên khởi đầu

### P0 — Phải làm trước beta

- [x] Bảo toàn dữ liệu: migration, backup/restore và recovery khi sync thất bại.
- [x] Luồng Hôm nay xuyên suốt từ nhiệm vụ đến focus session và completion.
- [x] Trạng thái loading/empty/error thống nhất tại các màn chính.
- [x] Ranh giới server/client cho khóa API, auth và dữ liệu phụ huynh.
- [x] Test regression cho onboarding, task completion, offline recovery, AI action confirmation và family consent.

### P1 — Làm khi P0 ổn định

- [x] Weekly planning và gợi ý phân bổ thời gian có thể chấp nhận/từ chối.
- [x] Nâng cấp insight điểm thử, chủ đề yếu và ôn lại.
- [x] Phân tách dần `main_shell`, Home, Study, Account và API family. (Đã tách: main_shell → `shell_banners.dart`; Home → `exam_mode_cards.dart`, `post_exam_card.dart`, `add_task_dialog.dart`, `snack_message.dart`; Study → `score_tab_view.dart`, `ai_post_focus_sheet.dart`, `study_entry_dialogs.dart`, `study_analytics_view.dart` (lát cắt biểu đồ + phân tích nâng cao, widget thuần nhận dữ liệu); Account → `account_family_entries.dart`, `appearance_card.dart`; Notes → `note_editor_view.dart`, `notes_empty.dart`; AI Coach → `ai_quick_actions.dart`. API family: harness `node --test` + logic thuần ở `api/_family_logic.js` (14 test); handler Supabase còn lại tách tiếp khi cần.)
- [x] Accessibility: cỡ chữ, tương phản, screen reader, touch target, motion reduction.

### P2 — Chỉ cân nhắc sau khi xác nhận nhu cầu

- [x] Cải tiến mascot/gamification. (Achievements: domain/service/sheet + UI entries/hooks + 14 tests).
- [x] Mở rộng leaderboard/cộng đồng. (Bảng vàng kỷ lục: personal_records + LeaderboardScreen + Account entry + 10 tests).
- [x] Tính năng native bổ sung (notification nâng cao). (plan_notifications + AdaptivePolicy integration + Account toggle + 8 tests; truyền payload + điều hướng khi nhấn thông báo qua NotificationTapHandler → main_shell; widget Android sync thêm key streak/level/xp/huy hiệu + gọi lại sau task/phiên/điểm; advanced flags đọc lúc khởi động; 2 tests widget sync).
- [x] Các báo cáo/phân tích chuyên sâu ít dùng. (Màn `DeepReportScreen` mở từ "Tôi" và tab Tiến độ: xu hướng điểm theo tuần, năng lực chủ đề <6.5, điểm theo môn, thời gian học + hiệu quả phiên. Domain `deep_report.dart` thuần + 10 unit test + 5 widget test; chạy 100% offline, không gọi AI. Có thể bổ sung thêm mảng báo cáo khác sau.)

## 12. Nguyên tắc triển khai

- Cải tổ theo lát cắt dọc có thể phát hành, không viết lại toàn bộ app.
- Mọi thay đổi dữ liệu phải có backup, migration và rollback/khôi phục rõ ràng.
- Mọi tính năng AI phải có fallback thao tác thủ công.
- Chỉ thêm một tính năng nếu xác định được nó cải thiện bước nào trong vòng lặp học.
- Không thêm billing, paywall, subscription hoặc cơ chế kiếm tiền vào bất kỳ giai đoạn nào của kế hoạch này.
- Đánh đổi ưu tiên: độ tin cậy và luồng học hằng ngày quan trọng hơn số lượng tính năng hay hiệu ứng giao diện.

## 13. Definition of Done cho từng hạng mục

Một hạng mục được coi là hoàn thành khi:

1. Có mô tả vấn đề, người dùng mục tiêu và tiêu chí nghiệm thu.
2. Có thiết kế cho loading, empty, error, offline và quyền bị từ chối nếu liên quan.
3. Có kiểm thử phù hợp: unit cho domain, widget cho UI, integration cho luồng rủi ro.
4. Không làm mất dữ liệu cũ và có migration nếu thay đổi schema.
5. Đã kiểm tra mobile và web/PWA khi UI hoặc platform capability bị ảnh hưởng.
6. Event đo lường (nếu cần) không thu dữ liệu học tập nhạy cảm vượt quá mục đích đã nêu.
7. Không đưa vào billing, paywall, subscription, IAP hay bất cứ phụ thuộc thanh toán nào.

