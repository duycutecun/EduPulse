# Biên bản thảo luận kế hoạch phát triển EduPulse

**Dự án:** EduPulse — Trợ lý Sĩ tử & Đếm ngược Kỳ thi (Flutter PWA + Mobile)  
**Repo:** `C:\Users\Minh\.gemini\antigravity-ide\scratch\edupulse-flutter`  
**Ngày họp:** 2026-10-15  
**Hình thức:** 4 agent chạy song song (BOSS, DEV, UI CREATOR, USER & KHÁCH HÀNG), 2 vòng phát biểu + 1 vòng điều phối chốt kế hoạch; **VÒNG 4 (cùng ngày): kiểm chứng bằng mã nguồn + hiệu chỉnh**  
**Chi phí:** 0đ — toàn bộ chạy bằng agent local + dịch vụ free tier (Gemini free, OpenRouter `:free`, Vercel Hobby, Supabase free, GitHub Actions)

## Thành viên tham gia

| Vai | Nhiệm vụ trong buổi họp |
|---|---|
| **BOSS** | Nhà sáng lập / quản lý sản phẩm: định vị, yêu cầu đo được, lộ trình, phân bổ quota |
| **DEV** | Kỹ sư Flutter: đánh giá khả thi kỹ thuật, nợ công nghệ, thứ tự thực thi |
| **UI CREATOR** | Thiết kế UI/UX: luồng mở app→học, gamification, điều hướng, accessibility |
| **USER** | Học sinh lớp 12, người dùng thật: nhu cầu thực, đánh giá tính năng |
| **KHÁCH HÀNG** | Phụ huynh: niềm tin, quyền riêng tư, yêu cầu báo cáo |
| **ĐIỀU PHỐI VIÊN** | Tổng hợp transcript, xử lý xung đột, xuất kế hoạch cuối cùng |

## Tài liệu tham khảo trong buổi họp

- `README.md`
- `docs/KE_HOACH_CAI_TO_APP.md` (ràng buộc: **không billing** dưới mọi hình thức)
- `docs/DU_LIEU_VA_PHIEN_BAN.md`

---

# VÒNG 1 — Phát biểu ban đầu

## [BOSS] — Nhà sáng lập / Quản lý sản phẩm

### 1. Tầm nhìn & định vị

- **Đối tượng thật:** học sinh THPT 15–18 tuổi, ôn THPTQG/TSA/HSA trong 30–120 ngày cuối; điện thoại Android tầm trung, mạng chập chờn, chỉ có 1–3 tiếng học/ngày rải rác.
- EduPulse **không** là app "đa năng", mà là cái đồng hồ bám luật: mở app là biết ngay nên làm gì tiếp theo.
- **Giá trị khác biệt:** offline-first thật (mất mạng vẫn học được 100%), gia sư AI miễn phí đọc được ảnh đề bài, và cửa sổ tin cậy cho phụ huynh — mà không lấy của học sinh một đồng nào.

### 2. Yêu cầu đặt ra cho team

- **Tốc độ:** mở app → nhiệm vụ ưu tiên + nút *Bắt đầu* hiện ra **< 1,5 giây** trên máy RAM 3GB; từ mở app đến phiên học đầu tiên **< 15 giây**.
- **Offline:** 100% luồng Hôm nay (xem → học → hoàn thành → kế hoạch cập nhật) chạy được khi tắt mạng hoàn toàn.
- **AI:** token trả về đầu **< 5 giây**; khi lỗi hoặc hết quota phải có đường vòng thủ công rõ ràng — không tồn tại màn hình chết.
- **Tin cậy:** crash-free ≥ 99,5%; sync thành công ≥ 99%; **0 mất dữ liệu** khi đổi thiết bị, restore backup hoặc tắt app giữa lúc sync.
- **Chất lượng giao diện:** touch target ≥ 44dp, tương phản WCAG AA, cỡ chữ 200% không vỡ layout.
- **CI:** format + analyze + toàn bộ test pass + build web xanh; phủ domain ≥ 70%.

### 3. Lộ trình 3 mốc

- **Mốc 1 — MVP ổn định (4 tuần):** P0 hoàn tất; ≥ 120 test pass; migration v1→v3 và offline→online restore có test bảo vệ; trạng thái loading/empty/error thống nhất ở 5 màn chính. *Đạt = 10 học sinh dùng 7 ngày liên tiếp, không mất một phiên học nào.*
- **Mốc 2 — Cải tổ trải nghiệm (5 tuần):** IA 3 điểm đến (Hôm nay/Kế hoạch/Cá nhân), onboarding sinh kế hoạch tuần đầu, phiên học có phản tư ≤ 15 giây. *Đạt = ≥ 70% người dùng mới hoàn tất phiên đầu mà không cần vào tab AI hay Cài đặt; D7 ≥ 35%.*
- **Mốc 3 — Mở rộng (6 tuần):** AI theo ngữ cảnh có preview/undo, cửa sổ phụ huynh, PWA/app ổn định, cộng đồng và bảng xếp hạng. *Đạt = ≥ 500 người dùng hoạt động/tuần, ≥ 60% phiên gắn với nhiệm vụ.*

### 4. Chiến lược "0 chi phí"

- **Agent gánh phần lặp:** sinh test, tách màn hình lớn, viết migration, review, release notes — người chỉ định hướng và duyệt diff.
- **Tầng miễn phí:** Gemini free tier + OpenRouter các model `:free` + Vercel Hobby + Supabase free + GitHub Actions (2.000 phút/tháng) + GitHub Pages cho PWA.
- **Chất lượng bằng guardrail thay vì bằng tiền:** timeout, retry có giới hạn, error taxonomy, fixture test cho prompt, cache 24h, catalogue model tự cập nhật.
- **Ranh giới cứng:** khóa API nằm phía server (proxy), BYOK cho người dùng tự nhập; không billing, không quảng cáo, không bán dữ liệu học tập — không lúc nào.

### 5. Rủi ro kinh doanh lớn nhất & giảm thiểu

- **Phụ thuộc free tier AI** (hết quota, model đổi hành vi hoặc bị rút): 3 provider dự phòng, tự chuyển model khi lỗi, cache, và trợ lý học thuần local dự trù sẵn.
- **Lộ khóa API** trong binary/web bundle: proxy server, rate limit, audit log đã lọc, không bao giờ log giá trị khóa, có quy trình xoay key.
- **Rụng người dùng ngay sau kỳ thi** vì mất mục tiêu: cần chế độ hậu kỳ thi, mục tiêu mới, và cho phép tự tạo kỳ thi.
- **Quyền riêng tư học sinh** (người dưới 18 tuổi, dữ liệu nhạy cảm): consent tối thiểu, xoá dữ liệu một chạm, báo cáo phụ huynh do học sinh chủ động chia sẻ. Đây là ranh giới không đổi được — miễn phí không có nghĩa là cẩu thả.

---

## [DEV] — Kỹ sư phát triển

### 1. Đánh giá tính khả thi

- Điều hướng 3 tab "Hôm nay / Kế hoạch / Cá nhân": **khả thi cao**. `lib/app/main_shell.dart` đã có `IndexedStack` + lazy tab, lazy-load và cache widget (`_cachedAi`, `_cachedStudy`) — chỉ cần đổi mapping index, gộp AI vào entry điểm theo ngữ cảnh và chuyển Study/Exams/Notes thành route phụ thay vì tab. Repo pattern đã có sẵn: repository singleton + `revision` ValueNotifier (`TaskRepository`, `StudySessionRepository`, `ExamRepository`) và `AsyncStateController` — đủ để dựng controller cho từng tab mà không cần thêm provider/riverpod.
- Onboarding → kế hoạch học đầu tiên: **khả thi, đây là lát cắt rẻ nhất**. `onboarding_screen.dart` (~1.316 dòng) đã seed nhiệm vụ mẫu qua `preset_exams.dart`; nâng lên "tuần khởi đầu có thể sửa" chỉ là mở rộng bước seed + thêm màn preview "Bắt đầu ngay". Có ngay `ai_plan.dart`/`ai_sprint4_planner.dart` và logic thuần `distribute_day`, `optimize_week`, `weekly_summary` để tái dùng cho việc sinh tuần học.
- AI theo ngữ cảnh thay vì tab chính: **khả thi về UI, rủi ro về kiến trúc**. `AiCoachScreenState` đang phơi `sendPrompt` qua GlobalKey cho `main_shell` — tách AI khỏi tab sẽ đụng chỗ này; cần tách `AiRouter`/`ai_copilot_service.dart` (1.051 dòng) thành các use-case nhỏ (giải thích, tạo task có preview, quiz) trước khi gắn vào nhiệm vụ/điểm thử.

### 2. Rủi ro kỹ thuật & nợ công nghệ

- **File khủng vẫn là nợ chính**: study_screen ~1.850, account_screen ~1.341, onboarding ~1.316, auth_screen ~1.262, ai_coach_screen ~1.129, ai_copilot_service ~1.051. Kế hoạch cải tổ điều hướng sẽ *chạm trực tiếp* vào các file này (state nhiệm vụ, phiên học, AI) — sửa trên file lớn dễ gãy ngầm.
- **Migration SharedPreferences**: hiện đã có hạ tầng tốt (`data_schema_version`, `DataMigration` v1→v3 với snapshot/rollback, inventory đầy đủ trong `docs/DU_LIEU_VA_PHIEN_BAN.md`). Rủi ro là thêm model mới (tuần kế hoạch, phản tư phiên) mà migrate lệch phiên bản hoặc quên ghi khoá vào inventory.
- **Sync**: `sync_outbox_v1` + `backup_service.dart` (~936 dòng) là vùng rủi ro nhất với người dùng 2 thiết bị; kế hoạch mới (session reflection, plan) làm tải dữ liệu đồng bộ tăng lên.
- **Test**: 85 file test (tốt), nhưng nếu tách feature và đổi đồng thời state pattern, dễ lệch test khỏi hành vi thật — cần test hồi quy đứng sau mỗi lát tách.

### 3. Ưu tiên đề xuất

- **Làm trước (mỏng, đúng vòng lặp)**: (a) đổi tab 3 cột + chuyển Study/Exams/Notes thành route phụ; (b) onboarding xuất "tuần khởi đầu + Bắt đầu ngay" tận dụng `preset_exams`; (c) nối task → focus session → phản tư 15 giây. Đây là Giai đoạn 1 nhưng nên làm **trước** việc tách file lớn, vì nó định hình controller cho việc tách.
- **Làm song song, nhẹ**: tách `study_screen`/`home_screen` theo lát cắt hành vi (đã có `score_tab_view`, `study_analytics_view`, `exam_mode_cards`... làm tiền lệ — tiếp tục đà đó, không viết lại).
- **Hoãn/làm nhẹ**: chuyển SharedPreferences → database; AI đa ngữ cảnh tản đều (chỉ làm 2 điểm: tạo task từ AI có preview + tổng kết phiên); đổi state management toàn cục; mở rộng AI tab thành trợ lý toàn app.

### 4. Độ phù hợp người dùng thật

- Học sinh điện thoại phổ thông + 4G chập chờn: kế hoạch 3 tab + "Bắt đầu ngay" **đúng hướng** — giảm nhận thức so với 4 tab + AI tab riêng.
- Ràng buộc thực tế phải nhớ: mọi mới (plan, reflection) phải chạy **hoàn toàn offline**, payload nhẹ (SharedPreferences còn nguyên ở giai đoạn 1), không ép preload AI/ảnh; fallback thủ công cho mọi đề xuất AI; giữ PWA cài được trên máy yếu (bundle web, font local đã ổn).
- Streak/mascot giữ nguyên nhưng **phản hồi phụ** (đúng 5.2) — tránh gamification che CTA học trên màn hình nhỏ.

---

## [UI] — UI CREATOR

### 1. Luồng "mở app → học trong <15 giây, một tay"

- App đã đúng hướng: `HomeHeader` gọn 48px đúng vì "mở app là biết mình phải làm gì", `TodayMissionCard` đã thu gọn còn 1 việc ưu tiên + 3 việc kế tiếp (`_collapsedCount = 4`). Giữ nguyên thứ tự này.
- Thêm **thanh hành động dính đáy màn hình** (sticky bottom bar, cao 56px + safe-area): luôn hiện "Bắt đầu · 25 phút" cho việc ưu tiên, bên phải là "Hoãn". Vùng này nằm trong tầm ngón tay cái khi cầm một tay trên máy 6.1" — quan trọng hơn mọi thứ khác trên màn hình.
- Một chạm = vào thẳng phiên Pomodoro gắn với nhiệm vụ đó. **Không dialog xác nhận, không chọn môn/lại thời lượng.** Mọi câu hỏi dồn về sau phiên (theo 5.3: form 15 giây khi kết thúc).
- Khởi động offline-first: nếu đã có dữ liệu local, Home render ngay (<150ms), không chờ mạng. Skeleton chỉ cho lần mở đầu tiên.
- Có phiên đang dở → `ActiveSessionResumeCard` thay CTA bằng "Tiếp tục, còn X phút". Empty state chỉ có **một** nút "Lập kế hoạch 3 phút", không để bảng trống.

### 2. Gamification: giữ 3, dời 2

