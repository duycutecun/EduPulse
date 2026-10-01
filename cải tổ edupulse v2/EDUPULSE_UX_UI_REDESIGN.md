# EduPulse — UX/UI Redesign Implementation Specification

> **Version:** 1.0  
> **Date:** 2026-10-01  
> **Product:** EduPulse  
> **Repository:** `duycutecun/EduPulse`  
> **Deployment:** `https://edu-pulse-five-gamma.vercel.app/`

---

## 1. Product direction

### 1.1 Product definition

EduPulse is a **personal study assistant for exam preparation**.

Its job is not to become a social network, productivity suite, or game. Its primary purpose is to help a student:

1. know what to study,
2. start studying quickly,
3. finish planned work,
4. understand progress,
5. adjust the next plan when reality changes.

### 1.2 Core product loop

```text
PLAN
  ↓
TODAY'S TASKS
  ↓
START STUDY
  ↓
STUDY SESSION
  ↓
COMPLETE / NOT COMPLETE
  ↓
SHORT REVIEW
  ↓
PROGRESS
  ↓
AI ADJUSTMENT
  ↓
NEXT PLAN
```

### 1.3 Primary UX principle

Every major screen must answer one question clearly.

| Screen | Primary question |
|---|---|
| Today | What should I study now? |
| Study | What am I studying and how do I stay focused? |
| AI | How can EduPulse help me right now? |
| Progress | Am I actually improving? |
| Exam | What am I preparing for? |
| Settings/Profile | How does EduPulse work for me? |

Do not allow secondary information to visually compete with the primary action.

---

# 2. Redesign goals

## 2.1 Main goals

- Make **Today's Tasks** the center of the product.
- Reduce cognitive load.
- Make starting a study session possible in one obvious action.
- Turn AI from a standalone chatbot into an assistant embedded in the study workflow.
- Keep countdown as useful context, not the main action.
- Keep progress useful for reflection rather than decoration.
- Reduce game mechanics.
- Preserve useful existing business logic where possible.
- Maintain offline-first behavior and existing data compatibility.
- Work well on mobile/PWA and desktop web.

## 2.2 Non-goals

This redesign is **not**:

- a complete rewrite of the backend,
- a replacement for existing AI providers,
- a new gamification system,
- a social/community feature,
- a visual-only skin over the current architecture.

The implementation should prioritize **UX restructuring over unnecessary backend changes**.

---

# 3. Feature disposition

## 3.1 Keep

| Feature | Status | Notes |
|---|---|---|
| Today's Tasks | KEEP / CORE | Main product surface |
| Task creation/edit/delete | KEEP / CORE | Must become consistent |
| Task completion | KEEP / CORE | Primary interaction |
| Reschedule | KEEP / CORE | Essential for real-life study |
| Countdown | KEEP | Contextual |
| Exam management | KEEP | Supports planning |
| AI Coach | KEEP / CORE | Reframe as contextual assistant |
| AI Study Plan | KEEP / CORE | Feeds the task system |
| Pomodoro / Focus | KEEP | Execution tool |
| Study session tracking | KEEP | Lightweight |
| Study log | KEEP | Minimal post-session feedback |
| Progress | KEEP | Reflection |
| AI weakness analysis | KEEP | Secondary insight |
| Offline-first | KEEP | Preserve |
| Supabase sync | KEEP | Preserve |
| Multiple AI providers | KEEP INTERNALLY | Hide complexity from normal users |
| Quiz from image | KEEP / SECONDARY | Do not place in main flow |
| Web search | KEEP INTERNALLY | AI decides when useful |

## 3.2 Simplify / modify

| Feature | Change |
|---|---|
| Home dashboard | Rebuild around Today's Tasks |
| Countdown card | Smaller, contextual |
| AI Coach | Contextual assistant, not only chat |
| AI Plan | Shorter flow; one-tap application |
| Pomodoro | Launch directly from a task |
| Study log | Fewer required inputs |
| Progress | Separate daily/weekly/long-term information |
| Exam screen | One primary exam first; additional exams secondary |
| Mascot | Emotional companion, not a major dashboard module |
| XP | De-emphasize |
| Level | De-emphasize |
| Streak | Remove from primary UI; optionally keep data compatibility |
| Notifications | Action-oriented, not noisy |
| Model selection | Hide under advanced settings |

## 3.3 Hide from core UX

- XP counter
- Level
- Streak counter
- Mascot EXP
- Costume/unlock mechanics
- Bốc Quẻ / random reward
- Streak-saving bùa
- AI model selector
- Technical AI settings
- Detailed AI provider information

