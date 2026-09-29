# EduPulse --- Product, UX/UI & Development Specification

> **Phiên bản:** 1.0\
> **Phạm vi dữ liệu:** Tổng hợp từ bộ phỏng vấn UX/UI Q1--Q730\
> **Sản phẩm:** EduPulse\
> **Định hướng:** Trợ lý học tập cá nhân giúp học sinh duy trì kỷ luật
> ôn thi

------------------------------------------------------------------------

## 1. Tóm tắt sản phẩm

EduPulse là một **trợ lý học tập cá nhân** dành cho học sinh ôn thi. Sản
phẩm không nên trở thành một hệ thống quản lý học tập quá phức tạp; giá
trị cốt lõi là giúp người dùng:

1.  Biết hôm nay cần làm gì.
2.  Bắt đầu học nhanh.
3.  Theo dõi việc học thực tế.
4.  Nhận hỗ trợ từ AI khi cần.
5.  Điều chỉnh kế hoạch dựa trên dữ liệu thật.
6.  Duy trì việc học đúng cách thay vì chỉ học nhiều hơn.

### Tuyên ngôn sản phẩm

> **"Bạn đặt mục tiêu, EduPulse giúp biến nó thành hành động."**

### Nguyên tắc UX cốt lõi

-   **Nhanh**
-   **Tiện**
-   **Dễ nhìn**
-   **Dễ sử dụng**
-   **Cá nhân hóa**
-   AI thông minh nhưng không được tự ý thực hiện các thay đổi quan
    trọng.
-   App thích nghi với nhịp học thật của học sinh thay vì ép người dùng
    theo một thời khóa biểu cứng.
-   Người dùng có thể học ít hơn nhưng **học đúng cách hơn**.

------------------------------------------------------------------------

# 2. Product Positioning

## 2.1. EduPulse là gì?

EduPulse được định vị là:

> **Một trợ lý học tập cá nhân có cảm giác như một app native cao cấp.**

Cảm giác mong muốn:

-   Personal tutor
-   Premium native app
-   Productivity cho học sinh
-   AI tutor + learning management
-   Thân thiện nhưng không trẻ con
-   Thông minh nhưng không phô trương
-   Có tính cá nhân hóa cao
-   Ít clutter

## 2.2. Không nên biến EduPulse thành

-   Một LMS nặng nề.
-   Một app gamification thuần túy.
-   Một chatbot AI độc lập.
-   Một calendar app.
-   Một task manager khô cứng.
-   Một app ép người dùng phải học theo lịch.
-   Một dashboard đầy card và số liệu nhưng khó hành động.

------------------------------------------------------------------------

# 3. Core User Problems

EduPulse giải quyết ba vấn đề chính:

### 3.1. Có kế hoạch nhưng không thực hiện

Người dùng có thể lập kế hoạch nhưng trì hoãn hoặc không bắt đầu.

### 3.2. Dễ mất động lực

Người dùng có thể bỏ học vài ngày, hoàn thành không đủ task hoặc cảm
thấy kế hoạch quá nặng.

### 3.3. Khó tập trung

Người dùng có thể dành nhiều thời gian nhưng hiệu quả thấp.

Vì vậy EduPulse không chỉ đo **study time**, mà phải quan tâm:

-   Task completion
-   Actual study time
-   Focus
-   Difficulty
-   Understanding
-   Mood
-   Effectiveness
-   Score
-   Weakness
-   Study patterns

------------------------------------------------------------------------

# 4. Core Product Loop

Luồng sử dụng lý tưởng:

``` text
Mở app
  ↓
Biết hôm nay cần làm gì
  ↓
Chọn task
  ↓
Start Focus
  ↓
Học
  ↓
Hoàn thành / ghi nhận session
  ↓
Reflection nếu phù hợp
  ↓
Cập nhật progress
  ↓
AI học từ dữ liệu
  ↓
Điều chỉnh recommendation / kế hoạch
```

App phải làm cho vòng lặp này nhanh và ít ma sát.

------------------------------------------------------------------------

# 5. Information Architecture

## 5.1. Main navigation

Sử dụng **3 tab chính**:

1.  **Học**
2.  **AI**
3.  **Tôi**

Mobile sử dụng bottom tab bar.

Desktop sử dụng navigation/sidebar nhưng giữ cùng information
architecture.

## 5.2. Học

Bao gồm:

-   Home/Dashboard
-   Tasks
-   Goals/Exam
-   Calendar
-   Focus
-   Study Log / Analytics
-   Notes

Goal, Calendar và Focus có thể mở như các màn hình riêng từ Home hoặc
context tương ứng, thay vì biến tất cả thành tab chính.

## 5.3. AI

AI Coach là một khu vực riêng nhưng cũng xuất hiện xuyên suốt sản phẩm.

## 5.4. Tôi

Bao gồm:

-   Profile
-   Learning Profile
-   Progress
-   Settings
-   AI permissions
-   Privacy
-   Data
-   Appearance
-   Accessibility
-   Advanced Settings

------------------------------------------------------------------------

# 6. Home / Dashboard

## 6.1. Mục tiêu

Home phải trả lời ngay:

> **"Hôm nay tôi cần làm gì?"**

Không được biến Home thành một dashboard phân tích quá tải.

## 6.2. Thứ tự Home

Định hướng chính:

``` text
Countdown
↓
Today’s Tasks
↓
AI Recommendation
↓
Progress
↓
Study Time
↓
Mascot
```

AI recommendation có thể xuất hiện contextually khi thực sự đáng chú ý.

## 6.3. Countdown

Countdown là hero element.

Hiển thị:

