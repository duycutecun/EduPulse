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
| **Sprint 0** | Nền tảng, Tokens, Shared UI & Data Audit | 7 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Sprint 1** | Điều hướng mới (4 tabs) + Màn hình Hôm nay (Today) | 8 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Sprint 2** | Quản lý Nhiệm vụ (Single Source of Truth) | 10 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Sprint 3** | Chế độ Học tập trung (Study Mode) + Phiên học | 7 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Sprint 4** | Trợ lý AI Ngữ cảnh (Context Engine & Actions) | 9 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Sprint 5** | Tiến độ (Progress) & Quản lý Kỳ thi (Exam) | 7 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Sprint 6** | Giao diện đa thiết bị (Responsive) & Tinh chỉnh thẩm mỹ | 7 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Sprint 7** | QA, E2E Scenarios & Release Gates | 6 | 0 | 0% | ⏳ Chưa bắt đầu |
| **Tổng cộng** | **Toàn bộ lộ trình EduPulse v2** | **61** | **0** | **0%** | **Sẵn sàng triển khai** |

> **MVP Boundary (Ưu tiên số 1):** Hoàn thành xong **Sprint 0 + Sprint 1 + Sprint 2 + Sprint 3** là đã có thể chạy thông luồng học tập cốt lõi (Tạo task → Thấy ở Hôm nay → Bắt đầu học → Bấm giờ tập trung → Hoàn thành → Ghi nhận).

---

## 2. Sprint 0 — Nền Tảng & Rà Soát Hiện Trạng (Foundation & Audit)

> **Mục tiêu:** Thiết lập baseline an toàn, xây dựng design tokens và component dùng chung trước khi đụng vào code UI màn hình.

- [ ] **FE-0.1: Rà soát và phân loại màn hình hiện tại** `[P0] [FE]`
  - [ ] Liệt kê toàn bộ routes/screens hiện có trong codebase (`lib/features/...`).
  - [ ] Lập bản đồ điều hướng cũ chuyển tiếp sang 4 tab mới (`Hôm nay`, `AI`, `Tiến độ`, `Tôi`).
  - [ ] Định danh các widget/component tái sử dụng được.
  - [ ] Định danh các thành phần gamification cần ẩn khỏi luồng chính (XP, Level, Streak counter, Mascot EXP, Bùa, Bốc quẻ).
  - [ ] Rà soát layout mobile và desktop/web hiện tại.
  - *Done when:* Có danh sách mapping rõ ràng từng screen cũ sang cấu trúc mới, không sót màn hình quan trọng.

- [ ] **FE-0.2: Xây dựng hệ thống Design Tokens dùng chung** `[P0] [FE]`
  - [ ] Chuẩn hóa bộ semantic colors trong `AppColors` (chế độ sáng/tương phản cao).
  - [ ] Chuẩn hóa Typography tokens (Headings, Body, Captions, Numeric/Timer font).
  - [ ] Chuẩn hóa Spacing (4, 8, 12, 16, 24, 32px), Radius (8, 12, 16, 20px), Elevation.
  - [ ] Chuẩn hóa kích thước Touch targets (tối thiểu 44-48px cho mobile).
  - *Done when:* Mọi màn hình mới sử dụng tokens chung, không hardcode giá trị tùy tiện.

- [ ] **FE-0.3: Tạo các Shared UI Primitives (Component cốt lõi)** `[P0] [FE]`
  - [ ] `PrimaryButton` (CTA màu chủ đạo, nổi bật nhất).
  - [ ] `SecondaryButton` / `IconButton`.
  - [ ] `TaskCard` (Card nhiệm vụ đa năng: checkbox, thông tin môn, thời lượng, nút học).
  - [ ] `SectionHeader` (Tiêu đề nhóm tinh tế, rõ ràng).
  - [ ] `BottomNavigation` (4 tabs chuẩn mobile).
  - [ ] `DesktopSidebar` (Sidebar thu gọn/mở rộng chuẩn desktop).
  - [ ] `EmptyState`, `ErrorState`, `LoadingState` (Đồng bộ, có hành động cụ thể).
  - [ ] `ConfirmationDialog` / `ActionBottomSheet` (Hộp thoại xác nhận trước thao tác quan trọng).
  - [ ] `ProgressIndicator` (Thanh tiến trình học tập tối giản).
  - *Done when:* Bộ UI Primitives hoàn thiện trong `lib/shared/widgets`, sẵn sàng cho Sprint 1 & 2.

- [ ] **BE-0.1: Rà soát & chuẩn hóa Data Model** `[P0] [BE]`
  - [ ] Rà soát models: Tasks, Study Sessions, Exams, Subjects, Progress.
  - [ ] Rà soát cơ chế lưu offline (SharedPreferences / Hive / SQLite) và đồng bộ Supabase.
  - [ ] Xác định các trường gamification hiện tại để đảm bảo backward-compatible không làm crash dữ liệu cũ.
  - *Done when:* Schema dữ liệu được chuẩn hóa, rủi ro migration bằng 0, ID task/session được bảo toàn.

