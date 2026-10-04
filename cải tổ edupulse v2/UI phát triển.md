# 🎨 Kế Hoạch Tối Ưu Hóa Giao Diện EduPulse

> **Trạng thái:** Sprint 0–7 đã hoàn thành 100%. Đây là lộ trình tinh chỉnh UI để nâng tầm trải nghiệm người dùng từ "hoạt động đúng" → "trải nghiệm xuất sắc".
>
> **Nguyên tắc cốt lõi:** "Mở app là biết mình phải làm gì."

---

## 📊 Hiện Trạng — Gap Analysis

### ✅ Đã làm tốt
| Thành phần | Tình trạng |
|---|---|
| Kiến trúc 4-tab (Hôm nay / AI / Tiến độ / Tôi) | ✅ Đúng spec |
| Task card, Edit/Delete/Reschedule flow | ✅ Hoàn chỉnh + Undo |
| AI Quick Actions grid (2 cột, 5 nút) | ✅ Đã có |
| AI error recovery (retry + tự học) | ✅ Đã có |
| DailySummaryCard (exam countdown + giờ học) | ✅ Compact, đúng vị trí |
| ProgressInsightCard trên Home | ✅ Đã có |

### ⚠️ Vấn đề cần cải thiện

| # | Vấn đề | Màn hình | Mức độ |
|---|---|---|---|
| U-01 | HomeHeader: mascot + streak chiếm 80px — đẩy task xuống dưới fold | Home | 🔴 Cao |
| U-02 | Thứ tự block Home sai ưu tiên: Header → DailySummary → ProgressInsight → TodayMissions | Home | 🔴 Cao |
| U-03 | AiCopilotHubCard + QuickActionCard + AiReadinessCard: 3 block AI riêng biệt gây nhiễu | Home | 🔴 Cao |
| U-04 | AI screen: quick actions màu bị lẫn (orangeDark dùng cho cả "Điểm yếu" lẫn "Điều chỉnh lịch") | AI | 🟡 Trung |
| U-05 | AI screen: prompt gợi ý hardcode ("đạo hàm lớp 12") — không cá nhân hóa | AI | 🟡 Trung |
| U-06 | Empty state Home (không có task): không có nút "AI lập kế hoạch" nổi bật | Home | 🟡 Trung |
| U-07 | Toast/SnackBar: text màu đen mặc định, không có icon, thiếu visual weight | Toàn app | 🟡 Trung |
| U-08 | Loading state: không có skeleton cho task list | Home | 🟡 Trung |
| U-09 | Typography không nhất quán: một số chỗ dùng fontSize trực tiếp thay vì AppTokens | Toàn app | 🟢 Thấp |
| U-10 | Task card không có visual cue cho deadline gần (hôm nay/ngày mai) | Home | 🟡 Trung |
| U-11 | Progress screen: thiếu empty state hướng dẫn khi chưa có dữ liệu | Progress | 🟡 Trung |
| U-12 | Bottom nav: không có active indicator rõ ràng trên desktop sidebar | Desktop | 🟢 Thấp |
| U-13 | Exam countdown dạng chip (nhỏ, tím) — không nổi bật theo ngữ cảnh kỳ thi | Home | 🟢 Thấp |

---

## 🗂️ Lộ Trình Tối Ưu — 4 Giai Đoạn

---

### Giai đoạn 1 — Ưu tiên thông tin (Critical Path)
> **Mục tiêu:** Task đầu tiên phải hiện ngay khi mở app, không cuộn.

#### G1-A: Sắp xếp lại thứ tự block trên Home
```
HIỆN TẠI:                    ĐỀ XUẤT:
HomeHeader (80px)            HomeHeader (Thu gọn: 48px)
DailySummaryCard (60px)      DailySummaryCard (Giữ nguyên)
ProgressInsightCard (60px)   TodayMissionCard ← LÊN ĐẦU
TodayMissionCard             ProgressInsightCard (thu nhỏ, dưới task)
AiCopilotHubCard             AiCopilotHubCard + QuickActionCard (gộp)
QuickActionCard              AiReadinessCard (ẩn hoặc thu gọn)
AiReadinessCard
```

**Thay đổi cụ thể:**
- [`home_screen.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/home/presentation/screens/home_screen.dart): Đổi thứ tự widget trong `build()` — TodayMissionCard lên ngay sau DailySummaryCard
- [`home_header.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/home/presentation/widgets/home_header.dart): Thu gọn header xuống ~48px — bỏ border container, giảm padding, mascot nhỏ hơn (36px)
- [`ai_copilot_hub_card.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/home/presentation/widgets/ai_copilot_hub_card.dart) + [`quick_action_card.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/home/presentation/widgets/quick_action_card.dart): Gộp thành 1 widget `AiActionsRow` — 3-4 nút ngang, không card nặng nề

