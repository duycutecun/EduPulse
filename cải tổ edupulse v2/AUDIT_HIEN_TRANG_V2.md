# EduPulse v2 — Báo Cáo Rà Soát Hiện Trạng (Sprint 0 Audit Report)

> **Mã nhiệm vụ:** `FE-0.1`, `BE-0.1`, `AI-0.1`, `QA-0.1`  
> **Thời gian thực hiện:** 2026-10-01  
> **Người thực hiện:** Antigravity AI Assistant  
> **Trạng thái Baseline Tests:** ✅ **188/188 tests passed**, `flutter test` sạch 100%.

---

## 1. Rà Soát Màn Hình & Bản Đồ Điều Hướng (FE-0.1)

### 1.1. Hiện trạng cấu trúc điều hướng (v1)
- **Mobile Navigation hiện tại:** 3 tab tại `lib/app/main_shell.dart`:
  1. `Học` (`HomeScreen`) — chứa Hero Countdown, Nhiệm vụ hôm nay, Mascot, Copilot Hub, AI Readiness.
  2. `Tập trung` (`StudyScreen`) — chứa Pomodoro, Đồng hồ đếm giờ, Nhật ký học tập, Biểu đồ.
  3. `Tôi` (`AccountScreen`) — chứa Cài đặt, Thông tin cá nhân, Hồ sơ học tập.
- **Desktop Sidebar hiện tại:** 3 tab chính (`Học`, `Tập trung`, `Tôi`) + các menu phụ (`Calendar`, `Goals`, `Focus`, `Notes`, `AI Coach`).

### 1.2. Bản đồ chuyển đổi sang Điều Hướng Mới (v2)
Theo đặc tả v2, kiến trúc điều hướng sẽ chuyển đổi thành **4 tab chính**:

| Tab v2 | Screen tương ứng | Chức năng cốt lõi | Chuyển đổi từ v1 |
|---|---|---|---|
| **1. Hôm nay** | `TodayScreen` (tái cấu trúc từ `HomeScreen`) | Trả lời: *"Hôm nay tôi cần học gì?"*. Đưa Tasks lên đầu, nút Bắt đầu học nổi bật nhất, thu nhỏ countdown thành ngữ cảnh phụ. | Giữ luồng task, bỏ hero countdown chiếm chỗ, ẩn các khối gamification gây xao nhãng. |
| **2. AI** | `AiCoachScreen` (đưa lên làm Tab chính thức) | Trả lời: *"EduPulse có thể giúp gì cho tôi ngay bây giờ?"*. Tích hợp Quick Actions, Action Preview, Context-aware Assistant. | Trước đây mở dạng Modal/BottomSheet từ `HomeScreen` hoặc menu phụ desktop; nay thành Tab độc lập. |
| **3. Tiến độ** | `ProgressScreen` (tách và làm gọn từ `StudyScreen`) | Trả lời: *"Tôi có đang thực sự tiến bộ không?"*. Tổng kết ngày/tuần, mức độ hoàn thành theo môn, xu hướng, phân tích điểm yếu. | Chuyển phần Analytics & Logs từ tab `Tập trung` sang đây, bỏ bớt biểu đồ rườm rà. |
| **4. Tôi** | `AccountScreen` | Trả lời: *"EduPulse hoạt động cho tôi như thế nào?"*. Quản lý mục tiêu kỳ thi (`ExamsPage`), Hồ sơ học tập (`LearningProfileScreen`), Cài đặt thông báo & dữ liệu. | Tinh giản giao diện, chuyển `Kỳ thi` thành mục phụ trợ rõ ràng. |

### 1.3. Định danh các thành phần Gamification cần ẩn khỏi Core UX
- `mascot_companion_modal.dart` & `mascot_avatar.dart`: Ẩn khỏi màn hình chính, chỉ giữ lại như bạn đồng hành nhẹ nhàng trong Cài đặt/Tôi hoặc xuất hiện tinh tế khi hoàn thành session.
- Bộ đếm XP & Thăng hạng Level: Không hiển thị trên card nhiệm vụ hay màn hình Hôm nay.
- Bộ đếm Streak khổng lồ: Bỏ khỏi header màn hình chính; vẫn lưu dữ liệu trong background để backward-compatible.
- Cơ chế bùa / bốc quẻ / trang phục: Ẩn hoàn toàn khỏi luồng học tập chính.

---

## 2. Rà Soát Data Model & Single Source of Truth (BE-0.1, BE-0.2)

### 2.1. Vị trí Model hiện tại
- **Tasks:** `TodayTask` nằm trong `lib/features/study/domain/models/study_models.dart`.
  - Có đầy đủ các trường: `id`, `title`, `isDone`, `subject`, `topic`, `priority`, `estimateMinutes`, `deadline`, `scheduledAt`, `note`, `status`, `skipReason`, `rescheduleCount`.
  - Đã có khả năng lưu trữ offline-first qua `StorageService` và sync Supabase qua `SupabaseService`.
- **Study Sessions:** `StudySession` nằm trong `lib/features/study/domain/models/study_models.dart`.
  - Đã có liên kết `taskId`, `plannedMinutes`, `actualMinutes`, và đánh giá phản hồi (`mood`, `focus`, `difficulty`, `understanding`, `effectiveness`).
- **Exams:** `ExamModel` nằm trong `lib/features/exams/domain/models/exam_model.dart`.
  - Hỗ trợ ngày thi, đếm ngược, môn học thi, điểm mục tiêu.