-   Ngày
-   Giờ
-   Phút
-   Giây
-   Tên kỳ thi
-   Target score nếu có
-   Progress tới kỳ thi nếu phù hợp

Countdown phải:

-   Medium-sized
-   Nổi bật nhưng không chiếm toàn bộ màn hình
-   Có visual adaptation theo giai đoạn
-   Không cần xuất hiện quá mạnh ở mọi context

Khi còn 1 ngày:

> "Ngày mai là ngày thi. Bạn đã sẵn sàng chưa?"

Sau kỳ thi, nếu có primary exam khác, hệ thống chuyển sang exam tiếp
theo.

## 6.4. Today's Tasks

Home chỉ hiển thị khoảng **5 task**, sau đó:

> Xem tất cả

Task card compact:

-   Checkbox
-   Task name
-   Subject
-   Duration

Nếu có nhiều task:

``` text
High
Medium
Low
```

Task overdue phải có trạng thái rõ ràng.

## 6.5. Task completion

Hoàn thành task cần có phản hồi kết hợp:

-   Checkbox
-   Strikethrough
-   Animation
-   Feedback nhẹ
-   Haptic nếu được bật

Animation thay đổi theo context/importance.

Task cuối ngày có thể có celebration nhẹ + mascot.

Không dùng celebration quá phô trương.

## 6.6. Progress

Progress chính = phần trăm task hoàn thành.

Hiển thị cả:

-   \%
-   số task

Ví dụ:

``` text
3/5
60%
```

Progress ưu tiên dạng progress bar, compact.

## 6.7. Study Time

Không chiếm quá nhiều diện tích.

Ví dụ:

``` text
45 phút hôm nay
+12% so với hôm qua
```

Nếu chưa có dữ liệu:

> "Chưa có dữ liệu"

hoặc CTA:

> "Bắt đầu phiên học đầu tiên →"

## 6.8. Mascot

Mascot xuất hiện contextual.

Có thể xuất hiện:

-   Home
-   Empty state
-   Milestone
-   AI
-   Focus
-   Completion

Mascot:

-   Có thể nói
-   Có trạng thái
-   Có expression
-   Animation nhẹ
-   Người dùng có thể disable

Phong cách:

> **Cute anime mascot**

Nhưng không được khiến UI trở nên trẻ con.

------------------------------------------------------------------------

# 7. Task System

## 7.1. Task model

Task cơ bản:

``` text
Task
├── Title
├── Subject
├── Topic
├── Duration
├── Deadline
├── Priority
├── Status
├── Note
├── Goal
├── Subtasks
├── Recurrence
└── Study Sessions
```

## 7.2. Tạo task

Task creation = 50% user + 50% AI.

UI:

-   Manual creation là primary.
-   AI creation là secondary/contextual.

## 7.3. Subject

Subject là required field.

## 7.4. Duration

Duration có thể:

-   User nhập
-   AI estimate
-   User chỉnh lại

## 7.5. Priority

Ba mức:

-   High
-   Medium
-   Low

## 7.6. Deadline

Deadline có thể:

-   Có
-   Không có

Nếu có:

-   Ngày
-   Giờ

Deadline gần sẽ thay đổi visual status.

## 7.7. Subtasks

Cho phép subtasks.

Parent task hiển thị progress.

## 7.8. Recurring task

Cho phép recurring tasks.

Nếu bỏ lỡ recurring task:

> Giữ task ở trạng thái missed, không tự động merge sang ngày khác.

## 7.9. Undo

Sau khi complete:

> Undo trong 5 giây.

## 7.10. Reschedule

Có:

-   Quick options
-   AI suggestion

Nếu task bị reschedule quá nhiều lần:

> Cảnh báo + đề xuất AI chia nhỏ.

## 7.11. Skip

Có Skip.

Lý do:

-   Không đủ thời gian
-   Quá khó
-   Không cần thiết nữa
-   Không có tài liệu
-   Không có động lực
-   Khác

## 7.12. Task → Focus

Task có action:

> Start Focus

Một task có thể có nhiều study session.

------------------------------------------------------------------------

# 8. Add Task UX

Manual creation là primary.

AI là secondary.

Các trường chính:

-   Task name
-   Subject
-   Topic
-   Duration
-   Deadline
-   Priority
-   Note

Add Task có thể adaptive:

-   Mobile → bottom sheet/full-screen tùy context
-   Desktop → modal/side panel

Draft phải được autosave.

Validation:

-   Inline error
-   Toast/error feedback tùy context

------------------------------------------------------------------------

# 9. Goal & Exam System

## 9.1. Goal hierarchy

``` text
Exam
 ↓
Score Goal
 ↓
Study Goal
```

Có thể có nhiều goals.

Primary exam quyết định:

-   Countdown
-   AI planning

Home chỉ hiển thị primary exam.

## 9.2. Exam creation

Hỗ trợ:

-   Manual
-   Preset
-   AI

Preset có thể autofill:

-   Exam date
-   Subjects
-   Structure
-   Goal

## 9.3. Exam fields

``` text
Tên
Kỳ thi
Ngày thi
Môn
Cấu trúc
Mục tiêu điểm
```

Thông tin học tập bổ sung:

-   Trình độ hiện tại
-   Điểm gần nhất
-   Thời gian học/ngày
-   Giờ thường học

## 9.4. Target score

Target có thể dựa trên:

``` text
Current score → Target score
```

Nếu không có target:

> Hỏi người dùng.

Nếu target có vẻ không thực tế:

> Cảnh báo nhẹ, không phán xét.

## 9.5. Exam date change

Nếu ngày thi thay đổi:

> AI recalculates plan.

## 9.6. Goal progress

Có thể dựa trên:

