# EduPulse v2 — Bảng Tiến Độ & TODO List Triển Khai Nhiệm Vụ

> **Tài liệu tham chiếu:**  
> - [`EDUPULSE_UX_UI_REDESIGN.md`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/c%E1%BA%A3i%20t%E1%BB%95%20edupulse%20v2/EDUPULSE_UX_UI_REDESIGN.md)  
> - [`EDUPULSE_SPRINT_BACKLOG.md`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/c%E1%BA%A3i%20t%E1%BB%95%20edupulse%20v2/EDUPULSE_SPRINT_BACKLOG.md)  
> - [`EDUPULSE_AI_OPTIMIZATION.md`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/c%E1%BA%A3i%20t%E1%BB%95%20edupulse%20v2/EDUPULSE_AI_OPTIMIZATION.md)  
>
> **Mục tiêu cốt lõi:** Biến EduPulse thành trợ lý học tập cá nhân tập trung cao độ vào vòng lặp:  
> **Kế hoạch (Plan) → Nhiệm vụ hôm nay (Today's Tasks) → Bắt đầu học (Start Study) → Phiên học tập trung (Study Mode) → Hoàn thành & Đánh giá (Complete & Review) → Cập nhật tiến độ & Tinh chỉnh AI (Progress & AI Adjustment).**  
>
> **Hướng dẫn sử dụng:** Khi hoàn thành bất kỳ hạng mục nào, đánh dấu `[x]` vào ô checkbox tương ứng và cập nhật bảng tổng kết tiến độ (Progress Dashboard) ở phần 1.

---

## 1. Bảng Tổng Kết Tiến Độ (Progress Dashboard)

| Giai đoạn / Sprint | Trọng tâm | Số tasks | Hoàn thành | Tỉ lệ (%) | Trạng thái |
|---|---|:---:|:---:|:---:|:---:|
| **Sprint 0** | Nền tảng, Tokens, Shared UI & Data Audit | 7 | 7 | 100% | ✅ Hoàn thành |
| **Sprint 1** | Điều hướng mới (4 tabs) + Màn hình Hôm nay (Today) | 8 | 8 | 100% | ✅ Hoàn thành |
| **Sprint 2** | Quản lý Nhiệm vụ (Single Source of Truth) | 10 | 10 | 100% | ✅ Hoàn thành |
| **Sprint 3** | Chế độ Học tập trung (Study Mode) + Phiên học | 7 | 7 | 100% | ✅ Hoàn thành |
| **Sprint 4** | Trợ lý AI Ngữ cảnh (Context Engine & Actions) | 9 | 9 | 100% | ✅ Hoàn thành |
| **Sprint 5** | Tiến độ (Progress) & Quản lý Kỳ thi (Exam) | 7 | 7 | 100% | ✅ Hoàn thành |
| **Sprint 6** | Giao diện đa thiết bị (Responsive) & Tinh chỉnh thẩm mỹ | 7 | 7 | 100% | ✅ Hoàn thành |
| **Sprint 7** | QA, E2E Scenarios & Release Gates | 6 | 6 | 100% | ✅ Hoàn thành |
| **Sprint 8** | Đối chiếu đặc tả (Spec Conformance) — sửa 10 điểm lệch | 3 | 3 | 100% | ✅ Hoàn thành |
| **Tổng cộng** | **Toàn bộ lộ trình EduPulse v2** | **64** | **64** | **100%** | ✅ Hoàn thành |

> **MVP Boundary (Ưu tiên số 1):** Hoàn thành xong **Sprint 0 + Sprint 1 + Sprint 2 + Sprint 3** là đã có thể chạy thông luồng học tập cốt lõi (Tạo task → Thấy ở Hôm nay → Bắt đầu học → Bấm giờ tập trung → Hoàn thành → Ghi nhận).

---

## 2. Sprint 0 — Nền Tảng & Rà Soát Hiện Trạng (Foundation & Audit)

> **Mục tiêu:** Thiết lập baseline an toàn, xây dựng design tokens và component dùng chung trước khi đụng vào code UI màn hình.

- [x] **FE-0.1: Rà soát và phân loại màn hình hiện tại** `[P0] [FE]`
  - [x] Liệt kê toàn bộ routes/screens hiện có trong codebase (`lib/features/...`).
  - [x] Lập bản đồ điều hướng cũ chuyển tiếp sang 4 tab mới (`Hôm nay`, `AI`, `Tiến độ`, `Tôi`).
  - [x] Định danh các widget/component tái sử dụng được.
  - [x] Định danh các thành phần gamification cần ẩn khỏi luồng chính (XP, Level, Streak counter, Mascot EXP, Bùa, Bốc quẻ).
  - [x] Rà soát layout mobile và desktop/web hiện tại.
  - *Done when:* Có danh sách mapping rõ ràng từng screen cũ sang cấu trúc mới, không sót màn hình quan trọng (Báo cáo tại [`AUDIT_HIEN_TRANG_V2.md`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/c%E1%BA%A3i%20t%E1%BB%95%20edupulse%20v2/AUDIT_HIEN_TRANG_V2.md)).

- [x] **FE-0.2: Xây dựng hệ thống Design Tokens dùng chung** `[P0] [FE]`
  - [x] Chuẩn hóa bộ semantic colors trong `AppColors` (chế độ sáng/tương phản cao).
  - [x] Chuẩn hóa Typography tokens (Headings, Body, Captions, Numeric/Timer font).
  - [x] Chuẩn hóa Spacing (4, 8, 12, 16, 24, 32px), Radius (8, 12, 16, 20px), Elevation.
  - [x] Chuẩn hóa kích thước Touch targets (tối thiểu 44-48px cho mobile).
  - *Done when:* Mọi màn hình mới sử dụng tokens chung, không hardcode giá trị tùy tiện (Triển khai tại [`app_tokens.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/core/constants/app_tokens.dart)).

- [x] **FE-0.3: Tạo các Shared UI Primitives (Component cốt lõi)** `[P0] [FE]`
  - [x] `PrimaryButton` (CTA màu chủ đạo, nổi bật nhất tại [`primary_button.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/shared/widgets/primary_button.dart)).
  - [x] `SecondaryButton` / `IconButton` (Nút phụ chuẩn WCAG tại [`primary_button.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/shared/widgets/primary_button.dart)).
  - [x] `SectionHeader` (Tiêu đề nhóm tinh tế tại [`section_header.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/shared/widgets/section_header.dart)).
  - [x] `EmptyState`, `ErrorState`, `LoadingState` (Đồng bộ tại [`state_views.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/shared/widgets/state_views.dart)).
  - [x] `ConfirmationDialog` / `ActionBottomSheet` (Hộp thoại xác nhận tại [`confirmation_dialog.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/shared/widgets/confirmation_dialog.dart)).
  - *Done when:* Bộ UI Primitives hoàn thiện trong `lib/shared/widgets`, sẵn sàng cho Sprint 1 & 2.

- [x] **BE-0.1: Rà soát & chuẩn hóa Data Model** `[P0] [BE]`
  - [x] Rà soát models: Tasks, Study Sessions, Exams, Subjects, Progress.
  - [x] Rà soát cơ chế lưu offline (SharedPreferences / Hive / SQLite) và đồng bộ Supabase.
  - [x] Xác định các trường gamification hiện tại để đảm bảo backward-compatible không làm crash dữ liệu cũ.
  - *Done when:* Schema dữ liệu được chuẩn hóa, rủi ro migration bằng 0, ID task/session được bảo toàn.

- [x] **BE-0.2: Định nghĩa Task là "Single Source of Truth"** `[P0] [BE]`
  - [x] Thống nhất Task tạo thủ công và Task do AI gợi ý/tạo lập đều dùng chung một Model `TodayTask`.
  - [x] Study Session tham chiếu trực tiếp đến `taskId`.
  - [x] Trạng thái hoàn thành chỉ được quản lý ở 1 nơi duy nhất.
  - *Done when:* Không còn entity nhiệm vụ riêng biệt giữa AI và ứng dụng, tránh xung đột dữ liệu.

- [x] **AI-0.1: Định nghĩa Hợp đồng Hành động AI (AI Action Contract)** `[P0] [AI]`
  - [x] Xây dựng JSON schema cho các action: `recommend`, `create_task`, `edit_task`, `delete_task`, `reschedule_task`, `split_task`, `create_plan`, `explain`.
  - [x] Thiết lập quy tắc: AI không tự ý âm thầm xóa hoặc sửa đổi lịch của người dùng.
  - [x] Quy định các hành động phá hủy (destructive actions) bắt buộc phải có bước xác nhận (confirmation).
  - *Done when:* Toàn bộ I/O schema của AI được định nghĩa rõ trong code bằng Dart models.

- [x] **QA-0.1: Bộ kiểm thử hồi quy cơ bản (Baseline Regression Suite)** `[P0] [QA]`
  - [x] Checklist test đăng nhập / auth.
  - [x] Checklist test CRUD task hiện tại, tính năng offline, sync Supabase.
  - [x] Chạy `flutter test` đảm bảo toàn bộ tests hiện tại vượt qua trước khi bắt đầu cải tổ (Đạt 188/188 tests pass).
  - *Done when:* 100% tests hiện tại pass, không có lỗi tiềm ẩn trước Sprint 1.

---

## 3. Sprint 1 — Điều Hướng Mới & Màn Hình "Hôm Nay" (Navigation + Today)

> **Mục tiêu:** Đưa "Hôm nay" (Today's Tasks) thành trung tâm của sản phẩm, giúp học sinh mở app là biết ngay cần học gì.

- [x] **FE-1.1: Triển khai Cấu trúc Điều hướng Mới (Primary Navigation)** `[P0] [FE]`
  - [x] Bottom Navigation cho Mobile với đúng 4 tab: `Hôm nay` | `AI` | `Tiến độ` | `Tôi`.
  - [x] Left Sidebar cho Desktop/Web: hiển thị 4 mục chính và khu vực kỳ thi phụ trợ.
  - [x] Xử lý active state trực quan, bảo toàn tab state khi chuyển đổi, hỗ trợ deep link / refresh web (Phím tắt Ctrl+1..4).
  - *Done when:* Điều hướng mượt mà trên cả mobile và desktop, không reload vô lý.

- [x] **FE-1.2: Tái thiết kế Màn hình "Hôm Nay" (Rebuild Today Screen)** `[P0] [FE]`
  - [x] Section 1: Lời chào ngắn gọn & ngữ cảnh kỳ thi ("Còn X ngày thi THPTQG").
  - [x] Section 2: Tóm tắt tiến độ ngày (Ví dụ: `2/5 nhiệm vụ · 1h20m học`).
  - [x] Section 3: Danh sách nhiệm vụ hôm nay (Today's Tasks) - Hiển thị ngay trên màn hình đầu tiên không cần cuộn nhiều.
  - [x] Section 4: Nút "Bắt đầu học" (Start Study) trực quan, nổi bật nhất trên Task đầu tiên (`TodayMissionCard`).
  - [x] Section 5: Gợi ý nhanh từ AI (Daily recommendation) gọn gàng bên dưới hoặc theo card.
  - [x] Ẩn các khối gây xao nhãng (XP, level, streak khổng lồ, mascot chiếm spotlight).
  - *Done when:* Nhiệm vụ quan trọng nhất nhìn thấy ngay lập tức khi mở app.

- [x] **FE-1.3: Thuật toán sắp xếp Task trên màn hình Hôm nay** `[P0] [FE]`
  - [x] Ưu tiên 1: Task đang học dở (in-progress/active session).
  - [x] Ưu tiên 2: Task quá hạn (overdue) hoặc mức ưu tiên cao (high priority).
  - [x] Ưu tiên 3: Task theo lịch trong ngày.
  - [x] Phân tách trực quan giữa task chưa làm và task đã hoàn thành (completed tasks xếp xuống cuối).
  - *Done when:* Học sinh luôn thấy việc cần giải quyết nhất ở vị trí đầu tiên.

- [x] **FE-1.4: Widget Tổng kết trong ngày (Daily Summary Widget)** `[P1] [FE]`
  - [x] Hiển thị tỉ lệ hoàn thành nhiệm vụ (`x/y nhiệm vụ`) và thời lượng thực tế (`Xh Ym`).
  - [x] Cập nhật tức thời (reactive) ngay khi task hoàn thành hoặc kết thúc session học.
  - [x] Hoạt động trơn tru ngay cả khi offline (sử dụng TodayService + Local Storage).
  - *Done when:* Số liệu phản ánh tức thì, không cần tải lại trang.

- [x] **BE-1.1: Xây dựng Service/Query dữ liệu Hôm nay** `[P0] [BE]`
  - [x] Cung cấp API/Service lấy danh sách task hôm nay, trạng thái, thời gian đã học, active session (`TodayService`).
  - [x] Hỗ trợ local cache, tải tức thời khi mở ứng dụng (< 200ms).
  - *Done when:* Màn hình Hôm nay nạp đủ dữ liệu từ một stream/provider nhất quán.

- [x] **BE-1.2: Logic tổng hợp số liệu trong ngày (Daily Aggregation)** `[P1] [BE]`
  - [x] Tính toán tự động: tổng task, task hoàn thành, số phút đã học thực tế từ session logs (`DailySummary`).
  - [x] Tránh tính toán thủ công phân mảnh ở nhiều nơi.
  - *Done when:* Số liệu đồng nhất tuyệt đối giữa dashboard và database.

- [x] **AI-1.1: Gợi ý nhiệm vụ hôm nay từ AI (Daily Recommendation)** `[P1] [AI]`
  - [x] Đầu vào: Danh sách task hôm nay, deadline gần nhất, thời gian rảnh của học sinh.
  - [x] Đầu ra: Gợi ý 1 task nên học trước kèm lý do ngắn gọn (1-2 câu).
  - [x] Không tự bịa ra task mới khi chưa có yêu cầu.
  - *Done when:* Gợi ý hữu ích, nhấp vào là có thể bắt đầu học ngay.

- [x] **QA-1.1: Kiểm thử Màn hình Hôm nay & Điều hướng** `[P0] [QA]`
  - [x] Test chuyển tab trên mobile & desktop.
  - [x] Test hiển thị màn hình rỗng (khi chưa có task nào).
  - [x] Test khi có nhiều task, sắp xếp đúng thứ tự ưu tiên.
  - [x] Test cập nhật tiến độ khi tick hoàn thành task.
  - *Done when:* Tất cả kịch bản Sprint 1 đều pass (188/188 tests pass, 0 flutter analyze warning).

---

## 4. Sprint 2 — Quản Lý Nhiệm Vụ Toàn Diện (Task Management)

> **Mục tiêu:** Biến Tasks thành "Single Source of Truth" với đầy đủ thao tác: Tạo, Sửa, Xóa an toàn, Hoàn thành, Dời lịch (Reschedule).

- [x] **FE-2.1: Hoàn thiện Component TaskCard** `[P0] [FE]`
  - [x] Trình bày: Checkbox hoàn thành, tên bài học, môn học, chủ đề, thời lượng dự kiến, deadline.
  - [x] Hành động chính: Nút "Bắt đầu học" (Start) nổi bật.
  - [x] Hành động phụ (menu/action sheet): Sửa, Dời lịch (Reschedule), Chia nhỏ, Xóa.
  - [x] Màu/icon môn học lấy từ `AppSubjects`; cảnh báo "Dời N lần" khi bị dời ≥ 3 lần.
  - [x] Nhãn accessibility tách rõ: chạm hàng = mở chi tiết, chạm vòng tròn = đánh dấu hoàn thành.
  - *Done when:* Card trực quan, dễ hiểu, không cần mở chi tiết vẫn biết rõ cần làm gì.

- [x] **FE-2.2: Màn hình Chi tiết Nhiệm vụ (Task Detail Screen/Sheet)** `[P0] [FE]`
  - [x] Tài liệu kèm theo (ảnh ≤250KB, tối đa 3/nhiệm vụ, có Undo) + lịch sử các phiên học liên quan — làm ở Sprint 3 vì cần schema `StudySession` gắn task.
  - [x] Ghi chú — có, hiển thị khi có nội dung.
  - [x] Nút CTA chính: "Bắt đầu phiên học ngay".
  - [x] Tích hợp nút trợ giúp AI theo ngữ cảnh: "Hỏi AI về bài này", "Chia nhỏ bài học" (chia nhỏ chạy thật, không phụ thuộc AI).
  - [x] Đánh dấu hoàn thành ngay trong màn chi tiết, ghi qua repository.
  - *Done when:* Trải nghiệm liền mạch, điều hướng quay lại không làm mất ngữ cảnh.

- [x] **FE-2.3: Giao diện Tạo & Chỉnh sửa Nhiệm vụ (Create/Edit Task)** `[P0] [FE]`
  - [x] Form nhập liệu nhanh, thông minh: Tên task, Môn học, Thời lượng, Deadline, Mức độ ưu tiên.
  - [x] Validation rõ ràng, hiển thị lỗi inline.
  - [x] Chỉnh sửa bảo toàn nguyên vẹn ID và lịch sử session cũ.
  - *Done when:* Người dùng có thể tạo task chỉ trong vài giây.

- [x] **FE-2.4: Giao diện Dời lịch Thông minh (Reschedule UI)** `[P0] [FE]`
  - [x] Lựa chọn nhanh: Chuyển sang ngày mai, Chuyển sang cuối tuần, Chọn ngày cụ thể (thêm "Hôm nay").
  - [x] Cảnh báo nhẹ nhàng nếu một task bị dời ≥ 3 lần và gợi ý chia nhỏ task.
  - [x] Thao tác dời lịch cập nhật ngày của task hiện tại, KHÔNG tạo duplicate task.
  - [x] Cảnh báo khi chọn ngày vượt hạn chót.
  - *Done when:* Lịch học phản ánh đúng thực tế mà không sinh rác dữ liệu.

- [x] **FE-2.5: Hộp thoại xác nhận Xóa Nhiệm vụ (Delete Confirmation)** `[P0] [FE]`
  - [x] Xác nhận rõ ràng, nêu đích danh tên nhiệm vụ cần xóa.
  - [x] Hỗ trợ nút Hoàn tác (Undo) qua SnackBar trong 5 giây nếu lỡ tay bấm nhầm.
  - [x] Bỏ hẳn đường xóa tắt (`Dismissible` trong danh sách).
  - *Done when:* Không bao giờ có tình trạng xóa nhầm nhiệm vụ ngoài ý muốn.

- [x] **BE-2.1: Hoàn thiện Task Repository & CRUD Service** `[P0] [BE]`
  - [x] Hỗ trợ đầy đủ Create, Read, Update, Delete, Reschedule, Complete.
  - [x] Đảm bảo cơ chế offline-first: lưu vào local trước, sync Supabase sau khi có mạng.
  - [x] Giữ nguyên UUID và timestamp chuẩn ISO.
  - *Done when:* Mọi thao tác task đều nhất quán khi online lẫn offline.

- [x] **BE-2.2: Xây dựng Task State Machine** `[P0] [BE]`
  - [x] Quản lý chặt chẽ các trạng thái: `scheduled`, `started`, `completed`, `not_completed`, `rescheduled`.
  - [x] Chặn các bước chuyển trạng thái không hợp lệ.
  - *Done when:* Trạng thái nhiệm vụ luôn minh bạch, chính xác.

- [x] **BE-2.3: Tương thích Migration dữ liệu cũ** `[P1] [BE]`
  - [x] Kiểm tra các task đã tạo ở phiên bản trước, map đúng vào cấu trúc dữ liệu mới.
  - [x] Không làm biến mất bất kỳ task nào của người dùng hiện tại.
  - *Done when:* Dữ liệu người dùng cũ hiển thị trọn vẹn trong UI v2.

- [x] **AI-2.1: Tích hợp Hành động AI với Task Service (AI Task Actions)** `[P0] [AI]`
  - [x] AI có thể tạo task thông qua câu lệnh tự nhiên (ví dụ: "Tạo task ôn hàm số 45 phút chiều mai").
  - [x] AI có thể dời lịch, sửa hoặc xóa task (bắt buộc xác nhận trước khi thực thi xóa).
  - [x] AI sử dụng cùng 1 Task Service với người dùng, ngăn ngừa duplicate task.
  - [x] AI tự chuẩn hoá môn học trước khi ghi (tránh sinh môn mới song song với môn cũ).
  - *Done when:* Thao tác bằng ngôn ngữ tự nhiên ra kết quả task chuẩn xác.

- [x] **QA-2.1: Bộ test kiểm thử Task CRUD** `[P0] [QA]`
  - [x] Kiểm thử tạo, sửa, xóa, hoàn tác, dời lịch, hoàn thành.
  - [x] Kiểm thử tính bền vững khi tắt mở lại app, ngắt kết nối mạng.
  - [x] Thêm `test/task_repository_test.dart` (50 test) + `test/subject_catalog_test.dart` (39 test).
  - [x] Bắt được 1 lỗi thật: bước `recover_orphan_tasks` quét sai tiền tố khoá (`today_task_` thay vì `task_`) nên cứu task mồ côi không bao giờ chạy.
  - *Done when:* 100% test cases cho Task vượt qua — `flutter test` 278/278, `flutter analyze` sạch.

---

## 5. Sprint 3 — Chế Độ Học Tập Trung & Ghi Nhận Phiên Học (Study Mode & Session)

> **Mục tiêu:** Rút ngắn tối đa khoảng cách từ "Tôi nên học" đến "Tôi đang học thực sự", tạo môi trường học không xao nhãng.

- [x] **FE-3.1: Màn hình Chế độ Học tập trung (Distraction-Free Study Mode)** `[P0] [FE]`
  - [x] Thiết kế tối giản: Chỉ hiển thị tên nhiệm vụ, môn học, đồng hồ đếm giờ (Timer).
  - [x] Ẩn toàn bộ thanh điều hướng (Bottom Nav / Sidebar), ẩn điểm XP, level, mascot nhảy nhót.
  - [x] Các nút điều khiển rõ ràng: Tạm dừng (Pause), Tiếp tục (Resume), Hoàn thành phiên (Complete).
  - *Done when:* Màn hình tập trung tuyệt đối, học sinh không bị phân tâm bởi bất cứ thứ gì khác.

- [x] **FE-3.2: Bộ đếm thời gian an toàn (Timer Engine & State Recovery)** `[P0] [FE]`
  - [x] Hỗ trợ đếm ngược (Pomodoro) và đếm xuôi (Stopwatch).
  - [x] Hoạt động ngầm chính xác: thay `Timer.periodic` **trừ 1/giây** bằng `FocusClock` neo theo
    `DateTime.now()`; timer chỉ còn đẩy giao diện, mỗi lần hỏi đều tính lại từ mốc.
    Khi app quay lại (`resumed`) gọi `_syncClockToUi()` để đồng hồ nhảy thẳng về đúng số.
  - [x] Tạm dừng/tiếp tục giữ đúng số đã học (trước đây xoá `_pomStartedAt` khi pause).
  - [x] *Done when:* Không bao giờ bị mất thời gian học của học sinh do tai nạn phần mềm.
    → **BE-3.2 đã xong** (khôi phục phiên sau khi bị kill app), xem mục kế tiếp.

- [x] **FE-3.3: Màn hình Hoàn thành Phiên học & Đánh giá nhanh (Session Completion)** `[P0] [FE]`
  - [x] Thông báo chúc mừng ngắn gọn kèm số phút đã học thực tế.
  - [x] Đánh giá cảm xúc/mức độ tiếp thu nhanh chỉ với 1 chạm (5 emoji: 😫 😐 🙂 😄 🔥).
  - [x] Nút hoàn thành task và trở về màn hình Hôm nay để tiếp tục việc kế tiếp.
  - *Done when:* Thao tác kết thúc phiên học chỉ mất dưới 3 giây.

- [x] **BE-3.1: Lưu trữ Phiên học (Study Session Persistence)** `[P0] [BE]`
  - [x] Lưu đầy đủ: `taskId`, `startTime`, `endTime`, `actualDurationMinutes`, `status`, `feedbackRating`.
    → `StudySession` có `startedAt`/`endedAt` (đều nullable nên phiên cũ không cần migration),
    `status` = `completed`/`cancelled`, `actualMinutes` đã có sẵn. `feedbackRating` là **getter tính ra**
    từ 5 thang đánh giá chi tiết — không lưu thêm để tránh hai nguồn sự thật cùng một câu hỏi.
  - [x] Tự động cập nhật tổng thời gian học của môn học và của ngày hôm đó.
    → `StudySessionRepository.minutesOn(day)` + `minutesForSubject(subject, {day})` **tính ra** từ danh sách
    phiên (không lưu tổng riêng để tránh trôi lệch khi xoá/sửa phiên); so khớp môn dùng `AppSubjects.normalize`.
  - [x] Ghi `startedAt` từ mốc `_pomStartedAt` thật lúc bấm bắt đầu, không ước lượng từ `completedAt`.
  - [x] `today_service.getTodayStudyMinutes()` dùng chung `minutesOn()` — một đường tính duy nhất.
  - *Done when:* Lịch sử phiên học được ghi nhận chính xác vào cơ sở dữ liệu.
  - [x] **Bỏ ghi trùng `_addLog()` ở vòng pomodoro** (đã chốt với người dùng):
    `StudyLog` chỉ còn là ghi chép **nhập tay**; pomodoro chỉ ghi `StudySession`.
    Mọi nơi tổng hợp (tab Nhật ký, `WeeklyChartWidget`, `summarizeWeek()`, AI context)
    chuyển sang `StudyTimelineEntry`/`buildStudyTimeline()` để gộp hai nguồn mà
    không bỏ sót thời gian học thật. Xoá một dòng nhật ký sẽ xoá **đúng bảng gốc**
    của nó (session qua repository, log nhập tay qua `StorageService`).
    Dữ liệu pomodoro **cũ** vẫn được migration v3 dọn về một nguồn duy nhất:
    các `StudyLog` trùng vòng pomodoro thật (`Phiên N` khớp session hoặc lệch vài giờ/phút)
    bị xoá; log nhập tay khác vẫn giữ nguyên.

- [x] **BE-3.2: Cơ chế khôi phục phiên học đang dở (Active Session Recovery)** `[P0] [BE]`
  - [x] Lưu trạng thái phiên đang chạy vào local storage
    (`active_study_session`, qua `StudySessionRepository.saveActive`).
  - [x] Khi người dùng mở lại app, tự động phát hiện phiên đang chạy và hỏi tiếp tục
    hay kết thúc. Chọn **Tiếp tục** → nối lại đồng hồ từ đúng số giây còn lại;
    chọn **Kết thúc phiên** → ghi phần đã học thành phiên `status: cancelled`.
  - [x] Không hỏi linh tinh: vòng mới mở màn hình, vòng học < 1 phút, vòng đã hết
    giờ, hoặc quá 6 giờ — đều tự dọn ảnh chụp.
    → Đồng thời `autoStart` (mở bằng nút "học ngay") **không còn bỏ qua** câu hỏi
    khôi phục: trước đây nó ghi đè ảnh chụp và mất thời gian đã học của phiên cũ.
  - *Done when:* Không để sót phiên học "mồ côi" làm sai lệch dữ liệu.
    → Ảnh chụp được xoá khi vòng kết thúc/reset/đổi chế độ và khi rời màn khi
    vòng đã dừng, nên không bao giờ hỏi về một phiên đã xong.

- [x] **BE-3.3: Tổng hợp Thời gian học theo thời gian thực (Real-time Study Aggregation)** `[P1] [BE]`
  - [x] Cập nhật widget tổng thời gian học ngay khi phiên học kết thúc (`StudySessionRepository.revision`).
  - *Done when:* Số phút học đồng bộ ngay lập tức trên dashboard.

- [x] **QA-3.1: Ma trận kiểm thử Chế độ Học** `[P0] [QA]`
  - [x] Test đếm giờ, tạm dừng, tiếp tục, hoàn thành sớm, hết giờ.
  - [x] Test đưa app xuống nền (background), tắt màn hình, refresh trình duyệt web.
  - [x] Test offline khi đang học và sau đó kết nối mạng lại để đồng bộ.
  - *Done when:* Tất cả các kịch bản ngoại lệ đều bảo toàn dữ liệu phiên học.
    14/14 test QA chế độ học override, snapshot không mất, `_recordCompletedFocus`
    giữ thông tin thật, migration v3 pass.

---

## 6. Sprint 4 — Trợ Lý AI Ngữ Cảnh & Hành Động (AI Assistant)

> **Mục tiêu:** Biến AI từ một chatbot trò chuyện thông thường thành một gia sư kèm cặp gắn liền với từng tác vụ học tập cụ thể.

- [x] **AI-4.1: Xây dựng AI Context Engine (Bộ xử lý ngữ cảnh đa cấp độ)** `[P0] [AI]`
  - [x] Cấp độ 0 (No context): Kiến thức phổ thông.
  - [x] Cấp độ 1 (Task context): Tên bài, môn, ghi chú khi học sinh bấm "Hỏi AI về bài này".
  - [x] Cấp độ 2 (Today context): Danh sách task hôm nay, thời gian rảnh, task quá hạn.
  - [x] Cấp độ 3 (Learning Profile): Hiệu quả học tập các môn, điểm khó, lịch sử đánh giá cảm xúc.
  - [x] Cấp độ 4 (Full Planning): Thông tin kỳ thi, mục tiêu điểm số, toàn bộ khối lượng công việc.
  - [x] Nén context (Context compression): Không gửi raw database, chỉ gửi tóm tắt tối thiểu cần thiết.
  - *Done when:* AI luôn trả lời đúng ngữ cảnh của học sinh mà không cần học sinh phải gõ lại từ đầu.
    → `AiContextLevel` (none/task/today/learningProfile/full) + `AiStudyContext.buildFor(level)` với giới hạn ký tự riêng từng cấp; `AiRouter.chat` nhận `contextLevel`/`contextTask`.

- [x] **AI-4.2: Tính năng Gợi ý "Tôi nên học gì bây giờ?" (Daily Coach)** `[P0] [AI]`
  - [x] Phân tích tức thời dựa trên thời gian hiện tại, deadline và độ ưu tiên.
  - [x] Trả về 1 khuyến nghị rõ ràng + 1 nút hành động trực tiếp [Bắt đầu task X].
  - *Done when:* Học sinh không bao giờ phải rơi vào trạng thái phân vân không biết làm gì.
    → Quick Action "Tôi nên học gì?" dùng `AiCopilotService.buildSituationReport()` (cục bộ, chạy cả khi offline) đẩy thẳng khuyến nghị + nút hành động vào hội thoại.

- [x] **AI-4.3: Tính năng Giải thích Bài học theo ngữ cảnh (Explain Contextual)** `[P0] [AI]`
  - [x] Mở từ màn hình Task hoặc Study Mode.
  - [x] Giải thích trọng tâm kiến thức của bài học hiện tại, hỗ trợ đặt câu hỏi đào sâu.
  - *Done when:* Cung cấp câu trả lời súc tích, dễ hiểu, bám sát môn học.
    → Nút "Hỏi AI" trong `StudyPage` (chế độ học tập trung) + Quick Action "Giải thích bài này" gửi kèm ngữ cảnh cấp 1 của bài đang chọn.

- [x] **AI-4.4: Tính năng Lập Kế hoạch Ôn tập Thông minh (AI Study Planner)** `[P0] [AI]`
  - [x] Tiếp nhận mục tiêu: Ngày thi, mục tiêu điểm, thời gian học mỗi ngày.
  - [x] Tạo danh sách task cân bằng, không nhồi nhét quá tải.
  - [x] **Bắt buộc có bước Preview**: Học sinh xem trước kế hoạch, chỉnh sửa rồi mới bấm [Áp dụng].
  - [x] Khi áp dụng, tự động tạo thành các Tasks chuẩn trong hệ thống.
  - *Done when:* Kế hoạch biến thành các nhiệm vụ cụ thể, không ghi đè dữ liệu cũ bừa bãi.
    → `AiStudyPlannerService` (sinh + parse + apply) và `AiPlanPreviewSheet` (tick/bỏ từng task trước khi áp dụng); sửa lỗi compile cũ và đổi tên model thành `AiPlannedTask` tránh trùng `features/study/domain/ai_plan.dart`.

- [x] **AI-4.5: Phân tích Điểm yếu Học tập (Weakness Analyzer)** `[P1] [AI]`
  - [x] Dựa vào đánh giá cảm xúc sau phiên học, tần suất dời task, môn học ít dành thời gian.
  - [x] Chỉ kết luận khi có đủ dữ liệu (tối thiểu 3-5 phiên học); nếu chưa đủ thì thông báo trung thực "Chưa đủ dữ liệu".
  - *Done when:* Nhận xét khách quan, gợi ý hành động khắc phục cụ thể.
    → `WeaknessAnalyzer` đọc điểm thi thử, thời gian học 14 ngày, số lần dời lịch và cảm xúc phiên; nối vào Quick Action "Phân tích điểm yếu"; dưới 3 phiên thì trả `WeaknessReport.insufficient()`.

- [x] **AI-4.6: Hệ thống Xác nhận Hành động An toàn (Action Confirmation System)** `[P0] [AI]`
  - [x] Bắt buộc hiển thị modal xác nhận trước khi: Xóa task, dời lịch hàng loạt, thay đổi kế hoạch ôn thi.
  - [x] Xử lý tính lũy thừa (Idempotency): Mỗi action có `action_id`, tránh gửi lặp nhiều lần tạo duplicate tasks.
  - *Done when:* AI an toàn tuyệt đối, không phá hỏng dữ liệu của người dùng.
    → Xóa task luôn qua `showConfirmDelete`; áp dụng kế hoạch phải qua `AiPlanPreviewSheet`; mỗi `AiPlannedTask` dùng id riêng làm khoá idempotency, `createTaskIfMissing` chặn trùng khi áp dụng lại.

- [x] **AI-4.7: Xử lý Lỗi & Dự phòng Ngoại tuyến (AI Fallback & Offline Handling)** `[P0] [AI]`
  - [x] Khi mất mạng hoặc API lỗi: Hiển thị thông báo thân thiện "AI tạm thời không khả dụng, bạn vẫn có thể tự học bình thường".
  - [x] Tuyệt đối không bao giờ để lỗi AI làm treo app hoặc chặn học sinh học bài.
  - *Done when:* Trải nghiệm ứng dụng luôn vững chắc dù AI có phản hồi chậm hay đứt mạng.
    → Lập kế hoạch/chat khi offline hiện thông báo thân thiện; Weakness Analyzer và Daily Coach chạy cục bộ nên luôn khả dụng.

- [x] **FE-4.1: Tái thiết kế Giao diện Trợ lý AI (AI Screen Redesign)** `[P0] [FE]`
  - [x] Không để màn hình chat trống trơn nhàm chán; hiển thị các Quick Actions:
    - [Tôi nên học gì?]
    - [Giải thích bài này]
    - [Lập kế hoạch]
    - [Phân tích điểm yếu]
  - [x] Card Action Preview trực quan khi AI đề xuất tạo/sửa task.
  - [x] Tích hợp nút Đánh giá phản hồi 👍/👎 cho từng câu trả lời của AI.
  - *Done when:* Màn hình AI sinh động, định hướng người dùng vào hành động thực tế.
    → Lưới `_AiQuickActions` 4 nút ở trạng thái Empty AI; preview kế hoạch qua `AiPlanPreviewSheet`; 👍/👎 đã có sẵn trong `ChatBubble`.

- [x] **QA-4.1: Bộ kiểm thử Trợ lý AI** `[P0] [QA]`
  - [x] Test gợi ý task, tạo task qua ngôn ngữ tự nhiên.
  - [x] Test xác nhận trước khi xóa/sửa task.
  - [x] Test xử lý khi timeout, mất mạng, phản hồi JSON lỗi.
  - *Done when:* Toàn bộ luồng tương tác AI an toàn và ổn định.
    → Thêm `test/ai_sprint4_test.dart` (12 test): context levels, WeaknessAnalyzer thiếu/đủ dữ liệu, parsePlan (JSON lỗi, thiếu title, kẹp giá trị) và applyPlan idempotent. `flutter test` 415/415, `flutter analyze` sạch.

---

## 7. Sprint 5 — Theo Dõi Tiến Độ & Quản Lý Kỳ Thi (Progress & Exam)

> **Mục tiêu:** Cung cấp bức tranh phản ánh năng lực thực tế và mục tiêu kỳ thi rõ ràng mà không biến app thành bảng dashboard số liệu khô khan.

- [x] **FE-5.1: Màn hình Tổng quan Tiến độ (Progress Overview Screen)** `[P0] [FE]`
  - [x] Hiển thị hoàn thành hôm nay, thời gian học hôm nay.
  - [x] Xu hướng tuần: Tổng thời lượng học, tỉ lệ hoàn thành nhiệm vụ theo tuần.
  - [x] Biểu đồ trực quan, tối giản, dễ nắm bắt chỉ trong 5 giây.
  - *Done when:* Học sinh hiểu rõ mình đang tiến bộ hay thụt lùi mà không bị ngợp số liệu.

- [x] **FE-5.2: Tiến độ chi tiết theo từng Môn học (Subject Progress)** `[P1] [FE]`
  - [x] Thời gian đã dành cho môn, số bài đã học, đánh giá mức độ hiểu bài trung bình.
  - [x] Cảnh báo môn học bị bỏ quên hoặc lệch so với mục tiêu ban đầu.
  - *Done when:* Giúp học sinh phân bổ lại thời gian học giữa các môn hợp lý hơn.

- [x] **FE-5.3: Màn hình Quản lý Kỳ thi (Exam Management Screen)** `[P0] [FE]`
  - [x] Kỳ thi chính nổi bật: Tên kỳ thi (VD: THPT Quốc Gia), ngày thi, đồng hồ đếm ngược số ngày.
  - [x] Danh sách các môn thi trong kỳ thi kèm điểm số mục tiêu.
  - [x] Hỗ trợ thêm/sửa/đổi ngày thi dễ dàng.
  - *Done when:* Mục tiêu kỳ thi luôn hiện diện rõ ràng làm kim chỉ nam cho việc học.

- [x] **BE-5.1: Bộ tính toán Dữ liệu Tiến độ (Progress Aggregation Engine)** `[P0] [BE]`
  - [x] Aggregation theo ngày, tuần, tháng, môn học và kỳ thi.
  - [x] Xử lý đúng múi giờ và mốc thời gian bắt đầu ngày/tuần.
  - *Done when:* Kết quả phân tích số liệu chuẩn xác 100% so với log phiên học thực tế.

- [x] **BE-5.2: Quản lý Dữ liệu Kỳ thi (Exam Data Service)** `[P0] [BE]`
  - [x] CRUD kỳ thi, chỉ định Kỳ thi chính (Primary Exam).
  - [x] Tự động tính toán số ngày còn lại theo thời gian thực.
  - *Done when:* Dữ liệu kỳ thi lưu trữ an toàn, đồng bộ Supabase.

- [x] **AI-5.1: Phân tích & Nhận định Tiến độ từ AI (Progress Insights)** `[P1] [AI]`
  - [x] Đưa ra nhận xét khách quan dựa trên số liệu thật (Ví dụ: "Tuần này bạn học Toán rất đều, nhưng môn Lý đang bị trễ 2 buổi so với kế hoạch").
  - [x] Đề xuất hành động điều chỉnh cụ thể.
  - *Done when:* Nhận định hữu ích, kích thích hành động cải thiện.

- [x] **QA-5.1: Bộ kiểm thử Tiến độ & Kỳ thi** `[P0] [QA]`
  - [x] Test tính toán số liệu tuần, chuyển giao giữa các tuần.
  - [x] Test đếm ngược ngày thi, thay đổi ngày thi.
  - *Done when:* Kiểm thử số liệu và logic ngày tháng chính xác tuyệt đối.

---

## 8. Sprint 6 — Tối Ưu Giao Diện Đa Thiết Bị & Thẩm Mỹ (Responsive & Polish)

> **Mục tiêu:** Mang lại trải nghiệm mượt mà, cao cấp trên điện thoại di động, máy tính bảng và màn hình máy tính lớn.

- [x] **FE-6.1: Tối ưu Giao diện Mobile (Mobile Polish)** `[P0] [FE]`
  - [x] Kiểm thử trên các kích thước: màn hình nhỏ, màn hình tiêu chuẩn, màn hình lớn.
  - [x] Không để xảy ra tràn viền ngang (overflow error).
  - [x] Touch targets thoải mái, bàn phím ảo không che khuất ô nhập liệu.
  - *Done when:* Trải nghiệm mượt mà như ứng dụng bản địa (native feel).

- [x] **FE-6.2: Tối ưu Giao diện Tablet (Tablet Adaptive Layout)** `[P1] [FE]`
  - [x] Bố cục thích ứng linh hoạt, tận dụng không gian rộng rãi thay vì phóng to giao diện điện thoại.
  - *Done when:* Giao diện trên máy tính bảng hiển thị khoa học và cân đối.

- [x] **FE-6.3: Tối ưu Giao diện Desktop / Web lớn (Desktop Layout)** `[P0] [FE]`
  - [x] Sidebar trái cố định hoặc thu gọn tiện lợi.
  - [x] Nội dung chính giới hạn độ rộng hợp lý (max-width), hỗ trợ cột phụ trợ (countdown, lịch nhanh).
  - *Done when:* Desktop chuyên nghiệp, tối ưu cho việc học tập bằng laptop/PC.

- [x] **FE-6.4: Tinh chỉnh Phân cấp Thị giác (Visual Hierarchy)** `[P0] [FE]`
  - [x] Áp dụng đúng thứ tự: **Hành động chính → Nhiệm vụ → Ngữ cảnh → Thông tin chi tiết → Trang trí**.
  - [x] Nút CTA luôn nổi bật nhất; loại bỏ hoặc thu nhỏ các chi tiết trang trí gây rối mắt.
  - *Done when:* Mọi màn hình đều có 1 điểm nhấn hành động rõ ràng.

- [x] **FE-6.5: Đồng bộ các Trạng thái Rỗng, Đang tải & Báo lỗi (States Polish)** `[P0] [FE]`
  - [x] Màn hình rỗng có hình minh họa nhẹ nhàng kèm nút hành động (VD: Chưa có task → Nút "Thêm nhiệm vụ ngay").
  - [x] Skeleton loaders cho cảm giác tải trang mượt mà.
  - [x] Thông báo lỗi lịch sự kèm nút thử lại.
  - *Done when:* Không còn màn hình trắng tinh hoặc thông báo lỗi kỹ thuật khó hiểu.

- [x] **FE-6.6: Hiệu ứng Chuyển động & Phản hồi Rung (Micro-interactions & Haptics)** `[P2] [FE]`
  - [x] Haptic feedback nhẹ nhàng khi tick hoàn thành nhiệm vụ và khi kết thúc đếm giờ.
  - [x] Hỗ trợ chế độ giảm chuyển động (`Reduced Motion`) cho học sinh nhạy cảm thị giác.
  - *Done when:* Ứng dụng sống động, đem lại cảm giác thành tựu khi hoàn thành bài học.

- [x] **QA-6.1: Ma trận Kiểm thử Responsive Toàn diện** `[P0] [QA]`
  - [x] Test trên Mobile (Android/iOS), Tablet, Desktop Web (Chrome, Edge, Safari).
  - *Done when:* Không còn lỗi vỡ layout trên bất kỳ thiết bị mục tiêu nào.

---

## 9. Sprint 7 — Ổn Định Toàn Diện, Kiểm Thử E2E & Release Gates (Stabilization)

> **Mục tiêu:** Kiểm thử toàn bộ các kịch bản người dùng thực tế và vượt qua các cổng kiểm soát chất lượng (Release Gates) trước khi đưa vào sản xuất.

- [x] **E2E-1: Kịch bản A — Tạo mới và Hoàn thành Nhiệm vụ** `[P0] [QA]`
  - [x] Tạo task mới → Xuất hiện ở Hôm nay → Bấm "Bắt đầu học" → Vào Chế độ học tập trung → Hoàn thành phiên → Đánh giá cảm xúc → Số liệu cập nhật vào Tiến độ.
  - *Pass criteria:* Không mất dữ liệu, thời gian học chuẩn, tiến độ tăng ngay.

- [x] **E2E-2: Kịch bản B — Lập Kế hoạch Ôn tập bằng AI** `[P0] [QA]`
  - [x] Yêu cầu AI lập kế hoạch → Xem bản xem trước (Preview) → Xác nhận [Áp dụng] → Các task tự động tạo trong Hôm nay → Bắt đầu học bình thường.
  - *Pass criteria:* Không tạo duplicate task, task tạo bởi AI hoạt động y như task thủ công.

- [x] **E2E-3: Kịch bản C — Dời lịch Nhiệm vụ (Reschedule Flow)** `[P0] [QA]`
  - [x] Nhiệm vụ hôm nay chưa xong → Chọn dời sang ngày mai → Biến mất khỏi Hôm nay, xuất hiện ở ngày mai.
  - *Pass criteria:* ID task giữ nguyên, lịch sử không bị đứt đoạn.

- [x] **E2E-4: Kịch bản D — Học Ngoại tuyến và Đồng bộ lại (Offline-to-Online Flow)** `[P0] [QA]`
  - [x] Ngắt mạng hoàn toàn → Mở app xem task → Học 25 phút trong Chế độ học → Hoàn thành phiên → Bật lại mạng → Dữ liệu tự động sync lên Supabase.
  - *Pass criteria:* Toàn bộ dữ liệu phiên học ngoại tuyến được bảo toàn, không bị ghi đè hay mất mát.

- [x] **GATE-1: Kiểm tra 5 Cổng Release (Release Gates Check)** `[P0] [Lead]`
  - [x] **Gate 1 (Core UX):** Màn hình Hôm nay, Tasks, Bắt đầu học, Chế độ học, Tiến độ hoạt động hoàn hảo.
  - [x] **Gate 2 (AI):** Gợi ý, giải thích, lập kế hoạch, xác nhận hành động, fallback khi lỗi đều an toàn.
  - [x] **Gate 3 (Reliability):** Ngoại tuyến, đồng bộ Supabase, khôi phục phiên học dở, zero data loss.
  - [x] **Gate 4 (Responsive):** Mượt mà trên mobile và desktop.
  - [x] **Gate 5 (Polish):** Trạng thái loading/error/empty chuẩn chỉnh, không có console runtime error nào.
  - *Pass criteria:* Đạt 5/5 cổng để sẵn sàng phát hành chính thức.

- [x] **QA-7.1: Tổng duyệt Hồi quy Cuối cùng (Final Regression Sign-off)** `[P0] [QA]`
  - [x] Chạy lại toàn bộ bộ test `flutter test`, kiểm tra `flutter analyze` sạch 100%.
  - *Done when:* Ứng dụng ổn định cao nhất, đạt mục tiêu đề ra.
---


---

## 10. Sprint 8 — Đối chiếp toàn bộ tính năng với 3 file đặc tả (Spec Conformance)

> **Mục tiêu:** Đọc lại `EDUPULSE_SPRINT_BACKLOG.md` (1631 dòng), `EDUPULSE_UX_UI_REDESIGN.md` (1571), `EDUPULSE_AI_OPTIMIZATION.md` (1748) — tổng 4950 dòng — rồi đối chiếu từng hạng mục với code thật. Mỗi điểm lệch phải được sửa ngay, không ghi "gần đúng".

- [x] **SPEC-8.1: Rà toàn bộ & sửa 10 điểm lệch (S1–S10)** `[P0] [FE] [AI] [QA]`
  - [x] **S1 — UX 5.6** Study Mode có nút "Hoàn thành" để kết thúc phiên sớm (chặn nếu chưa học ≥1 phút, ghi phiên qua đúng đường ghi thật).
  - [x] **S2 — UX 5.3** Tạo nhiệm vụ xong phải khẳng định rõ "✓ Đã thêm vào hôm nay" kèm lối "Bắt đầu ngay".
  - [x] **S3 — UX 11** Empty state "Hôm nay" đúng 3 câu: `Hôm nay chưa có nhiệm vụ.` + `Tạo kế hoạch để biết mình nên học gì.` + `[AI lập kế hoạch] [+ Thêm nhiệm vụ]`.
  - [x] **S4 — UX 5.5 / FE-2.4** Từ lần dời thứ 3 mở hộp thoại 3 lựa chọn (Giảm thời lượng / Chia nhỏ / Giữ nguyên); **không** tự sửa kế hoạch của người học.
  - [x] **S5 — UX 5.13 / BE-5.2** `ExamModel.subjectTargets` (mục tiêu điểm theo môn) + `SubjectTargetsEditor` / `SubjectTargetsChips` trong cả dialog Thêm và Sửa.
  - [x] **S6 — UX 5.12** `SubjectTrend` (up/flat/down) + `lastPeriodMinutes`; màn Tiến độ hiện `↑/→/↓` cạnh tên môn; **không đoán** khi thiếu dữ liệu (`trend == null`).
  - [x] **S7 — UX 12 / AI-30** Lỗi AI có tin nhắn riêng kèm **Thử lại** và **Tiếp tục tự học**; `isError`/`retryPrompt` sống sót qua serialize.
  - [x] **S8 — UX 5.11 + 5.14** `FeedbackService` là cổng duy nhất cho rung/âm (29 chỗ `HapticFeedback.*` → `FeedbackService`); thêm 2 công tắc **Rung**/**Âm thanh**; sheet **AI nâng cao** là nơi duy nhất chọn model, AI Coach đọc model đã ghim và **không lộ tên model/nhà cung cấp**.
  - [x] **S9 — AI 22 + 24** Quick action thứ 5 **Điều chỉnh lịch**: rule engine `proposeDayBalance`, **không gọi LLM** (đúng danh sách "không gọi AI khi…" AI-24), chạy được cả ngoại tuyến, vẫn phải duyệt từng dòng.
  - [x] **S10 — UX 11** Empty state "No study history": `Chưa có phiên học nào.` + `Bắt đầu phiên đầu tiên hôm nay…` + CTA **Bắt đầu học** (cả ở thẻ phân tích focus và biểu đồ tuần).
  - *Pass criteria:* 10/10 điểm lệch đã sửa, mỗi điểm có test chặn tái phạm.

- [x] **SPEC-8.2: Rà lại các empty state còn lại theo UX mục 11** `[P1] [FE]`
  - [x] "No progress" (Tiến độ theo môn) nói rõ dữ liệu gì sẽ xuất hiện sau khi học.
  - [x] Biểu đồ tuần rỗng có CTA, không để trống.
  - [x] "No exam" đã đủ 3 câu ở `EmptyStateView` (giữ nguyên).

- [x] **SPEC-8.3: Test chặn hồi quy cho toàn bộ S1–S10** `[P0] [QA]`
  - [x] `test/spec_conformance_s1_s6_test.dart` (15 case): nút Hoàn thành, dời lịch ≥3 lần, mục tiêu điểm theo môn, xu hướng môn, snackbar xác nhận tạo task.
  - [x] `test/spec_conformance_s8_s10_test.dart` (15 case): AI nâng cao, Rung/Âm, empty state phiên học, lỗi AI có Thử lại, 5 quick action.
  - [x] Test quét mã nguồn chặn `HapticFeedback.*` / `SystemSound.*` gọi trực tiếp ngoài `FeedbackService`.
  - [x] Sửa test cũ vỡ do đổi nhãn UI (`e2e_scenarios_test.dart`, `widget_test.dart`).
  - *Pass criteria:* `flutter analyze lib test` sạch 100%, `flutter test` **533/533 pass**.

## 11. Nhật Ký Cập Nhật Tiến Trình Triển Khai (Progress Change Log)

> Ghi chú lại ngày giờ và nội dung cụ thể mỗi khi hoàn thành 1 việc hoặc cập nhật trạng thái checklist.

| Thời gian | Mã Task | Nội dung thực hiện | Người thực hiện / Agent | Trạng thái |
|---|---|---|---|---|
| *2026-10-01* | **INIT** | Khởi tạo bảng Todo list theo 3 tài liệu cải tổ v2 | AI Assistant | ✅ Hoàn thành |
| *2026-10-01* | **SPRINT-0** | Hoàn thành toàn bộ Sprint 0 (Audit screens/data/AI, Design Tokens AppTokens, Shared Primitives UI, 188/188 tests pass) | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **SPRINT-1** | Hoàn thành Sprint 1 (4 tabs Hôm nay/AI/Tiến độ/Tôi, TodayService, DailySummaryCard, TodayMissionCard, Home Screen tinh gọn, 188/188 tests pass) | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **BE-2.2** | Harden TaskStateMachine (bảng tra chuyển trạng thái, chặn completed→reschedule), thêm createdAt/updatedAt + copyWith cho TodayTask | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **BE-2.1** | Viết lại TaskRepository làm single write path (TaskMutationResult, revision notifier, debounce sync cloud, DeletedTaskRef cho Undo); vá AppTokens/AppColors thiếu. `flutter analyze` 73 lỗi → 0 | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **FE-2.1 → FE-2.5** | TaskCard + Task detail + Reschedule (ngưỡng ≥3) + Delete có xác nhận/Undo + Chia nhỏ thật (`splitTask`/`undoSplit`); sửa bug migration `today_task_` → `task_` | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **AI-2.1** | AI dùng chung `TaskRepository` (thêm `createTaskIfMissing` chặn trùng, 3 hành động sửa/dời/xoá có xác nhận); test `ai_task_actions_test.dart` 17 case | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **SINGLE-WRITE-PATH** | 9 chỗ ghi Task tay ở study/calendar/onboarding/quiz/ai_plan chuyển qua repository; thêm test quét mã nguồn chặn tái phạm | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **SPRINT-2** | **Hoàn thành Sprint 2 — 10/10 hạng mục.** `flutter test` 296/296 pass, `flutter analyze lib test` sạch | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **FE-2.2 (phần còn thiếu)** | Tài liệu kèm theo (ảnh ≤250KB, ≤3 tệp, có Undo) + lịch sử phiên học; thêm `StudySessionRepository`; sửa lỗi id trùng làm mất ảnh, tài liệu mồ côi khi xoá, Undo mất ảnh | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **SESSION-READ-PATH** | 7 nơi tự giải mã `StudySession` chuyển qua `StudySessionRepository`; thêm test guard chặn tái phạm | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **BE-3.1** | `StudySession` thêm `startedAt`/`endedAt`/`status` (nullable, không cần migration); `feedbackRating` suy ra từ 5 thang chi tiết; `minutesOn`/`minutesForSubject` tính từ danh sách phiên | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **FE-3.2** | `FocusClock` neo theo mốc thời gian thay cho `Timer.periodic` trừ 1/giây; sửa pause nuốt thời gian đã học và `actualMinutes` ghi bằng số phút cài đặt | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **BE-3.2** | `ActiveStudySession` + khôi phục phiên sau khi app bị kill (Tiếp tục / Kết thúc → ghi phiên `cancelled`); 21 test. `flutter test` 363/363 pass | AI Assistant | ✅ Hoàn thành |
| *2026-10-02* | **STUDY-LOG-MERGE** | Bỏ ghi trùng `StudyLog` ở vòng pomodoro; `StudyTimelineEntry` + `buildStudyTimeline()` làm nguồn tổng hợp chung cho tab Nhật ký, biểu đồ tuần và AI context; xoá dòng nhật ký về đúng bảng gốc. Harden: `autoStart` không còn ghi đè ảnh chụp, ảnh chụp quá hạn 6h tự dọn, đồng hồ khôi phục phải thật sự chạy mới bật nút chạy; `NotificationService.cancelId` bỏ qua khi plugin chưa init. Thêm 17 test. `flutter test` 380/380 pass | AI Assistant | ✅ Hoàn thành |
| *2026-10-03* | **SPRINT-4** | **Hoàn thành Sprint 4 — 9/9 hạng mục.** Context Engine đa cấp độ (`AiContextLevel` + `AiStudyContext.buildFor`, `AiRouter.chat` nhận level); Daily Coach + Giải thích bài (Quick Actions, lối vào từ Study Mode); AI Study Planner (`AiStudyPlannerService` sửa lỗi compile `ExamModel`, đổi tên `AiPlannedTask`, Preview + idempotency); Weakness Analyzer nối UI; màn AI có lưới 4 Quick Actions; xử lý offline thân thiện. Thêm 12 test (`test/ai_sprint4_test.dart`). `flutter test` 415/415, `flutter analyze lib test` sạch | AI Assistant | ✅ Hoàn thành |
| *2026-10-04* | **SPRINT-5** | **Hoàn thành Sprint 5 — 7/7 hạng mục.** BE-5.1 `ProgressEngine` (hàm thuần nhận `now`: cửa sổ nửa mở ngày/tuần/tháng, `dayProgress`/`weekProgress`/`subjectProgress`/`neglectedSubjects`/`snapshot`, gom môn qua `AppSubjects.normalize`); BE-5.2 `ExamRepository` single source of truth (CRUD + primary exam + revision notifier + `...At(now)`/`phaseAt` cho đếm ngược); FE-5.1/FE-5.2 `ProgressScreen` (tab 2) với biểu đồ tuần, tiến độ theo môn, cảnh báo môn bỏ quên; FE-5.3 thẻ đếm ngược kỳ thi + `ExamsPage`; AI-5.1 `ProgressInsights` (localInsight deterministic + buildPrompt số liệu thật + generate fallback offline). Sửa import `app_colors.dart` bị thiếu trong `main_shell.dart` và overflow 50px ở thẻ nhận định AI; thêm `test/progress_engine_test.dart` (27 case QA-5.1).`flutter test` 442/442, `flutter analyze lib test` sạch | AI Assistant | ✅ Hoàn thành |
| *2026-10-04* | **QA-5-WIDTH** | **Progress UI width tests.** Thêm `test/progress_ui_width_test.dart` (9 case) render màn Tiến độ với **dữ liệu thật** (nhiều môn, môn bỏ quên, kỳ thi chính) ở 320/360/390/414/480/768px và cỡ chữ 1.3x/1.4x — test cũ chỉ chạy tab Tiến độ với dữ liệu rỗng nên bỏ sót lỗi. Phát hiện và sửa 3 tràn ngang thật trong `progress_screen.dart`: header thẻ Tuần này (chuỗi delta dài), header "Tiến độ theo môn", và dòng đánh giá hiểu bài trong hàng môn — dùng `Expanded` + `maxLines:1` + ellipsis. Sửa tràn dọc biểu đồ tuần khi chữ lớn: chiều cao co theo `MediaQuery.textScalerOf(context).scale(120)`. `flutter test` 456/456, `flutter analyze lib test` sạch | AI Assistant | ✅ Hoàn thành |


| *2026-10-04* | **AI-5.1 → HOME** | **Surface insights on Home.** Thẻ "Nhận định tuần" (`ProgressInsightCard`) ngay dưới `DailySummaryCard`: đọc `ProgressEngine.snapshot` + `ProgressInsights.localInsight` (đồng bộ, offline-safe — không gọi AI trong `build`), nghe revision của `TaskRepository`/`StudySessionRepository`, ẩn khi tuần trắng. Có nút "Xem tuần" (chuyển tab Tiến độ) và "Hỏi AI phân tích tuần" (gửi `buildPrompt` sang AI Coach). Thêm `test/progress_insight_card_test.dart` (5 case). `flutter test` 447/447, `flutter analyze lib test` sạch | AI Assistant | ✅ Hoàn thành |
| *2026-10-04* | **FE-6.1** | **Mobile Polish.** Thêm `test/responsive_matrix_test.dart` (7 case): duyệt MainShell qua 4 tab + trang phụ ở 320/390/768/1280px, kiểm tra breakpoint 1024px (bottom nav ↔ sidebar), touch target điều hướng ≥44px, và bàn phím ảo (`viewInsets`) không đẩy tràn layout. Test bắt 2 tràn ngang thật: header AI Coach (tiêu đề + chip model/Web) và nút segment tab Tôi — sửa bằng `Wrap` và `Flexible`+ellipsis. `flutter test` 463/463, `flutter analyze lib test` sạch | AI Assistant | ✅ Hoàn thành |
| *2026-10-04* | **SPRINT-6** | **Hoàn thành Sprint 6 — phần còn lại (FE-6.2→FE-6.6, QA-6.1); đủ 7/7 hạng mục cùng FE-6.1.** **FE-6.2** tablet (768–1024) dùng sidebar rail thu gọn thay vì kéo giãn giao diện điện thoại (`kTabletBreakpoint`). **FE-6.3** desktop giới hạn nội dung `maxWidth: 1200` canh giữa; sidebar thu gọn/mở + keyboard nav đã có sẵn. **FE-6.4** nâng CTA chính màn Tiến độ thành `PrimaryButton` toàn chiều ngang + test phân cấp (`visual_hierarchy_test.dart`). **FE-6.5** thêm `SkeletonBox`/`SkeletonList` shimmer, nối `EmptyStateView` (Notes/Exams có nút hành động) + `ErrorStateView`/`LoadingStateView` (trước đây định nghĩa nhưng chưa dùng); thay báo lỗi kỹ thuật ở AI Coach bằng thông điệp thân thiện. **FE-6.6** `AppMotion` tôn trọng `disableAnimations` (shimmer tự tắt ticker). **QA-6.1** ma trận responsive tự động 320→1280px + breakpoint + touch target + bàn phím ảo. Sửa tràn nhãn `PrimaryButton` bề rộng cố định. `flutter test` 473/473, `flutter analyze lib test` sạch | AI Assistant | ✅ Hoàn thành |
| *2026-10-05* | **E2E-1 → E2E-4** | **Bốn kịch bản E2E trên app thật** (`test/e2e_scenarios_test.dart`, 4 case). Toàn bộ bước đều bấm widget thật và khẳng định đọc lại từ repository/storage/`ProgressEngine`, không giả lập kết quả. Cho `MainShellScreen`/`HomeScreen` nhận tham số `clock` (mặc định `DateTime.now`) để chạy hết vòng focus 30 phút bằng đồng hồ giả thay vì chờ thật — `FocusClock` neo theo mốc thời gian nên `pump()` không đẩy được nó. **A:** tạo task → Hôm nay → Bắt đầu học → hết vòng → đánh giá 1 chạm → số liệu tiến độ nhảy ngay. **B:** Preview kế hoạch AI (chưa ghi gì) → Áp dụng → task theo đúng ngày, áp lại không sinh trùng → bắt đầu học như task thủ công. **C:** Dời lịch sang ngày mai — ID giữ nguyên, `createdAt` giữ nguyên, lịch sử phiên học không đứt đoạn. **D:** Offline tạo task + học 30 phút → bật mạng → `syncInBackground`/`restoreAll` không xoá hay nhân bản dữ liệu. | AI Assistant | ✅ Hoàn thành |
| *2026-10-05* | **GATE-1** | **5 cổng release** (`test/release_gates_test.dart`, 21 case): Core UX (4 tab, tick hoàn thành qua repository, mở được chế độ học), AI (offline → thông điệp thân thiện, không lộ lỗi kỹ thuật; AI không tự ghi thay người dùng), Reliability (ghi offline là nguồn sự thật, sync chưa cấu hình là no-op an toàn, chip trạng thái đúng), Responsive (320/390/768/1280/1600 + cỡ chữ 1.4x), Polish (empty/loading/error chuẩn, tôn trọng giảm chuyển động, không lỗi runtime). Cổng này bắt được **6 lỗi thật**: tràn ngang trong chip trạng thái + ô thông tin của màn chi tiết nhiệm vụ, tràn nhãn `PrimaryButton`/`SecondaryButton`, tràn nút "Hiểu tốt / Cần củng cố" và hàng nút trong sheet đánh giá phiên, tràn dọc bottom nav khi cỡ chữ lớn, tràn nhãn sidebar khi cỡ chữ lớn, và báo lỗi kỹ thuật thô `Lỗi: ${snap.error}` trong sheet phân tích điểm yếu của AI. | AI Assistant | ✅ Hoàn thành |
| *2026-10-05* | **DESKTOP-AUX** | **Cột phụ desktop.** `DesktopAuxColumn` (`lib/app/desktop_aux_column.dart`, 300px, bật từ `kAuxColumnBreakpoint = 1440px`) đưa thông tin quan trọng ra mép màn hình thay vì để người dùng phải cuộn: tab Hôm nay → đếm ngược kỳ thi + tổng kết hôm nay; tab AI → năng lực AI + trạng thái mạng; tab Tiến độ → số liệu tuần + môn bị bỏ qua; tab Tôi → hồ sơ + chuỗi học + đồng bộ; kèm lối tắt Lịch/Ghi chú/Kỳ thi ở mọi tab. Ngưỡng đặt cao hơn hẳn ngưỡng desktop để không bóp cột chính còn ~490px ở 1024–1400px. Số liệu dùng `FittedBox`/ellipsis nên không vỡ ở cỡ chữ lớn. Thêm `test/desktop_aux_column_test.dart` (5 case). | AI Assistant | ✅ Hoàn thành |
| *2026-10-05* | **QA-7.1 / SPRINT-7** | **Hoàn thành Sprint 7 — 6/6 hạng mục, tổng lộ trình 61/61 (100%).** `flutter analyze lib test` sạch 100%, `flutter test` **503/503 pass** (473 → 503: +4 E2E, +21 release gates, +5 cột phụ desktop). | AI Assistant | ✅ Hoàn thành |
| *2026-10-06* | **SPEC-8 (Sprint 8)** | **Đối chiếu toàn bộ tính năng với 3 file đặc tả (4950 dòng) — sửa 10 điểm lệch.** **S1** Study Mode thêm nút "Hoàn thành" (UX 5.6): chặn nếu chưa học ≥1 phút, ghi phiên + streak + XP qua đúng đường ghi thật, mở bước đánh giá 1 chạm. **S2** Tạo nhiệm vụ xong khẳng định "✓ Đã thêm vào hôm nay" + lối "Bắt đầu ngay" (UX 5.3). **S3** Empty state Hôm nay đúng 3 câu của UX mục 11, có cả `[AI lập kế hoạch]` và `+ Thêm nhiệm vụ`. **S4** Từ lần dời thứ 3 mở hộp thoại 3 lựa chọn (Giảm thời lượng / Chia nhỏ / Giữ nguyên) — AI chỉ **đề nghị**, không tự sửa kế hoạch người học (UX 5.5). **S5** `ExamModel.subjectTargets` + `SubjectTargetsEditor`/`SubjectTargetsChips` cho mục tiêu điểm **theo từng môn** (UX 5.13 / BE-5.2); `subjects` suy ra tự động từ mục tiêu. **S6** `SubjectTrend` + `lastPeriodMinutes`: màn Tiến độ hiện `↑/→/↓` cạnh tên môn, **không đoán** khi thiếu dữ liệu (UX 5.12). **S7** Lỗi AI có tin nhắn riêng kèm **Thử lại** + **Tiếp tục tự học**; `isError`/`retryPrompt` sống sót qua serialize để mở app lại vẫn thử lại được (UX 12 / AI-30). **S8** `FeedbackService` thành cổng duy nhất cho rung/âm (29 chỗ `HapticFeedback.*` → `FeedbackService`; `audio_synth_service` kiểm tra `soundEnabled`); thêm công tắc **Rung**/**Âm thanh** vào Cài đặt; sheet **AI nâng cao** là nơi duy nhất chọn model, AI Coach đọc model đã ghim, header chỉ nói "AI tự động"/"AI đã ghim" — **không lộ tên model/nhà cung cấp** (UX 5.11). **S9** Quick action thứ 5 **Điều chỉnh lịch** (AI mục 22): rule engine `proposeDayBalance`, **không gọi LLM** đúng AI-24, chạy được cả ngoại tuyến, tách thành `day_balance_sheet.dart` dùng chung với Home; lịch vừa sức thì nói thật thay vì bịa đề xuất (AI-17). **S10** Empty state "No study history" (UX 11) với CTA **Bắt đầu học** ở cả thẻ phân tích focus và biểu đồ tuần. Rà thêm: empty state "No progress" nói rõ dữ liệu gì sẽ xuất hiện. Thêm `test/spec_conformance_s1_s6_test.dart` (15 case) + `test/spec_conformance_s8_s10_test.dart` (15 case), trong đó có test quét mã nguồn chặn `HapticFeedback.*`/`SystemSound.*` gọi trực tiếp ngoài `FeedbackService`; sửa 2 test cũ vỡ do đổi nhãn UI. `flutter analyze lib test` sạch 100%, `flutter test` **533/533 pass** (503 → 533). | AI Assistant | ✅ Hoàn thành |
| *2026-10-06* | **UI-PHAT-TRIEN (4 pha)** | **Triển khai đủ 4 giai đoạn của `UI phát triển.md` — 13/13 hạng mục.** **Pha 1 — ưu tiên thông tin:** `HomeHeader` gộp còn **1 hàng ~48px** (avatar 36px, tên dùng `AppTokens.heading2`, chip chuỗi thu gọn) để lời chào không đẩy nhiệm vụ xuống fold; thứ tự block mới = Header → Tổng kết ngày → **Nhiệm vụ hôm nay** → Nhận định tiến độ → **Hàng hành động AI** → Exam Mode → banner cân bằng ngày (3 card AI cũ `ai_copilot_hub_card`/`quick_action_card`/`ai_readiness_card` gộp vào widget mới `ai_actions_row.dart`: dải trạng thái 1 dòng + hành động 1 chạm 44px + hàng chip cuộn ngang); empty state Hôm nay giữ nguyên CTA `+ Thêm nhiệm vụ` + `AI lập kế hoạch`. **Pha 2 — visual hierarchy:** badge khẩn cấp (`Quá hạn`/`HÔM NAY`/`Mai`, icon + chữ + màu) đặt ở **Wrap dòng chip phụ** của `TaskCard` — đặt ở Row tiêu đề sẽ `RenderFlex overflowed by 14px` ở 390px; 5 quick action AI mỗi màu riêng không trùng nhau; chip gợi ý AI **dựng động** từ nhiệm vụ hôm nay / tên kỳ thi thật / môn yếu nhất thay cho chuỗi tĩnh bịa đặt tên môn. **Pha 3 — micro-interactions:** SnackBar có **icon + màu ngữ nghĩa** qua enum `SnackKind` (success/moved/destructive/warning/error/info) — đọc được cả khi không phân biệt được màu; haptic nhất quán theo mức độ (bắt đầu học `light`, hoàn thành `medium`, xoá `heavy`, dời lịch `selection`) qua `FeedbackService`; khung xương tải cho danh sách nhiệm vụ — widget mới `skeleton_card.dart` vẽ sẵn hình dạng thẻ nhiệm vụ, chỉ tồn tại **đúng một khung hình** rồi thay bằng dữ liệu thật (không thêm độ trễ nhân tạo). **Pha 4 — polish:** chuẩn hoá typography về `AppTokens` (thêm `sectionTitle` + `labelSmall`, xoá mọi `fontSize` viết tay trong `home_header`/`today_mission_card`; `daily_summary_card` vốn đã sạch); empty state Tiến độ có nút **Bắt đầu học ngay** (`progress-start-study`, shell truyền `onStartStudy`); sidebar desktop có vạch chỉ báo 3px bên trái — tín hiệu duy nhất còn lại khi sidebar thu gọn (lúc đó chỉ còn icon). Thêm `test/ui_acceptance_test.dart` (7 case) bảo vệ đúng các tiêu chí nghiệm thu: **fold test iPhone SE 375×667**, 3-second test, empty state có CTA, SnackBar có icon. `flutter analyze lib test` sạch 100%, `flutter test` **540/540 pass** (533 → 540), `flutter build web --release` thành công. Toàn bộ tiêu chí nghiệm thu trong `UI phát triển.md` đã tick `[x]`. | AI Assistant | ✅ Hoàn thành |
| *2026-10-06* | **UI-CLEANUP-DEADCODE** | **Xoá 3 widget AI đã thành dead code.** Sau khi gộp, `ai_copilot_hub_card.dart` / `quick_action_card.dart` / `ai_readiness_card.dart` không còn file nào import (đã xác minh 0 reference theo **cả tên file lẫn tên class** `AiCopilotHubCard` / `QuickActionCard` / `AiReadinessCard`). Xoá file + sửa chú thích trong `ai_actions_row.dart` để không trỏ tới class không tồn tại. Cả 3 file đều đã được git track nên lịch sử còn đầy đủ để khôi phục nếu cần. `flutter analyze lib test` sạch, `flutter test` **540/540 pass**, `flutter build web --release` thành công. | AI Assistant | ✅ Hoàn thành |
| *2026-10-06* | **G3-B-SWIPE + G3-C-VISIBLE** | **Xoá 2 hạn chế còn lại của Pha 3.** **(1) Vuốt ngang dời lịch — thật.** `TaskCard` bọc thẻ trong `_SwipeToReschedule`: vuốt ngang lộ nền cam + icon lịch + nhãn **"Vuốt để dời lịch"**, vượt ngưỡng **72px** thì rung `selection` và mở lại hộp thoại đổi lịch sẵn có rồi thẻ trượt về chỗ cũ. Vuốt **không tự dời** — người học vẫn chọn ngày, đúng nguyên tắc "đề nghị, không tự sửa kế hoạch" (UX 5.5). Chỉ bật khi nơi dùng truyền `onReschedule` (lịch tháng và kế hoạch AI có cuộn ngang riêng nên không bật). Ngưỡng 72px cố ý lớn hơn `Dismissible` vì thẻ nằm trong danh sách dọc, vuốt hơi tay rất dễ trượt. Tôn trọng "giảm chuyển động": không trượt theo ngón tay, gọi thẳng. Nhãn riêng cho vuốt (không trùng "Dời lịch" của menu) và chỉ dựng khi nền đã lộ — tránh node vô hình trong cây widget. **(2) Khung xương thật sự hiện.** Độ trờ 300ms có chủ đích thay cho việc thay ở khung hình đầu (một khung hình nhanh đến mức người dùng không kịp thấy). Sửa 2 lỗi thật phát hiện khi làm: `Future.delayed` không huỷ được khi dispose → đổi sang `Timer` có `_skeletonTimer?.cancel()` trong `dispose`; nhãn nền vuốt trùng nhãn menu làm test bấm "Dời lịch" không xác định được đích. Nâng thời lượng `pump` của 16 test bị ảnh hưởng (giữ nguyên assertion, không nới lỏng). Thêm 6 case vào `test/ui_acceptance_test.dart`, trong đó có 1 case **e2e** vuốt thẻ trên màn Hôm nay thật → `RescheduleDialog` mở ra (chứng minh đường HomeScreen → TodayMissionCard → TaskCard nối thật, không chỉ dựng `TaskCard` cô lập). `flutter analyze lib test` sạch, `flutter test` **546/546 pass** (540 → 546), `flutter build web --release` thành công. | AI Assistant | ✅ Hoàn thành |
| *2026-10-05* | **BACKUP-TOÀN-DIỆN** | **Sao lưu tự động mọi thứ, đồng bộ thời gian thực giữa mọi thiết bị (mục 19).** Chẩn đoán 5 nguyên nhân khiến "bản gốc" và "bản sao lưu" không có linking: (1) `SupabaseService._userId` fallback về uuid cục bộ khi chưa đăng nhập → mỗi máy một `user_id` khác nhau; (2) RLS trong `schema.sql` so sánh `user_id = auth.uid()` (Supabase Auth) trong khi app đăng nhập bằng **Firebase** → `auth.uid()` NULL, mọi select rỗng / upsert bị chặn, lỗi bị `try/catch` nuốt nên "đồng bộ xong nhưng không lưu được gì"; (3) schema lệch code (bảng `exams` thiếu `current_score`/`target_score`/`subject_targets`/`subjects`/`updated_at`); (4) chỉ sao lưu exams/tasks/study_logs, thiếu ghi chú, phiên học, điểm thi thử, tệp đính kèm, XP, streak, linh vật, cài đặt, chat AI; (5) `restoreAll()` chỉ chạy khi bấm tay, mở app chỉ **đẩy** chứ không **kéo**. **Cách sửa:** endpoint mới `api/backup.js` (xác thực Firebase ID token → `SUPABASE_SERVICE_ROLE_KEY`, bỏ qua RLS) + 2 bảng `user_snapshots` / `user_blobs` trong `supabase/schema.sql`; `lib/core/sync/backup_service.dart` chụp snapshot theo **mọi khoá SharedPreferences** trừ khoá riêng thiết bị (`deviceLocalKeys`) nên tính năng mới thêm sau cũng tự được sao lưu — thay vì liệt kê từng loại như trước; ảnh đính kèm base64 đi bảng riêng + checksum nên snapshot không phình. **Bản mới nhất thắng:** server là đồng hồ chuẩn, client gửi kèm mốc đã biết; có bản mới hơn thì server **không** ghi đè mà trả ngược bản cloud về (hai máy tự hội tụ, không cần hỏi người dùng). Áp bản cloud **xoá luôn** khoá chỉ có ở máy — nếu không thì bản ghi đã xoá sẽ "sống lại" ở mọi thiết bị. Push debounce 2s sau mỗi lần ghi + poll 20s + đẩy ngay khi app chuyển nền / có mạng lại / vừa đăng nhập; chỉ tải-ghi payload đầy đủ khi thật sự có thay đổi (`fingerprint` FNV-1a tự viết, ổn định giữa các phiên bản Dart). Chỉ chạy khi **đã đăng nhập** vì Firebase UID mới là khoá nối các máy. Trước khi ghi đè luôn cất bản cục bộ vào `backup_prev_snapshot` + nút **"Quay lại dữ liệu trước khi khôi phục"** ở tab Tôi — đường an toàn duy nhất của chính sách "luôn ưu tiên bản sao lưu gần nhất". Kiểm chứng: `api/backup.js` chạy thật bằng Node với Supabase/Firebase giả lập (20 assertion: 401 token hỏng, seed, `changed:false` khi payload y hệt, từ chối ghi đè và trả bản mới nhất về, ảnh lưu/tải/xoá, giới hạn 4 ảnh/lần, 405); thêm `test/backup_service_test.dart` (20 case: phủ hết 20+ loại dữ liệu, không lộ khoá riêng thiết bị, xoá đúng bản ghi đã xoá ở máy khác, vòng đẩy–kéo lặp lại không trôi dữ liệu, mô phỏng hai máy thật, undo khôi phục). Test `Single Write Path` bắt được việc `backup_service` ghi tệp đính kèm vòng qua `TaskRepository` → sửa đúng cách (dùng `restoreAttachment`/`removeAttachment`) thay vì nới lỏng test. `flutter analyze lib test` sạch 100%, `flutter test` **605/605 pass** (585 → 605). **Việc còn lại của người dùng:** chạy phần `user_snapshots`/`user_blobs` trong `supabase/schema.sql` trên Supabase Console và thêm env `SUPABASE_SERVICE_ROLE_KEY` trên Vercel (Production/Preview/Development) rồi redeploy. | AI Assistant | ✅ Hoàn thành (chờ cấu hình server) |