- **Giữ:** streak (1 chip 🔥 một dòng), XP/cấp (chỉ trong Cá nhân), mascot (phản hồi cảm xúc *sau* phiên học, có thể tắt — đã có key `mascot_enabled`).
- **Dời khỏi Home:** bốc quẻ — giữ, nhưng chỉ bên trong modal mascot, tối đa 1 lần/ngày, không nổ hiệu ứng. Bốc quẻ không được mở tự động.
- **Bảng xếp hạng:** chuyển xuống cuối tab Kế hoạch. Với học sinh lớp 12 đang chậm nhịp, bảng so sánh là động lực âm. Nếu giữ, chỉ hiện kỷ lục cá nhân (đúng hướng "Bảng vàng" hiện có, chạy trên máy).
- **Nguyên tắc:** 40% đầu fold chỉ chứa việc cần làm. Gamification cao tối đa 1 hàng chip, nằm dưới fold, và chỉ xuất hiện **sau khi** hoàn thành (delay ~300ms) chứ không phải trước. Không thưởng bằng cách chặn màn hình.

### 3. Ba tab Hôm nay · Kế hoạch · Cá nhân

- Map trực tiếp: Hôm nay = Home; **Kế hoạch** = gộp Tiến độ + "Mục tiêu" (kỳ thi) + "Tập trung" (Pomodoro/nhật ký/điểm) + Lịch; Cá nhân = tab Tôi.
- **Bỏ AI khỏi thanh tab.** AI trở thành lối vào ngữ cảnh + một hàng nút ở dưới Home (`AiActionsRow` đã gộp đúng 3 card → 1 hàng, giữ).
- Di chuyển các trang full-screen (Exams/Study/Calendar) thành **section trong tab Kế hoạch** — đừng để học sinh "đi lạc" sang màn pushed rồi mất phương hướng.
- Lưu ý kỹ thuật khi chuyển: `main_shell` đang có `_switchTab(1)` cho AI và `_switchTab(2)` cho Tiến độ, `NotificationTapHandler` điều hướng theo tab index — phải đổi sang route push và kiểm test lại, kẻo tab bị lệch.

### 4. Hợp người dùng thật (lớp 12, máy phổ thông, học tối)

- **Chữ:** tiêu đề nhiệm vụ 16–17px (nâng từ body 14), tên môn ≥16px, phụ đề 13px, không có chữ nào dưới 12px. Kiểm với `textScale` 1.3 không vỡ layout — học sinh hay bày to chữ ra đọc.
- **Tương phản:** giữ biến thể high contrast; chú ý chip vàng streak (chữ vàng-trên-vàng dễ trượt AA) và badge huy hiệu — chuyển sang chữ nâu đậm. Chữ phụ ≥4.5:1.
- **Vùng chạm:** giữ token 44/48, CTA chính 56, cách các nút ≥8px; hành động nguy hiểm (xoá) đặt xa CTA học.
- **Dark mode: hiện app CHƯA có** (`app_theme.dart` `Brightness.light`, comment ghi rõ "Không có dark mode"). Với người ôn thi buổi tối đây là thiếu sót lớn nhất của tôi. Đề xuất P1: nền #12141A, card #1B1F27, chủ động theo hệ thống + override "theo giờ".
- **Hiệu ứng rất ít:** bỏ confetti/tự chạy carousel; chỉ một hiệu ứng — dấu tick khi hoàn thành kèm âm thanh ngắn (đã có `AudioSynthService`). Tôn trọng reduce motion; tránh glass blur vì máy phổ thông yếu GPU.

---

## [USER] — Học sinh lớp 12, người dùng thật

- Điều làm tôi mở app hằng ngày: thẻ "việc quan trọng nhất hôm nay" + đếm ngược kỳ thi. Hai thứ đó cho tôi lý do mở app trong 3 giây. Nút "Bắt đầu ngay" dẫn thẳng vào Pomodoro mà không phải vào tab khác là đúng hướng.
- Điều làm tôi bỏ sau 1 tuần: quá nhiều điểm đến tranh sự chú ý. Chat AI, lộ trình AI, nhật ký học, bốc quẻ, điểm thi thử — cái nào cũng hay nhưng không cái nào bắt buộc phải mở lại. Tôi bỏ khi app không hỏi tôi "hôm qua chưa xong việc gì".
- Đánh giá thật từng tính năng:
  - **Nhiệm vụ hôm nay**: lõi, giữ lại. Cần cho hoãn/chia nhỏ một chạm và hỏi lý do ngắn.
  - **Streak + lá bùa**: giữ được 1–2 tuần đầu, sau đó gây lo khi sắp mất chuỗi. Lá bùa tránh bỏ cuộc — good.
  - **Mascot/bốc quẻ**: dễ thương nhưng tôi chỉ bấm 2–3 lần rồi chán. Không được để nó che nút học.
  - **Quiz từ ảnh**: tính năng tôi sẽ dùng nhất trong tab AI vì giải quyết việc ngay trước mắt. Nhưng phải lưu kết quả và gợi ý ôn lại, không xong là hết.
  - **Lộ trình AI**: hay nhưng tôi không tin kế hoạch sinh sẵn 14 ngày; tôi cần kế hoạch cho 3 ngày tới và được sửa được.
  - **Pomodoro**: cần gắn với nhiệm vụ + hỏi "hiểu chưa" sau phiên, chứ bấm giờ trống không thì tôi bỏ.
  - **Nhật ký học**: ép viết dài là rào cản. Gợi ý hỏi 3 câu 15 giây là đủ.
  - **Điểm thi thử**: cần, nhưng chỉ hữu ích khi nói "môn này yếu, đổi 25 phút từ thứ Năm sang thứ Sáu".
  - **Báo cáo phụ huynh**: với tôi chỉ cần một công tắc "con tự gửi" — quan trọng là tôi chọn chia sẻ gì.

## [KHÁCH HÀNG] — Phụ huynh

- Tin tưởng vì: dữ liệu lưu trên máy + báo cáo chỉ chứa những gì con tôi chủ động chọn chia sẻ; có ngắt liên kết bất cứ lúc; không quảng cáo; không thu phí; không đòi số điện thoại hay kết bạn với người lạ.
- Lo nhất: quyền riêng tư chat và ảnh đề bài của con gửi đi đâu; con bị kéo vào app lúc 11 giờ đêm; app "báo" điểm xấu của con lên tôi gì hiểu lầm. Muốn báo cáo tuần có ngữ cảnh ("tuần này 4 phiên, mạnh Hóa, cần cải thiện Toán"), không phải bảng số thô.
- Yêu cầu không thương lượng: màn xem trước báo cáo trước khi gửi, nhật ký thay đổi quyền chia sẻ, có cách xóa toàn bộ dữ liệu, không có leaderboard nhìn thấy tên thật của con.

**Yêu cầu cho kế hoạch:**

- MUST-HAVE (người dùng thật): luồng Hôm nay liền mạch mở app → bắt đầu → hoàn nhất; hoãn/chia nhỏ nhiệm vụ; Pomodoro gắn nhiệm vụ; streak không phá vỡ tâm lý; quiz từ ảnh lưu được kết quả; điểm thử → gợi ý cụ thể; báo cáo phụ huynh do học sinh kiểm soát; offline + sync không mất dữ liệu.
- Nice-to-have: lộ trình AI dài ngày, deep report, bảng xếp hạng, widget màn hình chính, nhắc học nâng cao, trang phục mascot.

**Về ràng buộc "miễn phí 100%, không quảng cáo, không billing":**

- Đúng và cần thiết — với học sinh Việt Nam, thu phí = chết. Nhưng không đủ để giữ người dùng lâu dài. Miễn phí chỉ là vé vào cửa; thứ giữ chân là (1) AI vẫn trả lời tốt và ổn định — đây là rủi ro thật vì phụ thuộc model free của bên thứ ba; (2) dữ liệu của tôi không bao giờ mất; (3) mỗi tuần có lý do mới để mở lại. Đề nghị: ưu tiên tuyệt đối cho độ ổn định AI + fallback không AI, và chốt chỉ số giữ chân D7 thay vì thêm tính năng.

---

# VÒNG 2 — Phản biện & đề xuất phương án

*Các bên đọc ý kiến lẫn nhau để phản hồi, tranh luận và đề xuất phương án chốt.*

## [BOSS] vòng 2

### 1. Phản hồi từng bên

**Với DEV — đồng ý 90%:** đổi 3 tab và chuyển Study/Exams/Notes xuống route phụ là việc đầu tiên; onboarding ra kế hoạch khởi đầu + "Bắt đầu ngay" là lát cắt rẻ nhất; AI rời tab chính nhưng chỉ làm 2 điểm (tạo task có preview, tổng kết phiên). Hai chỗ tôi push back: (a) không được hoãn test navigation — UI cảnh báo đúng, `_switchTab(1)/(2)` và `NotificationTapHandler` đổi index sai là hỏng thông báo nhiệm vụ, phải test lại trong M1; (b) mọi đường AI phải có fallback không AI (rule-based offline), vì "miễn phí chỉ là vé vào cửa". Chuyển database tôi đồng ý hoãn, nhưng có điều kiện: phải chứng minh backup/restore 100% qua test + diễn tập migrate/rollback trước khi chạm schema v4.

**Với UI — đồng ý:** giữ Home hiện có, TodayMissionCard 4 việc, sticky bar 56px một chạm, không dialog, AA/16px/touch 44/48, không blur, AiActionsRow 1 hàng. Từ chối leaderboard kể cả "xuống cuối tab Kế hoạch": phụ huynh đã nói không tên thật, đây là nice-to-have, giữ nó là tranh chú ý. Dark mode đồng ý làm P1, nhưng chỉ theo hệ thống + lịch người dùng tự đặt (để nhắc con tắt trước 21h), không app tự ép, không glass.

**Với USER/PHỤ HUYNH — đồng ý toàn bộ MUST.** Push back hai điểm: "kế hoạch 3 ngày sửa được" tôi chốt đúng như vậy, không phải lộ trình 14 ngày; bốc quẻ không bỏ mà nhốt trong modal mascot tối đa 1 lần/ngày, không che nút học. Bổ sung: freeze streak 1 lần/tháng, để streak là lá bùa chứ không phá tâm lý.

### 2. Phạm vi chốt

**LÀM NGAY:** 3 tab + route push; thẻ "Hôm qua chưa xong gì"; sticky bar Pomodoro gắn nhiệm vụ; phản tư 15s "hiểu chưa"; hoãn/chia nhỏ task; streak freeze; quiz lưu kết quả + gợi ý ôn lại; onboarding xuất kế hoạch 3 ngày; nhật ký 3 câu; dark mode system+schedule; preview báo cáo con tự gửi; xóa toàn bộ dữ liệu một chạm.

**LÀM SAU:** AI 2 điểm có preview; tách file khủng; widget; deep report.

**BỎ-HOÃN:** leaderboard BỎ; lộ trình AI 14 ngày HOÃN; chuyển database HOÃN có điều kiện; AI đa ngữ cảnh HOÃN; đổi state management toàn cục BỎ.

### 3. Lộ trình 3 mốc

- **M1 "Hôm nay liền mạch" — 3 tuần.** Tiêu chí đo: Home render <150ms; mở app→bắt đầu Pomodoro ≤2 chạm; test 3 tab + notification push 0 fail; freeze streak và quiz-lưu pass 100%.
- **M2 "Kế hoạch sửa được + điểm→hành động" — 3 tuần.** Tiêu chí: sửa/hoãn/chia task ≤3 chạm; gợi ý cụ thể ("đổi 25 phút từ thứ Năm sang Sáu") hiện trong session; dark mode contrast AA ≥4.5; p95 frame <16ms; study_screen/account tách xuống <900 dòng mỗi file; AI preview huỷ/chỉnh được 100%.
- **M3 "Giữ chân — 4 tuần"**. Tiêu chí: sync xanh 500 kịch bản không mất dữ liệu; crash-free ≥99.5%; đo D1/D7; ít nhất 1 lý do mở lại mỗi tuần (nhắc nhiệm vụ chưa xong + gợi ý ôn).

### 4. Quota (0 chi phí)

DEV: 50% tính năng M1+M2; 20% tách file khủng + viết test navigation/sync; 20% backup/restore + diễn tập migrate; 10% hiệu năng và perf budget. AI chỉ chạy local/heuristic, không tốn tiền. UI: 100% thiết kế token cho dark mode và các card M1. BOSS: chốt phạm vi, copy map, đo D1/D7. USER/PHỤ HUYNH: hai vòng phỏng vấn để duyệt preview báo cáo và xác nhận không thấy áp lực trước M3.

---

## [DEV] vòng 2

### 1. Đánh giá chi phí dev từng yêu cầu

**Rẻ, nên làm ngay trong Mốc 1:**

- Sticky bottom bar 56px (`Bắt đầu · 25 phút` + `Hoãn`): widget thuần local state, không đụng router/repository, dễ widget test, render <150ms dễ đạt vì chỉ setState trong vùng bar.
- Hoãn/chia nhỏ 1 chạm: thêm 2 action vào TaskActionSheet đang có, gọi lại `updateTask(dueDate)`/`splitTask()` — hầu như không có model mới.
- Phiên học gắn nhiệm vụ: chỉ cần thêm `taskId` vào entity session + truyền qua route constructor; không đổi schema phức tạp.
- Nhật ký 3 câu 15 giây: form 3 trường + timestamp, lưu qua repository local sẵn có.
- Bỏ tên thật khỏi leaderboard: filter field, hoặc chỉ giữ kỷ lục cá nhân → gần như free.
- Gỡ AI khỏi tab giữ `AiActionsRow`: nhưng **cái đắt là refactor navigation**, không phải UI phần tử.