### 2.2. Kết luận Single Source of Truth (BE-0.2)
- Toàn bộ tính năng AI (tạo task, dời lịch, chia nhỏ) và các thao tác thủ công đều dùng chung model `TodayTask`.
- Không tạo thêm bảng hay model Task phụ nào khác.
- Task status chuẩn hóa qua State Machine: `scheduled`, `started`, `completed`, `not_completed`, `rescheduled`.

---

## 3. Hợp Đồng Hành Động AI — Action Contract (AI-0.1)

AI trong EduPulse v2 không xuất văn bản tự do khi cần thao tác dữ liệu. Mọi hành động đều tuân thủ cấu trúc JSON:
- `recommend`: Gợi ý task nên học kèm lý do.
- `create_task`: Tạo task mới (yêu cầu đủ title, subject, duration).
- `update_task` / `edit_task`: Chỉnh sửa nội dung task hiện tại (bảo toàn ID).
- `delete_task`: Xóa task (**Bắt buộc Confirmation modal**).
- `reschedule_task`: Dời lịch task (cập nhật `scheduledAt`, tăng `rescheduleCount`).
- `split_task`: Chia 1 task dài thành các phần nhỏ 25-30 phút (**Bắt buộc Confirmation preview**).
- `create_plan`: Tạo danh sách task cho kỳ thi (**Bắt buộc Preview trước khi Apply**).
- `explain`: Hỗ trợ giải thích kiến thức theo ngữ cảnh task đang học.

---

## 4. Kết Quả Kiểm Thử Hồi Quy Baseline (QA-0.1)

- Đã thực thi lệnh `flutter test`.
- Kết quả: **188/188 tests passed** (0 failures, 0 errors).
- Toàn bộ các tính năng hiện tại (Data migration, Offline storage, Quick Add parser, Bottom sheet, Adaptive policy, High contrast, AI Citations) đều đạt chuẩn và có test bảo vệ vững chắc.

---

## 5. Nhật Ký Tiến Trình Triển Khai (Progress Log)

> Mỗi hạng mục hoàn thành được ghi lại tại đây kèm file đã thay đổi và kết quả kiểm chứng.
> Dùng file này để biết đã làm đến đâu.

**Trạng thái Sprint 4 (2026-10-03): 9/9 hạng mục.** Xong: AI-4.1, AI-4.2,
AI-4.3, AI-4.4, AI-4.5, AI-4.6, AI-4.7, FE-4.1, QA-4.1. Context engine có
`AiStudyContext.build`, Daily Coach qua `AiDailyBriefing`, giải thích qua
`onOpenAiCoachWith`, AI plan đã kịch bản, weakness analyzer trong
`_analyzeWeakTopics`, xác nhận xoá Task và fallback offline đều có trong
`ai_coach_screen`/`ai_copilot_service`.

**Trạng thái Sprint 3 (2026-10-03): 7/7 hạng mục.** Xong: BE-3.1, BE-3.2,
FE-3.2, BE-3.3, FE-3.3, QA-3.1, FE-3.1. Tạo đường ghi thống nhất
`StudySession`, dừng ghi trùng `StudyLog` ở vòng pomodoro, gộp nhật ký/session
bằng `StudyTimelineEntry`, khôi phục active session an toàn hơn, migration v3
dọn dữ liệu Pomodoro legacy, quick rating 1 chạm ở post-focus sheet và revision
để Home cập nhật tổng giờ ngay.

**Trạng thái Sprint 2 (2026-10-02): 10/10 hạng mục.** Xong: BE-2.1, BE-2.2,
BE-2.3, FE-2.1, FE-2.2, FE-2.3, FE-2.4, FE-2.5, QA-2.1, AI-2.1. Việc dọn
đường ghi Task cũng đã xong, và 2 mục còn thiếu của FE-2.2 (tài liệu đính kèm
+ lịch sử phiên học) đã đóng ở Sprint 3. Còn nợ nhỏ: 6 chỗ **đọc**
`StudySession` vẫn tự giải mã JSON thay vì qua `StudySessionRepository` (đã
có đường đọc duy nhất) — không sai dữ liệu nhưng nên dọn cho nhất quán.

### 2026-10-02 — Sprint 2 bắt đầu

#### Phát hiện quan trọng: Sprint 2 code chưa từng được nối vào app

Rà soát trước khi code cho thấy toàn bộ thư mục `lib/features/tasks/` **đã được viết ở Sprint 0/1 nhưng là dead code — không nơi nào import**. Cụ thể:

| File | Trạng thái trước | Vấn đề |
|---|---|---|
| `task_state.dart` | Đã viết | `canTransition` cho phép `scheduled → bất kỳ` (không chặn được gì) |
| `task_repository.dart` | Đã viết | Gọi `SupabaseService.syncToCloud()` **không tồn tại** → không compile; `rescheduleTask` bypass state machine; không có timestamp |
| `task_card.dart` | Đã viết | 0 nơi sử dụng |
| `task_detail_sheet.dart` | Đã viết | Sai import path → không compile |
| `task_edit_sheet.dart` | Đã viết | 15+ lỗi token, edit dựng lại object → mất field |
| `reschedule_dialog.dart` | Đã viết | Lỗi token, không nối |

Màn hình Hôm nay vẫn dùng `StorageService` trực tiếp với logic nhúng trong `TodayMissionCard` — **vi phạm nguyên tắc Single Source of Truth (BE-0.2)**.

**Trạng thái `flutter analyze` trước khi sửa: 73 lỗi.**

---

### ✅ BE-2.2 — Task State Machine (hoàn thành)

**File:** `lib/features/tasks/domain/models/task_state.dart`

