# ADR-0001 — Thiết kế iOS-first (hệ sinh thái iOS) và token chuyên biệt

- **Ngày:** 2026-10-16
- **Trạng thái:** chấp nhận (áp dụng từ slice "design foundation + Home" —
  `app_colors.dart`, `app_theme.dart`, màn Home đã được restyle).
- **Trạng thái kế thừa:** không áp dụng cho màn chưa được restyle (theme
  `AppTheme.lightTheme` vẫn giữ nguyên cho đến hết slice tương ứng).

## Bối cảnh

Người dùng chọn hướng triển khai (hợp nhất các chỉ mục a/b/c trong
`BAN_THAY_DOI_V2.md`): **toàn bộ UI/UX redesign, ưu tiên iOS**, trong đúng
codebase Flutter hiện có — không tạo ứng dụng iOS-native riêng. Hai nền tảng
mobile/PWA/iOS của app dùng một `ThemeData` duy nhất, và hiện tại theme là
Phong cách Duolingo (màu xanh lá `#58CC02`).

## Quyết định

1. **Theme iOS-first là nền tảng của UI mới.** Mọi slice sau restyle theo
   hướng này sẽ dùng `AppTheme.iosLightTheme` — màu lấy từ hệ sinh thái
   iOS (SF Symbols/SF Pro, Apple HIG): systemBlue làm chủ đạo, systemGreen
   cho thành tựu, systemPurple cho hành động AI, systemOrange cảnh báo,
   systemRed lỗi, hệ màu grouped/background tương ứng.
2. **Token iOS-first nằm trong `AppColors` (nhóm `ios*`), song song token
   cũ.** Mọi widget chưa được restyle vẫn dùng token cũ; chúng chỉ được
   đổi khi tới slice của riêng màn đó. Token cũ được giữ nguyên để không
   phá build/test của các slice chưa chạy.
