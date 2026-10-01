# EduPulse — AI Optimization Specification

> **Mục tiêu:** biến AI của EduPulse từ một chatbot có nhiều tính năng thành một **gia sư cá nhân theo ngữ cảnh**, có khả năng hiểu tình trạng học tập, đưa ra đề xuất đúng lúc, thực hiện hành động có kiểm soát và học từ hành vi của người dùng.
>
> **Nguyên tắc cốt lõi:** AI phải **giảm tải cho học sinh**, không tạo thêm một hệ thống mà học sinh phải quản lý.

---

## 1. Tầm nhìn AI

### 1.1. Định vị

EduPulse AI không nên được thiết kế như:

> "Một chatbot để học sinh vào hỏi."

Mà nên là:

> **Một lớp trí tuệ nằm phía sau toàn bộ vòng lặp học tập của EduPulse.**

AI xuất hiện ở đúng điểm người dùng cần:

```text
Mở app
  ↓
AI hiểu tình trạng hôm nay
  ↓
Gợi ý việc cần làm
  ↓
Học
  ↓
Ghi nhận session
  ↓
AI phân tích kết quả
  ↓
Điều chỉnh kế hoạch
  ↓
Lặp lại
```

### 1.2. Core Loop

```text
PLAN → DO → REVIEW → ADJUST
```

AI phải hỗ trợ cả 4 bước:

| Giai đoạn | AI hỗ trợ |
|---|---|
| PLAN | Lập kế hoạch, ưu tiên task |
| DO | Giải thích, hỗ trợ khi học |
| REVIEW | Phân tích session, điểm yếu |
| ADJUST | Điều chỉnh lịch, task và kế hoạch |

---

# 2. Mục tiêu tối ưu

## P0 — Bắt buộc

- AI hiểu context trước khi trả lời.
- AI không tự bịa dữ liệu học tập.
- AI có thể tạo/sửa/xóa/reschedule task.
- Các thay đổi quan trọng phải có confirmation.
- AI output phải có schema rõ ràng.
- AI phải phân biệt request cần LLM và request chỉ cần rule engine.
- AI phải xử lý lỗi, timeout, thiếu context.
- AI phải sử dụng dữ liệu học tập thực tế để cá nhân hóa.
- AI phải giữ task làm "single source of truth".

## P1 — Quan trọng

- Phân tích điểm yếu theo môn/chủ đề.
- Phát hiện hành vi trì hoãn.
- Phát hiện lịch học quá tải.
- Điều chỉnh kế hoạch dựa trên lịch sử.
- Phân tích hiệu quả sau study session.
- Có feedback loop.

## P2 — Có thể triển khai sau

- Dự đoán workload.
- Adaptive study plan.
- Personalized learning strategy.
- Knowledge retrieval nâng cao.
- Model routing.
- A/B test prompt/model.

---

# 3. Kiến trúc AI tổng thể

```text
                         ┌────────────────────┐
                         │      EduPulse      │
                         └─────────┬──────────┘
                                   │
                         ┌─────────▼──────────┐
                         │   Context Engine   │
                         └─────────┬──────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
        ┌───────▼────────┐ ┌─────▼─────────┐ ┌──────▼────────┐
        │   Rule Engine  │ │   AI Engine   │ │ Knowledge/RAG │
        │                │ │               │ │               │
        └───────┬────────┘ └─────┬─────────┘ └──────┬────────┘
                │                │                  │
                └────────────────┼──────────────────┘
                                 │
                        ┌────────▼────────┐
                        │  Action Layer   │
                        └────────┬────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
        ┌─────▼─────┐      ┌────▼────┐      ┌─────▼─────┐
        │ Create    │      │ Update  │      │ Analyze   │
        │ Task      │      │ Task    │      │ Progress  │
        └───────────┘      └─────────┘      └───────────┘
                                 │
                        ┌────────▼────────┐
                        │      User       │
                        └─────────────────┘
```

---