- Chuyển `canTransition` từ `switch if → true` (lỏng lẻ) sang bảng tra `_allowed` khai báo tường minh toàn bộ vòng đời.
- Chặn 3 chuyển trạng thái nguy hiểm trước đây bị cho qua:
  - `completed → rescheduled` (phá lịch sử học tập)
  - `completed → notCompleted` / `completed → started`
  - `started → rescheduled` (phải đi qua `notCompleted`)
- Thêm `TaskStatus.label`, `TaskStatus.isTerminal` để UI không lặp lại switch.
- Thêm `tryTransition()` trả về trạng thái mới hoặc `null` nếu không hợp lệ.
- Giữ nguyên **tên chuỗi lưu trữ** (`todo`/`completed`/`skipped`) → dữ liệu v1 không phải migrate.

**Kiểm chứng:** `flutter analyze lib` → 73 lỗi còn lại (chỉ do 3 widget token), không lỗi logic.

---

### ✅ BE-2.1 — Task Repository làm Single Write Path (hoàn thành)

**File:** `lib/features/tasks/domain/repositories/task_repository.dart` (viết lại toàn bộ)

| Hạng mục | Trước | Sau |
|---|---|---|
| API sync cloud | `syncToCloud()` **không tồn tại** → crash | `SupabaseService.syncTasks()` + debounce 2s |
| Trạng thái báo lỗi | `debugPrint` rồi ghi tiếp | `TaskMutationResult` — chặn ghi, trả thông điệp tiếng Việt |
| `rescheduleTask` | Bypass state machine, reset cả `skipReason` vô điều kiện | Qua state machine, chặn task đã hoàn thành, giữ giờ hẹn |
| Lọc "hôm nay" | `getTodayTasks()` — 1 bản | `getTasksForDay()` — **bản duy nhất**, xoá bản trùng |
| Timestamp | Không có | `createdAt`/`updatedAt`, đóng dấu mỗi lần ghi |
| Phản ứng UI | UI tự `setState` rải rác | `revision` ValueNotifier |
| Chu trình AI | Gọi tay ở từng chỗ | Tự gọi trong `_afterMutation()` |
| Xóa + Undo | Không hoàn tác được | `DeletedTaskRef` giữ `id` + vị trí gốc |
| Task đã xong vẫn hiện "hôm nay" | Có | `isTerminal` loại khỏi ngày mới |

**`TodayTask` (BE-2.1 yêu cầu field bắt buộc):**
- Thêm `createdAt`, `updatedAt` — nullable + fallback nên **task cũ không có trường này vẫn parse được**.
- Bỏ `final` khỏi `subject/topic/priority/estimateMinutes/note/goalId/subtasks/recurrence` → edit không phải dựng lại object (trước đó dễ mất `createdAt` và field không nhớ).
- Thêm `copyWith()` giữ nguyên `id`.

**Vá design tokens (phát hiện khi fix):**
- `AppTokens`: thiếu `space6`, `space10`, `space14` → bổ sung (thang 2px).
- `AppColors`: thiếu nhóm ngữ nghĩa → bổ sung `background`, `surface`, `text`, `textSubtle`, `success`, `warning`, `error`, `info` (+ biến thể Dark/Light) theo đặc tả §10.3.
- Sửa lỗi `Radius.circular(AppTokens.rXl)` ở 3 file (`rXl` đã là `Radius` sẵn).

**Kiểm chứng:** `flutter analyze lib` → **No issues found!** (0 lỗi, 0 warning, 0 info).

---

### ✅ BE-2.3 — Tương thích Migration dữ liệu cũ (hoàn thành)

**File:** `lib/core/migration/data_migration.dart` (`currentSchemaVersion` 1 → **2**)

Thêm 3 bước migration mới, tất cả **idempotent** và **không bao giờ xoá dữ liệu**:

| Bước | Vấn đề thật đang xảy ra | Cách xử lý |
|---|---|---|
| `recover_orphan_tasks` | Task có JSON trong storage nhưng `id` mất khỏi `today_task_ids` (app bị kill giữa lúc ghi) → **task biến mất vĩnh viễn khỏi UI** | Dò mọi key `task_*` (đúng tiền tố `StorageService` dùng), parse thành công thì thêm lại id vào danh sách |
| `backfill_task_timestamps` | Task v1 không có `createdAt`/`updatedAt` dù BE-2.1 đã yêu cầu là bắt buộc | Suy ra từ `scheduledAt` → `deadline` → `now` (không bịa đặt) |
| `heal_task_consistency` | v1 cho phép `isDone` và `status` lệch nhau vì nhiều nơi tự ghi → state machine và UI hiển thị **khác nhau** | Chọn `status` làm nguồn chân lý, `isDone` là cờ dẩn xuất; giữ nguyên `skipReason` |

Đặc biệt: `skipped` giữ `isDone = false` và **không xoá `skipReason`** — lý do bỏ qua là dữ liệu AI cần dùng ở Sprint 4 (AI-4.5).

**Kiểm chứng:** `flutter analyze lib` → No issues found.

> 🐛 **Bug do chính BE-2.3 tạo ra, phát hiện khi viết test (QA-2.1):** bản đầu quét
> key `today_task_*`, trong khi `StorageService` thật ra lưu ở `task_$id`. Bước cứu
> task mồ côi vì thế **luôn im lặng không làm gì** — đúng kiểu bug "có code, có
> test cũ vẫn xanh, nhưng tính năng chết". Đã sửa bằng hằng số
> `_taskKeyPrefix` và test `task mồ côi (mất khỏi danh sách id) được cứu lại`.

---

### ✅ FE-2.1 / FE-2.2 / FE-2.4 / FE-2.5 — Nối toàn bộ UI Task vào repository