- [ ] **BE-0.2: Định nghĩa Task là "Single Source of Truth"** `[P0] [BE]`
  - [ ] Thống nhất Task tạo thủ công và Task do AI gợi ý/tạo lập đều dùng chung một Model `Task`.
  - [ ] Study Session tham chiếu trực tiếp đến `taskId`.
  - [ ] Trạng thái hoàn thành chỉ được quản lý ở 1 nơi duy nhất.
  - *Done when:* Không còn entity nhiệm vụ riêng biệt giữa AI và ứng dụng, tránh xung đột dữ liệu.

- [ ] **AI-0.1: Định nghĩa Hợp đồng Hành động AI (AI Action Contract)** `[P0] [AI]`
  - [ ] Xây dựng JSON schema cho các action: `recommend`, `create_task`, `edit_task`, `delete_task`, `reschedule_task`, `split_task`, `create_plan`, `explain`.
  - [ ] Thiết lập quy tắc: AI không tự ý âm thầm xóa hoặc sửa đổi lịch của người dùng.
  - [ ] Quy định các hành động phá hủy (destructive actions) bắt buộc phải có bước xác nhận (confirmation).
  - *Done when:* Toàn bộ I/O schema của AI được định nghĩa rõ trong code bằng Dart models.

- [ ] **QA-0.1: Bộ kiểm thử hồi quy cơ bản (Baseline Regression Suite)** `[P0] [QA]`
  - [ ] Checklist test đăng nhập / auth.
  - [ ] Checklist test CRUD task hiện tại, tính năng offline, sync Supabase.
  - [ ] Chạy `flutter test` đảm bảo toàn bộ tests hiện tại vượt qua trước khi bắt đầu cải tổ.
  - *Done when:* 100% tests hiện tại pass, không có lỗi tiềm ẩn trước Sprint 1.

---

## 3. Sprint 1 — Điều Hướng Mới & Màn Hình "Hôm Nay" (Navigation + Today)

