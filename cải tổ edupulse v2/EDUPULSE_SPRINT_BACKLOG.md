# EduPulse — Sprint Implementation Backlog

> **Version:** 1.0  
> **Date:** 2026-10-01  
> **Based on:** `EDUPULSE_UX_UI_REDESIGN.md`  
> **Goal:** triển khai redesign EduPulse theo từng sprint, có phân công Frontend / Backend / AI / QA và Definition of Done.

---

# 1. Delivery strategy

## Product loop

```text
PLAN
  ↓
TODAY'S TASKS
  ↓
START STUDY
  ↓
STUDY SESSION
  ↓
COMPLETE
  ↓
REVIEW
  ↓
PROGRESS
  ↓
AI ADJUSTMENT
  ↓
NEXT PLAN
```

## Sprint order

```text
Sprint 0 — Foundation & Audit
        ↓
Sprint 1 — Navigation + Today
        ↓
Sprint 2 — Task Management
        ↓
Sprint 3 — Study Mode + Session
        ↓
Sprint 4 — AI Assistant
        ↓
Sprint 5 — Progress + Exam
        ↓
Sprint 6 — Responsive + Visual Polish
        ↓
Sprint 7 — QA + Stabilization
```

## Priority labels

- **P0** — must have for redesigned core flow
- **P1** — important
- **P2** — secondary/polish

## Workstream labels

- **FE** — Frontend
- **BE** — Backend/data/sync
- **AI** — AI behavior/integration
- **QA** — testing/validation

---

# 2. Sprint 0 — Foundation & current-state audit

## Goal

Establish a safe baseline before changing the UI.

### FE-0.1 — Audit existing screens

**Priority:** P0

Tasks:

- [ ] Inventory all current routes/screens.
- [ ] Map current navigation.
- [ ] Identify reusable components.
- [ ] Identify duplicate task/planning components.
- [ ] Identify components related to XP/level/streak/mascot.
- [ ] Identify mobile-specific layouts.
- [ ] Identify desktop/web layouts.

**Done when:**

- A route/component map exists.
- Every current major screen is mapped to a redesign destination.
- No critical screen is left unclassified.

---

### FE-0.2 — Establish design tokens

**Priority:** P0

Create semantic tokens for:

- [ ] colors
- [ ] typography
- [ ] spacing
- [ ] radius
- [ ] elevation
- [ ] icon sizes
- [ ] touch targets

**Done when:**

- New screens can use shared tokens.
- No new redesign screen hardcodes arbitrary values unnecessarily.

---

### FE-0.3 — Create shared UI primitives

**Priority:** P0

Components:

- [ ] PrimaryButton
- [ ] SecondaryButton
- [ ] IconButton
- [ ] TaskCard
- [ ] SectionHeader
- [ ] BottomNavigation
- [ ] DesktopSidebar
- [ ] EmptyState
- [ ] ErrorState
- [ ] LoadingState
- [ ] ConfirmationDialog
- [ ] BottomSheet / Modal
- [ ] ProgressIndicator

**Done when:**

- Components are reusable.
- Mobile and desktop variants are supported where needed.

---

### BE-0.1 — Audit current data model

**Priority:** P0

Check:

- [ ] tasks
- [ ] study sessions
- [ ] exams
- [ ] subjects
- [ ] progress
- [ ] AI-generated data
- [ ] local cache
- [ ] Supabase sync
- [ ] existing gamification fields

**Done when:**

- Existing schema is documented.
- Migration risks are identified.
- Task and study session IDs can be preserved.

---

### BE-0.2 — Define task source of truth

**Priority:** P0

Decision:

```text
Manual Task
     \
      → TASK
     /
AI Task
```

Both must use the same task model.

**Done when:**

- No duplicate task entity is required for AI.
- Study sessions reference task ID.
- Completion status is authoritative in one place.

---

### AI-0.1 — Define AI action contract

**Priority:** P0

Define actions:

```text
recommend
create_task
edit_task
delete_task
reschedule_task
create_plan
analyze_progress
explain
```

**Done when:**

- Each action has input/output schema.
- Destructive actions require confirmation.
- AI cannot silently mutate user plans.