**Tốn chi phí ẩn — phải trừ ra khỏi M1:**

- Quiz ảnh lưu kết quả + gợi ý ôn lại: cần entity mới (QuizAttempt/ReviewSuggestion), luồng ảnh chưa có quy ước lưu offline, và gợi ý ôn lại bản chất là thuật toán lập lịch (SRS lite) — không "rẻ".
- Preview báo cáo phụ huynh: build report snapshot + luồng đồng thuận quyền + xóa dữ liệu 1 chạm phải đồng bộ local/server, dính migration và restore.
- Dark mode preflight toàn app: phải rà text/icon màu hardcode, contrast, chart colors, 5+ màn — không phải một biến theme.
- `_switchTab(1)/(2)` + `NotificationTapHandler` theo index: đây là **refactor khẩn cấp và rủi ro nhất** nếu làm trước khi gỡ tab AI, vì thứ tự tab sẽ đổi → index sai → bạn bị lỗi silent "mở sai màn" chứ không crash.

### 2. Phương án thực thi

**(a) task→session→reflection:** giữ kiến trúc hiện có, chỉ nối dữ liệu: `HomeScreen` (bar) → `TaskScreen` → `TimerSessionScreen(taskId)` → `ReflectionScreen(taskId, sessionId)`. Dùng 1 `SessionController` cục bộ chứa `taskId`, không global; reflection lưu 1 record gồm 3 câu + mức hiểu, không sinh phân tích AI ở M1. Bar chỉ set state và push 1 route duy nhất — không đụng bottom nav.

**(b) dark mode theo giai đoạn:** Giai đoạn 1 (M1, ~2 ngày) tạo bảng màu token-only (`AppColorTokens` cho hai scheme) và mockup 3 màn chính, chưa bật. Giai đoạn 2 (M2) bật theo màn Settings/Plan trước, có toggle "theo hệ thống", chạy contrast test AA. Giai đoạn 3 mới bake mặc định. Không bao giờ đổi `app_theme.dart` big-bang.

**(c) "hỏi công việc chưa xong hôm qua":** repo method `getIncompleteTasks(before: DateTime.now())` + một banner ở đúng tab Kế hoạch; data từ local source nên không chờ sync, 1 chạm mở luôn lại task đó.

**(d) AI rời tab không vỡ GlobalKey:** thay `_switchTab(index)` bằng route-based navigation (`pushNamed` hoặc route có key riêng), và `NotificationTapHandler` đọc payload từ notification thay vì map index hardcode. Tách `MainNavigation` chỉ còn 3 điểm đến. GlobalKey không sửa — chỉ đổi cách nó được gọi (qua route map), nên không xung đột.

### 3. Rủi ro phải giảm thiểu trước khi sửa

- **Test bảo vệ:** (i) golden/widget test cho 5 màn về 3 trạng thái loading/empty/error **trước** khi sửa AI tab (chụp baseline hiện tại), (ii) test điều hướng: mọi push/pop route qua bộ route mới có test, (iii) test regression task→session→reflection, (iv) migration v1→v3 có fixture v1/v2 và test round-trip restore.
- **Thứ tự merge:** nhánh 1 = refactor navigation + route map + test (chưa gỡ tab AI) → nhánh 2 = gỡ tab AI, chuyển UI AI vào `AiActionsRow`/modal → nhánh 3 = sticky bar + flow session → nhánh 4 = dark tokens. Nếu làm ngược (gỡ tab trước rồi mới refactor nav) sẽ vỡ index và mất thời gian xử lý regression.

### 4. Cam kết phạm vi Mốc 1

**Vào:** ≥120 test pass (bao gồm 5 màn trạng thái thống nhất + 3 flow mới), migration v1→v3 + restore offline→online có test, sticky bottom bar + hoãn/chia nhỏ, phiên học gắn task + hỏi "hiểu chưa" 15 giây, nhật ký 3 câu, banner "hôm qua chưa xong", refactor navigation an toàn + AI rời tab giữ `AiActionsRow`, token dark + mockup, crash-free ≥99.5%, sync ≥99%.

**Rời ra:** quiz ảnh lưu kết quả + gợi ý ôn lại, preview báo cáo phụ huynh, dark mode bật thực tế, PWA/app, xóa toàn bộ dữ liệu 1 chạm, AI phân tích theo ngữ cảnh/undo, bảng xếp hạng full. Lý do: tất cả đều cần model/nguyên liệu (AI attempt, permission model, dark pass 5 màn, service delete API) không sẵn, làm đồng thời sẽ phá crash-free và sync của M1.

---

## [UI] vòng 2

### 1. Phản hồi Dev — hi sinh ở Mốc 1 có chủ đích

Ổn với việc bỏ dark mode ở Mốc 1, không đổi state management, không đụng AI. Tôi hy sinh: (a) **sticky bar** "việc quan trọng nhất" — chỉ làm inline card trong Hôm nay, không FloatingPanel/FrostedLayer; (b) **transition mượt** — chỉ fade 150ms trong Material, bỏ hero tùy chỉnh và shared axis nhiều bước; (c) **page indicator onboarding** — dùng animated dots đơn giản, bỏ hiệu ứng ripple/parallax. Giữ **bắt buộc**: IndexedStack 3 tab + `_switchTab` theo enum không index, tab chính nhét càng nhiều trạng thái học được càng tốt để Mốc 2 rút ra thành route riêng không vỡ layout. Mọi thứ tôi thiết kế theo khung widget hiện có, không yêu cầu viết lại shell.

### 2. Dark mode theo giai đoạn — không big-bang

Đề xuất **token màu tập trung ngay từ Mốc 1** (`AppColors` → `AppColorsSeed.light/dark`), nhưng bảng dark **chỉ khai báo, chưa bật**. Lộ trình: Mốc 2 bật dark **theo tab**: tab Cá nhân/Profile trước (mật độ thấp, ít state phức tạp, dễ chạy lại toàn bộ test), rồi tab Thư viện/Nhiệm vụ, để cuối tab Hôm nay (nhiều realtime countdown, error state nhất). Lý do: tab nào chưa đổi thì force light, không có trạng thái "nửa sáng nửa tối" trong một màn hình. ThemeExtension riêng cho semantic states (success/warning/danger ở cả hai chế độ) để Mốc 1 đã phủ WCAG AA ở bảng sáng, tránh phải đo lại tương phản khi sang dark.

### 3. Form phản tư 15 giây + "việc chưa xong hôm qua"

Form: một màn hình riêng, trường "có làm được không?" (nút lá bùa to 56dp), counter tự động — không yêu cầu bắt buộc viết. Nếu đủ thời gian, bật 3 dòng ghi chú tùy chọn với hint gợi ý ("hôm nay vướng gì?"), nút "Bỏ qua" luôn hiện góc phải, nút "Lưu" to dưới đáy màn, không ẩn sau bàn phím. 15 giây tính từ lúc hiện, auto-advance nếu 2 lần cảm biến không chạm (chỉ khi đã chọn làm được/chưa) — không ép.

Việc chưa xong: không mở như việc tồn đọng (không đỏ, không số đỏ). Hiện dạng **chip xám trung tính** ở đầu Hôm nay: "2 việc trượt từ hôm qua" + nút "ôm hôm nay/xoay lại". Icon tròn mũi tên xoay, màu neutral, không có dấu chấm than. Bấm chip mới xổ danh sách chọn. Nếu người dùng chọn bỏ hẳn, dòng đó xám dần và biến mất sau 3 giây — không hỏi lại "chắc không?".

### 4. Handoff cho Dev (Mốc 0.5 tuần — dev chạy được ngay)

Gói bàn giao: (1) `design_tokens.dart` dạng biến const Dart, có comment hex/rgba — copy được, không cần đọc Figma; (2) **5 màn × 3 state** (loading skeleton / empty có CTA / error có nút thử lại) giao dưới dạng bảng widget mẫu ngắn, không phải file PSD; (3) ảnh chụp màn hình: 1 màn mỗi tab × 2 cỡ chữ (100%, 200%) cho cả bảng sáng, đánh dấu vùng touch <44dp; (4) phân loại nút: chính (filled 56dp), phụ, huy hiệu. Sau Mốc 1 dev không đợi design hoàn thiện — ship token trước, màn chi tiết sau, **tối đa 3 vòng review, mỗi vòng ≤1 ngày**.

### 5. Gamification chốt cho Mốc 2

**Giữ**: streak 1-2 tuần (lá bùa, không phạt), daily countdown → thành focus timer gắn nhiệm vụ, quiz từ ảnh nhưng bắt buộc lưu kết quả + ô bài gợi ý, "việc quan trọng nhất" làm chip nổi bật. **Bỏ**: lộ trình 14 ngày (thay bằng kế hoạch 3 ngày từ onboarding), nhật ký dài, leaderboard tên thật. **Đổi**: thay phần thưởng bằng thi đua cộng đồng ẩn danh (avatar mặt cười + mục tiêu chung), cửa sổ phụ huynh chỉ báo cáo định kỳ có **preview trước khi gửi** + nút xóa dữ liệu 1 chạm đặt ở Cài đặt → Quyền riêng tư, không chôn trong menu sâu. **Không đổi**: toàn bộ số/gamification hiển thị bằng dữ liệu cục bộ, offline hoàn toàn.

---

## [USER] & [KHÁCH HÀNG] vòng 2

### 1. Kế hoạch 3 mốc/an toàn kỹ thuật

**[USER]:** Mốc 1 (ổn định) đúng nỗi đau nhất: app hay mất phiên giữa bài. Nhưng 7 ngày × 10 học sinh là quá ít; phải thử trên máy phổ thông, mạng yếu, ít nhất 50 người/30 ngày. Thiếu tốc độ mở app <3 giây và backup offline — tôi mở lúc đang vội.

**[KHÁCH HÀNG]:** Ưu tiên ổn định là đúng. Nhưng phụ huynh cần biết rõ lộ trình 3 mốc có gì, và phải có phụ huynh tham gia thử nghiệm, không chỉ học sinh.

### 2. Phản hồi UI

**[USER]:** Đồng ý bỏ dialog — mỗi lần bấm là đứt mạch học. Sticky bar một chạm vào Pomodoro gắn sẵn nhiệm vụ #1 là đúng, nhưng đừng hỏi thêm bước nào. Đồng ý giữ streak chip/XP/mascot, nhưng leaderboard chỉ kỷ lục cá nhân.

**[KHÁCH HÀNG]:** Chữ ≥16px, AA là phải. Streak đỏ đang gây áp lực vô ích — phải có nút tắt toàn bộ gamification trong Cá nhân, ít nhất hiển thị "nghỉ có báo trước thì không mất streak".

### 3. Chống AI lỗi & "miễn phí vé vào cổng"

**[USER]:** Miễn phí, không quảng cáo là tốt. Nhưng điều kiện để tôi ở lại sau kỳ thi: (1) AI lỗi thì fallback trả kế hoạch dùng được trong 5 giây, không màn hình trắng; (2) tỷ lệ fallback thành công ≥99% trong 30 ngày; (3) không quảng cáo/cross-sell kể cả ở chế độ hậu kỳ thi; (4) chế độ hậu kỳ thi phải thật: hướng dẫn ôn lại kiến thức, không ép streak; (5) xuất/đọc lại dữ liệu được, không khoá trong app.

**[KHÁCH HÀNG]:** Thêm điều kiện của tôi: cửa sổ phụ huynh chỉ để "xem", không phải "điều khiển" — không khoá app khi con đang chạy phiên.

### 4. Cửa sổ tin cậy — must còn thiếu

**[USER]:** Cần nhắc đêm "dừng, đi ngủ" và giới hạn giờ học hợp lý: không nhắc học sau 22:30, không hiện streak âm về đêm. Nội dung phản tư cá nhân phải hỏi tôi trước khi cho phụ huynh xem.

**[KHÁCH HÀNG]:** Must: đặt được giờ học tối đa/ngày; báo cáo tuần cho phụ huynh chỉ gồm giờ học, phiên hoàn thành, lịch tuần tới — không chi tiết cảm xúc; mọi thay đổi quyền phụ huynh phải xin phép tôi qua app trước khi bật.

### 5. 5 yêu cầu NGOẠI LỆ KHÔNG THƯƠNG LƯỢNG

1. Không mất phiên/mất dữ liệu khi chuyển tab hay tắt máy — backup tự động, mở lại đúng chỗ đang làm.
2. Fallback AI đủ dùng, không màn hình trắng, không hỏng cả ngày học.
3. Không quảng cáo, không thu phí, không bán dữ liệu — kể cả mốc 3.
4. Tắt được toàn bộ gamification (streak, XP, mascot) và app vẫn đủ dùng cho kế hoạch + Pomodoro.
5. Streak không phạt khi người dùng báo trước, và có chế độ hậu kỳ thi rõ ràng sau ngày thi cuối cùng.

---

# VÒNG 3 — Điều phối viên chốt kế hoạch

**Bối cảnh:** ĐIỀU PHỐI VIÊN đọc toàn bộ 2 vòng phát biểu, xử lý các điểm tranh chấp (leaderboard, timeline 4/5/6 vs 3/3/4 tuần, quy mô pilot 10 vs 50 người, sticky bar, quiz lưu kết quả, xóa dữ liệu 1 chạm) và xuất bản kế hoạch cuối.

## Các quyết định lớn đã chốt