**Trước khi làm:** Sprint 2 có đủ model, repository, state machine, migration —
nhưng màn "Hôm nay" vẫn tự ghi thẳng vào `StorageService`, tự xoá bằng
`Dismissible`, tự lọc ngày. Nghĩa là các hạng mục BE vừa xong **không có đường
đi thật**.

| Nơi | Việc đã làm |
|---|---|
| `home_screen.dart` | create / toggle / skip / reschedule / delete / edit / detail / reorder / recurring / day-balance → **tất cả** qua `TaskRepository`; nghe `TaskRepository.instance.revision` để tự vẽ lại |
| `home_screen.dart` | `_loadTasks` đọc qua `repo.getTasksForDay()`; danh sách môn lấy từ `AppSubjects` |
| `today_mission_card.dart` | bỏ `Dismissible` (xóa không hỏi) → dùng `TaskCard` + menu có xác nhận |
| `task_card.dart` | nhãn accessibility tách rõ **hàng** (mở chi tiết) và **nút tròn** (đánh dấu hoàn thành); hiện giờ học, lý do bỏ qua, cảnh báo dời ≥ 3 lần; thêm hành động "Chia nhỏ" |
| `task_detail_sheet.dart` | dùng catalog + status chip; đánh dấu hoàn thành ngay trong sheet; nút "Chia nhỏ bài học" chạy thật (không phụ thuộc AI) |
| `reschedule_dialog.dart` | ngưỡng cảnh báo đổi `≥ 2` → `≥ 3` (đúng đặc tả); thêm lựa chọn "Hôm nay"; nút Chia nhỏ + Gợi ý AI |
| `delete_task_dialog.dart` (mới) | `showConfirmDelete()` nêu đích danh tên task; Undo SnackBar 5 giây dùng chung |
| `split_task_dialog.dart` (mới) | xem trước trước khi chia, chọn 2–4 phần, tổng phút không đổi |
| `task_repository.dart` | thêm `reorderTasks()`, `splitTask()`, `undoSplit()`, `TaskSplitResult` |

**Vì sao `splitTask()` an toàn với dữ liệu:** ghi **hết** phần con trước, kiểm tra
lại đã tồn tại, mới xoá task gốc. Hỏng ở bước nào thì task gốc còn nguyên.
`undoSplit()` xoá phần con và trả task gốc về **đúng vị trí cũ**.

**Kiểm chứng:** `flutter analyze lib` → sạch; `flutter test` → **278/278 pass**.

---

### ✅ QA-2.1 — Bộ test Task CRUD

**File:** `test/task_repository_test.dart` (mới, **50 test**)

Bao phủ đúng những chỗ dễ hỏng nhất: tạo/sửa (giữ `id` + `createdAt`), chuyển
trạng thái sai bị từ chối **và không ghi lại `updatedAt`**, dời lịch nhiều lần
vẫn chỉ có 1 task, xoá → hoàn tác giữ đúng thứ tự, `reorderTasks` không làm mất
task, `getTasksForDay` không nuốt task quá hạn, JSON hỏng không làm sập danh
sách, chia nhỏ + hoàn tác chia nhỏ, migration v2 (backfill / cứu task mồ côi /
vá mâu thuẫn `isDone`-`status` / idempotent).

**Kiểm chứng:** `flutter test` → **278/278 pass**; `flutter analyze lib test` → sạch.

---

### ✅ AI-2.1 — AI dùng chung đường ghi Task với người dùng

**File:** `lib/core/ai/ai_copilot_service.dart`, `lib/core/ai/ai_chat_actions.dart`,
`lib/features/tasks/domain/repositories/task_repository.dart`

Lỗi thật đã sửa:

| Vấn đề | Hậu quả |
|---|---|
| `addTask` tự ghi thẳng `StorageService.setTodayTaskJson` + tự thêm id | AI **bypass** hoàn toàn repository: không có `createdAt`, không có chống trùng, không phát tín hiệu `revision` ⇒ Home có thể không vẽ lại, AI vẫn tạo thêm bản sao |
| AI ghi `subject: 'Toán'` (không emoji) | Sinh **môn mới** song song với `'📐 Toán'` đang lưu ⇒ `groupBy(subject)` tách làm đôi, Sprint 5 thống kê sai |
| Không có hành động sửa / dời / xoá | AI chỉ tạo được task; các thay đổi còn lại người dùng phải tự làm thủ công |

Cách sửa:

- `TaskRepository.createTaskIfMissing()` — chặn trùng trước khi ghi. Trùng =
  tên (đã **bỏ dấu**, bỏ dấu câu, không phân biệt hoa/thường) + môn đã chuẩn hoá
  + **cùng ngày lên lịch**. Duyệt cả task đã hoàn thành trong ngày: nếu AI gợi
  ý lại đúng việc vừa làm xong thì đó vẫn là trùng.
- `AiActionType` thêm `editTask` / `rescheduleTask` / `deleteTask`, parser nhận
  `type: edit_task | reschedule_task | delete_task`.
- Quy tắc bắt buộc cho 3 hành động này: **không tìm thấy task khớp tên thì báo,
  không tạo mới**; **xoá phải qua đúng hộp thoại xác nhận của người dùng**
  (FE-2.5); **sửa mở form sửa, AI không tự đổi**; mọi ghi qua repository.
- Undo của AI cũng đi qua `deleteTask` → `restoreTask` (cùng đường với người
  dùng) thay vì xoá tay.