# 4. Context Engine

## 4.1. Vai trò

Context Engine là thành phần quan trọng nhất.

Không gửi nguyên toàn bộ database vào LLM.

Context Engine phải:

1. lấy dữ liệu liên quan;
2. lọc dữ liệu;
3. tổng hợp;
4. chuẩn hóa;
5. tạo context phù hợp với request;
6. gửi context tối thiểu cần thiết cho AI.

---

## 4.2. Context Model

### User Profile

```json
{
  "user_id": "user_123",
  "study_goal": "27+",
  "daily_study_minutes": 180,
  "preferred_study_time": ["19:00", "21:30"]
}
```

### Exam Context

```json
{
  "exam_id": "exam_123",
  "name": "THPTQG",
  "exam_date": "2027-06-xx",
  "days_remaining": 240,
  "target_score": 27
}
```

### Task Context

```json
{
  "id": "task_123",
  "title": "Hàm số",
  "subject": "Toán",
  "topic": "Hàm số",
  "duration_minutes": 60,
  "deadline": "2026-10-02",
  "priority": "high",
  "status": "pending",
  "reschedule_count": 1
}
```

### Learning Context

```json
{
  "subject": "Toán",
  "topic": "Hàm số",
  "focus": 2,
  "difficulty": 5,
  "understanding": 2,
  "mood": 2,
  "effectiveness": 2
}
```

### Behavior Context

```json
{
  "completion_rate_7d": 0.68,
  "average_session_minutes": 43,
  "reschedule_rate": 0.31,
  "overdue_tasks": 2,
  "preferred_start_hour": 19
}
```

---

# 5. Context cấp độ

Không phải request nào cũng cần toàn bộ context.

## Level 0 — No context

Dùng cho:

- giải thích kiến thức chung;
- câu hỏi không liên quan tài khoản.

## Level 1 — Current Task

Dùng cho:

> "Giải thích bài này."

Context:

```text
task
subject
topic
notes
```

## Level 2 — Today

Dùng cho:

> "Hôm nay tôi nên học gì?"

Context:

```text
today tasks
available time
overdue tasks
current time
```

## Level 3 — Learning Profile

Dùng cho:

> "Tôi yếu môn nào?"

Context:

```text
subject performance
study history
difficulty
understanding
completion
```

## Level 4 — Full Planning Context

Dùng cho:

> "Lập lại kế hoạch ôn thi cho tôi."

Context:

```text
exam
goals
subjects
tasks
deadlines
study history
available time
behavior
performance
```

---

# 6. Rule Engine

Không phải mọi quyết định đều cần AI.

## 6.1. Nguyên tắc

```text
Deterministic problem → Rule Engine
Reasoning problem → LLM
Knowledge problem → Retrieval + LLM
```

---

## 6.2. Ví dụ rule

### Quá tải

```text
IF
today_required_minutes > available_minutes

THEN
overload = true
```

### Task quá hạn

```text
IF
deadline < current_time
AND status != completed

THEN
status = overdue
```

### Task bị trì hoãn

```text
IF
reschedule_count >= 3

THEN
needs_intervention = true
```

### Deadline gần

```text
IF
days_to_deadline <= 3

THEN
priority_boost = high
```

### Study session quá dài

```text
IF
planned_duration >= 120

THEN
suggest_split = true
```

---

# 7. AI Engine

## 7.1. Không trả output tự do nếu cần hành động

Không nên:

```text
AI:
"Bạn có thể học Toán trước..."
```

và frontend phải tự đoán AI muốn làm gì.

Nên:

```json
{
  "type": "recommendation",
  "message": "Nên ưu tiên Hàm số trước.",
  "actions": [
    {
      "type": "start_task",
      "task_id": "task_123"
    }
  ]
}
```

---

# 8. AI Action Schema

Các action chính:

```text
recommend
create_task
update_task
delete_task
reschedule_task
split_task
create_plan
analyze_progress
analyze_weakness
explain
start_task
```