#### G1-B: Empty state cho Home khi chưa có task
```
HIỆN TẠI: Chỉ có nút "+ Thêm" nhỏ trong TodayMissionCard header
ĐỀ XUẤT:
  ╔══════════════════════════════╗
  ║  📋 Hôm nay chưa có nhiệm vụ ║
  ║                              ║
  ║  Tạo kế hoạch để biết mình   ║
  ║  nên học gì hôm nay.         ║
  ║                              ║
  ║  [ 🤖 AI lập kế hoạch ]      ║
  ║  [ + Thêm nhiệm vụ thủ công ]║
  ╚══════════════════════════════╝
```

**File cần sửa:**
- [`today_mission_card.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/home/presentation/widgets/today_mission_card.dart): Thêm `_EmptyTaskState` widget với 2 CTA nổi bật

---

### Giai đoạn 2 — Cải thiện Visual Hierarchy

#### G2-A: Task card — Urgency indicator
**Nguyên tắc:** Color-independent (không chỉ dùng màu, phải có icon/text)

```
Task deadline hôm nay:
  ┌────────────────────────────────┐
  │ ● Toán — Hàm số          🔴 HÔM NAY│
  │   45 phút                      │
  │            [Bắt đầu học]        │
  └────────────────────────────────┘

Task deadline ngày mai:
  ┌────────────────────────────────┐
  │ ○ Vật lý — Con quay      📅 Mai │
  │   30 phút                      │
  └────────────────────────────────┘
```

**File cần sửa:**
- [`task_card.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/tasks/presentation/widgets/task_card.dart): Thêm deadline badge (chip phải), tính từ `task.scheduledAt` hoặc `task.deadline`

#### G2-B: AI Quick Actions — Màu rõ ràng + không trùng
```
HIỆN TẠI:                    ĐỀ XUẤT:
🟢 Tôi nên học gì?          🟢 Tôi nên học gì?    (primary/xanh lá)
🔵 Giải thích bài này       🔵 Giải thích bài này  (blue)
🟣 Lập kế hoạch             🟣 Lập kế hoạch        (purple)
🟠 Phân tích điểm yếu   →   🟠 Phân tích điểm yếu  (orange)
🟠 Điều chỉnh lịch          🔵 Điều chỉnh lịch     (teal/infoDark)
```

**File cần sửa:**
- [`ai_coach_screen.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/ai_coach/presentation/screens/ai_coach_screen.dart) — class `_AiQuickActions`: Đổi màu "Điều chỉnh lịch" → `AppColors.blueDark`

#### G2-C: AI prompt gợi ý — Cá nhân hóa từ data thật
```
HIỆN TẠI (hardcode):
  "Giải thích dạng bài đạo hàm lớp 12"
  "Lập kế hoạch 3 ngày trước thi"
  "Kiểm tra lần này sai ở đâu?"

ĐỀ XUẤT (dynamic, từ AiCopilotService):
  → Lấy subject = preferredSubject() từ AiCopilotService
  → Lấy examName từ StorageService
  → "Giải thích bài [task đầu tiên hôm nay]"
  → "Lập kế hoạch ôn thi [examName]"
  → "Môn [weakestSubject] cần cải thiện gì?"
```

**File cần sửa:**
- [`ai_coach_screen.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/ai_coach/presentation/screens/ai_coach_screen.dart): Thay hardcode bằng dynamic prompt từ `AiCopilotService.preferredSubject()` + `buildSituationReport()`

---

### Giai đoạn 3 — Micro-interactions & Feedback

#### G3-A: SnackBar — Thêm icon + màu semantic

```
HIỆN TẠI: SnackBar(content: Text('Đã hoàn thành'))
          → Nền xanh mặc định, không icon

ĐỀ XUẤT:
  ✅ Hoàn thành nhiệm vụ      (nền xanh lá, icon check)
  🗑️ Đã xóa "Toán hàm số"    (nền đỏ, icon trash, nút Hoàn tác)
  📅 Đã dời sang ngày mai    (nền cam, icon calendar)
  ⚠️ Không xóa được          (nền đỏ đậm, icon warning)
```