> **Mục tiêu:** Đưa "Hôm nay" (Today's Tasks) thành trung tâm của sản phẩm, giúp học sinh mở app là biết ngay cần học gì.

- [ ] **FE-1.1: Triển khai Cấu trúc Điều hướng Mới (Primary Navigation)** `[P0] [FE]`
  - [ ] Bottom Navigation cho Mobile với đúng 4 tab: `Hôm nay` | `AI` | `Tiến độ` | `Tôi`.
  - [ ] Left Sidebar cho Desktop/Web: hiển thị 4 mục chính và khu vực kỳ thi phụ trợ.
  - [ ] Xử lý active state trực quan, bảo toàn tab state khi chuyển đổi, hỗ trợ deep link / refresh web.
  - *Done when:* Điều hướng mượt mà trên cả mobile và desktop, không reload vô lý.

- [ ] **FE-1.2: Tái thiết kế Màn hình "Hôm Nay" (Rebuild Today Screen)** `[P0] [FE]`
  - [ ] Section 1: Lời chào ngắn gọn & ngữ cảnh kỳ thi ("Còn X ngày thi THPTQG").
  - [ ] Section 2: Tóm tắt tiến độ ngày (Ví dụ: `2/5 nhiệm vụ · 1h20m học`).
  - [ ] Section 3: Danh sách nhiệm vụ hôm nay (Today's Tasks) - Hiển thị ngay trên màn hình đầu tiên không cần cuộn nhiều.
  - [ ] Section 4: Nút "Bắt đầu học" (Start Study) trực quan, nổi bật nhất trên Task đầu tiên.
  - [ ] Section 5: Gợi ý nhanh từ AI (Daily recommendation) gọn gàng bên dưới hoặc theo card.
  - [ ] Ẩn các khối gây xao nhãng (XP, level, streak khổng lồ, mascot chiếm spotlight).
  - *Done when:* Nhiệm vụ quan trọng nhất nhìn thấy ngay lập tức khi mở app.

- [ ] **FE-1.3: Thuật toán sắp xếp Task trên màn hình Hôm nay** `[P0] [FE]`
  - [ ] Ưu tiên 1: Task đang học dở (in-progress/active session).
  - [ ] Ưu tiên 2: Task quá hạn (overdue) hoặc mức ưu tiên cao (high priority).
  - [ ] Ưu tiên 3: Task theo lịch trong ngày.
  - [ ] Phân tách trực quan giữa task chưa làm và task đã hoàn thành (completed tasks xếp xuống cuối).
  - *Done when:* Học sinh luôn thấy việc cần giải quyết nhất ở vị trí đầu tiên.

- [ ] **FE-1.4: Widget Tổng kết trong ngày (Daily Summary Widget)** `[P1] [FE]`
  - [ ] Hiển thị tỉ lệ hoàn thành nhiệm vụ (`x/y nhiệm vụ`) và thời lượng thực tế (`Xh Ym`).
  - [ ] Cập nhật tức thời (reactive) ngay khi task hoàn thành hoặc kết thúc session học.
  - [ ] Hoạt động trơn tru ngay cả khi offline.
  - *Done when:* Số liệu phản ánh tức thì, không cần tải lại trang.

- [ ] **BE-1.1: Xây dựng Service/Query dữ liệu Hôm nay** `[P0] [BE]`
  - [ ] Cung cấp API/Service lấy danh sách task hôm nay, trạng thái, thời gian đã học, active session.
  - [ ] Hỗ trợ local cache, tải tức thời khi mở ứng dụng (< 200ms).
  - *Done when:* Màn hình Hôm nay nạp đủ dữ liệu từ một stream/provider nhất quán.

- [ ] **BE-1.2: Logic tổng hợp số liệu trong ngày (Daily Aggregation)** `[P1] [BE]`
  - [ ] Tính toán tự động: tổng task, task hoàn thành, số phút đã học thực tế từ session logs.
  - [ ] Tránh tính toán thủ công phân mảnh ở nhiều nơi.
  - *Done when:* Số liệu đồng nhất tuyệt đối giữa dashboard và database.

- [ ] **AI-1.1: Gợi ý nhiệm vụ hôm nay từ AI (Daily Recommendation)** `[P1] [AI]`
  - [ ] Đầu vào: Danh sách task hôm nay, deadline gần nhất, thời gian rảnh của học sinh.
  - [ ] Đầu ra: Gợi ý 1 task nên học trước kèm lý do ngắn gọn (1-2 câu).
  - [ ] Không tự bịa ra task mới khi chưa có yêu cầu.
  - *Done when:* Gợi ý hữu ích, nhấp vào là có thể bắt đầu học ngay.

- [ ] **QA-1.1: Kiểm thử Màn hình Hôm nay & Điều hướng** `[P0] [QA]`
  - [ ] Test chuyển tab trên mobile & desktop.
  - [ ] Test hiển thị màn hình rỗng (khi chưa có task nào).
  - [ ] Test khi có nhiều task, sắp xếp đúng thứ tự ưu tiên.
  - [ ] Test cập nhật tiến độ khi tick hoàn thành task.
  - *Done when:* Tất cả kịch bản Sprint 1 đều pass.

---

## 4. Sprint 2 — Quản Lý Nhiệm Vụ Toàn Diện (Task Management)

> **Mục tiêu:** Biến Tasks thành "Single Source of Truth" với đầy đủ thao tác: Tạo, Sửa, Xóa an toàn, Hoàn thành, Dời lịch (Reschedule).

- [ ] **FE-2.1: Hoàn thiện Component TaskCard** `[P0] [FE]`
  - [ ] Trình bày: Checkbox hoàn thành, tên bài học, môn học, chủ đề, thời lượng dự kiến, deadline.
  - [ ] Hành động chính: Nút "Bắt đầu học" (Start) nổi bật.
  - [ ] Hành động phụ (menu/action sheet): Sửa, Dời lịch (Reschedule), Chia nhỏ, Xóa.
  - *Done when:* Card trực quan, dễ hiểu, không cần mở chi tiết vẫn biết rõ cần làm gì.

- [ ] **FE-2.2: Màn hình Chi tiết Nhiệm vụ (Task Detail Screen/Sheet)** `[P0] [FE]`
  - [ ] Hiển thị đầy đủ thông tin: ghi chú, tài liệu kèm theo, lịch sử các phiên học liên quan.
  - [ ] Nút CTA chính: "Bắt đầu phiên học ngay".
  - [ ] Tích hợp nút trợ giúp AI theo ngữ cảnh: "Hỏi AI về bài này", "Chia nhỏ bài học".
  - *Done when:* Trải nghiệm liền mạch, điều hướng quay lại không làm mất ngữ cảnh.

- [ ] **FE-2.3: Giao diện Tạo & Chỉnh sửa Nhiệm vụ (Create/Edit Task)** `[P0] [FE]`
  - [ ] Form nhập liệu nhanh, thông minh: Tên task, Môn học, Thời lượng, Deadline, Mức độ ưu tiên.
  - [ ] Validation rõ ràng, hiển thị lỗi inline.
  - [ ] Chỉnh sửa bảo toàn nguyên vẹn ID và lịch sử session cũ.
  - *Done when:* Người dùng có thể tạo task chỉ trong vài giây.

- [ ] **FE-2.4: Giao diện Dời lịch Thông minh (Reschedule UI)** `[P0] [FE]`
  - [ ] Lựa chọn nhanh: Chuyển sang ngày mai, Chuyển sang cuối tuần, Chọn ngày cụ thể.
  - [ ] Cảnh báo nhẹ nhàng nếu một task bị dời ≥ 3 lần và gợi ý chia nhỏ task.
  - [ ] Thao tác dời lịch cập nhật ngày của task hiện tại, KHÔNG tạo duplicate task.
  - *Done when:* Lịch học phản ánh đúng thực tế mà không sinh rác dữ liệu.

- [ ] **FE-2.5: Hộp thoại xác nhận Xóa Nhiệm vụ (Delete Confirmation)** `[P0] [FE]`
  - [ ] Xác nhận rõ ràng, nêu đích danh tên nhiệm vụ cần xóa.
  - [ ] Hỗ trợ nút Hoàn tác (Undo) qua SnackBar trong 5 giây nếu lỡ tay bấm nhầm.
  - *Done when:* Không bao giờ có tình trạng xóa nhầm nhiệm vụ ngoài ý muốn.

- [ ] **BE-2.1: Hoàn thiện Task Repository & CRUD Service** `[P0] [BE]`
  - [ ] Hỗ trợ đầy đủ Create, Read, Update, Delete, Reschedule, Complete.
  - [ ] Đảm bảo cơ chế offline-first: lưu vào local trước, sync Supabase sau khi có mạng.
  - [ ] Giữ nguyên UUID và timestamp chuẩn ISO.
  - *Done when:* Mọi thao tác task đều nhất quán khi online lẫn offline.

- [ ] **BE-2.2: Xây dựng Task State Machine** `[P0] [BE]`
  - [ ] Quản lý chặt chẽ các trạng thái: `scheduled`, `started`, `completed`, `not_completed`, `rescheduled`.
  - [ ] Chặn các bước chuyển trạng thái không hợp lệ.
  - *Done when:* Trạng thái nhiệm vụ luôn minh bạch, chính xác.

- [ ] **BE-2.3: Tương thích Migration dữ liệu cũ** `[P1] [BE]`
  - [ ] Kiểm tra các task đã tạo ở phiên bản trước, map đúng vào cấu trúc dữ liệu mới.
  - [ ] Không làm biến mất bất kỳ task nào của người dùng hiện tại.
  - *Done when:* Dữ liệu người dùng cũ hiển thị trọn vẹn trong UI v2.

- [ ] **AI-2.1: Tích hợp Hành động AI với Task Service (AI Task Actions)** `[P0] [AI]`
  - [ ] AI có thể tạo task thông qua câu lệnh tự nhiên (ví dụ: "Tạo task ôn hàm số 45 phút chiều mai").
  - [ ] AI có thể dời lịch, sửa hoặc xóa task (bắt buộc xác nhận trước khi thực thi xóa).
  - [ ] AI sử dụng cùng 1 Task Service với người dùng, ngăn ngừa duplicate task.
  - *Done when:* Thao tác bằng ngôn ngữ tự nhiên ra kết quả task chuẩn xác.

- [ ] **QA-2.1: Bộ test kiểm thử Task CRUD** `[P0] [QA]`
  - [ ] Kiểm thử tạo, sửa, xóa, hoàn tác, dời lịch, hoàn thành.
  - [ ] Kiểm thử tính bền vững khi tắt mở lại app, ngắt kết nối mạng.
  - *Done when:* 100% test cases cho Task vượt qua.

---

## 5. Sprint 3 — Chế Độ Học Tập Trung & Ghi Nhận Phiên Học (Study Mode & Session)

> **Mục tiêu:** Rút ngắn tối đa khoảng cách từ "Tôi nên học" đến "Tôi đang học thực sự", tạo môi trường học không xao nhãng.

- [ ] **FE-3.1: Màn hình Chế độ Học tập trung (Distraction-Free Study Mode)** `[P0] [FE]`
  - [ ] Thiết kế tối giản: Chỉ hiển thị tên nhiệm vụ, môn học, đồng hồ đếm giờ (Timer).
  - [ ] Ẩn toàn bộ thanh điều hướng (Bottom Nav / Sidebar), ẩn điểm XP, level, mascot nhảy nhót.
  - [ ] Các nút điều khiển rõ ràng: Tạm dừng (Pause), Tiếp tục (Resume), Hoàn thành phiên (Complete).
  - *Done when:* Màn hình tập trung tuyệt đối, học sinh không bị phân tâm bởi bất cứ thứ gì khác.

- [ ] **FE-3.2: Bộ đếm thời gian an toàn (Timer Engine & State Recovery)** `[P0] [FE]`
  - [ ] Hỗ trợ đếm ngược (Pomodoro) và đếm xuôi (Stopwatch).
  - [ ] Hoạt động ngầm chính xác (sử dụng mốc thời gian `DateTime.now()` thay vì chỉ dựa vào `Timer.periodic`).
  - [ ] Khôi phục an toàn: Nếu tắt app, refresh trình duyệt hoặc có cuộc gọi đến, đồng hồ vẫn bảo toàn thời gian đã trôi qua.
  - *Done when:* Không bao giờ bị mất thời gian học của học sinh do tai nạn phần mềm.

- [ ] **FE-3.3: Màn hình Hoàn thành Phiên học & Đánh giá nhanh (Session Completion)** `[P0] [FE]`
  - [ ] Thông báo chúc mừng ngắn gọn kèm số phút đã học thực tế.
  - [ ] Đánh giá cảm xúc/mức độ tiếp thu nhanh chỉ với 1 chạm (5 emoji: 😫 😐 🙂 😄 🔥).
  - [ ] Nút hoàn thành task và trở về màn hình Hôm nay để tiếp tục việc kế tiếp.
  - *Done when:* Thao tác kết thúc phiên học chỉ mất dưới 3 giây.

- [ ] **BE-3.1: Lưu trữ Phiên học (Study Session Persistence)** `[P0] [BE]`
  - [ ] Lưu đầy đủ: `taskId`, `startTime`, `endTime`, `actualDurationMinutes`, `status`, `feedbackRating`.
  - [ ] Tự động cập nhật tổng thời gian học của môn học và của ngày hôm đó.
  - *Done when:* Lịch sử phiên học được ghi nhận chính xác vào cơ sở dữ liệu.

- [ ] **BE-3.2: Cơ chế khôi phục phiên học đang dở (Active Session Recovery)** `[P0] [BE]`
  - [ ] Lưu trạng thái phiên đang chạy vào local storage.
  - [ ] Khi người dùng mở lại app, tự động phát hiện phiên đang chạy và hỏi tiếp tục hay kết thúc.
  - *Done when:* Không để sót phiên học "mồ côi" làm sai lệch dữ liệu.

- [ ] **BE-3.3: Tổng hợp Thời gian học theo thời gian thực (Real-time Study Aggregation)** `[P1] [BE]`
  - [ ] Cập nhật widget tổng thời gian học ngay khi phiên học kết thúc.
  - *Done when:* Số phút học đồng bộ ngay lập tức trên dashboard.

- [ ] **QA-3.1: Ma trận kiểm thử Chế độ Học** `[P0] [QA]`
  - [ ] Test đếm giờ, tạm dừng, tiếp tục, hoàn thành sớm, hết giờ.
  - [ ] Test đưa app xuống nền (background), tắt màn hình, refresh trình duyệt web.
  - [ ] Test offline khi đang học và sau đó kết nối mạng lại để đồng bộ.
  - *Done when:* Tất cả các kịch bản ngoại lệ đều bảo toàn dữ liệu phiên học.

---

## 6. Sprint 4 — Trợ Lý AI Ngữ Cảnh & Hành Động (AI Assistant)

> **Mục tiêu:** Biến AI từ một chatbot trò chuyện thông thường thành một gia sư kèm cặp gắn liền với từng tác vụ học tập cụ thể.

- [ ] **AI-4.1: Xây dựng AI Context Engine (Bộ xử lý ngữ cảnh đa cấp độ)** `[P0] [AI]`
  - [ ] Cấp độ 0 (No context): Kiến thức phổ thông.
  - [ ] Cấp độ 1 (Task context): Tên bài, môn, ghi chú khi học sinh bấm "Hỏi AI về bài này".
  - [ ] Cấp độ 2 (Today context): Danh sách task hôm nay, thời gian rảnh, task quá hạn.
  - [ ] Cấp độ 3 (Learning Profile): Hiệu quả học tập các môn, điểm khó, lịch sử đánh giá cảm xúc.
  - [ ] Cấp độ 4 (Full Planning): Thông tin kỳ thi, mục tiêu điểm số, toàn bộ khối lượng công việc.
  - [ ] Nén context (Context compression): Không gửi raw database, chỉ gửi tóm tắt tối thiểu cần thiết.
  - *Done when:* AI luôn trả lời đúng ngữ cảnh của học sinh mà không cần học sinh phải gõ lại từ đầu.

- [ ] **AI-4.2: Tính năng Gợi ý "Tôi nên học gì bây giờ?" (Daily Coach)** `[P0] [AI]`
  - [ ] Phân tích tức thời dựa trên thời gian hiện tại, deadline và độ ưu tiên.
  - [ ] Trả về 1 khuyến nghị rõ ràng + 1 nút hành động trực tiếp [Bắt đầu task X].
  - *Done when:* Học sinh không bao giờ phải rơi vào trạng thái phân vân không biết làm gì.

- [ ] **AI-4.3: Tính năng Giải thích Bài học theo ngữ cảnh (Explain Contextual)** `[P0] [AI]`
  - [ ] Mở từ màn hình Task hoặc Study Mode.
  - [ ] Giải thích trọng tâm kiến thức của bài học hiện tại, hỗ trợ đặt câu hỏi đào sâu.
  - *Done when:* Cung cấp câu trả lời súc tích, dễ hiểu, bám sát môn học.

- [ ] **AI-4.4: Tính năng Lập Kế hoạch Ôn tập Thông minh (AI Study Planner)** `[P0] [AI]`
  - [ ] Tiếp nhận mục tiêu: Ngày thi, mục tiêu điểm, thời gian học mỗi ngày.
  - [ ] Tạo danh sách task cân bằng, không nhồi nhét quá tải.
  - [ ] **Bắt buộc có bước Preview**: Học sinh xem trước kế hoạch, chỉnh sửa rồi mới bấm [Áp dụng].
  - [ ] Khi áp dụng, tự động tạo thành các Tasks chuẩn trong hệ thống.
  - *Done when:* Kế hoạch biến thành các nhiệm vụ cụ thể, không ghi đè dữ liệu cũ bừa bãi.

- [ ] **AI-4.5: Phân tích Điểm yếu Học tập (Weakness Analyzer)** `[P1] [AI]`
  - [ ] Dựa vào đánh giá cảm xúc sau phiên học, tần suất dời task, môn học ít dành thời gian.
  - [ ] Chỉ kết luận khi có đủ dữ liệu (tối thiểu 3-5 phiên học); nếu chưa đủ thì thông báo trung thực "Chưa đủ dữ liệu".
  - *Done when:* Nhận xét khách quan, gợi ý hành động khắc phục cụ thể.

- [ ] **AI-4.6: Hệ thống Xác nhận Hành động An toàn (Action Confirmation System)** `[P0] [AI]`
  - [ ] Bắt buộc hiển thị modal xác nhận trước khi: Xóa task, dời lịch hàng loạt, thay đổi kế hoạch ôn thi.
  - [ ] Xử lý tính lũy thừa (Idempotency): Mỗi action có `action_id`, tránh gửi lặp nhiều lần tạo duplicate tasks.
  - *Done when:* AI an toàn tuyệt đối, không phá hỏng dữ liệu của người dùng.

- [ ] **AI-4.7: Xử lý Lỗi & Dự phòng Ngoại tuyến (AI Fallback & Offline Handling)** `[P0] [AI]`
  - [ ] Khi mất mạng hoặc API lỗi: Hiển thị thông báo thân thiện "AI tạm thời không khả dụng, bạn vẫn có thể tự học bình thường".
  - [ ] Tuyệt đối không bao giờ để lỗi AI làm treo app hoặc chặn học sinh học bài.
  - *Done when:* Trải nghiệm ứng dụng luôn vững chắc dù AI có phản hồi chậm hay đứt mạng.

- [ ] **FE-4.1: Tái thiết kế Giao diện Trợ lý AI (AI Screen Redesign)** `[P0] [FE]`
  - [ ] Không để màn hình chat trống trơn nhàm chán; hiển thị các Quick Actions:
    - [Hôm nay nên học gì?]
    - [Lập kế hoạch tuần này]
    - [Tôi đang yếu phần nào?]
    - [Giải thích bài tập]
  - [ ] Card Action Preview trực quan khi AI đề xuất tạo/sửa task.
  - [ ] Tích hợp nút Đánh giá phản hồi 👍/👎 cho từng câu trả lời của AI.
  - *Done when:* Màn hình AI sinh động, định hướng người dùng vào hành động thực tế.

- [ ] **QA-4.1: Bộ kiểm thử Trợ lý AI** `[P0] [QA]`
  - [ ] Test gợi ý task, tạo task qua ngôn ngữ tự nhiên.
  - [ ] Test xác nhận trước khi xóa/sửa task.
  - [ ] Test xử lý khi timeout, mất mạng, phản hồi JSON lỗi.
  - *Done when:* Toàn bộ luồng tương tác AI an toàn và ổn định.

---

## 7. Sprint 5 — Theo Dõi Tiến Độ & Quản Lý Kỳ Thi (Progress & Exam)

> **Mục tiêu:** Cung cấp bức tranh phản ánh năng lực thực tế và mục tiêu kỳ thi rõ ràng mà không biến app thành bảng dashboard số liệu khô khan.

- [ ] **FE-5.1: Màn hình Tổng quan Tiến độ (Progress Overview Screen)** `[P0] [FE]`
  - [ ] Hiển thị hoàn thành hôm nay, thời gian học hôm nay.
  - [ ] Xu hướng tuần: Tổng thời lượng học, tỉ lệ hoàn thành nhiệm vụ theo tuần.
  - [ ] Biểu đồ trực quan, tối giản, dễ nắm bắt chỉ trong 5 giây.
  - *Done when:* Học sinh hiểu rõ mình đang tiến bộ hay thụt lùi mà không bị ngợp số liệu.

- [ ] **FE-5.2: Tiến độ chi tiết theo từng Môn học (Subject Progress)** `[P1] [FE]`
  - [ ] Thời gian đã dành cho môn, số bài đã học, đánh giá mức độ hiểu bài trung bình.
  - [ ] Cảnh báo môn học bị bỏ quên hoặc lệch so với mục tiêu ban đầu.
  - *Done when:* Giúp học sinh phân bổ lại thời gian học giữa các môn hợp lý hơn.

- [ ] **FE-5.3: Màn hình Quản lý Kỳ thi (Exam Management Screen)** `[P0] [FE]`
  - [ ] Kỳ thi chính nổi bật: Tên kỳ thi (VD: THPT Quốc Gia), ngày thi, đồng hồ đếm ngược số ngày.
  - [ ] Danh sách các môn thi trong kỳ thi kèm điểm số mục tiêu.
  - [ ] Hỗ trợ thêm/sửa/đổi ngày thi dễ dàng.
  - *Done when:* Mục tiêu kỳ thi luôn hiện diện rõ ràng làm kim chỉ nam cho việc học.

- [ ] **BE-5.1: Bộ tính toán Dữ liệu Tiến độ (Progress Aggregation Engine)** `[P0] [BE]`
  - [ ] Aggregation theo ngày, tuần, tháng, môn học và kỳ thi.
  - [ ] Xử lý đúng múi giờ và mốc thời gian bắt đầu ngày/tuần.
  - *Done when:* Kết quả phân tích số liệu chuẩn xác 100% so với log phiên học thực tế.

- [ ] **BE-5.2: Quản lý Dữ liệu Kỳ thi (Exam Data Service)** `[P0] [BE]`
  - [ ] CRUD kỳ thi, chỉ định Kỳ thi chính (Primary Exam).
  - [ ] Tự động tính toán số ngày còn lại theo thời gian thực.
  - *Done when:* Dữ liệu kỳ thi lưu trữ an toàn, đồng bộ Supabase.

- [ ] **AI-5.1: Phân tích & Nhận định Tiến độ từ AI (Progress Insights)** `[P1] [AI]`
  - [ ] Đưa ra nhận xét khách quan dựa trên số liệu thật (Ví dụ: "Tuần này bạn học Toán rất đều, nhưng môn Lý đang bị trễ 2 buổi so với kế hoạch").
  - [ ] Đề xuất hành động điều chỉnh cụ thể.
  - *Done when:* Nhận định hữu ích, kích thích hành động cải thiện.

- [ ] **QA-5.1: Bộ kiểm thử Tiến độ & Kỳ thi** `[P0] [QA]`
  - [ ] Test tính toán số liệu tuần, chuyển giao giữa các tuần.
  - [ ] Test đếm ngược ngày thi, thay đổi ngày thi.
  - *Done when:* Kiểm thử số liệu và logic ngày tháng chính xác tuyệt đối.

---

## 8. Sprint 6 — Tối Ưu Giao Diện Đa Thiết Bị & Thẩm Mỹ (Responsive & Polish)

> **Mục tiêu:** Mang lại trải nghiệm mượt mà, cao cấp trên điện thoại di động, máy tính bảng và màn hình máy tính lớn.

- [ ] **FE-6.1: Tối ưu Giao diện Mobile (Mobile Polish)** `[P0] [FE]`
  - [ ] Kiểm thử trên các kích thước: màn hình nhỏ, màn hình tiêu chuẩn, màn hình lớn.
  - [ ] Không để xảy ra tràn viền ngang (overflow error).
  - [ ] Touch targets thoải mái, bàn phím ảo không che khuất ô nhập liệu.
  - *Done when:* Trải nghiệm mượt mà như ứng dụng bản địa (native feel).

- [ ] **FE-6.2: Tối ưu Giao diện Tablet (Tablet Adaptive Layout)** `[P1] [FE]`
  - [ ] Bố cục thích ứng linh hoạt, tận dụng không gian rộng rãi thay vì phóng to giao diện điện thoại.
  - *Done when:* Giao diện trên máy tính bảng hiển thị khoa học và cân đối.

- [ ] **FE-6.3: Tối ưu Giao diện Desktop / Web lớn (Desktop Layout)** `[P0] [FE]`
  - [ ] Sidebar trái cố định hoặc thu gọn tiện lợi.
  - [ ] Nội dung chính giới hạn độ rộng hợp lý (max-width), hỗ trợ cột phụ trợ (countdown, lịch nhanh).
  - *Done when:* Desktop chuyên nghiệp, tối ưu cho việc học tập bằng laptop/PC.

- [ ] **FE-6.4: Tinh chỉnh Phân cấp Thị giác (Visual Hierarchy)** `[P0] [FE]`
  - [ ] Áp dụng đúng thứ tự: **Hành động chính → Nhiệm vụ → Ngữ cảnh → Thông tin chi tiết → Trang trí**.
  - [ ] Nút CTA luôn nổi bật nhất; loại bỏ hoặc thu nhỏ các chi tiết trang trí gây rối mắt.
  - *Done when:* Mọi màn hình đều có 1 điểm nhấn hành động rõ ràng.

- [ ] **FE-6.5: Đồng bộ các Trạng thái Rỗng, Đang tải & Báo lỗi (States Polish)** `[P0] [FE]`
  - [ ] Màn hình rỗng có hình minh họa nhẹ nhàng kèm nút hành động (VD: Chưa có task → Nút "Thêm nhiệm vụ ngay").
  - [ ] Skeleton loaders cho cảm giác tải trang mượt mà.
  - [ ] Thông báo lỗi lịch sự kèm nút thử lại.
  - *Done when:* Không còn màn hình trắng tinh hoặc thông báo lỗi kỹ thuật khó hiểu.

- [ ] **FE-6.6: Hiệu ứng Chuyển động & Phản hồi Rung (Micro-interactions & Haptics)** `[P2] [FE]`
  - [ ] Haptic feedback nhẹ nhàng khi tick hoàn thành nhiệm vụ và khi kết thúc đếm giờ.
  - [ ] Hỗ trợ chế độ giảm chuyển động (`Reduced Motion`) cho học sinh nhạy cảm thị giác.
  - *Done when:* Ứng dụng sống động, đem lại cảm giác thành tựu khi hoàn thành bài học.

- [ ] **QA-6.1: Ma trận Kiểm thử Responsive Toàn diện** `[P0] [QA]`
  - [ ] Test trên Mobile (Android/iOS), Tablet, Desktop Web (Chrome, Edge, Safari).
  - *Done when:* Không còn lỗi vỡ layout trên bất kỳ thiết bị mục tiêu nào.

---

## 9. Sprint 7 — Ổn Định Toàn Diện, Kiểm Thử E2E & Release Gates (Stabilization)

> **Mục tiêu:** Kiểm thử toàn bộ các kịch bản người dùng thực tế và vượt qua các cổng kiểm soát chất lượng (Release Gates) trước khi đưa vào sản xuất.

- [ ] **E2E-1: Kịch bản A — Tạo mới và Hoàn thành Nhiệm vụ** `[P0] [QA]`
  - [ ] Tạo task mới → Xuất hiện ở Hôm nay → Bấm "Bắt đầu học" → Vào Chế độ học tập trung → Hoàn thành phiên → Đánh giá cảm xúc → Số liệu cập nhật vào Tiến độ.
  - *Pass criteria:* Không mất dữ liệu, thời gian học chuẩn, tiến độ tăng ngay.

- [ ] **E2E-2: Kịch bản B — Lập Kế hoạch Ôn tập bằng AI** `[P0] [QA]`
  - [ ] Yêu cầu AI lập kế hoạch → Xem bản xem trước (Preview) → Xác nhận [Áp dụng] → Các task tự động tạo trong Hôm nay → Bắt đầu học bình thường.
  - *Pass criteria:* Không tạo duplicate task, task tạo bởi AI hoạt động y như task thủ công.

- [ ] **E2E-3: Kịch bản C — Dời lịch Nhiệm vụ (Reschedule Flow)** `[P0] [QA]`
  - [ ] Nhiệm vụ hôm nay chưa xong → Chọn dời sang ngày mai → Biến mất khỏi Hôm nay, xuất hiện ở ngày mai.
  - *Pass criteria:* ID task giữ nguyên, lịch sử không bị đứt đoạn.

- [ ] **E2E-4: Kịch bản D — Học Ngoại tuyến và Đồng bộ lại (Offline-to-Online Flow)** `[P0] [QA]`
  - [ ] Ngắt mạng hoàn toàn → Mở app xem task → Học 25 phút trong Chế độ học → Hoàn thành phiên → Bật lại mạng → Dữ liệu tự động sync lên Supabase.
  - *Pass criteria:* Toàn bộ dữ liệu phiên học ngoại tuyến được bảo toàn, không bị ghi đè hay mất mát.

- [ ] **GATE-1: Kiểm tra 5 Cổng Release (Release Gates Check)** `[P0] [Lead]`
  - [ ] **Gate 1 (Core UX):** Màn hình Hôm nay, Tasks, Bắt đầu học, Chế độ học, Tiến độ hoạt động hoàn hảo.
  - [ ] **Gate 2 (AI):** Gợi ý, giải thích, lập kế hoạch, xác nhận hành động, fallback khi lỗi đều an toàn.
  - [ ] **Gate 3 (Reliability):** Ngoại tuyến, đồng bộ Supabase, khôi phục phiên học dở, zero data loss.
  - [ ] **Gate 4 (Responsive):** Mượt mà trên mobile và desktop.
  - [ ] **Gate 5 (Polish):** Trạng thái loading/error/empty chuẩn chỉnh, không có console runtime error nào.
  - *Pass criteria:* Đạt 5/5 cổng để sẵn sàng phát hành chính thức.

- [ ] **QA-7.1: Tổng duyệt Hồi quy Cuối cùng (Final Regression Sign-off)** `[P0] [QA]`
  - [ ] Chạy lại toàn bộ bộ test `flutter test`, kiểm tra `flutter analyze` sạch 100%.
  - *Done when:* Ứng dụng ổn định cao nhất, đạt mục tiêu đề ra.

---

## 10. Nhật Ký Cập Nhật Tiến Trình Triển Khai (Progress Change Log)

> Ghi chú lại ngày giờ và nội dung cụ thể mỗi khi hoàn thành 1 việc hoặc cập nhật trạng thái checklist.

| Thời gian | Mã Task | Nội dung thực hiện | Người thực hiện / Agent | Trạng thái |
|---|---|---|---|---|
| *2026-10-01* | **INIT** | Khởi tạo bảng Todo list theo 3 tài liệu cải tổ v2 | AI Assistant | ✅ Hoàn thành |
| ... | ... | ... | ... | ... |