---

## 8.1. Create Task

```json
{
  "action": "create_task",
  "task": {
    "title": "Luyện hàm số",
    "subject": "Toán",
    "topic": "Hàm số",
    "duration_minutes": 45,
    "deadline": "2026-10-02"
  }
}
```

## 8.2. Reschedule

```json
{
  "action": "reschedule_task",
  "task_id": "task_123",
  "from": "2026-10-01",
  "to": "2026-10-02",
  "reason": "Today workload is too high"
}
```

## 8.3. Split Task

```json
{
  "action": "split_task",
  "task_id": "task_123",
  "parts": [
    {
      "title": "Ôn lý thuyết",
      "duration_minutes": 30
    },
    {
      "title": "Làm bài tập",
      "duration_minutes": 30
    }
  ]
}
```

---

# 9. Confirmation System

AI không được âm thầm thực hiện các thay đổi có ảnh hưởng lớn.

## Không cần confirmation

- Đưa recommendation.
- Giải thích.
- Phân tích.
- Gợi ý task.
- Gợi ý thứ tự học.

## Cần confirmation

- Xóa task.
- Thay đổi nhiều task.
- Thay đổi kế hoạch dài hạn.
- Reschedule hàng loạt.
- Tạo hàng loạt task.

---

## UI mẫu

```text
AI đề xuất điều chỉnh lịch:

Hôm nay bạn có 3 giờ học
nhưng tổng task cần 4 giờ 15 phút.

Mình đề xuất:

✓ Toán — 60 phút — hôm nay
✓ Lý — 45 phút — hôm nay
→ Anh — chuyển sang ngày mai
→ Hóa — chia thành 2 phiên

[Áp dụng] [Chỉnh lại]
```

---

# 10. Idempotency

AI có thể timeout hoặc người dùng bấm lại.

Không được tạo:

```text
Luyện hàm số
Luyện hàm số
Luyện hàm số
```

Do một request được gửi 3 lần.

Mỗi action cần:

```text
action_id
request_id
user_id
timestamp
```

Backend kiểm tra request đã được thực hiện chưa.

---

# 11. AI Features

## 11.1. Daily Coach

### Input

```text
current_time
today_tasks
overdue_tasks
available_minutes
recent_sessions
```

### Output

```text
1 recommendation
0–2 warnings
0–2 actions
```

Không tạo một đoạn văn dài.

### Ví dụ

> Hôm nay bạn còn 2 giờ. Mình đề xuất bắt đầu bằng Hàm số vì task này gần deadline nhất.

Actions:

```text
[Bắt đầu Hàm số]
[Xem lịch]
```

---

# 12. Study Planner

AI phải lập kế hoạch dựa trên:

- ngày thi;
- mục tiêu;
- môn;
- mức độ hiện tại;
- điểm gần nhất;
- thời gian học/ngày;
- deadline;
- lịch sử học;
- hiệu suất.

### Không được

```text
Tạo 8 task/ngày
```

chỉ vì muốn phủ hết syllabus.

### Phải có

```text
Available Time
    ↓
Required Work
    ↓
Priority
    ↓
Task Allocation
    ↓
Review
```

---

# 13. Task Assistant

Người dùng có thể:

```text
"Tạo cho tôi task ôn hàm số 45 phút."

"Đổi task này sang ngày mai."

"Chia task này thành 3 phần."

"Xóa task này."

"Task này dài quá, giúp tôi chia nhỏ."
```

AI phải nhận biết intent và chuyển thành action.

---

# 14. Weakness Analyzer

Không được nói:

> "Bạn yếu Toán."

nếu chỉ có một session.

Phải có đủ dữ liệu tối thiểu.

Ví dụ:

```text
Subject
├── performance
├── understanding
├── difficulty
├── sessions
└── recent trend
```

### Output