1. **Điều hướng 3 tab** (Hôm nay / Kế hoạch / Cá nhân) bằng enum — bỏ bẫy index gây silent sai màn; Study/Exams/Notes → route push; notification tap đọc payload.
2. **AI rời tab chính**, chỉ giữ `AiActionsRow` + 2 điểm ngữ cảnh (tạo task có preview, tổng kết phiến); mọi đường AI có fallback rule-based offline, token đầu <5s.
3. **Leaderboard bỏ hoàn toàn** — thay bằng thi đua ẩn danh ở M3; streak freeze 1 lần/tháng, báo trước không mất streak, không âm về đêm, tắt được toàn bộ gamification.
4. **Dark mode tokens từ M1, bật theo màn từ M2** (Cá nhân → Kế hoạch → Hôm nay), chỉ theo hệ thống + lịch tự đặt.
5. **Timeline 3/3/4 tuần** (M1 "Hôm nay liền mạch" → M2 "Kế hoạch sửa được" → M3 "Giữ chân"); pilot 10 HS × 7 ngày trước M2, 50 người/30 ngày trước M3.
6. **Xóa dữ liệu 1 chạm** ở Cài đặt → Quyền riêng tư: M1 local, M2 cả cloud; cửa sổ phụ huynh chỉ "xem" không "điều khiển", preview trước khi gửi, xin phép con qua app.

## Gate chuyển mốc

- **M1→M2:** Home <150ms; ≤2 chạm đến Pomodoro; ≥120 test pass; nav/notification 0 fail; 10 HS × 7 ngày không mất phiên.
- **M2→M3:** sửa/hoãn/chia ≤3 chạm; dark AA; p95 frame <16ms; file lớn tách xuống <900 dòng; preview AI 100%; ≥8/10 HS xác nhận biết cách sửa lịch khi trượt việc.
- **Phát hành M3:** sync ≥99%; crash-free ≥99,5%; D7 ≥35%; AI fallback ≥99%/30 ngày trên 50 người dùng máy yếu.
- **Không đạt gate → dừng và sửa, không mở rộng phạm vi.**

## Kết luận

M1 giúp người dùng thật nhất: biến lý do họ mở app (việc quan trọng nhất + đếm ngược) thành phiên học ≤2 chạm, có banner "hôm qua chưa xong gì" và phản tư 15 giây. M2 làm kế hoạch đủ dẻo, M3 giữ chân sau kỳ thi (chế độ hậu kỳ thi + sync bất biến). Toàn bộ chạy được với **0 đồng chi phí**.

> Toàn bộ kế hoạch chi tiết (quyết định theo hạng mục, task list DEV, mapping yêu cầu không thương lượng → mốc) đã được xuất sang file **`KE_HOACH_PHAT_TRIEN_THOA_THUAN.md`**.

## Phụ lục: tiêu chí đo được được BOSS áp đặt

- Mở app → nhiệm vụ ưu tiên + nút Bắt đầu: **< 1,5 giây** trên RAM 3GB (USER đòi < 3 giây rộng hơn → giữ mốc 1,5s, đo lại ở pilot 50 người)
- Mở app → phiên học đầu: **< 15 giây**, ≤2 chạm
- 100% luồng Hôm nay chạy offline
- Touch target ≥44dp; WCAG AA; chữ 200% không vỡ layout
- ≥120 test pass ở M1; CI xanh; phủ domain ≥70%
- Khóa API chỉ ở phía server proxy; BYOK cho người dùng tự nhập

---

# VÒNG 4 — Kiểm chứng bằng mã nguồn & hiệu chỉnh kế hoạch

**Thời điểm:** 2026-10-15, ngay sau khi vòng 1–3 được ghi lại · **Thành phần:** vẫn 6 vai (BOSS, DEV, UI CREATOR, USER, KHÁCH HÀNG, ĐIỀU PHỐI VIÊN)
**Lý do họp:** vòng 1–3 đọc repo **có chọn lọc** — chỉ chỗ nào phục vụ lập luận của mình — và không mục nào kiểm "việc này đã xong sẵn chưa". Kết quả là kế hoạch M1 ghi 12 việc trong đó một số đã có trong code, một số quyết định chưa được thực thi (leaderboard, 4 tab). Vòng 4 bắt buộc mọi mục phải **kiểm được bằng một lệnh**; không bằng chứng thì không vào kế hoạch.
**Chi phí:** 0đ — không gọi API trả tiền, không tạo tài khoản mới, không đổi hạ tầng. Kiểm chứng chạy bằng `grep` + `git` trên chính máy này.

## 0. Giả định (nói trước, sửa được ngay)

1. Vòng 4 **kiểm chứng và hiệu chỉnh** kế hoạch đã có, không viết lại từ đầu.
2. Sáu vai do **một agent nhập vai tuần tự** — môi trường hiện tại không chạy 6 tiến trình độc lập. Đây là *biên bản phản biện có kịch bản*, không phải 6 ý kiến độc lập; phần "tranh chấp" ở mục 7 do người điều phối dàn dựng, không phải hai bên thực sự không biết ý nhau.
3. "0 chi phí" = không dịch vụ trả tiền + không thêm endpoint/hạ tầng nếu chưa cần + người dùng cuối không bao giờ bị thu phí.
4. Mọi số trong ngoặc là output lệnh thật, chạy ngày 2026-10-15 trên chính repo này (xem mục 11 để tự chạy lại).

→ Nếu giả định nào sai, đọc lại phần tương ứng trước khi dùng kết luận.

## 1. Bảng kiểm chứng thô (làm trước, khi chưa ai phát biểu)

| # | Hạng mục kế hoạch vòng 3 | Bằng chứng | Thực tế | Kết luận |
|---|---|---|---|---|
| 1 | 3 tab Hôm nay/Kế hoạch/Cá nhân, chọn bằng enum | `lib/app/main_shell.dart` `_primaryNavItems`; `_switchTab(0..3)` | `'Hôm nay', 'AI', 'Tiến độ', 'Tôi'`; `_visited = List.filled(4, false)` | **Chưa** — vẫn 4 tab, AI còn là một tab |
| 2 | Notification đọc payload, không đọc index | `lib/core/notifications/notification_tap_handler.dart` + `_checkNotificationTap()` | Đã đọc payload và mở đúng đích | **Một phần** — còn phụ thuộc index tab (0..3) |
| 3 | Dark mode token + bật theo màn | `app_theme.dart` chỉ `Brightness.light`; 0 file match `design_tokens`, `AppColorTokens`, `ThemeMode` | Chưa có token, chưa có dark | **Chưa** |
| 4 | Phiên học có phản tư 15 giây | 0 file match `Reflection` trong `lib` + `test` | Chưa có màn/record nào | **Chưa** |
| 5 | Banner "hôm qua chưa xong gì" | 0 file match `getIncompleteTasks` | Chưa có truy vấn lẫn UI | **Chưa** |
| 6 | Quiz ảnh lưu kết quả + gợi ý ôn lại | 0 file match `QuizAttempt`, `ReviewSuggestion` | Có `quiz_play_screen.dart`, `flashcard_review_screen.dart`; không có entity lưu | **Chưa** |
| 7 | Bỏ leaderboard | `lib/features/leaderboard/**`, 24 chỗ nhắc "Bảng vàng/Leaderboard" trong `lib`, `supabase/schema.sql`, 3 test riêng | Còn nguyên | **Chưa** — lệch quyết định vòng 3 |
| 8 | Streak freeze / lá bùa | `lib/core/utils/storage_service.dart`, `test/streak_and_week_test.dart` | Có | **Đạt (một phần)** — còn phải rà "không âm về đêm" và hạn mức 1 lần/tháng |
| 9 | Xuất/nhập dữ liệu | `lib/core/utils/data_transfer.dart` (`exportJson`), `account_screen.dart`, `test/widget_test.dart` | Có | **Đạt** |
| 10 | Xoá dữ liệu (local + cloud) | `privacy_data_screen.dart`; commit `3dbb05f` (`/api/account`) | Có | **Đạt** |
| 11 | Giới hạn giờ học + nhắc ngủ 22:30 | 0 file match `quietHours`, `studyTimeLimit`, `22:30` | Hạ tầng thông báo có (`plan_notifications`, `notification_service`, `adaptive_policy`) nhưng chưa có luật giờ | **Chưa** |
| 12 | Tách file khủng < 900 dòng | `wc -l` trên `lib/` | study 1850, account 1341, onboarding 1316, auth 1262, parent_home 1187, ai_coach 1129, home 1120, `ai_copilot_service` 1051 | **Chưa** — nhưng đã giảm mạnh so với 3088/1816/1466 ghi ở `KE_HOACH_CAI_TO_APP.md` |
| 13 | ≥120 test pass | 84 file `*_test.dart`; checklist ghi 934 test pass (2026-10-15) | 84 file / 934 test | **Đạt** (kế hoạch vòng 1 ghi "85 file" — lệch 1, cần đối chiếu) |
| 14 | AsyncState thống nhất loading/empty/error | commit `f0352ff` | Có | **Đạt** |
| 15 | BYOK lưu trong kho an toàn OS | commit `b32ee0c` (`flutter_secure_storage`) | Có | **Đạt** |
| 16 | Nhật ký thay đổi quyền chia sẻ | commit `867174d` | Có | **Đạt** |
| 17 | Không thêm function server (hạn mức Hobby) | 11 file `api/*.js` công khai (không tính `_*.js` và `*.test.js`); `vercel.json` có 1 cron `/api/cleanup 0 3 * * *` | 11 function + 1 cron | **Đạt** — còn ~1 slot, `family.js` đã 47 KB |
| 18 | Checklist phát hành | `docs/CHECKLIST_PHAT_HANH.md` | **10 mục còn mở**: xác nhận thủ công offline; "không mất dữ liệu" do người xác nhận; RLS (2 file SQL); `CRON_SECRET` + quota; deploy web `deploy.yml`; ghi rõ cấu hình build trong Summary; funnel onboarding; lỗi sync/AI trong ngưỡng; dữ liệu beta; người ký duyệt | **Chặn** |
| 19 | Tài liệu khớp mã nguồn | `README.md` ghi "3 tab chính: Học · AI · Tôi" | Mã có 4 tab: Hôm nay · AI · Tiến độ · Tôi | **Lệch** |

**Ba kết luận khô đọc ra từ bảng này:**

1. M1 **không bắt đầu từ số 0**: 6 hạng mục tưởng phải làm đã có sẵn trong code (xuất/nhập, xoá dữ liệu, consent quyền AI, BYOK, AsyncState, streak freeze).
2. M1 vẫn còn **5 việc chưa có một dòng code**: nav 3 tab, dark token, phản tư, banner "hôm qua", luật giờ học.
3. Thứ đang chặn người dùng thật **không phải tính năng thiếu**, mà là 2 file SQL (RLS) + 1 biến môi trường (`CRON_SECRET`) trong checklist phát hành.

## 2. [DEV] — chi phí thật, đo bằng số file sẽ phải sửa

**Nav 3 tab là việc đắt nhất, không phải việc rẻ nhất.**

- Bán kính ảnh hưởng: **8 file test** import `main_shell` (`widget_test`, `ui_acceptance_test`, `responsive_matrix_test`, `release_gates_test`, `e2e_scenarios_test`, `exam_immediate_refresh_test`, `desktop_aux_column_test`, `always_push_test`) + 4 file lib (`main.dart`, `onboarding_screen`, `reset_password_screen`, `account_role_gate`) + `_switchTab(0..3)` + `_visited` 4 phần tử + Ctrl+1..4 trong `_handleKey` + sidebar desktop + deep-link `deepLinkTaskId` + notification tap.
- **Chưa có golden test nào** (`matchesGoldenFile` = 0 file) → muốn đổi an toàn thì phải chụp baseline 5 màn × 3 trạng thái **trước**, đúng như tôi đã cảnh báo ở vòng 2. Ước lượng 4–6 ngày gồm baseline.
- Vì sao vẫn làm trước: mọi màn khác đang được xếp quanh thanh tab. Sửa dark hay banner trước rồi mới sửa nav là sửa hai lần.

**Dark mode — con số thật:** `AppColors` xuất hiện ở **92 file dart**. Token hoá cả 92 file là việc ~2 tuần, **không phải 2 ngày**. Nhưng làm **1 tab (Cá nhân)** thì khả thi trong 2–3 ngày vì mật độ thấp và ít state realtime.
→ DEV chấp nhận: M1' chỉ token + bật tab Cá nhân; Hôm nay/Kế hoạch để M2 theo lộ trình vòng 3.

**Phản tư 15 giây — rẻ hơn dự kiến:** `taskId` đã chạy xuyên suốt session/notes/study (`active_study_session.dart`, `study_models.dart`, `study_timeline.dart`), nên chỉ cần thêm 1 record + 1 màn nhận `taskId, sessionId`. 1–2 ngày.

**Banner "hôm qua chưa xong":** thêm `getIncompleteTasks(before:)` vào `task_repository.dart` (827 dòng) + 1 chip ở Home, đọc local source nên không chờ sync. 0,5 ngày.

**Nhắc ngủ 22:30 + giới hạn giờ học/ngày:** hạ tầng thông báo đã có sẵn; chỉ cần chặn lịch thông báo theo giờ máy + 1 cờ local. 1 ngày, **không cần server**.

**Quiz lưu kết quả + lịch ôn:** cần schema v4 (hiện `currentSchemaVersion = 3`) + migration + backup. **Giữ ở M2**, không thương lượng — đây là việc duy nhất có khả năng phá "không mất dữ liệu".