**Chi tiết đáng ghi nhận:** bộ lọc "task nào thuộc ngày hôm nay" được tách thành
`_belongsToDay()` dùng chung, vì `findDuplicate` cần biến thể *có* tính task đã
hoàn thành. Hai bản viết tay chắc chắn sẽ lệch nhau.

**Kiểm chứng:**
- `test/ai_task_actions_test.dart` (mới, **17 test**): chặn trùng (cùng ngày /
  khác ngày / khác môn / khác hoa-thường-dấu / task đã xong), `ignoreId`, parser
  3 hành động mới, chuẩn hoá môn của AI.
- `flutter test` → **295/295 pass**; `flutter analyze lib test` → sạch.

---

### ✅ Dọn đường ghi Task cũ — Single Write Path là toàn app

**Vì sao làm:** sau AI-2.1, grep còn **9 chỗ** tự ghi thẳng `StorageService`
ở 5 màn vẫn chạy thật (`study_screen` ×2, `calendar_screen` ×3,
`onboarding_screen`, `quiz_play_screen`, `ai_plan_screen`). Chúng dùng chung
khoá dữ liệu nên không sai dữ liệu, nhưng thiếu `createdAt`, không chống
trùng, không có Undo — tức là mỗi màn là một luật riêng.

| Màn | Trước | Sau |
|---|---|---|
| `study_screen` (ôn củng cố, phiên bù điểm) | ghi tay, tự thêm id | `createTaskIfMissing` + báo rõ khi bị chặn trùng |
| `ai_plan_screen` (đề xuất kế hoạch) | tự so tiêu đề không dấu, bỏ qua môn và ngày | `createTaskIfMissing` (tên bỏ dấu + môn + ngày) |
| `onboarding_screen` (seed nhiệm vụ) | ghi tay, tự cộng dồn id | `createTaskIfMissing`; điều kiện "chưa có task nào" dùng `getAllTasks()` |
| `quiz_play_screen` (ôn lại câu sai) | ghi tay | `createTaskIfMissing` — luyện lại cùng chủ đề trong ngày không tạo task trùng |
| `calendar_screen` (dời lịch) | `setTodayTaskJson` — **reset giờ về 00:00**, không tăng `rescheduleCount` | `rescheduleTask` — giữ giờ đã hẹn, tăng bộ đếm, chặn dời task đã xong |

Mọi màn cũng chuẩn hoá `subject` qua `AppSubjects.normalize()` — trước đó ghi
`'Toán'` trong khi Home lọc theo `'📐 Toán'`, nên nhiệm vụ tạo từ các màn này
có thể không hiện ở nhóm môn.

**Chống tái phạm:** thêm test quét mã nguồn (`Single Write Path`) chặn mọi
lời gọi `setTodayTaskJson`/`setTodayTaskIds`/`removeTodayTaskJson` ngoài 5 tệp
hạ tầng được phép. Test đã được thử bằng cách cố tình tạo một tệp vi phạm và
bắt đúng tên tệp.

**Kiểm chứng:** `flutter test` → **296/296 pass**; `flutter analyze lib test` → sạch.

---

### ✅ FE-2.2 (phần còn thiếu) — Tài liệu kèm theo + lịch sử phiên học

**File:** `lib/features/tasks/domain/models/task_attachment.dart` (mới),
`lib/features/study/domain/repositories/study_session_repository.dart` (mới),
`lib/features/tasks/presentation/widgets/task_detail_sheet.dart`,
`lib/core/utils/storage_service.dart`

**Vì sao làm kiểu này (không nhét base64 vào JSON task):** mỗi lần tick hoàn
thành hoặc đổi tiêu đề, task được ghi lại — gắn ảnh vào JSON nghĩa là mỗi
lần ghi kéo theo cả ảnh. Prefs phình to và ghi đè chậm dần trên Android. Mỗi
tệp nằm ở khoá riêng (`task_attachment_<task>_<id>`) nên sửa task không đụng
tới ảnh.

Quyết định trung thực về phạm vi: đặc tả §14 có "file attachments / scanned
documents", nhưng CHECKLIST dòng 72 đã **loại có chủ ý** (cần OCR + kho tệp
thật). Vì vậy app chỉ nhận **ảnh tĩnh ≤ 250KB, tối đa 3 tệp/nhiệm vụ**, chặn
ở repository (mọi đường ghi đều bị chặn như nhau) và báo rõ giới hạn khi vượt
— thay vì làm vỏ rồi gọi là xong.

**Lỗi thật đã sửa trong lúc làm:**

| Vấn đề | Hậu quả |
|---|---|
| `addAttachment` sinh id bằng `microsecondsSinceEpoch` | Hai lần gắn **trong cùng một micro-giây** trùng id → tệp mới **ghi đè tệp cũ**, mất ảnh mà không có dấu vết. Nay dùng bộ đếm như `_newId()` |
| Xoá task không dọn tài liệu | base64 mồ côi nằm vĩnh viễn trong prefs, không ai dọn |
| Undo xoá / Undo chia nhỏ trả lại task không kèm ảnh | Người dùng mất tài liệu mà **không được báo** — vi phạm chính điều FE-2.5 sinh ra để tránh |
| `StudySession` bị 6 nơi tự giải mã JSON | JSON hỏng bị nuốt im lặng ở một chỗ, hiện ra ở chỗ khác; `StorageService` còn thiếu hàm xoá phiên nên không ai dọn được phiên cũ |

Đã tạo `StudySessionRepository` làm đường đọc/ghi duy nhất
(`getForTask`, `totalMinutesForTask`, `updateFeedback`, `delete`) và chuyển
`study_screen` sang dùng nó. Test `Single Write Path` mở rộng chặn cả ghi
session lẫn ghi tài liệu đính kèm.

