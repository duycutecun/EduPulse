# Kế hoạch phát triển EduPulse — Bản thống nhất sau họp đa vai

**Ngày họp:** 2026-10-15 · **Thành phần:** BOSS, DEV, UI CREATOR, USER (học sinh), KHÁCH HÀNG (phụ huynh), ĐIỀU PHỐI VIÊN  
**Biên bản đầy đủ:** xem `LICH_SU_THAO_LUAN.md`  
**Ràng buộc cứng:** không billing / không quảng cáo / không bán dữ liệu ở **mọi** mốc. Dựa trên `KE_HOACH_CAI_TO_APP.md` mục 1.
**Chi phí:** 0đ — agent local + free tier (Gemini/OpenRouter `:free`, Vercel Hobby, Supabase free, GitHub Actions).

---

## 1. Quyết định đã chốt

| Hạng mục | Quyết định | Vai quyết định | Lý do |
|---|---|---|---|
| Điều hướng | 3 tab **Hôm nay / Kế hoạch / Cá nhân** (IndexedStack, chọn bằng **enum**, không index); Study/Exams/Notes → route push; notification tap **đọc payload**, không đọc index | BOSS + DEV + UI | Giảm điểm đến cạnh tranh; bẫy index gây silent sai màn |
| Onboarding | Giữ seed `preset_exams`; đầu ra **kế hoạch 3 ngày + "Bắt đầu ngay"**; sửa được ≤3 chạm | DEV + USER | User không tin lộ trình 14 ngày; 3 ngày phải sửa được |
| AI | **Rời tab**; giữ `AiActionsRow` 1 hàng + route chat; chỉ **2 điểm ngữ cảnh** (tạo task có preview; tổng kết phiên); mọi đường AI có **fallback rule-based offline**, token đầu <5s; tách `ai_copilot_service` | BOSS + DEV | AI là điểm đến tách rời; free tier không đảm bảo |
| Dark mode | Tokens từ M1 (`design_tokens.dart`), **bật theo màn từ M2** (Cá nhân → Kế hoạch → Hôm nay cuối); **chỉ theo hệ thống + lịch tự đặt**; AA + chữ 200% không vỡ | UI + BOSS | Rà màu hardcode 5 màn là việc ẩn; tránh "auto" gây nhầm |
| Gamification | **Streak**: giữ + **freeze 1 lần/tháng** + nghỉ báo trước không mất + **không âm về đêm** + **nút tắt toàn bộ**. **XP** → tab Cá nhân. **Mascot** → chỉ sau phiên, tắt được. **Bốc quẻ** → bỏ. **Leaderboard** → **bỏ** (chỉ kỷ lục cá nhân) | BOSS + UI + USER/KH | KH không dùng tên thật; gamification không được che CTA học |
| Quiz ảnh | Giữ đọc ảnh + sinh quiz; **lưu kết quả + gợi ý ôn lại** (SRS lite) — ra khỏi M1 | USER + DEV | Cần entity `QuizAttempt`/`ReviewSuggestion` mới |
| Báo cáo phụ huynh | Chỉ **"xem", không "điều khiển"**; công tắc "con tự gửi"; **preview trước gửi**; chỉ giờ học/phiên/lịch tuần tới, không chi tiết cảm xúc; đổi quyền phải **xin phép con trong app**; nhật ký thay đổi quyền | USER/KH | Tin vì dữ liệu trên máy + con chủ động chia sẻ |
| Nhiệm vụ/lịch | Hoãn/chia nhỏ ≤3 chạm; banner "Hôm qua chưa xong gì" (chip xám, không đỏ); gợi ý đổi lịch cụ thể | BOSS + USER | Điểm thử hữu ích khi dẫn tới đổi lịch |
| Sync | Queue idempotent, migration v1→v3 + restore có test, 500 kịch bản offline→online không mất dữ liệu, backup offline | DEV | Mất phiên học = mất niềm tin |
| Quyền riêng tư | **Xóa toàn bộ dữ liệu 1 chạm** (Cài đặt → Quyền riêng tư); ảnh/chat có thời hạn cache; giới hạn giờ học tối đa/ngày; nhắc "đi ngủ" 22:30; không chuyển database | KH | Điều kiện để người dùng ở lại |

## 2. Các điểm tranh chấp đã xử lý