**Leaderboard:** ẩn entry rất rẻ; xoá code thì phải sửa 3 test + `supabase/schema.sql`. Đề nghị **ẩn ngay, xoá sau**.

**Không thêm endpoint:** api đang 11 function công khai + 1 cron, sát mức đã tự đặt ở commit `38ec2c4`. Quiz/phản tư/nhắc ngủ đều làm local → 0 function mới. (Nói thẳng: docs Vercel hiện ghi "Functions Created per Deployment: framework-dependent" cho Hobby, tức con số 12 là **mốc kỷ luật tự đặt của repo**, không phải luật cứng — càng phải giữ.)

## 3. [UI] — thứ người dùng thật cảm nhận được ngay trên bản build hiện tại

1. **Dark mode**: vẫn là thiếu sót lớn nhất với người học đêm. Tôi không thích "một tab tối trong app sáng" vì nó nửa vời, nhưng tôi chấp nhận con số 92 file. Nhượng bộ: **tab Cá nhân ở M1'**, và tôi ghi lại đề nghị cho M2: ưu tiên tiếp theo phải là **màn phiên học (Tập trung)** — chỗ người học đêm ngồi lâu nhất — chứ không phải Hôm nay.
2. **4 tab vẫn còn**, AI vẫn là một điểm đến độc lập → đúng như USER nói ở vòng 1: AI đang tranh sự chú ý. Nav 3 tab phải xong trước mọi việc khác.
3. **CTA "Bắt đầu ngay" đã tồn tại** (`home_screen.dart`, dòng 284) → luồng một chạm không bắt đầu từ số 0. Việc còn lại là gắn nó vào **nhiệm vụ ưu tiên** và cứng hoá vị trí ngón tay cái, không phải vẽ mới.
4. **Leaderboard còn hiện ở 24 chỗ trong `lib`**, kể cả đường điều hướng thông báo trong `main_shell` ("Bảng vàng") → mâu thuẫn trực tiếp với yêu cầu phụ huynh. Ẩn phải ẩn ở **cả** nơi điều hướng, không chỉ ở màn.
5. Chữ ≥16px, AA, touch 44/48: giữ nguyên tiêu chuẩn vòng 2; kèm điều kiện mới — kiểm **trên máy 3GB, mạng yếu**, không chỉ trên trình duyệt desktop.

## 4. [USER] — học sinh, thử đúng trên bản hiện tại

- Nút "Bắt đầu ngay" có thật, tôi thấy nó. Nhưng nó nằm trong thẻ, không phải thứ luôn ở ngón tay tôi.
- **Không có gì nói với tôi "hôm qua bạn trượt gì"** → app chưa đóng vòng lặp. Đây là thứ duy nhất khiến tôi mở lại ngày thứ 8.
- Học xong một phiên là hết, không có chỗ ghi 15 giây → tôi quên mình chưa hiểu gì.
- **4 tab với tôi là nhiều**, tôi cần ít lựa chọn hơn chứ không phải thêm.
- **Bảng vàng còn đó** → tên tôi có thể hiện; mẹ tôi sẽ hỏi. Tôi không muốn điều đó.
- **23h học, màn hình trắng** → mỏi mắt. Nhưng tôi thú nhận: thứ làm tôi bỏ app sớm hơn là **không có gì bắt tôi dừng**.
- Với bạn: tôi giữ **5 yêu cầu ngoại lệ ở vòng 2**, thêm một điều kiện: mọi việc trong M1' phải kiểm được **bằng tay trên máy 3GB + 4G yếu**, và phải có **một buổi ngồi cạnh tôi** — không có buổi đó thì kế hoạch vẫn chỉ là suy đoán.

## 5. [KHÁCH HÀNG] — phụ huynh

- **Tin hơn, vì có bằng chứng chứ không phải lời hứa**: analytics mặc định TẮT, xoá dữ liệu có thật, nhật ký thay đổi quyền có thật, khoá BYOK lưu trong kho an toàn của hệ điều hành. Đây là loại việc tôi cần thấy.
- **Nhưng**: checklist ghi RLS (2 file SQL) chưa áp và `CRON_SECRET` chưa đặt. Nghĩa là dữ liệu học tập của con tôi, khi đã lên server, **chưa được khoá chặt ở phía server**. Tôi không đồng ý cho con dùng bản có dữ liệu trên server khi hai việc này chưa xong.
- **Nhắc ngủ 22:30 + giới hạn giờ học/ngày**: với tôi việc này quan trọng **ngang hoặc hơn** dark mode. Nếu phải chọn một, tôi chọn cái chặn con học lúc nửa đêm.
- **Bảng vàng**: đã thoả thuận là không tên thật, mà nó vẫn còn. Không phải lỗi kỹ thuật — là chưa làm. Ẩn ngay.
- Điều tôi **không** cần: thêm tính năng. Điều tôi cần: dòng "không có lỗi mất dữ liệu học tập đã biết" trong checklist **được tích bởi một người thật**, không phải bởi test tự động.

## 6. [BOSS] — quyết định

1. **Không mở tính năng mới khi 2 rào chắn dữ liệu chưa xong** (RLS + `CRON_SECRET`). Đây là quyết định chặn, không phải đề xuất.
2. **M1 rút từ 12 việc xuống 9, giữ 3 tuần.** Ba việc trong danh sách cũ đã xong sẵn trong code (notification đọc payload, streak freeze, xoá dữ liệu local) và 2 việc chất lượng đã xanh (analyze + 934 test) — nên không tính lại. Giữ nguyên gate, siết khối lượng.
3. **Ngân sách 0đ**: không endpoint mới, không dịch vụ mới, không cần thẻ, không free trial.
4. **Chống lệch tài liệu**: README nói 3 tab, code có 4 → sửa trong M1'. Tài liệu sai cũng là một loại lỗi.
5. **Đo bằng người thật**: 10 HS × 7 ngày + 3 câu hỏi phỏng vấn + 1 buổi ngồi cạnh. Không có dữ liệu đó thì mọi thứ tự ưu tiên chỉ là suy đoán.
6. **Tôi rút lại 3 điểm so với vòng 3**: (a) "BỎ leaderboard" → **ẩn ngay, xoá code sau**; (b) "dark bật từ M2" → **token + tab Cá nhân ngay M1'**; (c) "nhắc ngủ ở M3" → **M1'**.

## 7. Tranh chấp vòng 4 & cách chốt

| Điểm tranh chấp | Bên | Chốt | Căn cứ |
|---|---|---|---|
| Nav 3 tab hay dark làm trước? | DEV (nav) vs UI (dark) | **Nav trước** | Mọi màn khác đang xếp quanh thanh tab; làm ngược phải sửa hai lần |
| Dark 1 tab hay hoãn hẳn sang M2? | UI (muốn bật) vs DEV (92 file) | **1 tab (Cá nhân) trong M1'**, phần còn lại theo lộ trình | Mật độ Cá nhân thấp, chạy lại test rẻ; 92 file là thật |
| Ưu tiên dark hay nhắc ngủ? | UI (dark) vs KHÁCH HÀNG (nhắc ngủ) | **Làm cả hai** (cùng rẻ); nếu buộc chọn 1 → **nhắc ngủ** | DEV: nhắc ngủ 1 ngày, không cần server |
| Xoá hay ẩn leaderboard? | BOSS vòng 3 (bỏ) vs DEV (chi phí test/schema) | **Ẩn entry ngay, xoá code sau** | Ẩn: 0,5 ngày, không mất dữ liệu, không phá test |
| Beta công khai khi M1' xong? | BOSS (nhanh) vs KHÁCH HÀNG (chặn) | **Chưa** — chờ RLS + `CRON_SECRET` + xác nhận thủ công + người ký duyệt | Dữ liệu người dưới 18 tuổi |
| Quiz lưu kết quả trong M1'? | USER (cần) vs DEV (schema v4) | **Không** — ở M2 | Việc duy nhất có khả năng phá "không mất dữ liệu" |

## 8. Kế hoạch hiệu chỉnh — M1' (3 tuần, 9 việc)

| # | Việc | File/vùng chạm | Ước lượng | Vai |
|---|---|---|---|---|
| 1 | Nav 3 tab + route push + baseline golden 5 màn × 3 trạng thái **trước khi sửa** | `main_shell.dart` + 8 file test import nó | 4–6 ngày | DEV |
| 2 | Nhiệm vụ ưu tiên → 1 chạm vào phiên, ở vị trí luôn trong tầm ngón tay (CTA "Bắt đầu ngay" đã có sẵn) | `home_screen.dart` dòng 284 + session entity | 1 ngày | DEV + UI |
| 3 | Hoãn/chia nhỏ nhiệm vụ ≤3 chạm | `TaskActionSheet` (đang có) | 0,5–1 ngày | DEV |
| 4 | Banner "hôm qua chưa xong gì" (chip xám, 1 chạm mở lại) | `task_repository.dart`, Home | 0,5 ngày | DEV |
| 5 | Phản tư 15 giây gắn `taskId`/`sessionId` | study session + màn mới | 1–2 ngày | DEV + UI |
| 6 | Dark token + bật tab Cá nhân, AA, chữ 200% không vỡ | `app_theme.dart` + `AppColors` (chỉ chạm vùng Cá nhân) | 2–3 ngày | UI + DEV |
| 7 | Nhắc ngủ 22:30 + giới hạn giờ học/ngày (local) | `plan_notifications.dart`, `adaptive_policy.dart` | 1 ngày | DEV |
| 8 | Ẩn leaderboard, gồm cả đường điều hướng "Bảng vàng" trong `main_shell` | `lib/features/leaderboard/**` (giữ code, không xoá) | 0,5 ngày | DEV |
| 9 | Sửa README/tài liệu lệch + cập nhật checklist phát hành | `README.md`, `docs/` | 0,5 ngày | BOSS |

**Gate M1' (đo được, không đàm phán):** Home render <150ms; mở app → phiên học ≤2 chạm; **3 tab, AI không còn tab**; banner + phản tư có test; dark tab Cá nhân đạt AA; nhắc ngủ chặn được lịch thông báo sau 22:30; ≥120 test pass và analyze sạch; 10 HS × 7 ngày **không mất một phiên học nào**.

**Không đạt gate → dừng, sửa, không mở thêm phạm vi.**

## 9. "0 chi phí" còn đúng không?

| Hạng mục | Dùng gì | Trong free tier? | Rủi ro / điều kiện |
|---|---|---|---|
| AI | Gemini free + OpenRouter `:free` + BYOK của người dùng | ✅ 0đ | Hết quota hoặc model đổi hành vi → **fallback rule-based local** là yêu cầu cứng, không phải tuỳ chọn |
| Hosting | Vercel Hobby + GitHub Pages | ✅ 0đ | Hobby là gói **non-commercial** → khớp với chính sách không thu phí; nếu một ngày có quảng cáo/donate là vi phạm cả hai ràng buộc cùng lúc |
| Server | 11 function công khai + 1 cron | ✅ 0đ | Cron Hobby giới hạn **1 lần/ngày** (docs Vercel) → dọn dữ liệu chỉ chạy 3h sáng; muốn dày hơn phải đổi cách làm, **không đổi bằng tiền** |
| Database | Supabase free | ✅ 0đ | Free tier có thể tạm dừng khi không hoạt động → app **buộc** phải chạy được offline-first |
| CI/CD | GitHub Actions | ✅ 0đ nếu repo public | Repo private: 2.000 phút/tháng (visibility không xác minh được từ môi trường này — cần người xác nhận) |
| Buổi họp này | 6 vai do **1 agent nhập vai**, không gọi dịch vụ ngoài | ✅ 0đ | Đổi lại: không phải 6 ý kiến độc lập (giả định 2) |

## 10. Chặn phát hành — phải xong trước khi cho người thật dùng

| Việc | Nguồn | Không xong thì |
|---|---|---|
| Áp `supabase/family_v4.sql` (RLS cho `family_goals`/`family_messages`/`family_notif_tokens`) | checklist 2b | Dữ liệu cửa sổ phụ huynh không được khoá ở phía server |
| Áp `supabase/email_codes.sql` (DDL + RLS bảng mã OTP) | checklist 2b | Mã OTP không có rào bảo vệ |
| Đặt `CRON_SECRET` + `AI_DAILY_QUOTA` + `AI_DAILY_QUOTA_ANON` | checklist 2b | Cron dọn dữ liệu **fail-closed**; quota AI không chặn được |
| Xác nhận **bằng tay** offline + "không mất dữ liệu học tập" | checklist mục 2 | Không có ai chịu trách nhiệm cho ràng buộc cứng nhất |
| Người ký duyệt (+ ngày) | checklist mục 5 | Không có over-ride nào được ghi lại |

Checklist còn **5 mục nữa** (funnel onboarding, lỗi sync/AI trong ngưỡng, ghi cấu hình build trong Summary, dữ liệu beta, chữ ký duyệt) — nhóm này chỉ tích được **sau khi có người dùng thật**, nên không tính là rào chặn kỹ thuật.

## 11. Tự kiểm chứng lại (chạy trong repo này)