-   Task
-   Study time
-   Score
-   Milestone

Goal type quyết định cách tính progress.

Hiển thị:

-   Graph
-   Text
-   Progress bar/ring tùy context

------------------------------------------------------------------------

# 10. AI Coach

## 10.1. Vai trò

AI =

> **Tutor + Advisor + Study Management Assistant**

AI không phải chatbot clone của ChatGPT.

UI AI phải có visual language riêng của EduPulse.

## 10.2. AI context

AI mặc định biết context học tập cần thiết:

-   Tasks
-   Completion
-   Skipped tasks
-   Rescheduled tasks
-   Study time
-   Focus sessions
-   Scores
-   Mock scores
-   Notes
-   Reflections
-   Plan history
-   AI chat history

Nhưng quyền sử dụng dữ liệu phải có controls.

## 10.3. AI capabilities

AI có thể:

-   Phân tích điểm yếu
-   Phân tích progress
-   Tạo task
-   Chia task
-   Ước lượng duration
-   Gợi ý resources
-   Tạo learning plan
-   Tối ưu schedule
-   Phân tích study efficiency
-   Tìm pattern
-   Phân tích focus
-   Điều chỉnh difficulty
-   Suggest Pomodoro
-   Nhắc deadline
-   Phân tích notes
-   Tạo quiz
-   Hỗ trợ giải bài

## 10.4. AI autonomy

Nguyên tắc:

> **AI có thể chủ động, nhưng không được tự ý thực hiện thay đổi quan
> trọng.**

Permission level:

``` text
Read
Analyze
Suggest
Create
Modify
Notify
```

Mặc định định hướng:

``` text
Read + Analyze + Suggest
```

Thay đổi quan trọng:

> Preview → Accept / Edit / Reject

## 10.5. AI recommendation

Không hiển thị recommendation liên tục.

Chỉ xuất hiện khi:

> "Đáng để nói."

Recommendation có thể:

-   Ngắn
-   Trung bình
-   Dài

Tùy context.

## 10.6. AI plan changes

Hiển thị:

``` text
Before
↓
After
```

Kèm:

-   Reason
-   Diff
-   Accept
-   Edit
-   Reject

## 10.7. AI confidence

Các insight quan trọng có:

-   Confidence
-   Evidence
-   Fact vs inference

Nếu AI suy luận nguyên nhân:

> Phải ghi rõ đó là hypothesis.

## 10.8. AI uncertainty

Khi chưa đủ dữ liệu:

> Không được đoán như sự thật.

AI phải:

-   Nói chưa đủ dữ liệu
-   Hoặc hỏi thêm
-   Hoặc verify bằng nguồn đáng tin

## 10.9. AI citations

Tùy câu trả lời:

-   Inline source
-   Source card
-   Source list

Khi dùng web:

> Ưu tiên nguồn authoritative.

## 10.10. AI feedback

Có:

-   👍
-   👎
-   Regenerate
-   Report / feedback

Feedback reason:

-   Sai kiến thức
-   Không hiểu câu hỏi
-   Giải thích khó hiểu
-   Nguồn không đáng tin
-   Quá dài
-   Quá ngắn
-   Khác

------------------------------------------------------------------------

# 11. Focus Mode

## 11.1. Philosophy

Focus phải làm người dùng cảm thấy:

> "Bây giờ chỉ cần học."

## 11.2. Focus UI

Thông tin chính:

``` text
Current Task
Timer
Progress
Pause
End Session
```

Timer là element lớn nhất.

## 11.3. Timer

Default example:

``` text
00:25:00
```

Có progress ring.

Hiển thị remaining time.

## 11.4. Session

Timer phải tiếp tục dựa trên timestamp nếu app đóng.

Khi quay lại:

> Hỏi user có thực sự học trong khoảng thời gian đó không.

## 11.5. App leaving

Nếu phát hiện người dùng thường xuyên rời app:

-   Gentle reminder
-   Break suggestion
-   Shorter session
-   Pattern analysis

Không tạo áp lực.

## 11.6. Pause

Pause button rõ ràng.

Nếu pause \>15 phút:

> Gentle reminder.

## 11.7. Break

Break tự động.

Break screen có:

-   Timer
-   Eye rest
-   Water
-   Movement

Có Skip.

## 11.8. Session completion

Record:

-   Planned time
-   Actual time
-   Task
-   Subject
-   Focus
-   Difficulty
-   Understanding
-   Mood
-   Effectiveness
-   Optional notes

## 11.9. Reflection

Reflection không xuất hiện sau mọi session.

AI quyết định khi nào đủ hữu ích.

Mood:

``` text
Emoji + 1–5
```

Focus:

``` text
Emoji + 1–5
```

Difficulty:

``` text
Easy → Hard
```

Understanding:

``` text
Not understand → Understand
```

Effectiveness:

``` text
Not effective → Very effective
```

------------------------------------------------------------------------

# 12. Study Log & Analytics

## 12.1. Study Log

Có thể xem:

-   Day
-   Week
-   Month
-   Calendar
-   All sessions

Daily summary:

-   Total time
-   Sessions
-   Tasks
-   Subject
-   Efficiency

## 12.2. Analytics

Main chart:

> Study time by day

Có comparison:

> This week vs previous week.

Ví dụ:

> "Tuần này bạn học nhiều hơn 18%."

Có thể có insight:

> "Hiệu suất học giảm trong 3 ngày gần đây."

## 12.3. Efficiency

Efficiency là composite AI-calculated metric.

Hiển thị:

``` text
Efficiency 84%
+12% vs last week
```

Có description.

Nếu:

-   8h nhưng efficiency thấp → AI phân tích.
-   2h nhưng efficiency cao → AI phân tích.