```text
Hàm số

Hiểu bài: thấp
Độ khó cảm nhận: cao
Số session: 5
Tỷ lệ hoàn thành: 60%

Nhận xét:
Bạn đang gặp khó khăn chủ yếu ở phần vận dụng.

Gợi ý:
→ Ôn lại lý thuyết 20 phút
→ Làm 5 câu cơ bản
→ Sau đó mới chuyển sang bài vận dụng
```

---

# 15. Reflection Coach

Sau session:

```text
Bạn cảm thấy thế nào?
😫 😐 🙂 😄 🔥
```

và:

```text
Focus
Difficulty
Understanding
Mood
Effectiveness
```

AI dùng dữ liệu này để điều chỉnh.

### Ví dụ

Nếu:

```text
Math
Difficulty = 5
Understanding = 1
Focus = 2
```

AI có thể:

> Có vẻ phiên học vừa rồi hơi quá sức. Lần sau mình đề xuất chia bài thành các phần 25–30 phút.

---

# 16. Behavioral Intelligence

AI nên phát hiện pattern.

## Pattern 1

```text
Task > 90 phút
↓
thường xuyên reschedule
```

Insight:

> Các task dài đang có khả năng bị trì hoãn.

## Pattern 2

```text
19:00–21:00
completion rate cao
```

Insight:

> Khung giờ buổi tối hiện đang phù hợp với bạn hơn.

## Pattern 3

```text
Subject A
high difficulty
low understanding
repeated failure
```

Insight:

> Cần giảm độ khó đầu vào thay vì tăng thời lượng.

---

# 17. AI phải biết "không đủ dữ liệu"

Ví dụ:

> "Tôi yếu phần nào?"

Nếu mới học 2 session:

```text
Chưa đủ dữ liệu để kết luận chắc chắn.
Hiện tại mình chỉ thấy dấu hiệu khó khăn ở...
```

Không được biến một tín hiệu nhỏ thành kết luận chắc chắn.

---

# 18. Knowledge AI

Đối với câu hỏi học thuật:

```text
User Question
      ↓
Classify
      ↓
Need external knowledge?
      ↓
Retrieval
      ↓
Relevant sources
      ↓
LLM
      ↓
Answer
```

Ưu tiên:

1. Nội dung học tập được người dùng cung cấp.
2. Tài liệu đáng tin cậy.
3. Knowledge base của EduPulse.
4. Web search nếu sản phẩm hỗ trợ.

AI phải phân biệt:

```text
Known
Retrieved
Inferred
Uncertain
```

---

# 19. Prompt Architecture

Không nên dùng một prompt khổng lồ cho tất cả chức năng.

Nên chia:

```text
system_prompt
+
context
+
task_prompt
+
output_schema
```

Ví dụ:

```text
System:
Bạn là gia sư cá nhân của EduPulse.

Context:
...

Task:
Xác định 1–2 task nên ưu tiên hôm nay.

Constraints:
- Không tạo task mới.
- Không thay đổi lịch.
- Không bịa dữ liệu.

Output:
JSON schema.
```

---

# 20. Prompt Rules

AI phải:

- ưu tiên dữ liệu thật;
- không bịa;
- không khẳng định quá mức;
- trả lời ngắn khi request đơn giản;
- giải thích rõ khi có hành động;
- không hỏi lại nếu context đã đủ;
- chỉ hỏi khi thiếu dữ liệu quan trọng;
- không lặp lại thông tin người dùng đã biết;
- không đưa quá nhiều lựa chọn.

---

# 21. AI UI

## Home

```text
Gia sư cá nhân

Hôm nay bạn còn 2 giờ học.

Mình đề xuất:
Hàm số — 45 phút

[ Bắt đầu học ]
```

## Task Detail

```text
Hàm số
Toán · 45 phút

AI:
Task này hơi dài.
Bạn muốn chia thành 2 phiên?

[Chia nhỏ]
```

## After Session