```bash
# 1. Nav còn mấy tab
sed -n '343,350p' lib/app/main_shell.dart

# 2. Các hạng mục kế hoạch chưa có dòng code nào
grep -rl "design_tokens" lib test; grep -rl "ThemeMode" lib test
grep -rl "Reflection" lib test; grep -rl "getIncompleteTasks" lib test
grep -rl "QuizAttempt" lib test; grep -rl "quietHours" lib test

# 3. Dark mode thực tế
sed -n '95,100p' lib/core/theme/app_theme.dart

# 4. Zero-cost: số function công khai + cron
ls api/*.js | grep -v test | grep -v "/_" | wc -l
grep -n "crons" -A4 vercel.json

# 5. Quy mô test + bán kính nav refactor
find test -name "*_test.dart" | wc -l
grep -rl "main_shell" test | wc -l
grep -rl "matchesGoldenFile" test | wc -l

# 6. Mức độ phải chạm khi token hoá màu
grep -rl "AppColors" lib --include="*.dart" | wc -l
```

## Kết luận vòng 4

- Vòng 1–3 đặt đúng **hướng** (bớt điểm đến, đóng vòng lặp ngày, dữ liệu thuộc về người học, 0đ). Vòng 4 cho thấy hướng đó **chưa được thực thi ở 5 điểm**, trong khi 6 điểm khác **đã xong sẵn** — nên M1 nhỏ hơn ta tưởng về tính năng, nhưng **không được phép nhỏ hơn về rào dữ liệu**.
- Thay đổi lớn nhất so với vòng 3: **nhắc ngủ/giới hạn giờ, dark 1 tab, ẩn leaderboard** vào M1'; **nav 3 tab vẫn là việc đầu tiên**; **quiz lưu kết quả vẫn ở M2**.
- Điều kiện người dùng thật: không tuyên bố "phù hợp người dùng thật" cho tới khi có **10 HS × 7 ngày + một buổi ngồi cạnh**. Trước đó, mọi con số chỉ là giả thuyết.
- Chi phí của toàn bộ vòng này: **0đ**.

> Kế hoạch chi tiết ở `KE_HOACH_PHAT_TRIEN_THOA_THUAN.md` **chưa được cập nhật theo vòng 4** (mục 3 task list và gate vẫn là bản vòng 3) — trạng thái lệch được ghi ở đây thay vì sửa lặng.

---

*Hết biên bản. Buổi họp gồm 4 vòng, 6 vai: vòng 1–3 chốt kế hoạch, vòng 4 kiểm chứng bằng mã nguồn. Tất cả chạy local, không tốn chi phí.*

---
---

# PHẦN 2 — THẢO LUẬN CHIỀU SÂU (2026-10-16)

**Bối cảnh:** Sau khi chốt kế hoạch v1 (+ vòng 4 kiểm chứng bằng mã nguồn), chủ dự án yêu cầu các vai trao đổi **thật hơn, nhiều góc nhìn hơn, khách quan hơn**. Các vai tiếp nối chính phiên họp cũ, thêm vai mới **GIÁO VIÊN** (15 năm trong lớp, thu không biết bao nhiêu điện thoại vì dở app học tập). Yêu cầu: nói như con người thật — có tâm trạng, có điều giấu, bằng chứng đối chứng, chấp nhận nhượng.

---

## Vòng 1 — Mỗi vai nói điều chưa từng nói

### [BOSS] — Điều tôi sợ

Tôi sợ nhất không phải thiếu tính năng. Tôi sợ mốc 3/3/4 này: tôi tự cắt M1 từ 12 việc xuống 9 mà không có bằng chứng nào cho thấy 9 việc đủ để giữ người ta. Tôi sợ con số D7 ≥ 35% — tôi tự đặt, không baseline, không dữ liệu; nếu pilot 50 người ra 12%, tôi không biết mình có đủ thẳng thắn để tự sửa. Và tôi sợ cả việc chốt 0đ: Vercel Hobby là gói *non-commercial*, tức là ngày tôi cần tiền để duy trì app, tôi đã tự chặt con đường đó từ trước — còn sĩ tử thì rụng sạch sau ngày thi cuối, mà tôi chưa chứng minh chế độ hậu kỳ thi giữ nổi một ai.

Điều tôi nghĩ mọi người hiểu sai về tôi: DEV tưởng tôi đang đếm ngày, UI tưởng tôi muốn app đẹp. Không. Tôi chốt nhắc ngủ 22:30 và streak freeze không phải vì tôi tốt bụng, mà vì tôi sợ một đứa trẻ bị app của tôi bắt mở lúc nửa đêm.

Phe DEV đúng vì lý do sai. DEV nói nav 3 tab mất 4–6 ngày vì 8 file test import `main_shell` và chưa có golden nào. Con số đúng. Nhưng đó không phải "chi phí refactor" — đó là tôi đã cho ship tính năng nhiều tháng không có lưới an toàn. DEV đang trả nợ cho quyết định của tôi. Phe UI cũng vậy: dark mode là thiếu sót lớn nhất với người học đêm — đúng, nhưng USER đã nói thẳng: thứ làm cậu ấy bỏ app là "không có gì bắt tôi dừng", không phải màn hình trắng. UI đang dùng gu của mình thay bằng chứng.

Tôi đổi lại: bỏ hẳn hai điểm AI ngữ cảnh ở M2/M3, lấy RLS và `CRON_SECRET` xong trước khi một phiên học nào chạm server. AI chậm mất vài tháng được; dữ liệu học sinh lộ một lần là hết.

**Điều tôi chưa nói hai vòng trước:** sáu vai trong buổi họp này là **một** agent. Cái gọi là "tranh chấp rồi chốt" là tôi tự diễn. Tôi viết kế hoạch như thể có sự đồng thuận, nhưng thật ra tôi chỉ đang tự thuyết phục mình — và nếu điều đó khiến tôi chậm nhận ra app không ai dùng, đó mới là rủi ro lớn nhất.

### [DEV] — Điều làm tôi bực nhất

M1' nghe nhẹ — 9 việc. Nhưng việc số 1 là refactor nav, chạm đúng 8 file test đang green, `_switchTab(0..3)`, Ctrl+1..4, sidebar desktop, deep-link — và tôi phải viết test TRƯỚC. Tôi đồng ý nguyên tắc. Nhưng thú thật: viết test trước cho một thứ đang sai nghĩa là tôi đóng băng hành vi cũ bằng test, rồi tự phá nó. Và cái 1.850 dòng `study_screen.dart` lại là chỗ tôi phải thêm session entity + phản tư vào, còn lệnh tách <900 dòng thì nằm ở M2. Nghĩa là M1' tôi làm file khủng **khủng hơn** trước khi làm nó nhỏ lại. Cái đó ngược, và tôi không thích.

3/3 phần tính năng thì khả thi. M3 4 tuần — sync 500 kịch bản + 50 người × 30 ngày — là chốt cho vui. Nếu buộc nợ một việc, tôi nợ "500 kịch bản sync": giảm còn 50 kịch bản có xung đột + rớt mạng giữa chừng.

"Chữ 200% không vỡ layout" với sticky bar + form phản tư trên máy 3GB: không vỡ thì tôi làm được, vẫn **đọc được** thì không ai kiểm nổi trong 3 tuần. Còn gate "≥120 test pass" trong khi repo đang có 934 test xanh — con số này hoặc gõ nhầm hoặc không ai đọc lại. Bảo vệ chất lượng: tôi từ chối rải `if (isDark)` khắp widget để "bật dark 1 tab" cho qua gate. Token trước, hoặc giữ force light, không có con đường thứ ba.

**USER/KH sẽ phá cái gì mà họ không ngờ:** bật tắt toàn bộ gamification không phải một cờ UI — nó cắt ngang `registerStudyActivity`, hook XP lúc hoàn thành task, lịch nhắc "streak sắp mất", và cả luồng dữ liệu báo cáo phụ huynh đọc đúng chỗ đó. Nhắc 22:30: học sinh đang chạy Pomodoro lúc 22:29 thì app làm gì? Cắt giữa phiên là tạo race với autosave. Và 50 người dùng PWA chụp ảnh đề bài — ảnh đang lưu base64 trong SharedPreferences. Prefs phình trên máy 3GB là cách nhanh nhất để mất dữ liệu. Không ai trong phòng họp nói tới cái này.

Tôi nhận làm dark 1 tab + nhắc ngủ trong M1' dù cả hai đều ngoài vòng lặp học. Đổi lại: gate test phải viết lại — "0 test bị xoá hoặc skip, coverage domain ≥70%, golden 3 màn", không phải 5×3.

**Điều tôi giữ riêng chưa nói:** gate "10 HS × 7 ngày, không mất một phiên học" — tôi không có công cụ nào để đo thật. Không crash reporting, không log autosave. Con số đó sẽ ra từ việc hỏi 10 đứa trẻ "có mất gì không", và chúng sẽ bảo không. Tôi sợ một ngày mình ký vào ô PASS mà không thực sự kiểm chứng được, rồi nó đi lên checklist phát hành như một sự thật.

### [UI] — Cái sticky bar mà chính tôi từng xin bỏ

Ở vòng 2 tôi xin hy sinh nó; rồi biên bản ghi "chốt giữ sticky bar" như thể tôi vẫn đứng sau. Tôi đồng ý với BOSS, nhưng không vì lý do trong giấy. DEV mới là người đo đúng: cái đắt là refactor nav — 8 file test, chưa một golden, 4–6 ngày — và cái bar lại gắn vào đúng chỗ rủi ro đó. USER đã thử và nói thẳng: "Bắt đầu ngay" nằm *trong thẻ*, "không phải thứ luôn ở ngón tay tôi". Câu tôi lo: ai chịu trách nhiệm khi cái bar dính đè lên sheet hoãn nhiệm vụ, hoặc khi textScale 200% làm nó phình gần đôi và ăn mất cái fold mà chính tôi đòi "40% chỉ chứa việc cần làm"? KPI viết ≤2 chạm, không viết "không được che việc ưu tiên". Lỗ hổng đó là của tôi.

**Ba chỗ kế hoạch sẽ sinh trải nghiệm xấu:** ghép "dark theo lịch tự đặt" với "nhắc ngủ 22:30", học sinh sẽ tự rút ra bài học rằng *màn hình tối = app đang bảo mình đi ngủ*. Mình vừa tạo một tín hiệu lo âu bằng màu sắc. Nút tắt toàn bộ gamification: nghe tử tế, nhưng streak đang là thứ duy nhất cho nhiều đứa lý do mở app ngày thứ 8. Tắt sạch, Home sẽ lộ ra là nó rỗng. Tôi muốn "chế độ yên lặng" — vẫn giữ đếm ngược kỳ thi. D7 ≥35% đo bằng counter cục bộ, trong khi analytics mặc định TẮT. Con số này hiện không ai lấy được.

**Về USER và KHÁCH HÀNG — nói thật:** năm yêu cầu không thương lượng của phụ huynh, bốn là làm ba mẹ yên tâm, không phải làm đứa con học tốt hơn. Còn tôi cũng không sạch: vòng 3 tôi nài giữ leaderboard "chỉ kỷ lục cá nhân" — vì bảng đó do tôi thiết kế và tôi không muốn nó chết.

**Điều tôi giữ riêng chưa nói:** biên bản ghi rõ: sáu vai do một agent nhập vai. Nghĩa là không ai thực sự đứng ra bảo vệ học sinh — tôi đang đồng ý với chính tôi, hai vòng liền.

### [USER] — Học sinh lớp 12, dùng app thật

Đọc xong kế hoạch 3 mốc và 20 KPI, tôi thấy… bị đo quá nhiều. Hai mươi KPI cho một cái app ôn thi — buổi sáng của tôi đâu phải bảng dashboard. Tôi không phân biệt được Home render 150ms hay 300ms; tôi chỉ để ý khi đồng hồ Pomodoro **chết** lúc đang chạy. Cả bản kế hoạch giả định một điều: rằng **hôm nào tôi cũng muốn mở app**. Không có dòng nào nói về tuần trước kỳ thi, lúc tôi mệt đến mức không muốn nhìn thấy đếm ngược nữa.

Chỗ team đang tự lý giải: họ nghĩ tôi học 25 phút xong sẽ ngoan ngoãn trả lời form 3 câu "hiểu chưa". Sự thật? Tôi sẽ bấm **"Bỏ qua"** — hoặc tệ hơn, bấm đại "tạm ổn" cho xong, vì form đó hiện ra đúng lúc tôi đang bị đứt mạch nghĩ. Và họ nghĩ banner "hôm qua chưa xong gì" sẽ gọi tôi trở lại — đúng, nhưng nếu một ngày nó hiện "trễ 7 việc", tôi sẽ né mở app vì **tội lỗi**, không phải vì nhớ việc.

KPI tôi thấy vô nghĩa: `p95 frame <16ms`, "file <900 dòng", và "token AI đầu <5s" — nhanh mà trả lời sai thì vô dụng. KPI tôi muốn thêm: **"số lần tôi định xoá app mỗi tuần"** và **"số lần app nói đúng về tôi"**. Một lần app bảo "Toán yếu" trong khi tôi đang tụt Hóa, tôi không tin nó nữa suốt đời.

Tôi sẵn sàng **bỏ hẳn mascot, bốc quẽ, XP, trang phục** đổi lấy một thứ: Pomodoro + đếm ngược chạy thật khi tôi **tắt màn, chuyển app, 10 phút không chạm, hoặc điện thoại khởi động lại**.