## 12.4. Focus analytics

AI có thể phát hiện:

> "Bạn thường mất tập trung sau khoảng 35 phút."

AI có thể đề xuất:

> Session 50 phút → 35 phút.

## 12.5. Best study time

AI có thể phát hiện:

-   Thời gian học tốt nhất
-   Subject có focus thấp nhất
-   Correlation giữa focus và score

Chỉ kết luận khi đủ dữ liệu.

------------------------------------------------------------------------

# 13. Calendar

Calendar là feature quan trọng nhưng secondary.

## Mobile

Ưu tiên:

> Agenda/List

Có thể có compact week navigation.

## Desktop

> Calendar + AI + Task sidebar

Calendar hiển thị:

-   Tasks
-   Study sessions
-   Primary exam
-   Important milestones
-   Deadlines

## Scheduling

Task có deadline nhưng chưa có scheduled time.

AI có thể đề xuất schedule.

Desktop hỗ trợ drag.

Khi drag:

> Xác nhận trước khi thay đổi nếu cần.

Nếu schedule vượt deadline:

> Warning + AI alternative.

## Optimize Week

Có action:

> "Optimize this week"

AI sử dụng:

-   Deadlines
-   Goals
-   Efficiency
-   Free time
-   Difficulty
-   Energy
-   Focus

Thay đổi lịch:

> Diff + reason + Accept/Edit/Reject

------------------------------------------------------------------------

# 14. Notes

Notes hỗ trợ:

-   Task-linked
-   Subject-linked
-   Standalone
-   Goal-linked
-   Study-session-linked

AI có thể:

-   Read
-   Summarize
-   Detect knowledge gaps
-   Suggest task
-   Generate quiz
-   Detect repeated notes without practice
-   Feed weakness analysis

Note features:

-   Plain text
-   Markdown
-   LaTeX
-   Code blocks
-   Images
-   Scanned documents
-   File attachments
-   Autosave
-   Offline

Search:

> Global search + semantic search

------------------------------------------------------------------------

# 15. Search

Global search phải tìm được:

-   Tasks
-   Goals
-   Exams
-   Calendar
-   Notes
-   Study sessions
-   AI conversations
-   Resources

Ưu tiên semantic search.

Không có kết quả:

> "Không tìm thấy"

-   gợi ý query khác + AI hỗ trợ khi phù hợp.

------------------------------------------------------------------------

# 16. Notifications

Notification categories:

-   Task
-   Deadline
-   Exam
-   AI
-   Goal
-   Daily summary

AI có thể tự điều chỉnh frequency.

Nếu người dùng liên tục ignore notification:

> Giảm tần suất.

Daily digest được hỗ trợ.

Notification quan trọng nhất được xác định theo urgency.

Trong Focus:

> Chặn notification không quan trọng.

Deadline/exam khẩn cấp có thể bypass.

------------------------------------------------------------------------

# 17. Profile

Profile =

> Personalization + Learning Progress Dashboard

Header:

-   Avatar
-   Name
-   Main goal
-   Countdown

Stats:

-   Study time
-   Tasks
-   Focus sessions
-   Goals
-   Score
-   Progress

Learning Profile:

-   Subject levels
-   Study preferences
-   Best study times
-   Focus patterns
-   Learning patterns
-   Weaknesses

AI có thể cập nhật inferred preferences khi đủ dữ liệu.

User có thể sửa inference.

------------------------------------------------------------------------

# 18. Settings

Settings gồm:

``` text
Account
Learning
AI
Notifications
Appearance
Privacy
Data
Accessibility
Advanced
```

Mobile:

> Grouped + nested

Desktop:

> Full-page settings

Advanced settings có:

-   AI permissions
-   Sync
-   Data
-   Developer/debug
-   Experimental features

Developer/debug không hiển thị cho user bình thường.

------------------------------------------------------------------------

# 19. Privacy & Data

## Account

Login optional.

Guest:

-   Full app
-   Không cloud sync

Account:

-   Email/password

## Sync

Hybrid sync.

States:

``` text
Offline
Syncing
Synced
```

Auto sync.

Conflict:

> Show conflict when necessary.

Task edits có thể merge tự động.

## Data export

Export:

-   JSON
-   CSV
-   Markdown
-   ZIP

Import được hỗ trợ.

## Delete

Có:

-   Delete local data
-   Delete account
-   Delete cloud data
-   Delete AI memory

Xóa quan trọng:

> Confirmation + re-auth.

Có undo window cho account deletion.

## Privacy Center

Hiển thị:

-   Data stored
-   Cloud data
-   AI access
-   Notification usage

Có controls:

-   Cloud sync
-   Data sync
-   AI
-   AI data usage

------------------------------------------------------------------------

# 20. Appearance

Themes:

-   Light
-   Dark
-   System

Dark mode dùng palette riêng.

Accent adapt theo theme.

Font size adaptive.

Reduced motion.

High contrast.

------------------------------------------------------------------------

# 21. Accessibility

Các mục đã định hướng:

-   High contrast
-   Reduced motion
-   Adaptive font
-   Desktop keyboard navigation
-   Touch targets phù hợp

**Lưu ý:** Bộ phỏng vấn hiện có một số lựa chọn accessibility còn thấp
hơn mức nên có cho sản phẩm production. Khi triển khai thực tế, nên ưu
tiên bổ sung screen-reader labels, không phụ thuộc màu đơn độc và chuẩn
touch target nhất quán.

------------------------------------------------------------------------

# 22. Responsive Strategy

## Mobile

Adaptive single-column layout.

Mobile là trải nghiệm rất quan trọng.

## Tablet

Adaptive dashboard.