- **Leaderboard:** UI muốn giữ "xuống cuối tab Kế hoạch, chỉ kỷ lục cá nhân"; BOSS từ chối thẳng vì phụ huynh không chấp nhận tên thật. → **Chốt bỏ khỏi scope**, thay bằng thi đua ẩn danh ở M3.
- **Timeline 3 mốc:** kế hoạch cũ 4/5/6 tuần so với đề xuất 3/3/4. → **Chốt 3/3/4**, đẩy việc nặng (quiz lưu, preview báo cáo, dark bật thực) rời M1.
- **Quy mô thử nghiệm:** 10 HS × 7 ngày (BOSS/DEV) so với 50 người × 30 ngày (USER). → **Chốt 2 giai đoạn**: pilot 10 HS × 7 ngày trước M2; pilot 50 người/30 ngày trên máy phổ thông + mạng yếu trước M3.
- **Sticky bar vs inline card:** UI xin hy sinh sticky ở M1. → **Chốt giữ sticky bar** (làm chủ yếu "mở app→phiên <15s", ≤2 chạm); hy sinh chuyển cảnh/onboarding dots thay thế.
- **Quiz lưu kết quả:** USER/KH cần, DEV báo tốn ẩn entity. → **Chốt** đọc ảnh giữ M1, lưu + ôn lại chuyển M2 có migration+backup.
- **Xóa dữ liệu 1 chạm:** BOSS muốn "LÀM NGAY", DEV báo rời M1. → **Chốt M1** ship xóa **local** 1 chạm; M2 hoàn tất xóa cả cloud + nhật ký quyền.

## 3. Kế hoạch 3 mốc

### M1 (3 tuần) — "Hôm nay liền mạch"

1. Refactor nav: enum tab + route push + `NotificationTapHandler` đọc payload; test nav viết **trước** khi sửa.
2. Tách `ai_copilot_service`; AI rời tab, giữ `AiActionsRow`.
3. Home: thẻ "việc quan trọng nhất" + đếm ngược; render <150ms; 40% fold chỉ chứa việc cần làm.
4. Sticky bar "Bắt đầu · 25 phút" + "Hoãn" → phiên gắn `taskId`.
5. Hoãn/chia nhỏ ≤3 chạm (`TaskActionSheet`, `updateTask`/`splitTask`).
6. Banner "Hôm qua chưa xong gì" (chip xám), 1 chạm mở lại.
7. Phản tư 15 giây "hiểu chưa" (nút lá bùa 56dp, "Bỏ qua" luôn hiện).
8. Nhật ký 3 câu; streak freeze; xóa dữ liệu local 1 chạm.
9. Dark **tokens** (khai báo, chưa bật) + mockup 2 cỡ chữ.

**Tiêu chí đo:** Home <150ms; ≤2 chạm đến Pomodoro; mở app→phiên đầu <15s; **≥120 test pass**; nav/notification **0 fail**; 100% luồng Hôm nay offline; freeze + phản tư pass 100%.
**Rủi ro:** refactor nav silent sai màn → golden 5 màn × 3 state trước; migration mất dữ liệu → fixture v1/v2 + restore test.

### M2 (3 tuần) — "Kế hoạch sửa được"

1. Onboarding sinh kế hoạch 3 ngày sửa được.
2. Gợi ý đổi lịch cụ thể rule-based từ tiến độ thật.
3. Dark bật theo màn (Cá nhân → Kế hoạch → Hôm nay), chỉ hệ thống/lịch, AA.
4. Tách file <900 dòng (`study`/`home`/`account`/`onboarding`/`ai_coach`).
5. Quiz ảnh lưu kết quả + SRS lite (`QuizAttempt`, `ReviewSuggestion`) có migration.
6. Preview báo cáo phụ huynh + nhật ký quyền; **xóa toàn bộ dữ liệu (local + cloud)**.
7. Nút tắt gamification; XP → Cá nhân; mascot sau phiên.
8. AI điểm 1: tạo task có preview; pilot 10 HS × 7 ngày.

**Tiêu chí đo:** sửa/hoãn/chia ≤3 chạm; dark AA toàn màn; p95 frame <16ms; file <900 dòng; preview AI 100%; crash-free ≥99,5%; D7 ≥ baseline (mục tiêu 35% chốt sau baseline).
**Rủi ro:** SRS mới → backup/migration idempotent; màu hardcode → rà 5 màn.

### M3 (4 tuần) — "Giữ chân"

1. Sync queue + 500 kịch bản không mất dữ liệu; chính sách xung đột.
2. Pilot 50 người/30 ngày; đo D1/D7.
3. AI điểm 2: tổng kết phiên + fallback rule-based.
4. Cửa sổ phụ huynh hoàn chỉnh (chỉ xem; giới hạn giờ/ngày; nhắc ngủ 22:30; xin phép con).
5. Chế độ hậu kỳ thi + xuất/nhập dữ liệu + thi đua ẩn danh.