**Điều tôi giữ riêng:** tôi xoá app **không kêu** đâu. Tuần 3 tôi bỏ mở app đúng giờ, tuần 4 tôi tắt hết thông báo, tuần 5 tôi chỉ mở khi mẹ đứng sau lưng. Rồi một buổi sáng tôi định đổi theme — app lúc đó **chưa có dark mode** — tôi bấm nhầm "xoá dữ liệu", streak 47 ngày còn đâu. Team lo crash-free 99,5%, nhưng thứ giết tôi là **dữ liệu chết chứ không phải crash**. Vậy nên: mất dữ liệu thì cho tôi giữ lại một bằng chứng — ảnh streak, file xuất ra — may ra tôi cài lại.

### [KHÁCH HÀNG] — Phụ huynh

Điều làm tôi **thật sự** yên tâm hơn, không phải 20 KPI — mà là vòng kiểm chứng bằng code. Tôi đọc được dòng "analytics mặc định TẮT đã có trong mã", "xoá dữ liệu một chạy đã có". Lần đầu tiên tôi thấy họ chịu bị kiểm.

Nhưng tôi vẫn nghi. Họ chốt D7 ≥ 35% — tôi không cần biết mấy phần trăm, tôi cần biết **trong 30 ngày đó con tôi có bị tổn thương vì áp lực không**. "Streak không âm về đêm", "freeze" nghe chỉ là lời hứa. Và RLS hai file SQL chưa áp, `CRON_SECRET` chưa đặt — tức dữ liệu con tôi đã lên server **chưa bị khoá chặt**. Việc đó chưa xong, tôi chưa đồng ý cho con dùng bản có cloud.

Chỗ tôi thấy team hiểu sai nỗi lo của tôi: họ tưởng tôi lo **mất quyền kiểm soát**. Không. Tôi sợ nhất là **con bị dán nhãn**. Leaderboard, XP, "mạnh/yếu" — đứa trẻ 18 tuổi bị app gắn nhãn "Toán yếu", rồi tôi lặp lại nhãn ấy khi mắng nó, thì app đã hại chứ chẳng giúp. Tôi muốn một ngưỡng cảnh báo — "hôm nay học quá 4 tiếng", "còn thức lúc nửa đêm" — **phải xin phép cả hai bên**, nhưng đó là "báo động", không phải "điều khiển".

Và bí mật tôi chưa nói: tôi **không sợ app, tôi sợ chính tôi**. Đêm nào mệt làm, tôi muốn có thằng khác làm "kẻ ác" thay tôi ra lệnh "đi học đi". Nếu EduPulse làm ác nhân, con tôi sẽ ghét nó. Thứ tôi thật sự cần là app **dám bảo con tôi: "hôm nay thế đủ rồi, đi ngủ"**.

Về thầy cô vừa tham gia: tôi vừa hoan nghênh vừa dè chừng. Họ có quyền soi **kế hoạch học có vô lý không**, soi **AI có dạy sai không**. Nhưng bổn phận: thầy cô chỉ thấy dữ liệu khi chính con tôi cho phép, không phải kênh "nhà trường cứ hỏi là biết"; và **không được đẩy áp lực lớp học vào app** — nếu thầy cô đề xuất "xếp hạng lớp dựa trên app", tôi rút con ra ngay.

Một điều tôi nhượng: tôi chấp nhận con tôi **không bấm "gửi" mỗi tuần** mà chuyển sang "uỷ quyền trước 4 tuần, thu hồi được" — đổi lại, chính sách riêng tư phải **một trang, đọc hết trong 3 phút**, và nút "xoá toàn bộ dữ liệu" phải có **đếm ngược 7 ngày**.

### [GIÁO VIÊN] — 15 năm thu điện thoại vì dở app học tập

Tôi dạy 15 năm và đã thu không biết bao nhiêu điện thoại vì dở app học tập. Không đứa nào bỏ vì thiếu tính năng — bọn nó bỏ vì **chán**.

Nhận xét về kế hoạch EduPulse, thẳng thắn: các bạn làm đúng mấy chứ ít ai làm — offline thật cho máy RAM 3GB, bỏ leaderboard, streak freeze, tắt được gamification, xóa dữ liệu một chạy, và nhất là banner "hôm qua chưa xong gì". Cái banner đó giải đúng nỗi ám ảnh của tôi: học trò không hề quên việc, chúng né việc.

Nhưng các bạn thừa. Quiz AI, lộ trình AI, thi đua ẩn danh — cứ tưởng thêm đường vào là giữ chân được. Và thiếu một thứ chỉ giáo viên thấy: làm sao để một đứa bị gọi tên quay lại? Trong lớp tôi, đứa nào cũng ôn bài vì tôi hỏi trước bảng. App không hỏi trước bảng được ai.

Kỳ vọng "3 giây mở app, 25 phút học" — tôi cười buồn. Mở trong 3 giây thì thật. Nhưng 25 phút liên tục thì ít. Lớp tôi trung bình 8–10 phút là có tin nhắn Zalo. Nhiều đứa bấm Pomodoro cho có, để đấy đi ăn. Tôi từng thấy đứa giữ chuỗi 200 ngày mà chưa đọc hết trang Toán. Chuỗi hôm nay đo sự chăm, mai nó đo sự gian lận.

Chỗ tôi thấy nguy hiểm: báo cáo trực tiếp cho phụ huynh — đứa nhỏ sẽ "diễn" cho mẹ, ôn lúc 11 giờ đêm vì sợ báo cáo 0 phút. Tin mất một lần là mất luôn; "xin phép con trước khi bật" là câu quan trọng nhất, đừng cắt. AI nguy hiểm nhất: học sinh không hỏi "giải thích giúp em", chúng hỏi "làm hộ em". Gamification sống được hai tuần rồi thành thuổng.

Ép DEV làm: phát bản thử cho cả lớp trong giờ tự học, máy phổ thông của bọn nhỏ, một tuần trọn — không tuyển 10 đứa ngoan. Ép bỏ: thi đua ẩn danh ở M3. Đổi tên thành ẩn danh vẫn là so sánh.

Câu hỏi tôi gửi BOSS và DEV: trong cả rừng KPI, có chỉ số nào đo "mở app rồi tắt trong 5 giây vì chán" chưa? D7 đạt 35% mà nhiều đứa quay lại chỉ để vuốt cho khỏi mất chuỗi, các anh gọi đó là thành công à?

---

## Vòng 2 — Phản biện chéo: ai nhượng gì, ai giữ gì

### [BOSS] vòng 2 — Ba người làm tôi đổi thật

**Theo GIÁO VIÊN:** "25 phút liên tục là viển vông, 8–10 phút là thật" — câu đó đánh vào mốc số đo của tôi. Tôi đặt 25 phút vì đó là mặc định của mọi app, không vì lớp 12 ở nhà làm được. Đổi: phiên mặc định **10–15 phút**, và KPI đếm *phiên xong* chứ không đếm *phiên bắt đầu*. "Pilot cả lớp trong giờ tự học, không chọn 10 đứa ngoan" — tôi nhận. Pilot 10 đứa ngoan chỉ cho tôi kết quả tôi muốn nghe.

**Theo KHÁCH HÀNG:** "tôi sợ chính mình" và nỗi lo con bị dán nhãn "Toán yếu". Hai câu đó làm tôi bỏ luôn thi đua ẩn danh M3 dù đã đổi tên, và cắt nhãn môn yếu khỏi báo cáo phụ huynh trừ khi con tự chọn chia sẻ. App phải có một trạng thái **"hôm nay thế là đủ rồi"**.

**Theo DEV:** bạn đúng về gate "≥120 test" — đó là số tôi chọn cho oai, mình có 934 test rồi. Bỏ gate đó; gate là nav/notification 0 fail + golden diff 0. Ảnh base64 vào SharedPreferences là tôi tự giết máy 3GB → ảnh ra file store, có trần dung lượng. Việc tắt gamification cắt ngang `registerStudyActivity` — câu đó làm tôi tỉnh: không được "tắt", chỉ được **"chế độ yên lặng"**, dữ liệu vẫn ghi, chỉ không hiện chip XP/streak.

**Phản biện USER:** bạn đòi đổi mascot/XP lấy Pomodoro bền — chính bạn nói bạn xoá app âm thầm ở tuần 5. Pomodoro bền chỉ giúp bạn không tức giận khi **đã** mở app; nó không cho bạn **lý do mở lại**. Nên tôi giữ đúng một thứ của gamification: đếm ngược kỳ thi. Không vì đẹp — vì đó là thứ khiến bạn mở app.

**Tôi vẫn giữ một mình:** không leaderboard, không thi đua ẩn danh, không billing, không cloud trước khi RLS + `CRON_SECRET` xong. UI nói thật là nài giữ leaderboard vì bảng đó do mình vẽ — trân trọng, nhưng từ giờ UI không tự chấm bảng đó.

**Cam kết của tôi:** tôi tự ký dòng gate "10 HS không mất phiên". Ký không được thì dừng — không tô màu.

### [DEV] vòng 2 — Tôi nhận cuộc đổi, có điều kiện

**Cho BOSS:** đổi 2 điểm AI ngữ cảnh lấy RLS + `CRON_SECRET`: nhận. AI ngữ cảnh thiếu không ai chết; RLS thiếu mà dữ liệu cửa sổ phụ huynh đã lên server là tôi không ngủ được. **Điều kiện:** RLS không apply bằng cách chạy SQL rồi hy vọng. `family_v4.sql` và `email_codes.sql` chạm đúng bảng mà sync hiện tại ghi bằng anon key — thêm policy mà không test, sync sẽ fail **thầm lặng**: outbox đẩy không lên, banner vẫn xanh vì local luôn đúng. Tôi cần một harness chạy fixture 2 thiết bị + restore với RLS đã bật, xanh mới được gộp. `CRON_SECRET` rẻ — cron Hobby 1 lần/ngày nên 7 ngày đếm ngược xoả dữ liệu chỉ cần chạy 3h sáng. Chi phí ước lượng: **1,5–2 ngày + test**, lấy từ ngân sách AI vừa rảnh.

**Cho USER — Pomodoro sống qua tắt màn:** thật ra tôi làm được 80%, nhưng không phải cách cậu tưởng. PWA không cho timer chạy khi trình duyệt bị đóng — bị throttle, không ngoại lệ. Nhưng kiến trúc hiện tại sai ở chỗ khác: Pomodoro đang là *bộ đếm tiến*, tắt app là mất sạch. Sửa thành **timestamp-based session**: lưu `startedAt`/`pausedAccumMs`, mở lại app tính elapsed từ đồng hồ. Cách này sống qua kill/restart/chuyển app trên cả PWA lẫn mobile, vì nó không cần ai đếm — chỉ cần đọc đồng hồ. Cái không làm được trong M1: đồng hồ *nhìn thấy được* khi tắt màn trên web; Android native thì có thể thêm notification đếm ngược, đó là M2–M3.

**Cho GIÁO VIÊN — chuỗi gian lận:** đúng, nên tôi không cố chứng minh "ngồi học". Tôi chỉ đo được proxy: mỗi phiên lưu `foregroundMs` (app thực sự ở foreground), số lần pause, và có nộp phản tư không. Luật tôi đề xuất: ngày chỉ tính "phiên thật" nếu `foregroundMs` ≥ 60% thời lượng phiên, hoặc có phản tư. Chuỗi 200 ngày — cô cứ coi là số liệu của chính đứa trẻ với nó, không phải với cô. Tôi làm cái này local, không gửi đi đâu, khớp `analytics_consent` đang tắt mặc định.

**Cho KHÁCH HÀNG + USER — đếm ngược 7 ngày và bằng chứng streak:** 7 ngày: nhận. Xoá 1 chạm + đếm ngược local + cron server dọn phần cloud; backup cũ cũng phải nằm trong diện xoá, không phải chỉ bản live. Bằng chứng streak cho USER: tôi mở rộng `exportJson` thêm timeline phiên theo ngày + lịch sử freeze — USER mở file JSON tự đếm xem ngày nào bị gãy và vì sao. Sync của file xuất phải ghi kèm `data_schema_version` để import lại không lệch. Cả hai việc này vào M2 vì đụng schema; M1' chỉ làm phần local read-only.

**Cam kết của tôi, đo được:** (1) M1': timestamp-based session + nav refactor + golden 3 màn — đo bằng test fixture "kill app giữa phiên, mở lại còn đúng thời gian". (2) RLS + `CRON_SECRET`: harness fixture xanh trước khi merge, đo bằng "0 sync fail với RLS bật". (3) Export đủ bằng chứng + đếm ngược xoá: M2, đo bằng round-trip test. Không thêm endpoint mới. Không hứa gì tôi không chạy được bằng một lệnh.

### [UI] vòng 2 — Nhận một nửa, phản bác một nửa

**BOSS chê tôi "dùng gu thay chứng cứ"** — nhận một nửa, phản bác một nửa. Tôi nhận chỗ "dark mode là thiếu sót lớn nhất": bằng chứng của tôi chỉ là "học sinh học đêm", không phải số. Và đúng, thứ giết USER là *không gì bắt tôi dừng*, không phải màn hình trắng. Nhưng tôi phản bác một điểm: cái tôi gọi "gu" thực ra là ràng buộc biên — chữ 200%, một tay, máy 3GB. Cái đó đo được, và chính BOSS đã ghi nó vào KPI. Chỗ tôi thật sự sai: "40% fold" là số tôi bịa ra cho đẹp. Tôi rút. Thay bằng đo số chạm + thời gian tới việc đầu tiên trên 10 HS.