```text
Bạn vừa học 45 phút.

Bạn cảm thấy thế nào?

😫 😐 🙂 😄 🔥

AI:
Mình thấy hôm nay phần này khá khó.
Lần sau có thể giảm phiên xuống 30 phút.
```

---

# 22. Chat Screen

Chat không nên là trung tâm sản phẩm.

### Quick Actions

```text
[Hôm nay học gì?]
[Lập kế hoạch]
[Tôi yếu phần nào?]
[Giải thích bài này]
[Điều chỉnh lịch]
```

Sau khi request hoàn thành, AI nên dẫn người dùng về hành động:

```text
AI → Recommendation → Action
```

thay vì:

```text
AI → 10 đoạn hội thoại → không làm gì
```

---

# 23. Model Routing

Không phải request nào cũng dùng model lớn.

```text
Simple classification
→ Small/Fast model

Recommendation
→ Medium model

Complex planning
→ Strong model

Knowledge explanation
→ Retrieval + suitable model
```

Có thể triển khai sau khi hệ thống ổn định.

---

# 24. Cost Optimization

## Không gọi AI khi:

- chỉ cần sort task;
- tính countdown;
- tính tổng thời gian;
- kiểm tra deadline;
- tính completion rate;
- filter task;
- xác định overdue.

## Có thể gọi AI khi:

- cần reasoning;
- cần giải thích;
- cần lập kế hoạch;
- cần phân tích pattern;
- cần chuyển request tự nhiên thành action.

---

# 25. Caching

Có thể cache:

- Daily recommendation;
- Weekly insight;
- Subject analysis;
- Stable profile summary.

Không nên cache:

- current task status;
- countdown;
- realtime schedule;
- action execution result.

---

# 26. Context Compression

Không gửi:

```text
100 study sessions đầy đủ
```

Mà tạo summary:

```json
{
  "math": {
    "sessions": 12,
    "avg_focus": 3.1,
    "avg_understanding": 2.4,
    "trend": "improving"
  }
}
```

Sau đó chỉ lấy raw session khi AI cần điều tra sâu.

---

# 27. Feedback Loop

Sau mỗi AI response có thể có:

```text
👍
👎
```

Nếu 👎:

```text
Sai kiến thức
Không hiểu câu hỏi
Giải thích khó hiểu
Nguồn không đáng tin
Quá dài
Quá ngắn
Khác
```

Lưu feedback để đánh giá chất lượng.

Không nên chỉ lưu rating.

Cần:

```text
response_id
feature
model
prompt_version
context_version
feedback
reason
timestamp
```

---

# 28. AI Observability

Mỗi AI request nên có:

```text
request_id
user_id
feature
model
prompt_version
input_tokens
output_tokens
latency
success
error_type
action_type
confirmation_required
feedback
```

### Metrics

```text
AI success rate
AI error rate
average latency
token usage
cost/request
thumbs up rate
action completion rate
hallucination reports
```

---

# 29. AI Safety & Guardrails

## Không được

- tự ý xóa dữ liệu;
- tự ý thay đổi kế hoạch dài hạn;
- bịa điểm số;
- bịa tiến độ;
- bịa nguồn;
- nói chắc chắn khi dữ liệu chưa đủ;
- tạo hàng loạt task không kiểm soát.

## Phải

- validate input;
- validate output;
- giới hạn action;
- confirmation cho destructive actions;
- log action;
- rollback khi có thể.

---

# 30. Error Handling

## AI timeout

```text
Mình chưa xử lý được yêu cầu này.
Bạn có thể thử lại.
```

## AI unavailable

```text
AI đang tạm thời không khả dụng.

Bạn vẫn có thể:
→ Xem task hôm nay
→ Bắt đầu học
→ Tự chỉnh lịch
```

## Invalid output

Không đưa output lỗi trực tiếp lên UI.

```text
LLM
 ↓
Schema validation
 ↓
Invalid
 ↓
Retry / fallback
 ↓
Safe response
```

---

# 31. Offline Strategy

EduPulse nên vẫn hoạt động khi AI offline.