3. **Home là màn trọng tâm của slice đầu tiên** (theo KPI "mở app → việc
   cần làm ≤2 chạm"), nên slice này restyle toàn bộ widget của màn Home:
   `home_screen.dart` + các widget con của `features/home/…`.
4. **Thanh "Bắt đầu · 10 phút" là `Positioned` cuối màn** (Stack + `fit:
   StackFit.expand`). Flutter không cho `Column` chứa `Expanded` trước một
   widget khác; `Expanded` buộc phải là con cuối, nên thanh dính đáy được tách
   ra ngoài Column. `Stack` phải `expand` để luôn phủ kín màn (đảm bảo thanh
   luôn sát đáy, kể cả khi nội dung cuộn).
5. **Golden 3 màn được sinh lại** theo thiết kế mới (đã chạy
   `flutter test --update-goldens` và cập nhật baseline). Gate diff ≠ 0
   vẫn được giữ nguyên.
6. **Nav 4 tab / Leaderboard.** Xung đột giữa kế hoạch V2 (thay tab "Leaderboard")
   và `main_shell.dart` hiện tại vẫn được **defer** cho slice riêng — không
   đổi trong slice này.
7. **Tính năng native iOS (home screen WidgetKit, …) vẫn defer.** Hiện tại
   `PlatformCapabilities` báo `comingSoon` cho home widget trên iOS; việc
   này cần target WidgetKit mới và verification trên thiết bị thật, ngoài
   phạm vi slice này.
8. **Slice "còn lại" — toàn bộ màn/palette được chuyển sang token iOS-first.**
   Token cũ (`AppColors` Duolingo-style) được thay bằng token iOS tương ứng
   (xem mục 9) ở **toàn bộ** `lib/` — trừ hai file giữ nguyên:
   `app_colors.dart` (định nghĩa cả hai palette) và `app_theme.dart`
   (`lightTheme` cũ được giữ lại phục vụ harness test/giá trị tham chiếu).
   Tất cả feature: study, ai_coach, progress, account, tasks, calendar,
   notes, exams, leaderboard, family, search, auth, onboarding, gamification
   và các file app-level (`main_shell`, `tab_chrome`, `desktop_*`,
   `shell_banners`) + shared widget còn lại.
9. **Phân ánh token cũ → token iOS-first.**
   - `primary*` → `iosPrimary*` (primaryLight → `iosPrimarySoft`),
     `primaryDark` → `iosPrimaryDark`.
   - `green*` → `iosSuccess*` (`greenLight`/`greenSoft` → `iosSuccessSoft`),
     `greenDark` → `iosSuccess`.
   - `blue*` → `iosInfo*` (`blueLight` → `iosInfoSoft`, `blueDark` →
     `iosInfoDark`).
   - `purple*` → `iosSecondary*` (`purpleLight` → `iosSecondarySoft`),
     `purpleDark` → `iosSecondaryDark`.
   - `orange*` → `iosWarning*` (`orangeDark` → `iosWarningDark`).
   - `red*` → `iosError*` (`redDark` → `iosErrorDark`).
   - `yellow` → `iosStreak` (và `yellowDark` → `iosStreak`).
   - Text: `textPrimary`/`textSecondary`/`textMuted` → `iosTextPrimary`/
     `iosTextSecondary`/`iosTextMuted`.
   - Nền/tấm: `bgPage` → `iosBackground`, `bgPageSoft`/`cardLight` →
     `iosFill`, `cardWhite` → `iosCard`, `border`/`borderStrong` →
     `iosSeparator`, `progressBg` → `iosFill`, `progressDone` → `iosSuccess`.
   - Ánh sáng "soft" dùng `withValues(alpha: …)` như mọi token ios* khác.
10. **Token chung dùng bởi mọi màn (chạy ngay, không chờ slice riêng).**
    - `AppTokens` (font style) và `sync_status_bar` được chuyển ngay khi
      wiring theme vào `MaterialApp` — vì mọi màn render dưới `iosLightTheme`,
      nếu giữ token cũ thì toàn bộ app vẫn nhìn "vừa cũ".
    - `leaderboard_view` và `note_markdown` cũng đã chuyển token iOS-first
      cùng đợt "làm hết" (giao diện chức năng Leaderboard/Notes không đổi,
      chỉ màu sắc).
11. **Xung đột Leaderboard: ĐÃ chốt theo đặc tả V2** (`BAN_THAY_DOI_V2.md`
    mục C.1 — "Bỏ thi đua ẩn danh; không màn nào hiện số/tên người khác;
    kỷ lục cá nhân giữ").
    - Already: không có tab Leaderboard trong shell — "Bảng vàng kỷ lục"
      chỉ là màn con (kỷ lục **cá nhân**) từ tab Tôi + payload thông báo
      báo cáo tuần → tuân đặc tả, giữ nguyên.
    - Gỡ mã thi đua cộng đồng cũ (mã chết): `shared/widgets/leaderboard_view.dart`,
      `CommunityUser` (study_models), `fetchLeaderboard()` +
      `_upsertLeaderboardRow()` (supabase_service) — không màn nào hiển thị
      số/tên người học khác.
    - Gate tự động: `test/no_other_users_gate_test.dart` — quét `lib/` ngay
      khi mã hiện người khác dính lại đầu, đỏ trước khi lên màn.
    - Native home widget vẫn defer (mục 7, cần macOS/Xcode).
12. **IPA build trên GitHub Actions** (thiết lập riêng, không thuộc ADR
    design): workflow `.github/workflows/build-ios-ipa.yml` chạy trên
    `macos-14`, chạy `flutter analyze` + `flutter test` rồi
    `flutter build ios --release --no-codesign`, đóng gói `Runner.app`
    thành `.ipa` (Payload/) và upload artifact. Do không có certificate
    Apple trên CI, `.ipa` hiện là **không ký** — cần ký lại trước khi
    cài lên thiết bị thật (bước signing sẽ thêm sau nếu user cấp
    certificate/provisioning).

## Hệ quả

- `lib/core/constants/app_colors.dart`: nhóm token `ios*` (màu, token text,
  nền/tấm).
- `lib/core/theme/app_theme.dart`: thêm `iosLightTheme` và
  `iosLightThemeWithContrast`; `lightTheme` (Duolingo) không đổi.
- `lib/main.dart`: `MaterialApp` dùng `iosLightThemeWithContrast` — toàn
  bộ app (không chỉ màn Home) chạy trên theme iOS-first.
- `lib/core/constants/app_tokens.dart`: font style dùng token `iosText*`.
- `lib/shared/widgets/sync_status_bar.dart`: token `ios*` (dùng trên mọi
  màn).
- `lib/features/home/presentation/screens/home_screen.dart`: build theo
  `Stack` (thanh dính đáy), mọi màu dùng token iOS-first.
- Các widget của màn Home (12 file trong `features/home/…/widgets/`) và các
  shared widget được dùng trực tiếp bởi Home (`primary_button`,
  `state_views`, `app_bottom_sheet`, …) đã chuyển sang token iOS-first.
- `lib/features/study/…`: màn "Tập trung" (`study_screen.dart` —
  tuỳ chọn của user —, `study_page.dart`, `ai_plan_screen.dart`), biểu đồ
  tuần, biểu đồ điểm, tab điểm, sheet sau focus, `ai_post_focus_sheet`:
  đã chuyển sang token iOS-first (chỉ đổi màu token, không đổi logic).
- `lib/features/ai_coach/…`: màn AI (`ai_coach_screen.dart`), quiz, flashcard
  review, header/chat widgets/latex: đã chuyển sang token iOS-first.
- Toàn bộ feature còn lại (progress, account, tasks, calendar, notes, exams,
  leaderboard, family, search, auth, onboarding, gamification) và app-level
  shell đã chuyển token iOS-first.
- `.github/workflows/build-ios-ipa.yml`: workflow build IPA (analyze → test
  → build iOS không ký → artifact `.ipa`).
- `test/home_ios_first_theme_test.dart`: khóa contract theme + vị trí
  thanh "Bắt đầu" + token CTA.
- Các test cũ dùng `AppTheme.lightTheme` (theme Duolingo) vẫn chạy xanh
  — chúng mô phỏng hành vi, không phải màu sắc.