## Desktop

Dashboard nhiều cột.

Desktop sử dụng sidebar.

Sidebar:

-   Học
-   Calendar
-   Goals
-   Focus
-   AI
-   Notes
-   Tôi

Có thể collapse.

Collapsed sidebar:

-   Icon
-   Tooltip
-   Avatar

## Breakpoints

Định hướng:

``` text
Mobile < 768
Tablet ≈ 768–1024
Desktop ≥ 1024
```

Desktop layout có thể mở rộng tùy viewport.

------------------------------------------------------------------------

# 23. Desktop Navigation

Desktop:

> Sidebar / navigation rail

Có collapse.

Expanded sidebar có context.

Collapsed:

> Icons + tooltip.

Không chỉ scale UI mobile lên desktop.

Nguyên tắc:

> Cùng visual language, khác layout.

------------------------------------------------------------------------

# 24. Mobile Navigation

Bottom navigation:

``` text
Học
AI
Tôi
```

Có:

-   Safe area
-   Floating/subtle effect
-   Active state
-   Icon + label

AI icon ưu tiên:

> Brain / custom intelligent assistant icon.

------------------------------------------------------------------------

# 25. Add / Quick Actions

Không dùng một FAB cố định cho mọi nơi.

FAB/action là:

> Contextual.

Add Task có thể xuất hiện:

-   Tasks header
-   Bottom sheet
-   Navigation context

Quick Add hỗ trợ natural language.

Ví dụ:

> "Mai 19h học toán hàm số 45 phút"

AI parse → preview → confirm.

------------------------------------------------------------------------

# 26. Visual Direction

Đây là một trong những phần quan trọng nhất của redesign.

## Style

> **Premium native personal tutor**

Kết hợp:

-   Premium native app
-   Student productivity
-   Friendly education
-   AI tutor

Không được quá:

-   Corporate
-   Gamified
-   Childish
-   Cluttered

## Card usage

Không lạm dụng card.

Card chỉ dùng khi có nhóm thông tin thực sự cần tách biệt.

## Radius

Adaptive theo component.

## Shadow

Medium/subtle.

## Border

Medium/subtle.

## Color

Subject colors + semantic colors.

AI accent riêng nhưng phải nằm trong design system.

------------------------------------------------------------------------

# 27. Typography

Ưu tiên:

> System font

Để tạo cảm giác native.

Typography:

-   Heading: variable/bold tùy hierarchy
-   Body: adaptive
-   Vietnamese readability là ưu tiên
-   Countdown dùng số rõ ràng, dễ quét

Spacing:

> Custom token system.

------------------------------------------------------------------------

# 28. Buttons

Primary button:

> Filled / premium contextual treatment.

Có hierarchy:

``` text
Primary
Secondary
Tertiary
```

Mobile:

> Full-width CTA ở onboarding / critical action.

Radius:

> Contextual / rounded.

------------------------------------------------------------------------

# 29. Task Component

Task card ưu tiên dạng:

> List item

Có:

-   Checkbox
-   Task name
-   Subject
-   Duration
-   Priority indicator

Priority:

> Combination of color + icon/text.

Duration:

> Text hoặc clock + text tùy context.

Checkbox:

> Custom, accessible.

Completion:

> Subtle/delightful nhưng nhanh.

------------------------------------------------------------------------

# 30. Bottom Sheets

Bottom sheet có adaptive height.

Có:

-   Drag handle
-   Contextual height
-   Expand to full screen

Dùng cho:

-   Task detail
-   Add task
-   Contextual actions
-   AI actions

------------------------------------------------------------------------

# 31. Mascot System

Mascot style:

> Cute anime

Mascot không phải decoration liên tục.

Context:

-   Empty state
-   Completion
-   Focus
-   AI
-   Milestone
-   Home

Mascot có:

-   Expression
-   Idle animation
-   Context reaction
-   Reduced-motion variant
-   Disable option

Dark mode:

> Có thể giữ cùng mascot variant, ưu tiên không làm thay đổi nhận diện.

------------------------------------------------------------------------

# 32. Motion System

Motion:

> Smooth + contextual.

Không animate mọi thứ.

Ưu tiên:

-   Task completion
-   Navigation
-   AI streaming
-   Mascot
-   Countdown
-   Focus state

Reduced motion phải giảm animation.

------------------------------------------------------------------------

# 33. Error & Empty States

## Empty Task

> "Hôm nay chưa có kế hoạch."

Actions:

-   Tạo kế hoạch
-   AI suggestion

## Empty Calendar

> Không có lịch.

Actions:

-   Create
-   AI schedule

## Empty Notes

> Create Note

## Empty Study Log

> Chưa có dữ liệu

-   Start Focus

## Empty AI

> Suggested prompts + personalized entry point

## Error

Luôn ưu tiên:

``` text
Điều gì xảy ra?
↓
Tôi có thể làm gì?
↓
Retry / Continue
```

Không hiển thị technical error mặc định.

------------------------------------------------------------------------

# 34. Offline-first

Offline là capability quan trọng.

Offline UI:

> Small "Offline" indicator.

Offline vẫn dùng được:

-   Tasks
-   Calendar local data
-   Notes
-   Focus
-   Study log
-   Core navigation

AI khi offline:

> Unavailable + offline functionality continues.

Khi online:

> Sync + AI xử lý phần pending nếu phù hợp.

------------------------------------------------------------------------

# 35. Reliability

## Sync failure

``` text
Offline state
+
Retry
+
Keep local data
```

## AI API failure

``` text
Retry
↓
Fallback model
↓
Offline functions
```

## Long AI processing

``` text
Streaming
+
Status
```

## Task creation failure