### Offline được

- xem task;
- hoàn thành task;
- study session;
- timer;
- xem progress đã cache.

### Offline không được

- AI chat;
- AI planning;
- AI analysis mới.

UI:

```text
AI hiện không khả dụng khi offline.
Các chức năng học tập cơ bản vẫn hoạt động.
```

---

# 32. Data Privacy

AI chỉ nhận dữ liệu cần thiết.

Không gửi:

```text
toàn bộ database user
```

Mà gửi:

```text
minimum necessary context
```

Tách:

```text
Personal Profile
Learning Data
AI Context
AI Logs
```

và có chính sách retention phù hợp.

---

# 33. AI Feature Priority

| Feature | Priority | LLM | Rule | Action |
|---|---:|---:|---:|---:|
| Daily recommendation | P0 | ✓ | ✓ | ✓ |
| Task creation | P0 | ✓ |  | ✓ |
| Task edit | P0 | ✓ |  | ✓ |
| Reschedule | P0 | ✓ | ✓ | ✓ |
| Explain | P0 | ✓ |  |  |
| Study plan | P1 | ✓ | ✓ | ✓ |
| Weakness analysis | P1 | ✓ | ✓ |  |
| Reflection | P1 | ✓ | ✓ |  |
| Behavioral insight | P1 | ✓ | ✓ |  |
| Knowledge/RAG | P2 | ✓ |  |  |
| Model routing | P2 | ✓ |  |  |

---

# 34. Sprint triển khai AI

## AI Sprint 1 — Foundation

### Backend

- [ ] Context schema
- [ ] AI request model
- [ ] AI response model
- [ ] AI action schema
- [ ] Request ID
- [ ] Idempotency
- [ ] Logging

### AI

- [ ] System prompt
- [ ] Context prompt
- [ ] JSON output
- [ ] Schema validation
- [ ] Basic retry

### Frontend

- [ ] AI service layer
- [ ] Loading state
- [ ] Error state
- [ ] Action preview
- [ ] Confirmation modal

### QA

- [ ] Invalid output
- [ ] Timeout
- [ ] Duplicate request
- [ ] Empty context

### Definition of Done

- AI request có schema.
- AI response được validate.
- Action không được chạy trực tiếp từ text tự do.
- Duplicate request không tạo duplicate task.

---

# 35. AI Sprint 2 — Context Engine

### Backend

- [ ] User context
- [ ] Exam context
- [ ] Task context
- [ ] Study history summary
- [ ] Behavior summary

### AI

- [ ] Context selection
- [ ] Context compression
- [ ] Context priority
- [ ] Missing-data handling

### QA

- [ ] Current task context
- [ ] Today context
- [ ] Full planning context
- [ ] Insufficient data

### Definition of Done

AI nhận đúng context theo từng loại request.

---

# 36. AI Sprint 3 — Daily Coach

### Features

- [ ] Today recommendation
- [ ] Overload detection
- [ ] Deadline detection
- [ ] Task prioritization
- [ ] Start-task action

### Definition of Done

Mở Home có thể nhận được recommendation phù hợp mà không cần mở chatbot.

---

# 37. AI Sprint 4 — Task Assistant

### Features

- [ ] Natural language task creation
- [ ] Edit
- [ ] Delete
- [ ] Reschedule
- [ ] Split task
- [ ] Bulk planning

### Definition of Done

Người dùng có thể quản lý task bằng ngôn ngữ tự nhiên.

---

# 38. AI Sprint 5 — Learning Intelligence

### Features

- [ ] Weakness analysis
- [ ] Study session analysis
- [ ] Behavioral pattern
- [ ] Subject trend
- [ ] Personalized suggestions

### Definition of Done

AI có thể giải thích recommendation dựa trên dữ liệu thực tế.

---

# 39. AI Sprint 6 — Optimization

### Features