**File cần sửa:**
- [`home_screen.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/home/presentation/screens/home_screen.dart): Hàm `_showSnack()` — thêm tham số `icon` và `backgroundColor`; tạo helper `_iconSnack()`

#### G3-B: Haptic feedback nhất quán
```
Sự kiện                    Haptic
Toggle task done        →  HapticFeedback.mediumImpact()  ✅ (đã có)
Bắt đầu học            →  HapticFeedback.lightImpact()   ← cần thêm
Xóa task (confirm)     →  HapticFeedback.heavyImpact()   ← cần thêm
Swipe reschedule       →  HapticFeedback.selectionClick() ← cần thêm
```

#### G3-C: Loading skeleton cho task list
```
Khi _tasks chưa load (thay vì màn trắng):
  ┌─────────────────────────────┐
  │ ████████████░░░░░░░░  45ph  │  ← Shimmer
  └─────────────────────────────┘
  ┌─────────────────────────────┐
  │ ██████████░░░░░░░░░░  30ph  │  ← Shimmer
  └─────────────────────────────┘
```

**File cần sửa:**
- [`home_screen.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/features/home/presentation/screens/home_screen.dart): Thêm `_isLoadingTasks` bool, hiện skeleton khi true
- Tạo [`lib/shared/widgets/skeleton_card.dart`](file:///c:/Users/Minh/.gemini/antigravity-ide/scratch/edupulse-flutter/lib/shared/widgets): Skeleton widget tái sử dụng

---

### Giai đoạn 4 — Polish & Nhất quán

#### G4-A: Typography — Dùng AppTokens nhất quán
Một số chỗ vẫn dùng `fontSize: 16, fontWeight: FontWeight.w800` trực tiếp. Cần chuẩn hóa:
```dart
// Thay thế:
TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)
// Bằng:
AppTokens.sectionTitle  // hoặc AppTokens.heading
```

**Các file cần rà soát:**
- `home_header.dart`, `today_mission_card.dart`, `daily_summary_card.dart`

#### G4-B: Progress screen — Empty state hướng dẫn
```
Khi chưa có dữ liệu học:
  ╔══════════════════════════════════╗
  ║  📈 Chưa có dữ liệu tiến độ     ║
  ║                                  ║
  ║  Bắt đầu học để xem tiến bộ     ║
  ║  của bạn hiển thị tại đây.      ║
  ║                                  ║
  ║      [ Bắt đầu học ngay ]        ║
  ╚══════════════════════════════════╝
```

#### G4-C: Responsive — Desktop sidebar active state
```
HIỆN TẠI: Active item chỉ đổi màu text
ĐỀ XUẤT:
  ┌─────────────────────┐
  │ ▌ Hôm nay          │  ← Thanh xanh lá bên trái (4px)
  │   AI               │
  │   Tiến độ          │
  └─────────────────────┘
```

---

## 📋 Bảng Tổng Hợp Việc Cần Làm

| ID | Mô tả | File chính | Ưu tiên | Độ phức tạp |
|---|---|---|:---:|:---:|
| G1-A ✅ | Đổi thứ tự block Home | `home_screen.dart` | 🔴 P0 | Thấp |
| G1-A ✅ | Thu gọn HomeHeader | `home_header.dart` | 🔴 P0 | Thấp |
| G1-A ✅ | Gộp AI block trên Home | `home_screen.dart` + widgets | 🔴 P0 | Trung |
| G1-B ✅ | Empty state Home có AI CTA | `today_mission_card.dart` | 🔴 P0 | Thấp |
| G2-A ✅ | Task card deadline badge | `task_card.dart` | 🟡 P1 | Thấp |
| G2-B ✅ | AI Quick Actions đổi màu | `ai_coach_screen.dart` | 🟡 P1 | Rất thấp |
| G2-C ✅ | AI prompt gợi ý cá nhân hóa | `ai_coach_screen.dart` | 🟡 P1 | Trung |
| G3-A ✅ | SnackBar có icon + màu semantic | `home_screen.dart` | 🟡 P1 | Thấp |
| G3-B ✅ | Haptic feedback nhất quán | nhiều file | 🟢 P2 | Thấp |
| G3-C ✅ | Loading skeleton task list | `home_screen.dart`, widget mới | 🟢 P2 | Trung |
| G4-A ✅ | Typography chuẩn hóa | nhiều widget | 🟢 P2 | Thấp |
| G4-B ✅ | Progress empty state | progress screen | 🟢 P2 | Thấp |
| G4-C ✅ | Desktop sidebar active indicator | `desktop_sidebar.dart` | 🟢 P2 | Thấp |

---

## 🔢 Thứ Tự Khuyến Nghị Thực Hiện

```
Tuần 1 (P0 — Impact cao nhất):
  1. G1-A: Đổi thứ tự block Home + Thu gọn header
  2. G1-B: Empty state Home
  3. G2-A: Task deadline badge
  4. G2-B: AI Quick Actions màu

Tuần 2 (P1 — Chất lượng):
  5. G2-C: AI prompt cá nhân hóa
  6. G3-A: SnackBar semantic
  7. G4-B: Progress empty state

Tuần 3 (P2 — Polish):
  8. G3-B: Haptic feedback
  9. G3-C: Loading skeleton
  10. G4-A: Typography chuẩn hóa
  11. G4-C: Desktop sidebar
```

---

## ✅ Tiêu Chí Kiểm Tra (Acceptance Criteria)

Sau khi hoàn thành, app phải đạt:

- [x] **Fold test**: Task đầu tiên hiện ngay màn hình, không cần cuộn (iPhone SE — 375×667)
- [x] **3-second test**: Người dùng mới hiểu được mục đích màn Hôm nay trong 3 giây
- [x] **Empty state**: Mỗi màn hình đều có empty state có CTA rõ ràng
- [x] **No hardcode**: Prompt AI gợi ý lấy từ data thật (tên task, môn, kỳ thi)
- [x] **Visual hierarchy**: Mỗi màn hình có đúng 1 điểm nhấn hành động nổi bật nhất
- [x] **Consistent feedback**: Mọi action quan trọng đều có SnackBar có icon + màu phù hợp
- [x] **flutter analyze**: Sạch 0 warning sau mọi thay đổi
- [x] **flutter test**: Toàn bộ test pass — **540/540** (thêm mới `test/ui_acceptance_test.dart` — 7 case)