``` text
Error
+
Retry
+
Preserve draft
```

## Offline notes

``` text
Autosave local
+
Draft recovery
```

------------------------------------------------------------------------

# 36. Behavioral Intelligence

AI phải tìm pattern thay vì chỉ phản hồi từng event.

Ví dụ:

### Completion pattern

> Người dùng thường hoàn thành 60% kế hoạch.

AI:

> Đề xuất giảm workload + hỏi xác nhận.

### Focus pattern

> Người dùng mất tập trung sau \~35 phút.

AI:

> Đề xuất session ngắn hơn.

### Deadline pattern

> Người dùng thường miss deadline.

AI:

> Giảm load + chia nhỏ + điều chỉnh schedule.

### Subject avoidance

> Người dùng liên tục bỏ Toán.

AI:

> Phân tích nguyên nhân giả thuyết + đề xuất intervention.

Không được biến hypothesis thành fact.

------------------------------------------------------------------------

# 37. Personalization Engine

AI có thể học:

-   Best study time
-   Preferred session length
-   Subject difficulty
-   Study habits
-   Focus patterns
-   Avoidance patterns
-   Learning efficiency
-   Score correlation

Learning Profile được cập nhật khi:

> Có đủ dữ liệu.

AI phải cho phép sửa inference.

------------------------------------------------------------------------

# 38. Real Student Rhythm

EduPulse phải hỗ trợ lịch học thực tế.

Ví dụ:

``` text
07:00 — Học trên trường
12:00 — Xem lại bài
18:30 — Toán hàm số
19:00 — Lý con quay hồi chuyển
20:00 — Anh Writing
22:00 — Học online
```

App không được giả định rằng học sinh có một khoảng thời gian trống dài
và cố định.

AI phải thích nghi với:

-   School
-   Online class
-   Busy time
-   Free time
-   Energy
-   Focus
-   Deadline

------------------------------------------------------------------------

# 39. Exam Mode

## 7 ngày trước thi

Có thể chuyển sang:

> Revision mode

Ưu tiên:

-   Weakness
-   High-impact topics
-   Review
-   Reduced unnecessary workload

## 24 giờ trước thi

Ưu tiên:

-   Revision trọng tâm
-   Checklist
-   Chuẩn bị
-   Nghỉ ngơi hợp lý

## Exam Day

Home có thể chuyển thành:

``` text
Exam information
+
Checklist
+
Countdown/status
+
Quick AI support
```

Không hiển thị quá nhiều task.

## Sau thi

Exam chuyển thành:

> Completed / Waiting result

Giữ toàn bộ history.

Nếu có điểm:

-   Update goal
-   Compare target
-   Analyze
-   Suggest next step

------------------------------------------------------------------------

# 40. Post-exam

Nếu đạt target:

-   Celebration nhẹ
-   Mascot
-   Process analysis
-   Hỏi trước khi tạo goal mới

Nếu chưa đạt:

-   Không dùng ngôn ngữ tiêu cực
-   Phân tích khoảng cách
-   Đề xuất cải thiện
-   Có thể tạo goal mới

Nếu còn exam khác:

> Tự chuyển primary exam + thông báo.

Nếu không còn:

> Learning dashboard + hỏi mục tiêu tiếp theo.

------------------------------------------------------------------------

# 41. Mock Score

Mock score lưu:

-   Overall
-   Subject
-   Topic nếu có
-   Date
-   Target

AI phân tích:

-   Subject
-   Topic
-   Error type
-   Study time
-   Efficiency

Biểu đồ:

-   Theo thời gian
-   Theo môn
-   So với target

Nếu điểm giảm nhiều lần:

> Analyze + propose adjustment.

Nếu tăng:

> Analyze what contributed to improvement.

------------------------------------------------------------------------

# 42. Migration

Khi update data model:

> Auto migration + backup.

Nếu migration lỗi:

``` text
Rollback
+
Restore backup
+
Notify user
```

Không để mất dữ liệu.

------------------------------------------------------------------------

# 43. UX Principles

### Principle 1 --- Fast

Người dùng phải thao tác nhanh.

### Principle 2 --- Easy

Không bắt người dùng cấu hình quá nhiều.

### Principle 3 --- Personal

App phải dần hiểu người dùng.

### Principle 4 --- Adaptive

Kế hoạch thay đổi theo thực tế.

### Principle 5 --- Calm

Không tạo áp lực không cần thiết.

### Principle 6 --- Native

PWA/mobile phải có cảm giác như app native cao cấp.

### Principle 7 --- Useful

Mỗi component phải giúp người dùng hành động hoặc hiểu tình trạng học.

------------------------------------------------------------------------

# 44. Gamification

Gamification không phải trọng tâm.

Có thể giữ:

-   Achievement
-   Subtle feedback
-   Mascot reactions

Không ưu tiên:

-   Streak
-   XP
-   Level
-   Excessive rewards
-   Over-the-top celebration

Đặc biệt:

> **Không dùng Streak làm cơ chế ép người dùng.**

------------------------------------------------------------------------

# 45. Core Screens

Bộ màn hình redesign tối thiểu:

``` text
01 Splash
02 Onboarding
03 Home
04 Task List
05 Task Detail
06 Add Task
07 Goal List
08 Goal Detail
09 Exam Detail
10 Calendar
11 Focus
12 Study Reflection
13 Study Log
14 Analytics
15 AI Coach
16 AI Plan Preview
17 AI Diff
18 Notes
19 Note Detail
20 Search
21 Profile
22 Learning Profile
23 Settings
24 AI Permissions
25 Privacy Center
26 Data Management
27 Appearance
28 Accessibility
29 Notifications
30 Exam Day
31 Post-exam
32 Empty States
33 Error States
34 Offline States
```