---

### QA-0.1 — Baseline regression

**Priority:** P0

Create regression checklist for:

- [ ] login/auth if applicable
- [ ] existing tasks
- [ ] task completion
- [ ] exam data
- [ ] study sessions
- [ ] offline mode
- [ ] sync
- [ ] AI
- [ ] PWA install/basic behavior

**Done when:**

- Baseline tests pass before redesign work begins.
- Existing critical behavior has a known-good reference.

---

# 3. Sprint 1 — Navigation + Today/Home

## Goal

Make Today the center of the product.

---

## FE-1.1 — New primary navigation

**Priority:** P0

Mobile:

```text
Hôm nay | AI | Tiến độ | Tôi
```

Desktop:

```text
Sidebar:
Hôm nay
AI
Tiến độ
Tôi
```

**Done when:**

- Four primary destinations work.
- Active state is visible.
- Navigation does not break on refresh/deep link.
- Focus states exist on Web.

---

## FE-1.2 — Rebuild Today screen

**Priority:** P0

Sections:

1. Greeting
2. Exam context/countdown
3. Daily summary
4. Today's Tasks
5. AI suggestion
6. optional mascot

**Done when:**

- First task is visible without unnecessary scrolling on normal mobile viewport.
- Start Study is visually dominant.
- Countdown does not dominate.
- XP/level/streak are not primary UI.
- No duplicate task lists exist.

---

## FE-1.3 — Today task sorting

**Priority:** P0

Order:

1. active/in-progress task
2. overdue/high priority
3. scheduled task
4. optional tasks

**Done when:**

- User sees the most relevant next task first.
- Sorting is deterministic.
- Completed tasks are visually separated.

---

## FE-1.4 — Daily summary

**Priority:** P1

Display:

```text
2/5 nhiệm vụ
1h20m học
```

**Done when:**

- Values update immediately after task/session changes.
- Summary works offline.

---

## BE-1.1 — Today query/service

**Priority:** P0

Provide:

- today's tasks
- task status
- daily study time
- completion count
- active session

**Done when:**

- Today screen can load from one coherent data source.
- Offline cache is supported.

---

## BE-1.2 — Daily aggregation

**Priority:** P1

Compute:

- task count
- completed count
- study minutes
- remaining tasks

**Done when:**

- Calculations match raw task/session data.
- No duplicated manual counters are required.

---

## AI-1.1 — Daily recommendation

**Priority:** P1

Input:

- today's tasks
- deadlines
- available time
- recent sessions
- exam target

Output:

```text
recommendedTask
reason
optionalAlternative
```

**Done when:**

- AI recommends an existing task where possible.
- AI does not invent a task unless explicitly asked to plan.
- Recommendation is actionable.

---

## QA-1.1 — Navigation + Today tests

**Done when:**

- [ ] Mobile navigation
- [ ] Desktop navigation
- [ ] Today loading
- [ ] Empty Today
- [ ] Offline Today
- [ ] Task ordering
- [ ] Completion updates summary
- [ ] Active session recovery

all pass.

---

# 4. Sprint 2 — Task Management

## Goal

Make tasks the single source of truth.

---

## FE-2.1 — TaskCard

**Priority:** P0

Display:

- checkbox/status
- title
- subject
- topic
- duration
- deadline when relevant

Actions:

- start
- complete
- edit
- reschedule
- delete

**Done when:**

- Task can be understood without opening detail.
- Start is the primary action.
- Destructive actions are secondary.

---

## FE-2.2 — Task detail

**Priority:** P0

**Done when:**

- User can view all relevant task information.
- Start Study is primary.
- Edit/reschedule/delete are accessible.
- Back navigation preserves context.

---

## FE-2.3 — Create/Edit Task

**Priority:** P0

Required:

- name
- subject
- topic
- duration

Optional:

- deadline
- priority
- notes

**Done when:**

- Validation works.
- Editing preserves task ID.
- User can create a task in a short flow.
- Errors are inline and understandable.

---

## FE-2.4 — Reschedule UI

**Priority:** P0

Options:

- today
- tomorrow
- weekend/next available
- custom date

**Done when:**