**Kiểm chứng:** `test/task_attachment_session_test.dart` (mới, **23 test**:
hạn mức 250KB/3 tệp, tệp rỗng, JSON hỏng, thứ tự, vòng đời tài liệu qua
xoá/chia nhỏ/Undo, lọc phiên theo task, tổng phút, cập nhật phản hồi, xoá
phiên, và 3 test widget cho đúng 2 khối mới trong màn chi tiết).
`flutter test` → **319/319 pass**; `flutter analyze lib test` → sạch.

---

### ✅ FE-2.3 — Giao diện Tạo & Chỉnh sửa Nhiệm vụ (hoàn thành)

**File:** `lib/features/tasks/presentation/widgets/task_edit_sheet.dart` (viết lại toàn bộ)

Lỗi thật đã sửa:

| Vấn đề | Hậu quả |
|---|---|
| `_submit()` dựng `TodayTask` mới từ đầu | **Mất `createdAt`, `id`, `status`, `subtasks`, `goalId`, lịch sử session** khi sửa 1 task → đứt đoạn dữ liệu học tập |
| Danh sách môn viết cứng `['Toán','Văn',…]` (không emoji) | Sinh môn **mới** khác hệt môn cũ đang lưu (`'📐 Toán'`) → gom nhóm môn sai ở Sprint 5 |
| `_disposeRemote()` gọi `dispose()` 2 lần, có extension `baseline()` | Crash do dispose nhiều lần |
| Không có ô nhập ngày học | Sửa task không đổi được `scheduledAt` dù khoá dữ liệu cho phép |
| Nút lưu trôi theo nội dung | Bàn phím che mất nút khi cuộn form dài |

Cải thiện thêm: validate inline khi tên trống, cảnh báo deadline sớm hơn ngày học, bảng hành động dính đáy ngoài scroll view, chọn ngày linh hoạt (deadline cho phép quá khứ vì task quá hạn vẫn cần nhìn thấy).

**Chi tiết đáng ghi nhận:** đổi ngày học khi đang sửa task chưa xong sẽ tự tăng `rescheduleCount` và reset về `todo` — vì task ở ngày mới chưa từng bắt đầu.

---

### ✅ Chuẩn hoá danh mục môn học (phát hiện trong FE-2.3)

**File:** `lib/core/constants/subject_catalog.dart` (mới), `test/subject_catalog_test.dart` (mới, 39 test)

`subject` là khoá dữ liệu dùng để **gom nhóm thống kê** (Sprint 5), **tô màu chip** (TaskCard) và **AI chọn môn yếu**. Nhưng code đang ghi theo 2 chuẩn song song:

| Nơi | Chuỗi ghi ra |
|---|---|
| `quick_add_parser.dart`, `preset_exams.dart`, `study_screen.dart`, `AddTaskDialog` | `'📐 Toán'`, `'⚡ Lý'` |
| `task_edit_sheet.dart` (cũ) | `'Toán'`, `'Lý'` |

Hai chuỗi này là **hai môn khác nhau** với mọi `groupBy(subject)`. `AppSubjects` giờ là nguồn duy nhất, với `normalize()` hợp nhất mọi biến thể: không emoji, hoa/thường, có/khoảng trắng, cách viết vùng miền (`vật lí`/`vật lý`/`vatly`), và bí danh tiếng Anh (`math`, `physics`…). Môn lạ → **giữ nguyên**, không tự bịa môn (§10).

**Kiểm chứng:**
- `test/subject_catalog_test.dart` → **39/39 pass**
- `flutter test` (toàn bộ) → **278/278 pass** (188 test gốc + 39 catalog + 50 repository + 1 semantics mới), **không hồi quy**
- `flutter analyze lib test` → No issues found

> Ghi chú quy trình: 3 lỗi trong catalog (bảng bỏ dấu viết tay lệch chỉ số khiến `ý → a`, thiếu `ế`/`ậ`/`ấ`, `plainName` lệch tên) **đều bị test bắt trước khi** lan sang Sprint 5.

---

### ✅ BE-3.1 — Lưu trữ Phiên học

**File:** `lib/features/study/domain/models/study_models.dart`,
`lib/features/study/domain/repositories/study_session_repository.dart`,
`lib/features/study/presentation/screens/study_screen.dart`,
`lib/features/home/domain/services/today_service.dart`

Đặc tả yêu cầu `startTime`, `endTime`, `status`, `feedbackRating`. Ba quyết định
đáng nói:

| Quyết định | Vì sao |
|---|---|
| `startedAt`/`endedAt`/`status` **nullable** | Phiên cũ trên máy người dùng không có 3 trường này. Cho nullable nên đọc được nguyên vẹn, **không cần migration**; `status` mặc định coi là `completed` vì trước đây app chỉ ghi phiên hoàn thành |
| `startedAt` lấy từ `_pomStartedAt` | Mốc bấm "bắt đầu" đã có sẵn trong `study_screen`. Ước lượng bằng `completedAt - actualMinutes` sẽ ra một con số *trông* đúng nhưng là dữ liệu bịa |
| `feedbackRating` là **getter tính ra**, không lưu | Năm thang đánh giá chi tiết đã là nguồn thật. Lưu thêm một trường trung bình là tạo hai nguồn sự thật cho cùng một câu hỏi, rồi chờ chúng lệch nhau |