These can remain in code/data if removing them would create unnecessary migration work, but they should not be part of the primary UX.

## 3.4 Remove from core product

If product simplification is required, remove or disable:

- reward mechanics unrelated to study progress,
- repeated gamification prompts,
- decorative flows that interrupt study,
- duplicate planning surfaces that create a second task system.

---

# 4. Navigation

## 4.1 Recommended primary navigation

### Mobile

```text
┌─────────────────────────────┐
│                             │
│         Screen content      │
│                             │
│                             │
├─────────────────────────────┤
│  Hôm nay   AI   Tiến độ   Tôi│
└─────────────────────────────┘
```

Primary navigation:

1. **Hôm nay**
2. **AI**
3. **Tiến độ**
4. **Tôi**

### Desktop

Use a left sidebar:

```text
┌──────────────┬──────────────────────────────┐
│              │                              │
│ EduPulse     │          Content             │
│              │                              │
│ Hôm nay      │                              │
│ AI           │                              │
│ Tiến độ      │                              │
│ Tôi          │                              │
│              │                              │
│              │                              │
│ Kỳ thi chính│                              │
└──────────────┴──────────────────────────────┘
```

## 4.2 Navigation rules

- Never put more than 4 primary destinations in mobile bottom navigation.
- Exam management is secondary to Today.
- Focus mode is launched from a task, not treated as a competing primary destination.
- Settings are under Tôi.
- AI remains reachable globally but should also appear contextually from tasks.

---

# 5. Screen specification

# 5.1 Today / Home

## Purpose

Answer:

> “Hôm nay tôi cần làm gì?”

## Structure

```text
Greeting

Exam context
"Còn 82 ngày"

Today's progress
"2/5 nhiệm vụ · 1h20m"

TODAY'S TASKS
┌───────────────────────────┐
│ ○ Toán — Hàm số           │
│   45 phút                 │
│                           │
│       [Bắt đầu học]       │
└───────────────────────────┘

┌───────────────────────────┐
│ ○ Vật lý — Con quay       │
│   30 phút                 │
└───────────────────────────┘

┌───────────────────────────┐
│ ○ Anh — Writing           │
│   40 phút                 │
└───────────────────────────┘

AI suggestion
"Bạn nên bắt đầu bằng Toán..."
```

## Required actions

- Start task
- Complete task
- Edit task
- Reschedule task
- Add task
- Ask AI for recommendation

## Secondary information

- Countdown
- daily study time
- progress
- mascot

Do not let secondary information push the first task far below the fold.

---

# 5.2 Task detail

## Purpose

Show enough information to make the next action obvious.

```text
← Back

Hàm số

Môn
Toán

Chủ đề
Hàm số

Thời lượng
45 phút

Deadline
20:00

[ BẮT ĐẦU HỌC ]

[ Chỉnh sửa ]
[ Dời lịch ]
[ Xóa ]
```

## Rules

- Primary CTA must be Start Study.
- Delete is destructive and visually secondary.
- Reschedule must not require recreating the task.
- Editing must preserve task ID and completion history.

---

# 5.3 Create task

Required fields:

- Task name
- Subject
- Topic
- Expected duration

Optional:

- Deadline
- Priority
- Notes

Do not require unnecessary fields.

Primary action:

**Tạo nhiệm vụ**

After creation:

```text
✓ Đã thêm vào hôm nay
```

Offer:

- Start now
- Continue planning

---

# 5.4 Edit task

Use the same form structure as Create Task.

Do not create a separate visual language for editing.

Changes must preserve:

- task identity,
- study history,
- completion status,
- associated exam/subject where applicable.

---

# 5.5 Reschedule

Reschedule should be a lightweight action.

Example:

```text
Dời nhiệm vụ

Hôm nay
Ngày mai
Cuối tuần
Chọn ngày

[ Xác nhận ]
```

If AI detects repeated rescheduling:

```text
Bạn đã dời nhiệm vụ này 3 lần.

Có thể giảm thời lượng hoặc chia nhỏ nhiệm vụ?

[ Giảm thời lượng ]
[ Chia nhỏ ]
[ Giữ nguyên ]
```

AI must suggest, not silently modify.

---

# 5.6 Study Mode

This is a distraction-free screen.

```text
←                      ⋯

Toán
Hàm số

        34:12

     [ Pause ]

────────────────

Tập trung nhé.

[ Hoàn thành ]
```

## Rules