**GV nói đúng về 25 phút — tôi sửa, và sửa hẳn.** Thiết kế lại: mặc định **phiên 10 phút**, mốc 10/20/35 cho ai muốn dài. Hết 10 phút, app hỏi **"thêm 10 phút?"** — người dùng tự kéo dài, không bị ép. Chống chán bằng cách hiển thị *việc đang làm* trên màn đồng hồ thay vì đồng hồ trần. Streak không hiện số lớn nữa: đổi thành **"tuần này X phiên"**, streak chỉ làm dữ liệu nền cho lá bùa — chuỗi 200 ngày mà GV nhắc có thể gian lận, và nó cũng làm đứa yếu sợ.

**Form phản tư — sửa theo lời USER, vì anh ấy sẽ bấm Bỏ qua ngay lần đầu.** Bỏ màn riêng, bỏ 3 câu, bỏ đếm 15 giây, bỏ auto-advance. Một màn tổng kết, một câu: *"Phiên 10 phút xong. Hiểu chưa?"* — hai nút to **Hiểu rồi / Chưa hiểu**. Không bắt buộc. Không bấm gì trong 4 giây, app tự ghi "chưa rõ" rồi biến mất — không hỏi lại, không đuổi. Chỉ khi bấm "Chưa hiểu" mới hỏi tiếp một bước: 3 chip lý do (quá khó / hết giờ / làm việc khác) → đề xuất "chia nhỏ" hoặc "đổi lịch", gọn trong ≤2 chạm. Nhật ký dài bỏ.

**DEV nói đúng, tôi rút yêu cầu cũ.** Không còn cờ "tắt toàn bộ gamification". Thay bằng **3 công tắc nhỏ**: tắt màu đỏ streak, tắt mascot, tắt âm thanh. Streak vẫn tính, chỉ không hiện — `registerStudyActivity`, hook XP, nhắc streak không bị chạm. Ảnh đề bài tôi cũng nhượng: chỉ cache có TTL, không bao giờ vào SharedPreferences.

**Nhắc ngủ — nghe KH, nhưng nghe cả cảnh báo của DEV.** Không phải tiếng ác. Một dòng cuối màn phiên khi đã qua giờ: *"Hôm nay bạn đã x phiên — thế là đủ."* App nhận ra, không chặn. Và autosave phải xong **trước** khi dòng đó hiện.

**Dark mode — tôi đổi, và đổi luôn đích.** Không theo lịch nữa. Dark bật khi **bắt đầu phiên học**, tắt khi kết thúc — theo hành động, không theo giờ, nên không dính "màn hình tối = bảo tôi đi ngủ". Nếu M1' chỉ được dark một chỗ, tôi xin đổi từ Cá nhân sang **màn Phiên học**: Cá nhân mở 10 giây một ngày; màn phiên là nơi ngồi 40 phút liên tục trong bóng tối.

**Leaderboard — bỏ hẳn, GV đúng.** Thi đua ẩn danh vẫn là so sánh, đứa yếu sẽ buông. Tôi không xin giữ gì. Điều kiện duy nhất: không màn nào hiện số hay tên của người khác — kể cả ẩn danh — ít nhất tới hết M3.

### [USER] vòng 2 — Em xin thú thật

Thầy nói đúng 100%: **có, em từng bấm Pomodoro cho có**. Bấm "Bắt đầu", úp máy, mười mấy phút sau quay lại bấm "xong", streak vẫn lên như không. Nếu thầy đề xuất phiên 10 phút thay vì 25, em **dùng** — 10 phút em chịu được, 25 phút em nằm được. Nhưng "đếm phút thay vì streak", em chỉ đồng ý một nửa: gạt streak thì nhẹ, gạt cả tiến độ tuần của chính mình thì thấy người, nên số phút khó nói dối hơn. Vậy nên: giữ streak, nhưng đừng để nó là con số duy nhất em nhìn mỗi ngày — cho em thêm cột "tuần này X phút, mục tiêu Y". Thầy hỏi có KPI nào đo "mở 5 giây rồi tắt" chưa — có, và đó mới là KPI sống còn; D7 chỉ là hệ quả. BOSS sợ em mở app lúc nửa đêm: xin cứ chặn em, em cảm ơn.

UI hỏi form "hiểu chưa" — em sẽ điền thật nếu nó chỉ có **tối đa 2 nút**: "xong" và "chưa xong", vì "tạm ổn" là cái nút em nói dối. Nó hiện **sau khi em đã để máy xuống**, đừng hiện khi em còn đang nghĩ. Và phải có nút **"không muốn nói gì"**, to bằng nút lưu, đừng chôn góc. Em chịu được im lặng; em không chịu được áy náy.

Khoản mẹ em muốn xoá có đếm ngược 7 ngày — với em **bực**, em 18 rồi, em xoá là em thật sự muốn xoá. Nhưng em công nhận lần bấm nhầm mất 47 ngày, nên em cần **xuất bằng chứng** — ảnh streak, file JSON — để cài lại không bắt đầu từ đầu. Đếm ngược thì miễn, cho đổi thành **"xoá có hoàn tác 30 ngày"** càng hay.

BOSS, DEV: trong ba thứ — tắt màn, chuyển app, khởi động lại — chỉ làm được **một**, em chọn **chuyển app**. Em hay nhảy sang Zalo rồi về học; mỗi lần về mà timer chết, em mất nhịch luôn. Nhưng thứ em **muốn team hứa** là **khởi động lại**, vì máy 3GB của em treo là thường. Hứa được cả hai thì còn gì bằng — nhưng hứa mà không giữ được thì đừng hứa.

Nếu team không làm được — em nói thật. Em sẽ không xoá app đâu, xoá phiền lắm. Em sẽ không mở nó nữa, nhưng để nó nằm trên màn hình, tự hành hạ. Đến một buổi chiều thanh lọc điện thoại, em quét thấy "app này 40MB, lâu không mở" — bấm gỡ. Không drama. Chỉ là một buổi chiều em thấy nó vô dụng.

### [KHÁCH HÀNG] vòng 2 — Tôi tự rút lại một phần

Chị GV nói đúng, và đó là lý do tôi tự rút lại một phần yêu cầu cũ. Nếu đứa nhỏ diễn cho tôi, báo cáo càng chi tiết nó càng diễn giỏi hơn. Nên báo cáo tuần của tôi: **không số phút, không điểm, không xếp hạng**. Chỉ ba dòng: con mở app mấy buổi; một câu do chính con viết; và dòng hệ thống "tuần này con bỏ qua mấy lần" — để tôi biết lúc nào không nên hỏi. Cái bảng "hôm nay 0 phút" tôi xin bỏ hẳn; đó là cái bẫy bắt con ôn 11 giờ đêm vì sợ tôi.

UI: tôi đồng ý chữ "tử tế" — nhưng tử tế không phải nhỏ giọng, mà là nói xong thì thôi. Lúc 22:30 tôi muốn chính app nói, không phải tôi gõ: *"Muộn rồi con ơi. Hôm nay con đã cố. Mai làm tiếp cũng được. Chúc con ngủ ngon."* Một lần thôi. Sau đó: không khóa máy, không nhắc lại, không đếm ngược đỏ, không có dòng nào gửi về cho tôi kiểu "mẹ ơi con còn thức". Con ngồi tiếp thì app im hẳn. Không phạt, không drama.

USER (chính con tôi): con nói thật là tôi nhẹ cả người. Tôi chấp nhận con bấm "Bỏ qua" — bấm bao nhiêu lần cũng được, không trừ thưởng, không hỏi tại sao. Nhưng có một thứ tôi xin giữ quyền, chỉ một: con không được biến mất im lặng. Xoá app là quyền của con, nhưng app hiện một lần duy nhất "con sẽ mất dữ liệu, chắc không?" rồi gửi tôi một dòng xác nhận. Không phải để theo dõi con — là để tôi khỏi đứng như người mất hồn. Và dữ liệu phải nằm trong **thùng rác 30 ngày**: streak 47 ngày không được chết vì một cú bấm nhầm.

BOSS: tôi ủng hộ đổi. AI ngữ cảnh để sau; RLS và CRON_SECRET là điều kiện để tôi cho con chạm bản cloud. Thêm ba yêu cầu nữa tôi mới cho con dùng: một, dữ liệu của con thuộc về con — xuất ra và xoá hẳn được; hai, không quảng cáo, không bán dữ liệu, không theo dõi ngoài app; ba, nhắc ngủ đúng giờ con chọn, CRON trễ thì đừng gửi — tôi không muốn con nhận "đi ngủ thôi" lúc 2 giờ sáng.

**Thương lượng cuối của tôi:** tôi nhượng báo cáo tuần tự động. Tôi không cần xem con học bao nhiêu nữa. Tôi giữ **"xin phép con trước khi bật"** — câu chị GV vừa nhắc — cùng cái nút hoàn tác. Nếu chỉ được giữ một thứ, tôi giữ câu đó.

### [GIÁO VIÊN] vòng 2 — Nếu BOSS giữ leaderboard, tôi rút

**USER.** Cậu nói sẽ bấm "Bỏ qua" — tôi tin cậu trăm phần trăm. Mười lăm năm trong lớp, tôi chưa từng thấy đứa trẻ nào khai thật với cái form. Hỏi "hôm nay con thấy thế nào?", chúng trả lời điều chúng nghĩ tôi muốn nghe. Kỳ vọng "tự khai thật với app" sai ngay từ nguồn. Vậy form phản tư dài phải bỏ. Nhưng không bỏ hẳn việc lắng nghe: một câu hỏi đóng, hai nút — "còn lo" / "ổn" — mười giây, và app phải chấp nhận im lặng. UI chốt lời chữ là đúng, vì hễ để tự gõ là lại thành kiểu khoe. Cái tôi cần không phải dữ liệu khai, là **dữ liệu hành vi**: mở lúc mấy giờ, học bao lâu, bỏ giữa chừng không. Cậu nói dữ liệu chết giết cậu — đúng, nhưng dữ liệu giả còn tệ hơn, vì nó báo cáo sai cho cả nhà.

**UI.** "Chế độ yên lặng" đúng. Nhưng đếm ngược kỳ thi: theo tôi, chính nó làm các em nghẹn thở. Có lần tôi ghi bảng đếm ngược lên tường, mấy đứa yếu bắt đầu nhìn bức tường thay vì làm bài. Đếm ngược là công cụ của đứa giỏi đo tiến độ; đứa yếu cần cảm giác "hôm nay xong được một việc". Bỏ đồng hồ đếm, thay bằng **dấu đã qua** — "tuần này ôn xong 5/20 đề" — nhìn về sau, không nhìn về trước.

Leaderboard ẩn danh M3: tôi vẫn giữ quan điểm bỏ. Và nói thẳng với BOSS — nếu ông giữ nó, tôi rút khỏi dự án này. Không phải đe doạ. Tôi từng thấy một đứa khóc trong nhà vệ sinh vì tụt ba bậc trên bảng xếp hạng lớp. Tôi ký vào dự án này để làm app cho đứa yếu, không phải để dựng sàn đấu cho đứa mạnh.

**DEV + USER.** App không phân biệt được "học mười phút thật" với "bấm cho có" — và đừng mơ phân biệt. Bật máy, mở app, để yên trên bàn: đó là phiên đẹp với mọi hệ thống. Nhưng tôi — người trong lớp — nhìn là biết cậu có đang làm không, vì tôi biết cậu hỏng ở đâu trước khi cậu ngồi xuống. Vậy giới hạn của app: đo được sự có mặt, không đo được sự nghĩ. Nếu cố soi sâu — chụp màn hình, đếm cú nhấp — các em sẽ tìm cách qua mặt, và tôi mất luôn cả sự tin. Tôi chỉ giữ một tín hiệu không giả được: **cậu chủ động quay lại sau khi bỏ giữa chừng**.

**Chốt.** Một thay đổi tác động lớn nhất: bỏ toàn bộ điểm thành tích hiển thị — rank, XP, bảng xếp hạng — và thay bằng một câu app tự nói: **"hôm nay thế đủ rồi"**. Không phải con số. Con số, chúng tôi cho các em đủ rồi — cả đời còn lại của các em sẽ là những con số.

---

## Vòng 3 — Điều phối viên chốt Phiên bản V2

ĐIỀU PHỐI VIÊN đọc toàn bộ 3 vòng thảo luận sâu và xuất **BẢN THAY ĐỔI V2** — full bảng thay đổi v1→v2 (hạng mục | cũ | mới | nhường/lấy | vai chốt | lý do), kế hoạch M1'/M2/M3 phục ban, gate viết lại, xung đột còn lại, và bộ KPI V2 (từ 20 KPI xuống **8 KPI đo bên ngoài + 3 KPI người dùng**). Toàn bộ nội dung được xuất sang file riêng:

> 📄 **`BAN_THAY_DOI_V2.md`** — Bản thay đổi V2: phiên mặc định 10 phút, phản tư 1 câu 2 nút, chế độ yên lặng 3 công tắc, dark theo hành động phiên học, báo cáo phụ huynh 3 dòng, nhắc ngủ đúng một câu, Pomodoro timestamp-based, RLS + CRON_SECRET trước khi cloud, thùng rác 30 ngày, KPI V2 gồm "mở–tắt 5 giây vì chán", "app nói đúng về tôi", "chủ động quay lại sau bỏ giữa chừng".

*Hết Phần 2. Buổi họp sâu kéo dài 3 vòng với 6 vai; các vai phát biểu bằng chính phiên họp cũ, có nhớ ngữ cảnh trước đó. Tất cả chạy local, không tốn chi phí.*