------------------------------------------------------------------------

# 46. Onboarding

Onboarding khoảng:

> 3--5 phút

Adaptive.

Thu thập:

-   Name
-   Exam
-   Exam date
-   Target score
-   Subjects
-   Study time/day
-   Current level
-   Latest score
-   Usual study hours

AI hỗ trợ onboarding nhưng không thay người dùng quyết định.

Kết thúc:

> AI Plan Preview + Countdown

User xác nhận trước khi tạo tasks.

------------------------------------------------------------------------

# 47. Daily Experience

Một ngày lý tưởng:

``` text
Open EduPulse
↓
Countdown
↓
Today’s Tasks
↓
Chọn task
↓
Start Focus
↓
Học
↓
Complete
↓
AI/Reflection khi cần
↓
Đóng app
```

Đây là flow quan trọng nhất cần tối ưu.

------------------------------------------------------------------------

# 48. Design System Components

Component library nên bao phủ:

-   Button
-   Input
-   Select
-   Checkbox
-   Task
-   Goal
-   Exam
-   Calendar
-   AI message
-   AI recommendation
-   AI proposal
-   Progress
-   Countdown
-   Study session
-   Mascot
-   Modal
-   Bottom sheet
-   Toast
-   Notification
-   Empty state
-   Error state
-   Offline state
-   Search
-   Tabs
-   Navigation
-   Charts

Tất cả component cần:

-   State
-   Size
-   Theme
-   Interaction
-   Disabled
-   Loading
-   Error khi cần

Dark mode cần variant riêng.

------------------------------------------------------------------------

# 49. Design Tokens

Phải tạo design token system.

Bao gồm:

``` text
Color
Typography
Spacing
Radius
Shadow
Motion
Opacity
Icon size
Component height
Breakpoint
```

Không hard-code visual values tùy tiện trong từng màn hình.

------------------------------------------------------------------------

# 50. Figma Structure

Định hướng Figma:

``` text
00 — Cover / Documentation
01 — Foundations
02 — Colors
03 — Typography
04 — Icons
05 — Components
06 — Patterns
07 — Mobile
08 — Tablet
09 — Desktop
10 — Dark Mode
11 — Prototype
12 — Dev Handoff
```

Component-first.

Các component quan trọng phải có variants.

------------------------------------------------------------------------

# 51. Developer Handoff

Mỗi màn hình cần mô tả:

-   Layout
-   Dimensions
-   Spacing
-   Typography
-   Colors
-   States
-   Interaction
-   Animation
-   Responsive behavior
-   Accessibility
-   Error handling
-   Offline behavior

Không chỉ giao screenshot.

## Flutter-first

Kiến trúc triển khai:

> **Flutter-first, PWA responsive second**

Nhưng visual language phải nhất quán trên mobile/PWA/desktop.

------------------------------------------------------------------------

# 52. Navigation Behavior

## Mobile

``` text
Bottom Navigation
Học | AI | Tôi
```

## Desktop

``` text
Sidebar
├── Học
├── Calendar
├── Goals
├── Focus
├── AI
├── Notes
└── Tôi
```

Sidebar collapse.

Mobile hỗ trợ:

-   iOS safe area
-   Swipe back
-   Pull-to-refresh
-   Context menu
-   Long press

------------------------------------------------------------------------

# 53. iOS/PWA Native Feel

Mục tiêu:

> **Gần như native.**

Cần chú ý:

-   Safe areas
-   Navigation transition
-   Haptic
-   Touch interaction
-   Bottom sheet
-   Gesture
-   Typography
-   Status bar
-   Keyboard behavior
-   Pull-to-refresh
-   Swipe back
-   Edge-to-edge phù hợp context

Không làm PWA giống một website responsive thông thường.

------------------------------------------------------------------------

# 54. Interaction Feedback

Haptic:

-   Task complete
-   Timer end
-   Important action

Sound:

-   Optional

Animation:

-   Contextual

Không biến interaction thành animation showcase.

------------------------------------------------------------------------

# 55. Performance

Nếu phải lựa chọn:

> **Tốc độ \> visual effect.**

Không hy sinh:

-   App launch
-   Navigation
-   Task completion
-   Focus start
-   AI interaction

chỉ để có animation đẹp.

------------------------------------------------------------------------

# 56. Core Product Priorities

Theo toàn bộ interview, thứ tự ưu tiên nên là:

### P0 --- Core

-   Home
-   Today Tasks
-   Task management
-   Focus
-   Goal/Exam
-   Countdown
-   Study Log
-   AI Coach
-   Offline-first
-   Sync
-   Native mobile UX

### P1 --- Intelligence

-   Weakness analysis
-   Personalized planning
-   Adaptive workload
-   Efficiency analysis
-   Deadline risk
-   Focus pattern
-   Learning Profile

### P2 --- Organization

-   Calendar
-   Notes
-   Search
-   Resources
-   External calendar integration

### P3 --- Secondary

-   Achievement
-   Mascot expansion
-   Advanced analytics
-   Experimental AI features

------------------------------------------------------------------------

# 57. Những thứ không nên ưu tiên

Không nên dùng nguồn lực lớn cho:

-   Streak
-   XP-heavy gamification
-   Level-heavy system
-   Excessive animation
-   Social features ngoài leaderboard nếu có
-   UI quá nhiều card
-   AI tự động thay đổi kế hoạch quan trọng
-   Notification spam
-   Dashboard quá nhiều metrics

------------------------------------------------------------------------

# 58. Conflict / Clarification Register

Một số câu trả lời trong interview có mâu thuẫn hoặc chưa đủ rõ. Khi
implement **không nên tự đoán**.