- Hide primary navigation.
- Hide XP/level/streak.
- Avoid unnecessary animations.
- Keep screen readable at a glance.
- Support timer pause/resume.
- Preserve session if app is backgrounded.
- Allow completion without requiring a timer to reach zero.

## If Pomodoro is enabled

Timer belongs to the current task.

Do not make users select the task again.

---

# 5.7 Session completion

After a session:

```text
✓ Hoàn thành

45 phút học Toán

Bạn cảm thấy thế nào?

😫   😐   🙂   😄   🔥

[ Xong ]
```

Optional secondary feedback:

- Concentration
- Difficulty
- Understanding
- Mood
- Effectiveness

Only one short screen should be shown by default.

Do not force a long questionnaire.

---

# 5.8 AI

## AI home

The AI screen should not look like a generic chatbot.

Start with contextual actions:

```text
AI Coach

Bạn cần gì?

[ Tôi nên học gì? ]
[ Giải thích bài này ]
[ Lập kế hoạch ]
[ Phân tích điểm yếu ]

──────────────

Chat
[ Hỏi EduPulse... ]
```

## Contextual entry points

From a task:

```text
Không hiểu bài?
[ Hỏi AI ]
```

From progress:

```text
Môn này đang chậm hơn kế hoạch.
[ Hỏi AI cách cải thiện ]
```

From Today:

```text
Chưa biết học gì?
[ Để AI đề xuất ]
```

---

# 5.9 AI behavior

## Core principle

AI should **reduce work**, not create another workload.

## AI can

- recommend what to study,
- create tasks,
- edit tasks after user approval,
- delete tasks after user approval,
- reschedule tasks after user approval,
- explain concepts,
- analyze weaknesses,
- summarize study history,
- create a study plan,
- suggest reducing task scope.

## AI must ask when

- deleting an existing task,
- making a significant schedule change,
- changing a user's stated goal,
- applying a plan that replaces existing tasks,
- modifying multiple tasks.

## AI may act directly when

- generating a recommendation,
- summarizing progress,
- explaining a concept,
- drafting a plan before approval.

## Confirmation pattern

```text
AI đề xuất:

Dời Toán từ 20:00 → 20:30
và giảm từ 60 → 45 phút.

[ Áp dụng ]
[ Chỉnh sửa ]
[ Hủy ]
```

Do not silently mutate user plans.

---

# 5.10 AI answer feedback

Use the existing reason set:

- Sai kiến thức
- Không hiểu câu hỏi
- Giải thích khó hiểu
- Nguồn không đáng tin
- Quá dài
- Quá ngắn
- Khác

Keep feedback optional and compact.

Do not interrupt every answer with a large feedback form.

---

# 5.11 AI model/provider settings

Normal users should not need to understand:

- Gemini
- OpenRouter
- model names
- temperature
- provider details.

Put advanced controls under:

```text
Tôi
→ Cài đặt
→ AI nâng cao
```

Default behavior should automatically choose the configured provider/model.

---

# 5.12 Progress

## Main purpose

Answer:

> “Tôi có thực sự tiến bộ không?”

Structure:

```text
Tiến độ

Hôm nay
2/5 nhiệm vụ
1h20m

Tuần này
8h40m
24/30 nhiệm vụ

Môn học

Toán       ↑
Vật lý     →
Tiếng Anh  ↑

[ Xem chi tiết ]
```

## Detail

Show:

- study time,
- task completion,
- subject distribution,
- consistency,
- goal progress,
- recent performance.

Avoid turning Progress into a dashboard full of unrelated charts.

---

# 5.13 Exam / Goals

## Main exam

```text
Kỳ thi chính

THPTQG 2027

Còn 82 ngày

Ngày thi
...

Mục tiêu

Toán     9.0
Lý       9.0
Hóa      9.0
```

Actions:

- Edit exam
- Edit target
- Manage subjects
- View exam information

Additional exams should be secondary:

```text
+ Thêm kỳ thi
```

Do not force users to manage multiple exams if they only have one.

---

# 5.14 Profile / Tôi

Keep it practical.

```text
Tôi

Tên
...

Kỳ thi chính
...

Mục tiêu
...

Giờ thường học
...

Cài đặt
- Thông báo
- Âm thanh
- Rung
- Giao diện
- AI nâng cao
- Đồng bộ dữ liệu
```

Gamification should not dominate this screen.

---

# 6. Task data model / state model

A task should have one authoritative lifecycle.

```text
created
   ↓
scheduled
   ↓
started
   ↓
completed
```