`minutesOn(day)` và `minutesForSubject(subject, {day})` **tính** từ danh sách
phiên thay vì lưu tổng riêng: tổng lưu sẵn trôi lệch mỗi khi người dùng xoá
một phiên, rồi cần thêm một đường dọn dẹp và thêm một chỗ nữa để sai.
`minutesForSubject` so khớp qua `AppSubjects.normalize` vì `'📐 Toán'` và
`'Toán'` là cùng một môn. `today_service.getTodayStudyMinutes()` chuyển sang
dùng `minutesOn()` để chỉ còn một đường tính.

**Phát hiện chưa tự sửa — cần quyết định sản phẩm:** `_addLog()` vẫn ghi thêm
một dòng `StudyLog` cho *cùng* một vòng pomodoro mà `_recordCompletedFocus()`
vừa ghi vào `StudySession`. Hai bảng này cùng mô tả một khoảng thời gian đã
học nhưng lệch nhau (`StudyLog.hours` là số thập phân tự nhập, `actualMinutes`
là phút nguyên), và màn "Nhật ký học tập" cộng từ `StudyLog` còn thẻ tổng giờ
ở dòng ~1553. Gộp hai nguồn lại sẽ **đổi nội dung màn nhật ký đang hiển thị**
(nhật ký tay vẫn cần giữ vì không có phiên), nên để nguyên cho tới khi có
quyết định rõ: giữ `StudyLog` làm nhật ký khai báo thủ công và bỏ ghi trùng ở
vòng pomodoro.

**Kiểm chứng:** `test/task_attachment_session_test.dart` → **30 test** (thêm 7
test BE-3.1: round-trip `startedAt`/`endedAt`/`status`, tương thích phiên cũ,
`cancelled`, `feedbackRating` không ghi xuống JSON, `minutesOn`,
`minutesForSubject` gộp môn có/không emoji).
`test/task_repository_test.dart` thêm guard "chỉ repository mới giải mã được
StudySession" → chặn 6 nơi tự `try/catch` + `jsonDecode` quay lại.
`flutter analyze lib test` → sạch; `flutter test` → **327/327 pass**.

---

### ✅ FE-3.2 — Bộ đếm thời gian neo theo mốc thời gian thật

**File:** `lib/features/study/domain/focus_clock.dart` (mới),
`lib/features/study/presentation/screens/study_screen.dart`, `test/focus_clock_test.dart` (mới, 15 test)

**Lỗi thật:** đồng hồ Pomodoro cũ dùng `_pomSecondsNotifier.value--` mỗi tick.
Nó đếm **số lần tick**, không đếm thời gian đã trôi. Khi Android tiêu hệu tiền
vùy app, tick bị giữ lại rồi thả ra dồn một lúc (hoặc bị bỏ hẳn) — học sinh
ngồi học 25 phút mà đồng hồ chỉ trừ được 8 phút. Đây đúng là thứ mục tiêu
"Không bao giờ bị mất thời gian học" cấm, và nó âm thầm vì nhìn đồng hồ vẫn
chạy đều.

`FocusClock` giữ một mốc thời gian và **tính ra** mỗi lần hỏi; `Timer.periodic`
chỉ còn đẩy giao diện. Hai lỗi phụ đi kèm cũng sửa luôn:

| Vấn đề | Hậu quả |
|---|---|
| Pause xoá `_pomStartedAt` rồi Resume đặt lại thành `now` | Thời gian đã học trước lúc pause bị mất khỏi tổng, và `startedAt` của phiên trỏ vào lần bấm *sau* |
| Ghi `actualMinutes: _focusMinutes` | Một phiên bị tạm dừng nhiều lần vẫn ghi 25 phút → mọi tổng thời gian học về sau đều thừa. Nay đo thật từ mốc |
| `_recordAppLeaving` tự trừ `DateTime.now()` | Nó đo phút *ngay lúc app đang bị vùy* — tức lúc bộ đếm không đáng tin nhất. Nay lấy từ `FocusClock` |

Hàm nào của clock cần thời gian thật thì nhận `now` qua tham số, không tự gọi
`DateTime.now()` bên trong — một đồng hồ chỉ chạy được với đồng hồ thật thì cũng
chỉ kiểm chứng được bằng cách chờ thật.

**Còn lại (BE-3.2):** app bị hệ điều hành **kill hẳn** thì `FocusClock` mất trong
bộ nhớ; cần ghi phiên đang chạy xuống storage và hỏi tiếp tục/huỷ khi mở lại.

**Kiểm chứng:** `flutter analyze lib test` → sạch; `flutter test` → **342/342 pass**.

---

### ✅ BE-3.2 — Khôi phục phiên học đang dở

**File:** `lib/features/study/domain/active_study_session.dart` (mới),
`lib/features/study/domain/focus_clock.dart` (`FocusClock.restore`),
`lib/features/study/domain/repositories/study_session_repository.dart`
(`saveActive`/`getActive`/`clearActive`),
`lib/features/study/presentation/screens/study_screen.dart`,
`test/active_session_recovery_test.dart` (mới, 21 test)

Vòng Pomodoro chỉ sống trong bộ nhớ. Android giết tiến trình là biến mất
không dấu vết: đúng phần thời gian học mà mục tiêu "không mất thời gian học"
bắt buộc phải giữ. Nay `FocusClock` được chụp xuống `active_study_session` mỗi
lần bấm bắt đầu/tạm dừng và khi app bị vùy; lần mở sau app hỏi:

| Người dùng chọn | Kết quả |
|---|---|
| **Tiếp tục** | Nối lại đồng hồ từ số giây còn lại, giữ nguyên `startedAt` gốc |
| **Kết thúc phiên** | Ghi phần đã học thành `StudySession` với `status: cancelled` — bỏ dở không được nghĩa là không có gì được ghi |
| Bấm ra ngoài | Giữ ảnh chụp, lần sau vẫn hỏi được |