- Reschedule does not create a duplicate task.
- History/status remains intact.

---

## FE-2.5 — Delete confirmation

**Priority:** P0

**Done when:**

- Delete is never accidental.
- Confirmation names the task.
- Cancel leaves task unchanged.

---

## BE-2.1 — Task CRUD

**Priority:** P0

Implement/verify:

- create
- read
- update
- delete
- reschedule
- completion

**Done when:**

- All operations preserve IDs and timestamps.
- Offline and synced states behave consistently.

---

## BE-2.2 — Task state machine

**Priority:** P0

States:

```text
scheduled
started
completed
not_completed
rescheduled
```

**Done when:**

- Invalid state transitions are prevented.
- Existing task history remains usable.

---

## BE-2.3 — Task migration compatibility

**Priority:** P1

Map existing fields to new semantics.

**Done when:**

- Existing user tasks are visible in redesigned UI.
- No task disappears because of renamed fields.

---

## AI-2.1 — AI task actions

**Priority:** P0

Support:

- create task
- edit task
- delete task
- reschedule task

**Done when:**

- AI uses the same task service/API as manual actions.
- Delete/edit/reschedule require confirmation when appropriate.
- AI does not create duplicate tasks.

---

## QA-2.1 — Task CRUD

**Done when:**

- [ ] Create
- [ ] Read
- [ ] Edit
- [ ] Delete
- [ ] Reschedule
- [ ] Complete
- [ ] Refresh persistence
- [ ] Offline persistence
- [ ] Sync

all pass.

---

# 5. Sprint 3 — Study Mode + Study Session

## Goal

Reduce the distance between “I should study” and actually studying.

---

## FE-3.1 — Study Mode

**Priority:** P0

Screen:

```text
Task
Timer
Pause
Complete
```

Hide:

- primary navigation
- XP
- level
- streak
- unnecessary dashboard cards

**Done when:**

- User can start directly from a task.
- Screen is distraction-free.
- Timer is readable.
- Complete action is always available.

---

## FE-3.2 — Timer

**Priority:** P0

Support:

- start
- pause
- resume
- finish
- background/foreground recovery

**Done when:**

- Timer does not reset unexpectedly.
- Refresh/background behavior is safe.

---

## FE-3.3 — Session completion

**Priority:** P0

Show:

```text
✓ Hoàn thành
45 phút học

😫 😐 🙂 😄 🔥
```

**Done when:**

- Completion is one clear action.
- Feedback is optional/quick.
- Session is recorded.

---

## BE-3.1 — Study session persistence

**Priority:** P0

Store:

- task ID
- start time
- end time
- duration
- status
- optional feedback

**Done when:**

- Session can be reconstructed after interruption.
- Study minutes are accurate.

---

## BE-3.2 — Session recovery

**Priority:** P0

Handle:

- app backgrounding
- refresh
- temporary network loss

**Done when:**

- No session is silently lost.
- User can continue after returning.

---

## BE-3.3 — Daily study aggregation

**Priority:** P1

**Done when:**

- Study time matches recorded sessions.
- Daily summary updates automatically.

---

## QA-3.1 — Study mode test matrix

Test:

- [ ] start
- [ ] pause
- [ ] resume
- [ ] complete early
- [ ] timer reaches zero
- [ ] app background
- [ ] browser refresh
- [ ] offline
- [ ] return to active session
- [ ] completion feedback

**Done when:** all critical scenarios pass.

---

# 6. Sprint 4 — AI Assistant

## Goal

Turn AI into an assistant embedded in the study workflow.

---

## AI-4.1 — AI context engine

**Priority:** P0

AI should receive relevant context:

- current task
- today's tasks
- exam
- subjects
- recent sessions
- available study time
- progress

**Done when:**

- AI answers contextually.
- User does not need to repeat known information unnecessarily.

---

## AI-4.2 — Recommendation

**Priority:** P0

Questions:

- “Tôi nên học gì?”
- “Bây giờ nên làm gì?”

**Done when:**

- Recommendation points to real tasks when possible.
- Reason is concise.
- User can start recommended task directly.

---

## AI-4.3 — Explain

**Priority:** P0

From task/session:

