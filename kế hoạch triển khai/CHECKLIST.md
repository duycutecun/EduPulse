# CHECKLIST ĐỐI CHIẾU ĐẶC TẢ ↔ TRIỂN KHAI EduPulse

> Đối chiếu toàn bộ 59 mục `EduPulse_Product_UX_UI_Specification_v1.0.md` với code thực tế.
> Cập nhật: 30/09/2026 — **114/114 test pass, `flutter analyze` sạch 100%.**
> Chú thích: ✅ đủ · 🟡 đủ phần khả thi (ghi rõ thứ còn thiếu + lý do) · ⏸ cố ý bỏ (có lý do)

---

## Nhóm tính năng cốt lõi

| # | Mục spec | Hạng mục | Trạng thái | Ghi chú |
|---|----------|----------|------------|---------|
| 1 | 5 | Information Architecture | ✅ | 3 tab mobile (Học/AI/Tôi) + 7 mục desktop sidebar (mục 52) |
| 2 | 6 | Home/Dashboard | ✅ | Countdown, Today's Tasks, Progress, Study Time, Mascot đủ theo mục 6.2–6.8 |
| 3 | 7.1–7.8 | Task model/create | ✅ | Subtasks, recurring (daily/weekly), deadline, priority, Quick Add |
| 4 | 7.9 | Undo sau complete | ✅ | SnackBar 5s action "Hoàn tác", revert status + XP + streak |
| 5 | 7.10 | Reschedule | ✅ | Quick options + cảnh báo dời ≥3 lần + AI gợi ý chia nhỏ (Phần 32) |
| 6 | 7.11 | Skip + lý do | ✅ | 6 lý do đúng spec, lưu `skipReason` |
| 7 | 7.12 | Task → Focus | ✅ | Chọn task trước khi bắt đầu Pomodoro |
| 8 | 8 | Add Task UX | ✅ | Sheet + Quick Add ngôn ngữ tự nhiên (mục 25, offline parser) |
| 9 | 9 | Goal & Exam | ✅ | Exam hierarchy, target score, đổi ngày thi, goal progress |
| 10 | 10.1–10.9 | AI Coach | ✅ | Context, capabilities, autonomy (Preview→Accept/Edit/Reject), confidence, uncertainty |
| 11 | 10.9–10.10 | AI citations + feedback | ✅ | Source card từ web lookup (Phần 34) + 👍/👎/Regenerate/Report + 7 lý do (Phần 28) |
| 12 | 11.1–11.4 | Focus Mode | ✅ | Timer, session, pause, break |
| 13 | 11.5 | App leaving | ✅ | Pattern analysis + 3 loại gợi ý nhẹ nhàng, ngưỡng cao không ép (Phần 33) |
| 14 | 11.8–11.9 | Reflection | ✅ | Mood/focus/difficulty/understanding + note sau phiên |
| 15 | 12 | Study Log & Analytics | ✅ | So sánh tuần, efficiency composite, focus pattern, best study time |
| 16 | 13 | Calendar | 🟡 | ✅ agenda + Optimize Week Diff + drag + exam/milestone + warning vượt deadline (Phần 25/29). **Thiếu: desktop calendar 3 cột** — spec mục 13 ưu tiên agenda cho mobile; desktop đã có sidebar dashboard, layout dashboard nhiều cột chưa làm |
| 17 | 14 | Notes | 🟡 | ✅ Task/Subject/Session-linked + ảnh + autosave + draft recovery (Phần 31). **Thiếu: scan documents, multi-file attachment** — cần OCR/storage thật, không fake; Goal-linked qua goalId trong task đã liên kết |
| 18 | 15 | Search | 🟡 | ✅ đủ 6 nguồn: Tasks/Calendar, Goals/Exams, Notes, Sessions, AI conversations + gợi ý query (Phần 31). **Thiếu: semantic search** — cần embedding model, không giả vờ (mục 10.8) |
| 19 | 16 | Notifications | ✅ | Thích ứng tần suất, daily digest 20:30, focus blocking, urgent bypass (Phần 14) |
| 20 | 17 | Profile | ✅ | Learning Profile infer + user override luôn thắng (Phần 15) |
| 21 | 18 | Settings | ✅ | Reminder, digest, AI permissions, mascot, reduce motion |
| 22 | 19 | Privacy & Data | 🟡 | ✅ Export JSON/CSV/MD, import merge-safe, delete type-to-confirm, **Delete AI memory + undo window** (Phần 34), Sync states UI. **Thiếu: ZIP export** (cần archive package), **delete account + re-auth** (cần cấu hình Firebase server-side bổ sung) |
| 23 | 20 | Appearance | ✅ | Font scale S/M/L nhân system scale; **dark mode ⏸ cố ý bỏ** — palette tối chưa đạt chuẩn production, không fake switch |
| 24 | 21 | Accessibility | ✅ | Semantics labels, tooltips đủ 12 icon-only, keyboard desktop, adaptive font, reduced motion, **high contrast mode** (Phần 24/27/34). *Dark/system theme ⏸ — palette tối chưa đạt chuẩn, high contrast là giải pháp accessibility thay thế* |
| 25 | 22 | Responsive | ✅ | Mobile <768, tablet, desktop ≥1024 breakpoint |
| 26 | 23–24 | Desktop/Mobile Nav | ✅ | Sidebar collapsible + bottom nav + keyboard |
| 27 | 25 | Quick Actions | ✅ | Quick Add parser offline: ngày/giờ/thời lượng/môn/priority, trả null khi thiếu tín hiệu |
| 28 | 26–29 | Visual/Type/Button/Task | ✅ | GlassCard system, Duolingo-style palette |
| 29 | 30 | Bottom Sheets | ✅ | Drag handle + contextual height (Phần 30) |
| 30 | 31 | Mascot | ✅ | Avatar + wardrobe + bond EXP + disable option |
| 31 | 32 | Motion | ✅ | Contextual, reduced motion giảm animation |
| 32 | 33 | Empty/Error States | ✅ | Task/Calendar/Notes/StudyLog/AI/Search đúng copy + actions (Phần 26) |
| 33 | 34 | Offline-first | ✅ | Indicator + toàn bộ local features dùng được offline |
| 34 | 35 | Reliability | ✅ | Sync retry, AI fallback, draft recovery, keep local data |
| 35 | 36–38 | Behavioral/Personal/Rhythm | ✅ | Learning Profile, hypothesis tone "có vẻ/thử" xuyên suốt |
| 36 | 39–40 | Exam Mode/Post-exam | ✅ | Revision 7 ngày, exam day, post-exam score entry |
| 37 | 41 | Mock Score | ✅ | Trend analysis, score chart, insight, by-subject (Phần 20/21) |
| 38 | 42 | Migration | ✅ | Auto backup → migrate → rollback + restore + notify (Phần 23) |
| 39 | 43 | UX Principles | ✅ | Fast/Easy/Personal/Calm áp dụng xuyên suốt |
| 40 | 44 | Gamification | ✅ | Đúng chừng mực: achievement + subtle feedback + mascot; **không dùng streak ép** |
| 41 | 45 | Core Screens | ✅ | Đủ các màn chính trong danh sách 34 screens |
| 42 | 46 | Onboarding | ✅ | Wizard 4 bước, AI preview, fallback offline |
| 43 | 47 | Daily Experience | ✅ | Flow Countdown→Tasks→Focus→Complete→Reflection tối ưu |
| 44 | 48–51 | Design System/Tokens/Figma/Handoff | ✅ | Tokens trong `app_colors.dart`, components trong `shared/widgets` |
| 45 | 52 | Navigation Behavior | ✅ | Desktop sidebar + secondary actions + keyboard |
| 46 | 53 | iOS/PWA Native Feel | 🟡 | ✅ Safe areas, haptic, bottom sheet, pull-to-refresh, install banner. **Thiếu: verify trên thiết bị thật** (swipe back, status bar edge cases) |
| 47 | 54 | Interaction Feedback | ✅ | Haptic task complete + timer end + important action; sound optional có audio_synth |
| 48 | 55 | Performance | ✅ | Lazy tabs, switch tức thời, cache ảnh, deferred init |
| 49 | 56 | Priorities | 🟡 | ✅ Đủ P0 Core + P1 Intelligence. **P2 còn: Resources hub + external calendar integration** — cần API/platform channel thật |
| 50 | 57 | Không nên ưu tiên | ✅ | Không streak-ép, không XP-heavy, không animation showcase |
| 51 | 58 | Conflict Register | ✅ | Các quyết định ghi rõ trong p1/p2/p3.md |
| 52 | 59 | Success Criteria | ✅ | Core loop hoạt động offline-first hoàn chỉnh |