Ba quyết định đáng ghi:

- **Chỉ một khoá `active_study_session`, không dùng danh sách.** Chỉ một vòng
  chạy tại một thời điểm; có danh sách thì phải lo "vòng nào còn sống", mà đó
  chính là thứ không biết sau khi app bị kill.
- **Hết hạn 6 giờ là dữ liệu tạm cũ, không phải thứ cần hỏi.** Một vòng focus dài
  nhất cũng chỉ 60 phút, nên ảnh chụp cũ hơn 6 giờ không phải phiên người dùng còn
  muốn nối: nó bị dọn thẳng. Ảnh chụp **còn hiệu lực** thì câu hỏi "tiếp tục phiên
  học tối qua" vẫn có nghĩa và phần thời gian đã học được ghi thành phiên
  `cancelled` nếu người dùng chọn kết thúc.
- **`đã học + còn lại = tổng` là bất biến**, nên phần "đã học" **suy ra** từ phần
  còn lại thay vì lưu thêm. Bản đầu tiên của tôi lưu cả hai và test bắt được
  ngay: phần đã học bị đếm hai lần (420s thành 720s).

**Test bắt được 3 lỗi thật trong lúc làm:**

| Lỗi | Hậu quả |
|---|---|
| Vòng **đang tạm dừng** được khôi phục thành đang chạy | Mở app giữa lúc nghỉ → tự chạy tiếp và ghi phiên không mong muốn |
| `showDialog` gọi ngay trong `initState` | Chạm `Localizations` trước khi cây dựng xong → assertion; hộp thoại không hiện |
| Guard "chỉ repository giải mã StudySession" khớp nhầm | `ActiveStudySession.fromJson` chứa nguyên văn chuỗi `StudySession.fromJson` → cấm oan tệp sạch. Nay dùng `RegExp` có ranh giới `(?<![A-Za-z0-9_])` |

**Kiểm chứng:** `flutter analyze lib test` → sạch; `flutter test` → **363/363 pass**
(21 test mới: 16 unit + 5 widget test thật trên `StudyScreen`).

### 🔶 STUDY-LOG-MERGE — Gộp Nhật ký nhập tay và Phiên học

**File:** `lib/features/study/domain/study_timeline.dart` (mới),
`lib/features/study/domain/weekly_summary.dart`,
`lib/features/study/presentation/widgets/weekly_chart_widget.dart`,
`lib/features/study/presentation/screens/study_screen.dart`,
`lib/core/ai/ai_context.dart`,
`test/study_timeline_test.dart` (mới, 13 test), `test/ai_context_test.dart`,
`test/active_session_recovery_test.dart`

Mỗi vòng Pomodoro ghi **hai** bản ghi cho cùng một khoảng thời gian: một
`StudyLog` (giờ thập phân, đồng hồ cũ) và một `StudySession` (phút, có phản hồi).
Hệ quả là thời gian học bị đếm hai lần ở mọi nơi tổng hợp, và hai bảng lệch nhau
khi người dùng sửa/xoá ở một bên. Người dùng đã chốt: **`StudyLog` chỉ còn là
ghi chép nhập tay**.

Quy ước mới, đặt trong một chỗ duy nhất:

| Nguồn | Nghĩa là gì | Xoá ở đâu |
|---|---|---|
| `StudySession` | Phiên học thật (Pomodoro) | `StudySessionRepository.delete` |
| `StudyLog` | Ghi chép nhập tay, không có phiên đứng sau | `StorageService.removeStudyLog` |

`StudyTimelineEntry` + `buildStudyTimeline(logs:, sessions:)` là điểm gộp, mọi
nơi tổng hợp đều đi qua nó: tab Nhật ký (tổng giờ, số buổi, danh sách, xoá),
`WeeklyChartWidget`, `summarizeWeek()`/`weeklyHoursOf()` và AI context. Trước đây
AI chỉ đọc `StudyLog`, nên nếu chỉ dừng ghi trùng thì AI sẽ thấy gần như không có
gì — test hồi quy chốt lại đúng điều đó (3.25h chỉ từ phiên học).

**Ba lỗi thật lộ ra khi harden, đều do test bắt:**

| Lỗi | Hậu quả |
|---|---|
| `autoStart` bỏ qua nhánh khôi phục | Mở app bằng nút "học ngay" ghi đè ảnh chụp → mất thời gian đã học của phiên cũ |
| Ảnh chụp **tạm dừng** quá 6 giờ vẫn được hỏi | Chọn "Tiếp tục" sẽ nhận đồng hồ không chạy: giao diện báo đang học, số giây đứng yên, vòng treo vô hạn và không ghi được phiên |
| `NotificationService.cancelId` gọi plugin khi chưa `init()` | `LateError` làm vỡ luôn luồng bắt đầu phiên học (đáng lẽ lỗi thông báo không được chặn đồng hồ) |

**Dữ liệu cũ:** cho phép xoá nhưng vẫn xử lý thận trọng theo 2 bước:
1. Migration v2/v1 giữ nguyên `StudyLog` nhập tay.
2. Migration v3 (`drop_legacy_pomodoro_logs`) xoá các `StudyLog` trùng trùng với vòng Pomodoro thực: giống môn + giờ sai không quá 3 phút + thời lượng gần khớp, hoặc note đúng `Phiên <số>`. `StudySession` là nguồn thật nên luôn giữ.

**Kiểm chứng:** `flutter analyze lib test` → sạch; `flutter test` → **403/403 pass**.