**Tiêu chí đo:** sync ≥99%; crash-free ≥99,5%; **D7 ≥ 35%**; ≥1 lý do mở lại/tuần; AI <5s 100%, fallback thành công ≥99%/30 ngày.
**Rủi ro:** free tier AI → fallback; rụng sau kỳ thi → chế độ hậu kỳ thi, không ép streak.

## 4. Yêu cầu "NGOẠI LỆ KHÔNG THƯƠNG LƯỢNG" → ánh xạ mốc

| Yêu cầu (từ USER/KH) | Mốc |
|---|---|
| Mở app <3s + backup offline, không mất phiên khi chuyển tab/tắt máy | M1 (đo lại ở pilot M3) |
| Luồng Hôm nay mạch lạc; hoãn/chia ≤3 chạm | M1 |
| Streak không phá tâm lý (freeze, báo trước, không âm đêm, tắt gamification) | M1–M2 |
| Điểm → gợi ý đổi lịch cụ thể | M2 |
| Offline + sync + xuất/nhập không mất dữ liệu | M1 (local) → M3 (sync/export) |
| AI fallback <5s, không màn trắng, ≥99%/30 ngày | M1 (fallback) → M3 (đo) |
| Không quảng cáo/cross-sell, kể cả hậu kỳ thi | Toàn bộ (Definition of Done) |
| Chế độ hậu kỳ thi thật | M3 |
| Phụ huynh chỉ xem, giới hạn giờ, xin phép con, nhắc ngủ | M2 (preview/quyền) → M3 (hoàn chỉnh) |
| Xóa toàn bộ dữ liệu 1 chạm | M1 (local) → M2 (cloud) |

## 5. Task list cho DEV

**M1:**
- [ ] route map + enum tab trong `main_shell.dart`
- [ ] `NotificationTapHandler` đọc payload + test nav
- [ ] golden 5 màn × 3 state (baseline trước khi sửa)
- [ ] tách `ai_copilot_service.dart`, giữ `sendPrompt` cho `AiActionsRow`
- [ ] sticky bar local state + `taskId` vào session entity
- [ ] `TaskActionSheet` hoãn/chia nhỏ task
- [ ] `ReflectionScreen` 15 giây + `SessionController` local
- [ ] banner "hôm qua chưa xong" (`getIncompleteTasks`)
- [ ] streak freeze + nhật ký 3 câu
- [ ] `design_tokens.dart` const + ảnh chữ 200%
- [ ] xóa dữ liệu local 1 chạm
- [ ] `flutter analyze` + ≥120 test xanh

**M2:**
- [ ] onboarding 3 ngày + gợi ý reschedule
- [ ] dark theo màn + AA
- [ ] tách `study_screen`/`home_screen`/`account_screen`/`onboarding_screen` <900 dòng
- [ ] entity `QuizAttempt`/`ReviewSuggestion` + migration v3 + backup
- [ ] preview báo cáo trong `api/family.js`
- [ ] wipe local + cloud + nhật ký quyền
- [ ] AI tạo task có preview (undo/chỉnh 100%)

**M3:**
- [ ] sync queue + 500 kịch bản
- [ ] AI tổng kết phiên + fallback
- [ ] giới hạn giờ học + nhắc 22:30
- [ ] export/import dữ liệu
- [ ] thi đua ẩn danh

## 6. Gate chuyển mốc & tổng kết

- **M1 → M2:** Home <150ms, ≤2 chạm đến Pomodoro, ≥120 test pass, nav 0 fail, mất phiên = 0 trên 10 HS × 7 ngày.
- **M2 → M3:** sửa/hoãn ≤3 chạm, dark AA, p95 <16ms, file <900 dòng, preview AI 100%, ≥8/10 HS nói "biết sửa lịch khi trượt việc".
- **Phát hành M3:** sync ≥99%, crash-free ≥99,5%, **D7 ≥ 35%**, AI fallback ≥99%/30 ngày trên 50 người/máy yếu.
- **Không đạt gate → dừng, sửa, không mở rộng phạm vi.**

**Kết luận buổi họp:** M1 giúp người dùng thật nhất — nó sửa đúng lý do người ta mở app ("việc quan trọng nhất + đếm ngược") và biến nó thành phiên học trong ≤2 chạm, đồng thời trả lời câu hỏi người dùng luôn tự hỏi: "hôm qua chưa xong gì". M2 giữ cho kế hoạch đủ dẻo, M3 giữ chân sau kỳ thi. Toàn bộ kế hoạch chạy được với **0 đồng chi phí**.