```text
Không hiểu?
→ Hỏi AI
```

**Done when:**

- Current task context is passed automatically.
- User can ask follow-up questions.
- AI does not lose the active context unnecessarily.

---

## AI-4.4 — Plan generation

**Priority:** P0

Input:

- available time
- target/exam
- existing tasks
- recent progress

Output:

```text
task list
duration
reason
```

**Done when:**

- Plan is previewed before application.
- Existing tasks are not overwritten silently.
- Applying plan creates normal Tasks.

---

## AI-4.5 — Weakness analysis

**Priority:** P1

Use available study/progress data.

**Done when:**

- AI distinguishes observed data from inference.
- Recommendations are actionable.
- No unsupported certainty is presented.

---

## AI-4.6 — Action confirmation

**Priority:** P0

Confirmation required for:

- deleting task
- broad schedule changes
- replacing existing plan
- changing important goals

**Done when:**

- No destructive action happens without user confirmation.

---

## AI-4.7 — Error recovery

**Priority:** P0

If AI fails:

```text
AI đang không phản hồi.

[ Thử lại ]
[ Tiếp tục tự học ]
```

**Done when:**

- User input is preserved.
- Existing tasks remain accessible.
- Failure never blocks study.

---

## FE-4.1 — AI screen redesign

**Priority:** P0

Quick actions:

- Tôi nên học gì?
- Giải thích bài này
- Lập kế hoạch
- Phân tích điểm yếu

**Done when:**

- AI screen is not a generic empty chat.
- Contextual actions are visible.
- Chat remains available.

---

## QA-4.1 — AI behavior suite

Test:

- [ ] recommendation
- [ ] explain
- [ ] create task
- [ ] edit task
- [ ] delete confirmation
- [ ] reschedule
- [ ] plan
- [ ] weakness analysis
- [ ] AI failure
- [ ] malformed response
- [ ] duplicate action prevention

**Done when:** critical AI flows pass with deterministic mocks/tests where possible.

---

# 7. Sprint 5 — Progress + Exam

## Goal

Create a useful feedback loop without turning the app into an analytics dashboard.

---

## FE-5.1 — Progress overview

**Priority:** P0

Show:

- today's completion
- today's study time
- weekly study time
- weekly task completion
- subject overview

**Done when:**

- User can understand progress without interpreting complex charts.
- Empty states are actionable.

---

## FE-5.2 — Subject progress

**Priority:** P1

Show:

- study time
- completion
- trend
- goal relation

**Done when:**

- Data is derived from real sessions/tasks.
- Trends are not presented when insufficient data exists.

---

## FE-5.3 — Exam screen

**Priority:** P0

Show:

- exam name
- exam date
- countdown
- subjects
- target scores

**Done when:**

- Primary exam is obvious.
- Additional exams are secondary.
- Editing is easy.

---

## BE-5.1 — Progress aggregation

**Priority:** P0

Provide:

- daily
- weekly
- subject
- exam

aggregates.

**Done when:**

- Aggregates match raw data.
- Timezone/date boundaries are correct.

---

## BE-5.2 — Exam data

**Priority:** P0

Support:

- create
- update
- delete
- primary exam
- subjects
- target

**Done when:**

- Existing exam data is preserved.
- Countdown is derived from exam date.

---

## AI-5.1 — Progress insight

**Priority:** P1

Example:

```text
Bạn đang hoàn thành Toán đều hơn Vật lý.
Tuần này Vật lý thấp hơn kế hoạch 2 buổi.

Bạn có muốn điều chỉnh kế hoạch không?
```

**Done when:**

- Insight is grounded in actual data.
- AI distinguishes data from suggestion.
- No fabricated metrics.

---

## QA-5.1 — Progress/exam tests

- [ ] Daily aggregation
- [ ] Weekly aggregation
- [ ] Subject aggregation
- [ ] Exam creation
- [ ] Exam editing
- [ ] Primary exam
- [ ] Countdown
- [ ] Empty progress
- [ ] Timezone/date boundary

**Done when:** all pass.

---

# 8. Sprint 6 — Responsive + Visual Polish

## Goal

Make the redesigned system feel coherent on every supported viewport.