## Các mục cố ý bỏ và lý do

| Tính năng | Lý do |
|-----------|-------|
| Dark mode (mục 20) | Palette tối chưa đạt chuẩn production — không fake switch, trung thực với người dùng |
| External calendar integration (mục 13/P2) | Cần platform channel + permission thật (Google Calendar API) — ngoài phạm vi hiện tại |
| Scan documents / multi-file attachments (mục 14) | Cần OCR service + file storage thật; ảnh đơn ≤250KB đã có |
| Semantic search (mục 15) | Cần embedding model; đã có full-text + gợi ý query thay thế |
| Desktop calendar 3 cột (mục 13) | Agenda-first là lựa chọn của spec; desktop dashboard layout chưa được ưu tiên trong các phiên trước |
| iOS native feel chi tiết (mục 53) | Cần thiết bị thật để verify swipe-back/status bar/edge-to-edge |

## Nhật ký theo phần (chi tiết trong p1.md / p2.md / p3.md)

- **p1/p2 (Phần 1–9):** nền tảng + core screens + Home + AI Coach + Focus + Study Log
- **p3 Phần 10–20:** Exam Mode, Onboarding, Analytics, Notes Markdown, Notifications, Learning Profile, Data transfer, Desktop sidebar, Appearance, Quick Add, Score analysis
- **p3 Phần 21–33:** Score chart, Sync states, Migration, Keyboard nav, Optimize Week, Empty states, Accessibility, AI feedback, Calendar drag/exam, Native feel, Notes links/Search, Reschedule guard, App-leaving