- [ ] Rule engine
- [ ] LLM call reduction
- [ ] Context caching
- [ ] Model routing
- [ ] Token optimization
- [ ] AI analytics

### Target

Giảm các LLM call không cần thiết và giảm context dư thừa mà không làm giảm chất lượng recommendation.

---

# 40. Frontend Component Checklist

```text
AICard
AIMessage
AIQuickActions
AIRecommendation
AIActionPreview
AIConfirmation
AIErrorState
AIThinkingState
AIContextBadge
AIInsightCard
AIPlanPreview
AIFeedback
```

---

# 41. Backend Service Checklist

```text
AIService
ContextService
ContextBuilder
RuleEngine
ActionService
ActionValidator
ActionExecutor
AIResponseValidator
AIAnalyticsService
AIFeedbackService
```

---

# 42. Suggested API

## POST `/api/ai/chat`

```json
{
  "message": "Hôm nay tôi nên học gì?",
  "context_type": "today"
}
```

## POST `/api/ai/action`

```json
{
  "action_id": "action_123",
  "action_type": "reschedule_task",
  "payload": {}
}
```

## GET `/api/ai/context/today`

Trả context đã tổng hợp cho AI.

## POST `/api/ai/feedback`

```json
{
  "response_id": "response_123",
  "rating": "negative",
  "reason": "Quá dài"
}
```

---

# 43. Acceptance Criteria

## Context

- [ ] AI không nhận thừa dữ liệu.
- [ ] Context đúng request.
- [ ] Context có timestamp.
- [ ] Dữ liệu thiếu được đánh dấu.

## Reasoning

- [ ] Recommendation có lý do.
- [ ] Không kết luận từ dữ liệu quá ít.
- [ ] Không bịa dữ liệu.

## Actions

- [ ] Action có schema.
- [ ] Action được validate.
- [ ] Destructive action có confirmation.
- [ ] Action có idempotency.

## UX

- [ ] AI không làm phiền.
- [ ] AI luôn dẫn tới hành động cụ thể.
- [ ] Không bắt người dùng chat nếu quick action đủ.
- [ ] Loading/error/empty state đầy đủ.

## Performance

- [ ] Rule engine xử lý các logic deterministic.
- [ ] Không gọi LLM cho các phép tính đơn giản.
- [ ] Context được nén.
- [ ] Có timeout.
- [ ] Có retry/fallback.

---

# 44. Bộ test AI tối thiểu

## Task

```text
"Tạo task học Toán 45 phút."
"Đổi task này sang ngày mai."
"Chia task này thành 2 phần."
"Xóa task này."
```

## Planning

```text
"Hôm nay tôi có 1 tiếng, nên học gì?"
"Tôi chỉ có 30 phút tối nay."
"Lịch của tôi đang quá tải."
```

## Learning

```text
"Tôi yếu phần nào?"
"Tại sao tôi học mãi không hiểu phần này?"
"Giải thích bài này."
```

## Edge Cases

```text
Không có task
Không có exam
Không có study history
Không có deadline
Không đủ thời gian
Offline
AI timeout
AI trả JSON lỗi
User gửi request hai lần
```

---

# 45. Những thứ KHÔNG nên làm

## 1. Không biến AI thành chatbot bắt buộc

Sai:

```text
Mở app
→ Chat với AI
→ mới biết hôm nay học gì
```

Đúng:

```text
Mở app
→ thấy task
→ AI hỗ trợ khi cần
```

## 2. Không dùng AI cho mọi thứ

Countdown không cần AI.

Sort task không cần AI.

Tính tổng thời gian không cần AI.

## 3. Không để AI tự ý thay đổi dữ liệu

Mọi action phải qua Action Layer.

## 4. Không tạo quá nhiều recommendation

Một recommendation tốt > 7 recommendation chung chung.

## 5. Không dùng AI để thay thế UX

Nếu người dùng chỉ cần nút:

> "Bắt đầu học"

thì đừng bắt họ nói:

> "AI, hãy giúp tôi bắt đầu task này."