---

## FE-6.1 — Mobile polish

**Priority:** P0

Test:

- small phone
- normal phone
- large phone

Requirements:

- no horizontal overflow,
- comfortable touch targets,
- bottom nav,
- clear primary CTA,
- keyboard-safe forms,
- readable timer.

**Done when:**

- Critical screens pass on target mobile sizes.

---

## FE-6.2 — Tablet

**Priority:** P1

Use adaptive layouts rather than simply stretching mobile UI.

**Done when:**

- Main content uses available width appropriately.
- Navigation remains clear.

---

## FE-6.3 — Desktop

**Priority:** P0

Implement:

- sidebar
- content max width
- optional secondary column

**Done when:**

- Desktop does not look like an enlarged phone.
- Main task remains the visual priority.

---

## FE-6.4 — Visual hierarchy

**Priority:** P0

Apply:

```text
Action
Task
Context
Information
Decoration
```

**Done when:**

- Primary CTA is obvious.
- Secondary cards do not overpower tasks.
- Decorative UI cannot be mistaken for action.

---

## FE-6.5 — Empty/loading/error states

**Priority:** P0

Implement shared components for:

- empty
- loading
- error
- offline
- sync delayed

**Done when:**

- All core screens have meaningful states.
- No blank screen appears for expected empty data.

---

## FE-6.6 — Animation/haptics/sound

**Priority:** P2

Use only for:

- completion
- transition
- AI state
- subtle mascot reaction

**Done when:**

- Animation does not slow interaction.
- Reduced-motion preference is respected where supported.
- Sound can be disabled.

---

## QA-6.1 — Responsive matrix

```text
Mobile
Tablet
Desktop
Wide desktop
```

Check:

- [ ] navigation
- [ ] task cards
- [ ] forms
- [ ] study mode
- [ ] AI
- [ ] progress
- [ ] exam
- [ ] settings

**Done when:** no P0/P1 layout defect remains.

---

# 9. Sprint 7 — QA + Stabilization

## Goal

Release only when the core loop is stable.

---

# 9.1 End-to-end core flow

## Scenario A — New task

```text
Create task
→ Today
→ Start
→ Study
→ Complete
→ Feedback
→ Progress
```

**Pass criteria:**

- No data loss.
- Correct task status.
- Correct study duration.
- Progress updates.

---

## Scenario B — AI plan

```text
AI Plan
→ Preview
→ Confirm
→ Tasks created
→ Today
→ Start
```

**Pass criteria:**

- No duplicate tasks.
- User explicitly approves plan.
- Created tasks behave exactly like manual tasks.

---

## Scenario C — Reschedule

```text
Today
→ Reschedule
→ Tomorrow
→ Tomorrow Today view
```

**Pass criteria:**

- Original task ID preserved.
- Task appears on new date.
- History is intact.

---

## Scenario D — Offline study

```text
Online
→ Start study
→ Offline
→ Complete
→ Online
→ Sync
```

**Pass criteria:**

- Session is preserved.
- Completion is preserved.
- Sync does not duplicate data.

---

# 9.2 QA categories

## Functional

- [ ] Navigation
- [ ] Task CRUD
- [ ] Reschedule
- [ ] Study session
- [ ] Timer
- [ ] Progress
- [ ] Exam
- [ ] AI
- [ ] Offline
- [ ] Sync

## Visual

- [ ] Typography
- [ ] spacing
- [ ] hierarchy
- [ ] alignment
- [ ] overflow
- [ ] states
- [ ] responsive behavior

## Accessibility

- [ ] keyboard
- [ ] focus
- [ ] contrast
- [ ] semantic labels
- [ ] touch target
- [ ] reduced motion

## Performance

- [ ] initial load
- [ ] Today rendering
- [ ] task list scrolling
- [ ] AI response
- [ ] study mode
- [ ] offline startup

---

# 10. Definition of Done — global

A feature is not complete merely because it renders.

A backlog item is **DONE** only when:

### Frontend

- [ ] UI implemented
- [ ] loading state
- [ ] empty state
- [ ] error state
- [ ] responsive layout
- [ ] accessibility basics
- [ ] no console/runtime errors
- [ ] primary interaction is clear

