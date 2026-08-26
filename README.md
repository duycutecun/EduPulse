# EduPulse — Trợ lý Sĩ tử & Đếm ngược Kỳ thi 🎓

**EduPulse** là ứng dụng Flutter dành cho sĩ tử luyện thi THPTQG, TSA ĐHBK Hà Nội, HSA ĐHQG Hà Nội, và IELTS.

## ✨ Tính Năng Cốt Lõi

- 🕐 **Đếm ngược kỳ thi** — Flip tiles Ngày/Giờ/Phút/Giây theo thời gian thực
- 📋 **Nhiệm vụ hôm nay** — Checklist học tập theo môn, tick hoàn thành & Streak 🔥
- 🤖 **AI Coach (Gemini)** — Giải đề qua ảnh OCR & tư vấn phương pháp học
- ⏱️ **Pomodoro Lo-Fi** — Đồng hồ tập trung + âm thanh thư giãn
- 🏆 **Bảng vàng Sĩ tử** — Xếp hạng & cổ vũ lẫn nhau toàn quốc
- ☁️ **Supabase Cloud Sync** — Đồng bộ dữ liệu lên PostgreSQL đám mây

## 🛠️ Tech Stack

| Layer | Công nghệ |
|---|---|
| Frontend | Flutter (Web + Mobile) |
| Local Storage | SharedPreferences |
| Cloud Database | Supabase (PostgreSQL) |
| AI Engine | Google Gemini API |
| Hosting | Vercel / GitHub Pages |
| CI/CD | GitHub Actions |

## 🚀 Khởi Động

```bash
flutter pub get
flutter run -d chrome   # Web
flutter run             # Mobile
```

## ⚙️ Cấu Hình

1. **Gemini API Key** — Lấy miễn phí tại [aistudio.google.com](https://aistudio.google.com)
2. **Supabase** — Tạo project tại [supabase.com](https://supabase.com), chạy `supabase_schema.sql`

Nhập keys tại **Tab Cá nhân → Cài đặt** trong ứng dụng.

## 📦 Deploy Web

```bash
flutter build web --release
```

Xem [walkthrough.md](walkthrough.md) để biết hướng dẫn deploy Vercel & GitHub Pages.