---

# 46. KPI đề xuất

## Product KPI

### Time to First Study

Thời gian từ:

```text
Open app
→ Start Study
```

Mục tiêu: giảm tối đa.

### Recommendation Acceptance Rate

```text
recommendation shown
→ user accepts
```

### AI Action Completion Rate

```text
AI action proposed
→ action successfully executed
```

### Task Recovery Rate

Số task được cứu khỏi overdue/reschedule bằng AI.

---

## AI Quality KPI

```text
AI response success rate
AI thumbs-up rate
Action success rate
Invalid output rate
Hallucination report rate
Average latency
Average token usage
Cost per successful action
```

Không nên tối ưu chỉ theo số lượng AI messages.

---

# 47. Product Principle cuối cùng

EduPulse không cần trở thành:

> "Ứng dụng có thật nhiều AI."

Mục tiêu nên là:

> **"Ứng dụng học tập biết người dùng đang ở đâu, biết họ cần làm gì tiếp theo và giúp họ làm việc đó với ít ma sát nhất."**

AI tốt nhất trong EduPulse là AI mà người dùng **không cần nghĩ về việc đang sử dụng AI**.

Họ chỉ cảm thấy:

> "EduPulse hiểu hôm nay mình cần học gì."

---

# 48. Thứ tự triển khai khuyến nghị

```text
PHASE 1
Context Engine
      ↓
PHASE 2
Structured Output + Action Layer
      ↓
PHASE 3
Daily Coach
      ↓
PHASE 4
Task Assistant
      ↓
PHASE 5
Study Reflection
      ↓
PHASE 6
Weakness Analysis
      ↓
PHASE 7
Behavior Intelligence
      ↓
PHASE 8
RAG / Knowledge
      ↓
PHASE 9
Model Routing + Cost Optimization
```

## MVP AI

Nếu cần làm nhanh, chỉ cần:

```text
1. Context Engine
2. Daily Recommendation
3. Explain
4. Create Task
5. Reschedule Task
6. Action Confirmation
7. AI Feedback
```

Sau khi 7 phần này ổn định mới mở rộng sang weakness analysis, behavioral intelligence và adaptive planning.

---

# 49. Final Definition of Done — AI

EduPulse AI chỉ được coi là hoàn thành khi:

- [ ] AI hiểu context.
- [ ] AI không bịa dữ liệu người dùng.
- [ ] AI output có schema.
- [ ] AI action có validation.
- [ ] Action có idempotency.
- [ ] Action nguy hiểm có confirmation.
- [ ] Rule engine xử lý logic deterministic.
- [ ] LLM chỉ được gọi khi cần.
- [ ] AI có fallback khi lỗi.
- [ ] AI có feedback loop.
- [ ] AI sử dụng study history để cá nhân hóa.
- [ ] AI có thể giải thích recommendation.
- [ ] AI không làm tăng số bước người dùng phải thực hiện.
- [ ] AI không biến Home thành chatbot.
- [ ] Core flow vẫn hoạt động khi AI offline.
- [ ] Có logging và metrics để đánh giá chất lượng.
- [ ] Có test cho happy path, empty state, error, offline và duplicate action.

---

## Kết luận

**Kiến trúc AI ưu tiên của EduPulse:**

```text
          USER
            │
            ▼
      CONTEXT ENGINE
            │
       ┌────┴────┐
       ▼         ▼
   RULE ENGINE  AI ENGINE
       │         │
       └────┬────┘
            ▼
      ACTION LAYER
            │
            ▼
      EDU PULSE DATA
            │
            ▼
     LEARNING FEEDBACK
            │
            └──────→ CONTEXT ENGINE
```

Mục tiêu cuối cùng không phải là làm cho AI "nói hay hơn".

Mục tiêu là làm cho AI:

**Hiểu đúng → Quyết định hợp lý → Hành động an toàn → Học từ kết quả → Giảm tải cho học sinh.**