Alternative:

```text
scheduled
   ↓
not_completed
   ↓
rescheduled
   ↓
scheduled
```

## Required task fields

```text
id
title
subject
topic
expectedDuration
deadline
scheduledDate
status
createdAt
updatedAt
```

Optional:

```text
priority
notes
examId
aiGenerated
```

## Rules

- AI-generated tasks and manually created tasks use the same task model.
- Do not create a separate “AI task” entity unless technically required.
- A task must have one source of truth.
- Study sessions reference task ID.
- Progress is calculated from task/session data, not duplicated manually.

---

# 7. Daily workflow

## First open

```text
Open app
↓
Today
↓
See today's tasks
↓
Choose first task
↓
Start
```

## Returning user

If an unfinished session exists:

```text
Bạn đang học:
Hàm số

[ Tiếp tục ]
```

Do not force the user through Home again.

## After completion

```text
Complete
↓
Short feedback
↓
Next recommended task
```

Example:

```text
✓ Toán hoàn thành

Tiếp theo:
Vật lý — 30 phút

[ Bắt đầu ]
[ Nghỉ một chút ]
```

---

# 8. AI planning workflow

## User entry

```text
[ Lập kế hoạch học ]
```

## Minimal input

Use existing profile/exam/task data whenever possible.

Ask only what is missing:

- available study time,
- planning period if needed,
- constraints if needed.

## AI output

```text
Kế hoạch hôm nay

1. Toán — Hàm số
   45 phút

2. Vật lý — Dao động
   40 phút

3. Anh — Writing
   30 phút

Tổng: 1h55m

[ Áp dụng ]
[ Chỉnh sửa ]
```

## Important

Applying a plan must create/update normal Tasks.

It must not create a separate planning universe.

---

# 9. Responsive specification

## 9.1 Breakpoints

Use responsive layout based on available width rather than device-name assumptions.

Recommended starting points:

```text
< 600px       Mobile
600–1023px    Tablet / narrow web
≥ 1024px      Desktop
≥ 1440px      Wide desktop
```

Adjust according to existing Flutter layout architecture.

## 9.2 Mobile

Priorities:

1. Today's task
2. Start Study CTA
3. Countdown context
4. AI recommendation
5. secondary information

Rules:

- Bottom navigation.
- Minimum comfortable touch target around 44×44 logical pixels.
- Avoid dense tables.
- Use cards only when cards improve grouping.
- Avoid horizontal scrolling for primary content.
- Keep primary CTA within thumb reach where practical.

## 9.3 Tablet

- Use two-column layout where useful.
- Keep navigation compact.
- Do not simply stretch mobile cards.

## 9.4 Desktop

Use:

- sidebar,
- wider content column,
- optional secondary information column.

Example:

```text
┌─────────────┬───────────────────────┬───────────────┐
│ Navigation  │ Today's Tasks         │ AI / Summary  │
│             │                       │               │
│             │ task                  │ progress      │
│             │ task                  │ suggestion    │
│             │ task                  │               │
└─────────────┴───────────────────────┴───────────────┘
```

Maximum content width should be controlled to avoid excessive line length.

---

# 10. Visual system

## 10.1 Hierarchy

Priority order:

```text
Action
↓
Task
↓
Context
↓
Information
↓
Decoration
```

## 10.2 Typography

Use a small number of text styles.

Suggested semantic hierarchy:

- Display
- Heading
- Section title
- Body
- Secondary
- Caption

Avoid using font size alone to create hierarchy.

## 10.3 Color

Use semantic colors:

```text
Primary
Background
Surface
Text
Secondary text
Success
Warning
Error
Info
```

Do not assign a different bright color to every feature.

## 10.4 Cards

Cards should represent meaningful groups.

Avoid:

```text
Card inside card inside card
```

Use spacing and section headers instead when possible.

---

# 11. Empty states

Every empty state must answer:

1. What is missing?
2. Why does it matter?
3. What can I do next?

## No tasks

```text
Hôm nay chưa có nhiệm vụ.

Tạo kế hoạch để biết mình nên học gì.

[ AI lập kế hoạch ]
[ + Thêm nhiệm vụ ]
```

## No exam

```text
Bạn chưa có kỳ thi mục tiêu.

Thêm kỳ thi để EduPulse
có thể lập kế hoạch phù hợp.

[ Thêm kỳ thi ]
```

## No study history

```text
Chưa có phiên học nào.

Bắt đầu phiên đầu tiên hôm nay.

[ Bắt đầu học ]
```

