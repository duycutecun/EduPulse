# EduPulse — Trợ lý Sĩ tử & Đếm ngược Kỳ thi 🎓

**EduPulse** là ứng dụng Flutter (PWA + Mobile) dành cho sĩ tử luyện thi THPTQG, TSA ĐHBK Hà Nội, HSA ĐHQG Hà Nội, và IELTS. Hoạt động offline-first: mọi dữ liệu học tập được lưu an toàn trên máy và tự động đồng bộ lên đám mây khi có mạng.

## ✨ Tính Năng Cốt Lõi

Ứng dụng được tổ chức thành 5 tab chính (`main_shell.dart`):

### 0. 🎉 Onboarding lần đầu
- Màn hình chào mừng: chọn **kỳ thi mục tiêu** (THPTQG / TSA / HSA / HSG) → app tự tạo kỳ thi đếm ngược + seed **nhiệm vụ mẫu** cho ngày hôm nay (`onboarding_screen.dart`, preset tại `preset_exams.dart`)
- Ngày thi mặc định theo lịch thực tế (THPTQG: 11–12/06 hằng năm), có thể chỉnh sửa sau

### 1. 🏠 Học (Home) — Vòng lặp học tập hàng ngày
- **Thẻ đếm ngược kỳ thi chính** cho kỳ thi ưu tiên (`hero_countdown_card.dart`)
- **Nhiệm vụ hôm nay** — danh sách việc cần làm theo môn với mức ưu tiên/thời lượng ước tính; hoàn thành nhận XP (`today_mission_card.dart`)
- **Gamification** — XP, hệ thống cấp độ (`xpForLevel`), **Streak** học hàng ngày 🔥 và kỷ lục chuỗi ngày
- **Linh vật đồng hành** — EXP gắn kết, mở khóa trang phục theo mốc streak, tính năng "Bốc Quẻ Sĩ Tử" (`mascot_companion_modal.dart`)
- Mẹo học tập thông minh + lối tắt nhanh vào Pomodoro / AI Coach

### 2. 🚩 Mục tiêu (Kỳ thi)
- Đếm ngược cho **các kỳ thi mẫu có sẵn** (THPTQG, TSA, HSA, HSG) và **kỳ thi tự tạo**
- Chọn **kỳ thi chính**, theo dõi/cập nhật/xóa, nhãn mức độ khẩn cấp ("Sắp thi" < 30 ngày...)

### 3. ✨ AI Coach — Gia sư AI
- Chat **đa model**: Gemini trực tiếp + OpenRouter (GPT-4o mini...) qua `AiRouter`
- **Đọc ảnh**: tải lên ảnh đề/phiếu bài (file_picker), render công thức toán **LaTeX** (`flutter_math_fork`)
- **Tra cứu web** (Tavily, fallback Wikipedia) + tự động chuyển model khi lỗi
- **Lịch sử chat** được lưu lại giữa các phiên
- **Quiz từ ảnh** 📷➡️📝 — chụp trang sách/vở, AI đọc ảnh và sinh 5 câu trắc nghiệm để luyện ngay (`quiz_play_screen.dart`)
- **Điểm yếu từ lịch sử chat** 📊 — nút phân tích chỉ ra chủ đề yếu lặp lại trong 15 câu hỏi gần nhất + gợi ý việc cần làm
- **Lộ trình AI** 🗺️ — chọn quỹ thời gian (1–4h/ngày) và độ dài (3/7/14 ngày) → AI sinh kế hoạch học → một chạm đổ vào Nhiệm vụ hôm nay (`ai_plan_screen.dart` + `ai_plan.dart`)