## 58.1. AI data usage

Có hai hướng cùng xuất hiện:

-   AI được phép đọc gần như toàn bộ dữ liệu.
-   User có quyền kiểm soát dữ liệu AI.

Định hướng an toàn cho implementation:

> AI có thể access dữ liệu theo permission, nhưng phải có Privacy Center
> và per-data controls.

## 58.2. Local-only / Cloud

Có cả:

-   Có thể tắt cloud sync.
-   Không chọn local-only.

Đề xuất kiến trúc:

> Cho phép offline/local data ngay cả khi cloud sync tắt, nhưng cần xác
> nhận lại UX wording.

## 58.3. AI modify/delete

Có:

-   AI có quyền Create/Modify.
-   AI không được tự ý thay đổi quan trọng.

Định nghĩa:

> Important changes = luôn yêu cầu confirmation.

## 58.4. Notes folders/tags

Có câu trả lời về folders và tags chưa hoàn toàn nhất quán.

Cần quyết định cuối:

``` text
Folders
Tags
Hoặc cả hai
```

## 58.5. Note editor

Câu trả lời ban đầu chưa xác định rõ editor format.

Định hướng hiện tại:

> Markdown-capable editor + toolbar + rich interactions.

## 58.6. Accessibility

Một số câu trả lời ban đầu ưu tiên thấp:

-   Screen reader
-   Dynamic Type
-   Color-only state

Nhưng production implementation nên nâng lên chuẩn accessibility thực
tế.

------------------------------------------------------------------------

# 59. Product Success Criteria

EduPulse redesign được xem là đạt yêu cầu khi:

### Người dùng mới

Có thể:

``` text
Onboarding
→ thấy Countdown
→ thấy Today’s Tasks
→ Start Focus
```

mà không cần hướng dẫn dài.

### Người dùng cũ

Có thể:

``` text
Mở app
→ biết việc quan trọng nhất
→ bắt đầu học
```

trong vài giây.

### AI

AI phải:

-   Hiểu context
-   Không hỏi lại dữ liệu đã có
-   Không tự ý thay đổi quan trọng
-   Giải thích recommendation khi cần
-   Phân biệt fact/inference
-   Dùng dữ liệu thực tế để cá nhân hóa

### Focus

Người dùng có thể bắt đầu một phiên học với số thao tác tối thiểu.

### Offline

Mất mạng không được làm mất dữ liệu học.

### Native feel

Mobile/PWA phải cảm giác giống app native hơn website responsive.

------------------------------------------------------------------------

# 60. Final UX Direction

EduPulse nên được thiết kế như:

> **Một trợ lý học tập cá nhân có cảm giác như một app native cao cấp:
> nhanh, tiện, dễ nhìn, thân thiện và cá nhân hóa.**

Không cố làm người dùng học nhiều hơn bằng áp lực.

Thay vào đó:

``` text
Hiểu mục tiêu
↓
Hiểu lịch thực tế
↓
Hiểu năng lực
↓
Hiểu hành vi
↓
Đề xuất việc phù hợp
↓
Giúp bắt đầu
↓
Theo dõi kết quả
↓
Học từ dữ liệu
↓
Điều chỉnh
```

### Câu mô tả UX cốt lõi

> **"Mình không học nhiều hơn, nhưng mình học đúng cách hơn."**

### Câu mô tả sản phẩm

> **"Bạn đặt mục tiêu, EduPulse giúp biến nó thành hành động."**

### Cảm giác cuối cùng cần đạt

> **Nhanh · Tiện · Thân thiện · Dễ nhìn · Cá nhân hóa · Native · Thông
> minh nhưng không áp đặt**

------------------------------------------------------------------------

# 61. Implementation Priority

## Phase 1 --- Foundation

-   Flutter architecture
-   Responsive system
-   Design tokens
-   Theme
-   Navigation
-   Local data layer
-   Sync state
-   Component library

## Phase 2 --- Core Student Loop

-   Onboarding
-   Home
-   Tasks
-   Task Detail
-   Add Task
-   Focus
-   Study Session
-   Reflection
-   Study Log

## Phase 3 --- Goals

-   Exam
-   Goal
-   Target score
-   Milestones
-   Countdown
-   Progress

## Phase 4 --- AI

-   AI Coach
-   Context engine
-   Weakness analysis
-   AI recommendation
-   AI task generation
-   AI plan
-   AI diff
-   Permission system

## Phase 5 --- Organization

-   Calendar
-   Notes
-   Search
-   Resources
-   External calendar

## Phase 6 --- Advanced

-   Analytics
-   Learning Profile
-   Exam Day
-   Post-exam
-   Advanced privacy
-   Migration
-   Advanced AI personalization

------------------------------------------------------------------------

# 62. Final Design Brief

**EduPulse is not a productivity app that happens to contain AI.**

Nó nên được cảm nhận như:

> **Một gia sư cá nhân luôn biết hôm nay người học cần làm gì, hiểu khi
> nào kế hoạch đang quá nặng, nhận ra cách học nào đang hiệu quả và chỉ
> xuất hiện khi thực sự có ích.**

Visual language:

> **Premium native + friendly education + personal tutor**

UX language:

> **Fast + simple + contextual + adaptive**

AI philosophy:

> **Proactive but controlled**

Learning philosophy:

> **Quality of learning \> quantity of learning**

Product philosophy:

> **Goal → Plan → Action → Focus → Reflection → Adaptation**

Và toàn bộ sản phẩm phải quay trở lại một câu hỏi duy nhất:

> **"Ngay lúc này, điều gì giúp học sinh học tốt hơn?"**