## No progress

Never display a blank chart.

Explain what data will appear after studying.

---

# 12. Error states

## Network error

```text
Không thể đồng bộ ngay lúc này.

Dữ liệu của bạn vẫn được lưu trên thiết bị.

[ Thử lại ]
```

Do not block study if offline operation is supported.

## AI error

```text
AI đang không phản hồi.

Bạn vẫn có thể tiếp tục học hoặc thử lại sau.

[ Thử lại ]
[ Tiếp tục tự học ]
```

Do not erase user input.

## Sync conflict

If applicable:

```text
Có thay đổi mới trên thiết bị khác.

[ Giữ bản hiện tại ]
[ Xem thay đổi ]
```

Do not silently overwrite user data.

## Timer/session error

A study session should recover from:

- app backgrounding,
- temporary browser suspension,
- refresh,
- network loss.

---

# 13. Loading states

Avoid full-screen spinners whenever possible.

Use skeletons for:

- task list,
- progress,
- AI response.

For AI:

```text
AI đang suy nghĩ...
```

Streaming response is preferred where supported.

---

# 14. Notifications

Notifications should be useful, not nagging.

Good:

> “Bạn có phiên Toán lúc 19:00.”

Good:

> “Bạn còn 1 nhiệm vụ hôm nay.”

Avoid:

> “Bạn chưa giữ streak!”

Avoid shame-based notifications.

If the user repeatedly ignores a schedule, AI may suggest adjusting it rather than increasing notification frequency.

---

# 15. Mascot behavior

Mascot is optional emotional support.

Allowed:

- greeting,
- subtle completion celebration,
- encouragement after difficult sessions,
- contextual encouragement.

Not allowed in core flow:

- blocking task completion,
- requiring mascot interaction,
- excessive animations,
- XP dependency,
- streak dependency.

Example:

```text
✓ Hoàn thành

Mascot:
“Giỏi lắm! Nghỉ một chút rồi tiếp tục nhé.”
```

Keep it short.

---

# 16. Gamification policy

EduPulse should reward **real study behavior**, not app interaction.

Do not reward:

- opening the app,
- clicking AI,
- viewing screens,
- collecting arbitrary points.

If XP is retained, it should be derived from actual study/completion behavior.

Streak should not be used to shame the user.

A missed day should not create a “failure” state.

Preferred message:

> “Hôm qua chưa học được. Hôm nay mình tiếp tục nhé.”

Not:

> “Bạn đã mất streak!”

---

# 17. Accessibility

Required:

- sufficient text/background contrast,
- visible focus state on Web,
- keyboard navigation,
- semantic labels,
- screen-reader-friendly controls,
- minimum touch targets,
- no color-only status indicators,
- support reduced motion where possible.

Example:

```text
□ Chưa hoàn thành
✓ Đã hoàn thành
```

not color alone.

---

# 18. Performance

Redesign must not create unnecessary rebuilds or heavy UI.

Priorities:

- lazy rendering for long lists,
- avoid expensive animations,
- cache task/progress data,
- preserve offline-first architecture,
- avoid re-fetching unchanged data,
- debounce search/input where needed,
- keep AI calls explicit.

The Home screen should feel immediate even before remote sync completes.

---

# 19. Data / architecture constraints

Prefer reusing existing:

- Supabase schema,
- local storage,
- sync mechanism,
- AI provider abstraction,
- task services,
- study session data.

Before changing a data model:

1. determine whether current data can map to the new UX,
2. preserve IDs,
3. preserve history,
4. migrate only where necessary.

Do not rewrite backend logic merely to rename a UI concept.

---

# 20. Implementation order

## Phase 1 — Information architecture

- Replace primary navigation.
- Rebuild Home/Today.
- Establish task as source of truth.
- Move secondary features out of the core path.

## Phase 2 — Task flow

Implement:

```text
Create
→ View
→ Start
→ Study
→ Complete
→ Review
→ Next task
```

Then implement:

```text
Edit
Reschedule
Delete
```

## Phase 3 — AI

- Contextual AI entry points.
- AI recommendations.
- AI task creation.
- AI plan application.
- Confirmation for destructive/multi-task changes.

## Phase 4 — Progress

- Daily summary.
- Weekly progress.
- Subject progress.
- Exam progress.
- AI insights.

## Phase 5 — Visual redesign

- Typography.
- Spacing.
- Color system.
- Components.
- Cards.
- Buttons.
- Empty/error/loading states.

## Phase 6 — Responsive