### Backend

- [ ] data model verified
- [ ] persistence works
- [ ] IDs preserved
- [ ] offline behavior considered
- [ ] sync behavior tested
- [ ] no duplicate records

### AI

- [ ] input context defined
- [ ] output schema defined
- [ ] validation exists
- [ ] destructive actions require confirmation
- [ ] failure state handled
- [ ] no fabricated data
- [ ] action is idempotent where applicable

### QA

- [ ] happy path tested
- [ ] empty state tested
- [ ] error path tested
- [ ] offline path tested where relevant
- [ ] responsive tested
- [ ] regression tested

---

# 11. Release gates

## Gate 1 — Core UX

Required:

- Today
- Tasks
- Start Study
- Complete
- Progress

No release if any P0 flow is broken.

---

## Gate 2 — AI

Required:

- recommendation
- explain
- plan
- task actions
- confirmation
- AI failure recovery

---

## Gate 3 — Reliability

Required:

- offline
- sync
- session recovery
- no data loss

---

## Gate 4 — Responsive

Required:

- mobile
- desktop

Tablet/wide desktop may be P1 depending on release target.

---

## Gate 5 — Polish

Required before production release:

- accessibility basics
- loading/error/empty states
- performance check
- no known P0/P1 regressions

---

# 12. Recommended ticket naming

Use a consistent naming convention:

```text
FE-001 Navigation shell
FE-002 Today screen
FE-003 Task card

BE-001 Task state model
BE-002 Today query
BE-003 Study session persistence

AI-001 Context engine
AI-002 Daily recommendation
AI-003 Task actions

QA-001 Navigation regression
QA-002 Task CRUD
QA-003 Study session E2E
```

Suggested format:

```text
[AREA]-[NUMBER] Short description
```

---

# 13. Sprint summary

| Sprint | Main output | FE | BE | AI | QA |
|---|---|---:|---:|---:|---:|
| 0 | Foundation | ✓ | ✓ | ✓ | ✓ |
| 1 | Navigation + Today | ✓✓ | ✓ | ✓ | ✓ |
| 2 | Tasks | ✓✓ | ✓✓ | ✓ | ✓ |
| 3 | Study Mode | ✓✓ | ✓✓ | — | ✓✓ |
| 4 | AI Assistant | ✓ | ✓ | ✓✓ | ✓ |
| 5 | Progress + Exam | ✓ | ✓✓ | ✓ | ✓ |
| 6 | Responsive + Polish | ✓✓ | — | — | ✓✓ |
| 7 | Stabilization | ✓ | ✓ | ✓ | ✓✓ |

---

# 14. MVP boundary

If development time is limited, the MVP ends after:

```text
Sprint 0
+
Sprint 1
+
Sprint 2
+
Sprint 3
```

MVP must support:

```text
Create task
↓
See task today
↓
Start study
↓
Study
↓
Complete
↓
Review
```

AI can initially be limited to:

```text
Recommend
Explain
```

Progress can initially be:

```text
Today's completion
Today's study time
```

Do not delay the core product waiting for advanced analytics or gamification.

---

# 15. Final implementation principle

The developer should repeatedly ask:

> “Does this change make it easier for the student to know what to study and actually start studying?”

If yes:

```text
Implement prominently.
```

If useful but secondary:

```text
Keep it accessible but visually secondary.
```

If it adds complexity without improving study behavior:

```text
Do not add it to the core flow.
```

The redesigned EduPulse should ultimately feel like:

```text
OPEN
 ↓
KNOW WHAT TO DO
 ↓
START
 ↓
STUDY
 ↓
FINISH
 ↓
KNOW WHAT'S NEXT
```

not:

```text
OPEN
 ↓
LOOK AT DASHBOARD
 ↓
LOOK AT XP
 ↓
LOOK AT STREAK
 ↓
LOOK AT MASCOT
 ↓
OPEN AI
 ↓
OPEN POMODORO
 ↓
SEARCH FOR TASK
```

**Primary product metric for the redesign:**

> How quickly can a student go from opening EduPulse to starting the correct study task?

Everything in the redesign should support that outcome.