### 4. ⏱️ Tập trung (Study)
- **Đồng hồ Pomodoro** — tùy chỉnh thời lượng tập trung / nghỉ và số phiên
- **Nhật ký học tập** theo môn + biểu đồ giờ học hàng tuần theo tuần lịch T2–CN (`weekly_chart_widget.dart`)
- **Điểm thi thử** 📝 — ghi điểm từng lần thi theo môn, tổng hợp TB/mới nhất/cao nhất, **AI phân tích môn yếu** & gợi ý kế hoạch ôn (`score_summary.dart`)
- Âm thanh phản hồi tổng hợp (chirp/pop/equip) khi tương tác (`AudioSynthService`)

### 🛡️ Lá bùa giữ chuỗi (Giai đoạn 1)
- Nghỉ học **đúng 1 ngày** vẫn giữ nguyên streak 🔥 — mua bằng EXP gắn kết linh vật (100 EXP/lá, giữ tối đa 3 lá) tại Góc Tâm Tình
- Logic cập nhật trong `StorageService.registerStudyActivity()`

### ✨ Mẫu nhiệm vụ theo kỳ thi (Giai đoạn 1)
- Nút **✨** cạnh nút "+" trong Nhiệm vụ hôm nay: thêm nhanh nhiệm vụ mẫu theo kỳ thi mục tiêu đang ghim (nguồn: `preset_exams.dart`)

## 🧩 Năng lực nền tảng (ngang dọc)

- **Offline-first**: toàn bộ dữ liệu lưu cục bộ (SharedPreferences qua `StorageService`), tự động sync Supabase khi có lại mạng (banner offline/kết nối lại)
- **PWA**: cài đặt được trên Android/iOS kèm hướng dẫn cài (`PwaService`, `_InstallBanner`)
- Rung phản hồi (haptics) + âm thanh làm phản hồi tương tác

## 🎯 Tóm tắt giá trị sản phẩm

> *Đếm ngược kỳ thi + kỷ luật học hàng ngày (nhiệm vụ, streak, Pomodoro) + gia sư AI + động lực cộng đồng (bảng xếp hạng) — dùng được hoàn toàn offline.*

## 🛠️ Tech Stack

| Layer | Công nghệ |
|---|---|
| Frontend | Flutter (Web + Mobile) |
| Local Storage | SharedPreferences |
| Cloud Database | Supabase (PostgreSQL) |
| AI Engine | Google Gemini API + OpenRouter (GPT-4o mini, ...) |
| Web Search | Tavily API (fallback Wikipedia) |
| Hosting | Vercel / GitHub Pages |
| CI/CD | GitHub Actions |

## 🚀 Khởi Động

```bash
flutter pub get
flutter run -d chrome   # Web
flutter run             # Mobile
```

## ⚙️ Cấu Hình

API keys KHÔNG hardcode trong repo — truyền lúc build qua `--dart-define` (Vercel đọc từ biến môi trường, xem `build.sh` và `vercel.json`); nếu để trống, app dùng config người dùng nhập tại **Tab Cá nhân → Cài đặt**.

| Biến | Bắt buộc | Mục đích |
|---|---|---|
| `SUPABASE_URL` + `SUPABASE_ANON_KEY` | ☁️ Cloud sync | Đồng bộ dữ liệu & đăng nhập |
| `GEMINI_API_KEY` | 🤖 AI Coach | Lấy miễn phí tại [aistudio.google.com](https://aistudio.google.com) |
| `OPENROUTER_API_KEY` | Tuỳ chọn | Thêm model khác (GPT-4o mini...) tại [openrouter.ai](https://openrouter.ai) |
| `TAVILY_API_KEY` | Tuỳ chọn | Tra cứu web thời gian thực tại [tavily.com](https://tavily.com) |

Ví dụ chạy local:

```bash
flutter run -d chrome \
  --dart-define=GEMINI_API_KEY=your_key \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

## 📦 Deploy Web

```bash
flutter build web --release
```

Deploy Vercel đã cấu hình sẵn qua [`vercel.json`](vercel.json) và [`build.sh`](build.sh) (build tự động nhận keys từ biến môi trường).