- Mobile.
- Tablet.
- Desktop.
- Wide desktop.

## Phase 7 — Polish

- Animation.
- Haptics.
- Sound.
- Mascot reactions.
- accessibility.
- performance.

---

# 21. Acceptance criteria

## Home

- User can understand today's plan within 3 seconds.
- First recommended task is immediately visible.
- Start Study is the dominant CTA.
- Countdown does not dominate the screen.
- XP/streak/level do not compete with tasks.

## Task

- Create task in a short form.
- Edit without losing task identity.
- Reschedule without recreating.
- Delete with confirmation.
- Complete in one clear action.

## Study

- Start from task directly.
- No duplicate task selection.
- Navigation is minimized.
- Session survives temporary app backgrounding.
- Completion works even without timer reaching zero.

## AI

- AI can recommend tasks.
- AI can create tasks.
- AI can propose edits.
- AI asks before destructive or broad changes.
- AI does not silently overwrite plans.
- User can continue without AI when AI is unavailable.

## Progress

- Daily and weekly summaries are understandable.
- Charts support a decision rather than exist as decoration.
- No-data states are actionable.

## Responsive

- Mobile works without horizontal overflow.
- Desktop uses available space intentionally.
- Touch targets remain comfortable.
- Study Mode is distraction-free.

## Offline

- Existing offline-first behavior remains functional.
- Study data can be recorded offline.
- Sync happens when connectivity returns.
- User is informed when sync is delayed.

---

# 22. QA checklist

## Navigation

- [ ] Today opens by default.
- [ ] AI is accessible.
- [ ] Progress is accessible.
- [ ] Profile/settings are accessible.
- [ ] No important feature is hidden without a discoverable path.

## Tasks

- [ ] Create
- [ ] Edit
- [ ] Delete
- [ ] Reschedule
- [ ] Start
- [ ] Complete
- [ ] Reopen where supported
- [ ] Task state survives reload

## Study session

- [ ] Start
- [ ] Pause
- [ ] Resume
- [ ] Background app
- [ ] Return to app
- [ ] Complete
- [ ] Feedback
- [ ] Session recorded

## AI

- [ ] Recommendation
- [ ] Explain
- [ ] Create task
- [ ] Edit task
- [ ] Delete task confirmation
- [ ] Reschedule proposal
- [ ] Study plan
- [ ] Weakness analysis
- [ ] Error recovery
- [ ] Input preservation

## Exam

- [ ] Create
- [ ] Edit
- [ ] Delete
- [ ] Primary exam
- [ ] Subjects
- [ ] Targets
- [ ] Countdown

## Progress

- [ ] Daily
- [ ] Weekly
- [ ] Subject
- [ ] Exam
- [ ] Empty state

## Responsive

- [ ] Small mobile
- [ ] Large mobile
- [ ] Tablet
- [ ] Desktop
- [ ] Wide desktop

## Accessibility

- [ ] Keyboard
- [ ] Focus states
- [ ] Contrast
- [ ] Semantic labels
- [ ] Touch target
- [ ] Reduced motion
- [ ] Color-independent states

---

# 23. Final product rule

When deciding whether a UI element belongs in the core experience, ask:

> **Does this help the student decide what to study, start studying, complete it, or understand progress?**

If yes, keep it prominent.

If it is useful but secondary, move it down.

If it mainly exists to make the app feel busy, remove it.

The redesigned EduPulse should feel like:

> **“Mở app là biết mình phải làm gì.”**

not:

> **“Mở app để xem tất cả những thứ EduPulse có.”**

The desired experience is calm, focused, lightweight, and action-oriented.

---

## 24. Implementation summary

```text
OLD MENTAL MODEL

Dashboard
├── Countdown
├── XP
├── Level
├── Streak
├── Mascot
├── Tasks
├── AI
├── Pomodoro
├── Plan
├── Progress
└── Exam


NEW MENTAL MODEL

EduPulse
│
├── TODAY
│   ├── Countdown
│   ├── Today's Tasks
│   ├── Start Study
│   └── Daily Summary
│
├── AI
│   ├── Recommend
│   ├── Explain
│   ├── Plan
│   └── Analyze
│
├── PROGRESS
│   ├── Daily
│   ├── Weekly
│   ├── Subjects
│   └── Exam
│
└── ME
    ├── Exam
    ├── Goals
    ├── Profile
    └── Settings
```

**Core principle:**

```text
PLAN → DO → REVIEW → ADJUST
```

Everything else is secondary.
