# 🧠 Kế Hoạch Phát Triển AI — EduPulse "Bộ Não Thông Minh"

> **Mục tiêu:** Biến EduPulse thành ứng dụng có **bộ não AI thực sự** — hiểu người dùng, tự quản lý tác vụ, đưa ra gợi ý dựa trên dữ liệu thật, và tự động hóa mọi thứ có thể.
>
> **Nguyên tắc vàng:** AI chỉ nói điều có bằng chứng. Không bịa. Không đoán. Mọi gợi ý đều truy về dữ liệu thật.

---

## 📊 Hiện Trạng AI — Đánh Giá Honest

### ✅ Đã có (nền tảng tốt)
| Thành phần | Vai trò | Đánh giá |
|---|---|---|
| `AiRouter` | Điều phối model, failover 6 model | ✅ Vững |
| `AiStudyContext` | 13 section dữ liệu thật → prompt | ✅ Tốt |
| `AiChatActionParser` | Parse 8 loại action từ AI | ✅ Tốt |
| `AiCopilotService` | Thực thi action + situation report | ✅ Tốt |
| `ReadinessScore` | Điểm số 0-100 từ 5 yếu tố | ✅ Tốt |
| `StudyRhythm` | Phân tích giờ học, môn yếu, burnout | ✅ Tốt |
| `WeaknessAnalyzer` | Phân tích điểm yếu offline | ✅ Tốt |
| `AiInsights` | Gợi ý proactive (6h cache) | ✅ Tốt |
| `AiDailyBriefing` | Briefing hàng ngày (AI + offline) | ✅ Tốt |
| `AiRefreshService` | Bridge data-change → AI refresh | ✅ Tốt |
| `AiStudyPlannerService` | Lập kế hoạch 7 ngày + preview | ✅ Tốt |
| `FlashcardService` | Flashcard SM-2 + AI generate | ✅ Tốt |

### ⚠️ Thiếu (cần xây mới)
| Vấn đề | Tác động | Mức độ |
|---|---|---|
| Không có streaming response | User đợi 10-30s không có feedback | 🔴 Cao |
| Không có conversation memory | Chat giới hạn 40 messages, mất context | 🔴 Cao |
| Không có proactive notifications | AI chỉ hoạt động khi mở app | 🔴 Cao |
| Không có predictive analytics | Không dự đoán điểm số, không cảnh báo sớm | 🔴 Cao |
| Không có semantic search | Search chỉ keyword, không hiểu ý nghĩa | 🟡 Trung |
| Không có voice input | Không hỏi AI bằng giọng nói | 🟡 Trung |
| Không có cross-session learning | AI không học từ feedback quá khứ | 🟡 Trung |
| Không có adaptive difficulty | Quiz cùng độ khó cho mọi người | 🟡 Trung |
| Không có AI content generation | Không tạo bài tập, essay, study guide | 🟡 Trung |
| Không có emotion detection | Wellbeing chỉ dựa self-rating | 🟢 Thấp |
| Không có multi-device AI sync | AI history không đồng bộ | 🟢 Thấp |

---

## 🏗️ Kiến Trúc AI Đề Xuất — "EduPulse Brain"

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EDUPULSE BRAIN                               │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Perception  │  │   Memory     │  │      Reasoning           │  │
│  │  (Cảm nhận)  │  │   (Ký ức)    │  │      (Lập luận)          │  │
│  │              │  │              │  │                          │  │
│  │ • Dữ liệu    │  │ • Short-term │  │ • ReadinessScore         │  │
│  │   thật       │  │   (40 msgs)  │  │ • StudyRhythm            │  │
│  │ • Context    │  │ • Long-term  │  │ • WeaknessAnalyzer       │  │
│  │   levels     │  │   (summary)  │  │ • PredictiveEngine       │  │
│  │ • Web search │  │ • Feedback   │  │ • SituationDetector      │  │
│  │ • Image OCR  │  │   history    │  │ • ActionRecommender      │  │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘  │
│         │                 │                       │                 │
│         └────────┬────────┴───────────────────────┘                 │
│                  │                                                  │
│         ┌────────┴────────┐                                        │
│         │   Orchestrator  │  ← Điều phối mọi thứ                   │
│         │   (AiBrain)     │                                        │
│         └────────┬────────┘                                        │
│                  │                                                  │
│    ┌─────────────┼─────────────┐                                   │
│    │             │             │                                   │
│    ▼             ▼             ▼                                   │
│ ┌──────┐   ┌──────────┐   ┌──────────┐                            │
│ │ Chat │   │ Automation│   │ Proactive│                            │
│ │(Nói) │   │ (Tự làm)  │   │(Chủ động)│                            │
│ └──────┘   └──────────┘   └──────────┘                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Sprint AI — 5 Giai Đoạn

### Sprint AI-1: Nhận Thức & Ký Ức (Perception & Memory)
> **Mục tiêu:** AI hiểu người dùng sâu hơn, nhớ nhiều hơn, không bị mất thông tin.

#### AI-1.1: Conversation Memory System
**Vấn đề:** Chat giới hạn 40 messages, không có long-term memory.

**Giải pháp:**
- Tạo `AiMemoryService` — lưu trữ summary của mỗi conversation
- Khi chat đạt 30 messages → tự động tạo summary → lưu vào long-term memory
- Khi chat mới bắt đầu → inject summary cũ vào context
- Lưu: key topics discussed, decisions made, user preferences revealed

**File mới:** `lib/core/ai/ai_memory_service.dart`
**Data:** `ai_memory_summary` trong SharedPreferences (JSON, max 5000 chars)

#### AI-1.2: Streaming Response
**Vấn đề:** User đợi 10-30s không có feedback.

**Giải pháp:**
- Thêm `AiRouter.chatStream()` — trả về `Stream<String>`
- Hiển thị text từng chunk trong chat bubble
- Hiện "Đang suy nghĩ..." với animation khi chưa có chunk đầu
- Fallback: nếu model không hỗ trợ streaming → dùng blocking như cũ

**File sửa:** `lib/core/ai/ai_router.dart`, `lib/features/ai_coach/presentation/widgets/chat_bubble.dart`

#### AI-1.3: Feedback Learning Loop
**Vấn đề:** AI không học từ feedback (thumbs up/down) của user.

**Giải pháp:**
- Tạo `AiFeedbackLearner` — phân tích pattern feedback
- Nếu user thường dislike câu trả lời dài → giảm max_tokens
- Nếu user thường dislike câu trả lời thiếu data → tăng context level
- Lưu preferences: `ai_feedback_patterns` trong SharedPreferences

**File mới:** `lib/core/ai/ai_feedback_learner.dart`

---

### Sprint AI-2: Lập Luận & Dự Đoán (Reasoning & Prediction)
> **Mục tiêu:** AI không chỉ mô tả quá khứ mà còn dự đoán tương lai, đưa ra cảnh báo sớm.

#### AI-2.1: Predictive Analytics Engine
**Vấn đề:** App chỉ hiển thị quá khứ, không dự đoán tương lai.

**Giải pháp:**
- Tạo `PredictiveEngine` — dự đoán điểm số, khả năng đạt mục tiêu
- Input: mock scores history, study pace, days left, readiness score
- Output: "Với nhịp học hiện tại, bạn sẽ đạt 7.2 (mục tiêu: 8.0). Cần tăng 30 phút/ngày."
- Hiển thị trên Home screen dưới dạng card "Dự đoán"

**File mới:** `lib/core/ai/predictive_engine.dart`
**Data:** Tính toán từ MockScore + StudySession + ExamModel có sẵn

#### AI-2.2: Early Warning System
**Vấn đề:** Không có cảnh báo sớm khi user đang đi sai hướng.

**Giải pháp:**
- Tạo `EarlyWarningService` — phát hiện vấn đề sớm
- Các tình huống cảnh báo:
  - "3 ngày không học môn X" → cảnh báo bỏ bê
  - "Điểm Y giảm 2 lần liên tiếp" → cảnh báo xu hướng
  - "Còn 7 ngày, chưa ôn 40% chương trình" → cảnh báo thời gian
  - "Focus score giảm 3 tuần liên tiếp" → cảnh báo burnout
- Hiển thị dưới dạng banner trên Home + notification

**File mới:** `lib/core/ai/early_warning_service.dart`

#### AI-2.3: Cross-Subject Correlation
**Vấn đề:** AI không thấy mối liên hệ giữa các môn (ví dụ: yếu Toán → yếu Vật lý).

**Giải pháp:**
- Tạo `CrossSubjectAnalyzer` — tìm correlation giữa các môn
- Phân tích: nếu học Toán tốt → Vật lý có tốt không?
- Đưa ra gợi ý: "Bạn yếu hàm số → nên ôn lại trước khi làm bài Vật lý dao động"

**File mới:** `lib/core/ai/cross_subject_analyzer.dart`

---

### Sprint AI-3: Chủ Động & Tự Động Hóa (Proactive & Automation)
> **Mục tiêu:** AI không chỉ chờ user hỏi mà chủ động gợi ý, tự động xử lý việc nhỏ.

#### AI-3.1: Proactive Notification System
**Vấn đề:** AI chỉ hoạt động khi mở app.

**Giải pháp:**
- Tạo `AiNotificationService` — push notification thông minh
- Các notification thông minh:
  - "Đến giờ học Toán rồi" (dựa trên peak hour pattern)
  - "Hôm nay chưa học, còn 2 task nữa" (streak protection)
  - "Điểm Vật lý vừa cập nhật, xem phân tích" (data change)
  - "Còn 3 ngày thi, xem checklist ôn thi" (exam countdown)
- Timing thông minh: gửi lúc user thường học (từ StudyRhythm.peakHour())
- Respect quiet hours (22h-7h)

**File mới:** `lib/core/ai/ai_notification_service.dart`
**Cần:** `flutter_local_notifications` package

#### AI-3.2: Auto-Scheduler
**Vấn đề:** User phải tự sắp xếp lịch, AI chỉ gợi ý.

**Giải pháp:**
- Tạo `AutoSchedulerService` — tự động sắp xếp lịch tối ưu
- Input: tasks, peak hours, subject balance, exam countdown
- Output: lịch tối ưu cho 7 ngày tới
- User có thể accept/reject từng ngày
- Học từ accept/reject pattern để cải thiện suggestion

**File mới:** `lib/core/ai/auto_scheduler_service.dart`

#### AI-3.3: Smart Task Generator
**Vấn đề:** AI tạo task nhưng không dựa trên curriculum thật.

**Giải pháp:**
- Tạo `SmartTaskGenerator` — tạo task dựa trên exam syllabus
- Input: exam type (THPTQG/TSA/HSA), subject, days left
- Output: task list theo chương trình thi thực tế
- Ưu tiên: chương trình trọng số cao + môn yếu + chưa ôn

**File mới:** `lib/core/ai/smart_task_generator.dart`
**Cần:** Dữ liệu syllabus từng kỳ thi (có thể hardcode hoặc fetch)

---

### Sprint AI-4: Tương Tác Nâng Cao (Advanced Interaction)
> **Mục tiêu:** AI giao diện tự nhiên hơn — voice, semantic search, adaptive content.

#### AI-4.1: Voice Input
**Vấn đề:** Không thể hỏi AI bằng giọng nói.

**Giải pháp:**
- Tạo `VoiceInputService` — speech-to-text
- Dùng `speech_to_text` package (hỗ trợ tiếng Việt)
- Mic button trong chat input
- Fallback: nếu STT fail → hiện lỗi, giữ text input

**File mới:** `lib/core/ai/voice_input_service.dart`
**Cần:** `speech_to_text` package + microphone permission

#### AI-4.2: Semantic Search
**Vấn đề:** Search chỉ keyword, không hiểu ý nghĩa.

**Giải pháp:**
- Tạo `SemanticSearchService` — tìm kiếm theo ngữ nghĩa
- Dùng embedding model (OpenRouter có text-embedding)
- Index: tasks, notes, sessions, chat history
- Khi search "bài khó hiểu" → tìm được "bài khó", "bài chưa hiểu"

**File mới:** `lib/core/ai/semantic_search_service.dart`
**Cần:** Embedding model API (OpenRouter hoặc local)

#### AI-4.3: Adaptive Quiz
**Vấn đề:** Quiz cùng độ khó cho mọi người.

**Giải pháp:**
- Tạo `AdaptiveQuizEngine` — điều chỉnh độ khó theo năng lực
- Bắt đầu ở mức trung bình
- Đúng liên tiếp → tăng độ khó
- Sai liên tiếp → giảm độ khó + giải thích chi tiết
- Lưu performance per topic → ưu tiên topic yếu

**File mới:** `lib/core/ai/adaptive_quiz_engine.dart`

---

### Sprint AI-5: Tối Ưu & Hoàn Thiện (Optimization & Polish)
> **Mục tiêu:** AI nhanh hơn, thông minh hơn, tiết kiệm hơn.

#### AI-5.1: Response Caching
**Vấn đề:** Cùng một câu hỏi → gọi API lại.

**Giải pháp:**
- Tạo `AiResponseCache` — cache response theo hash của (question + context)
- TTL: 1 hour cho câu hỏi chung, 5 phút cho câu hỏi có context thay đổi
- Invalidate khi data thay đổi (qua AiRefreshService)

**File mới:** `lib/core/ai/ai_response_cache.dart`

#### AI-5.2: Model Selection Intelligence
**Vấn đề:** Model do user chọn hoặc Auto, không thông minh.

**Giải pháp:**
- Tạo `ModelSelector` — tự chọn model phù hợp
- Query đơn giản → model nhanh, rẻ
- Query phức tạp (có image, cần reasoning) → model mạnh
- Query cần web search → model hỗ trợ tool calling
- Học từ success rate của từng model

**File mới:** `lib/core/ai/model_selector.dart`

#### AI-5.3: Token Optimization
**Vấn đề:** Context 2500 chars nhưng không tối ưu.

**Giải pháp:**
- Tạo `ContextOptimizer` — nén context thông minh
- Ưu tiên: data quan trọng nhất (readiness, tasks, scores)
- Bỏ: data ít quan trọng (flashcard count, note titles)
- Dynamic: tăng/giảm context level theo query complexity

**File mới:** `lib/core/ai/context_optimizer.dart`

---

## 🔐 Hệ Thống Phân Quyền AI — "AI Được Làm Gì"

### Nguyên tắc: 3 tự động, 4 cần xác nhận, 3 bị cấm

### ✅ Tự động (không cần xác nhận)
| Hành động | Giải thích |
|---|---|
| Đọc dữ liệu học tập | AI đọc tasks, sessions, scores để hiểu context |
| Gợi ý nội dung | AI đưa ra suggestion, không tự thực thi |
| Tạo summary | AI tóm tắt notes, sessions, chat |
| Phân tích xu hướng | AI phân tích dữ liệu và báo cáo |
| Sắp xếp thứ tự task | AI reorder tasks theo ưu tiên |

### ⚠️ Cần xác nhận (AI đề xuất, user quyết định)
| Hành động | Giải thích |
|---|---|
| Tạo task mới | AI gợi ý task, user bấm "Tạo" |
| Sửa task | AI đề xuất thay đổi, user xác nhận |
| Dời lịch task | AI gợi ý ngày mới, user accept |
| Xóa task | AI gợi ý xóa, user xác nhận (type "XOA") |
| Lập kế hoạch | AI tạo plan, user preview + accept |
| Gửi notification | AI chọn timing, user có thể tắt |

### 🚫 Bị cấm (AI không được làm)
| Hành động | Giải thích |
|---|---|
| Xóa dữ liệu học tập | Không bao giờ tự xóa sessions, scores, notes |
| Thay đổi điểm số | AI không được sửa mock scores |
| Gửi dữ liệu ra ngoài | Không gửi data lên server không phải Supabase |
| Tự động mua/kích hoạt | Không có tính năng purchase |

---

## 📊 Data Flow — AI Nhìn Thấy Gì, Dùng Thế Nào

### AI Context Map (13 sections, 2500 chars)
```
┌─────────────────────────────────────────────────────────┐
│                    AI CONTEXT                           │
│                                                         │
│  Profile (50 chars)     → Hiển thị tên, mục tiêu       │
│  Exam (200 chars)       → Đếm ngược, phase, scores     │
│  Momentum (100 chars)   → Streak, level, EXP            │
│  Readiness (300 chars)  → Điểm 0-100, factors, levers  │
│  Tasks (400 chars)      → Hôm nay, overdue, skipped     │
│  Sessions (300 chars)   → Focus minutes, by-subject     │
│  Patterns (200 chars)   → Peak hours, focus issues      │
│  Wellbeing (150 chars)  → Burnout risk, mood            │
│  Logs (150 chars)       → Total hours, by-subject       │
│  Mock Scores (200 chars)→ Per-subject, weakest/strongest│
│  Notes (100 chars)      → Count, by-subject, titles     │
│  Flashcards (50 chars)  → Total, due                    │
│  Web Search (variable)  → External context              │
│                                                         │
│  TOTAL: ~2500 chars (có thể mở rộng với optimization) │
└─────────────────────────────────────────────────────────┘
```

### Data → AI Action Mapping
| Dữ liệu | AI Action | Ví dụ |
|---|---|---|
| Streak sắp đứt | Gợi ý học ngay | "Còn 2 giờ nữa là mất streak, học 15 phút thôi?" |
| Môn yếu | Tạo task ôn | "Toán đạt 5.2, cần ôn hàm số + tích phân" |
| Quá giờ học | Cảnh báo burnout | "Học 3 tiếng rồi, nghỉ 15 phút nhé" |
| Sắp thi | Tăng cường ôn | "Còn 5 ngày, ưu tiên ôn chương trọng số cao" |
| Task bị dời nhiều | Gợi ý chia nhỏ | "Task này đã dời 3 lần, chia nhỏ thành 2 phần?" |
| Giờ học tối ưu | Sắp xếp lịch | "Bạn học tốt nhất 19h-21h, đặt task Toán vào giờ này" |

---

## 🔢 Thứ Tự Ưu Tiên Thực Hiện

### Phase 1 — Nền tảng (2 tuần)
```
Tuần 1:
  1. AI-1.1: Conversation Memory System
  2. AI-1.2: Streaming Response
  3. AI-5.1: Response Caching

Tuần 2:
  4. AI-1.3: Feedback Learning Loop
  5. AI-5.2: Model Selection Intelligence
  6. AI-5.3: Token Optimization
```

### Phase 2 — Thông minh hơn (2 tuần)
```
Tuần 3:
  7. AI-2.1: Predictive Analytics Engine
  8. AI-2.2: Early Warning System

Tuần 4:
  9. AI-2.3: Cross-Subject Correlation
  10. AI-3.3: Smart Task Generator
```

### Phase 3 — Chủ động (2 tuần)
```
Tuần 5:
  11. AI-3.1: Proactive Notification System
  12. AI-3.2: Auto-Scheduler

Tuần 6:
  13. AI-4.3: Adaptive Quiz
  14. AI-4.1: Voice Input
```

### Phase 4 — Hoàn thiện (1 tuần)
```
Tuần 7:
  15. AI-4.2: Semantic Search
  16. Integration testing + Polish
```

---

## ✅ Tiêu Chí Kiểm Tra (Acceptance Criteria)

### Chức năng
- [ ] AI nhớ conversation cũ khi chat mới bắt đầu
- [ ] AI response hiển thị từng chữ (streaming)
- [ ] AI dự đoán điểm số dựa trên pace hiện tại
- [ ] AI cảnh báo sớm khi có vấn đề
- [ ] AI gửi notification thông minh (đúng lúc, đúng nội dung)
- [ ] AI tự động sắp xếp lịch tối ưu
- [ ] AI tạo task dựa trên chương trình thi thật
- [ ] AI nhận diện giọng nói tiếng Việt
- [ ] AI search hiểu ngữ nghĩa (keyword "khó" → tìm được "khó hiểu")
- [ ] AI điều chỉnh độ khó quiz theo năng lực

### Chất lượng
- [ ] Mọi AI suggestion đều có bằng chứng dữ liệu
- [ ] AI không bịa ra số liệu không có trong data
- [ ] AI response < 5 giây (với streaming)
- [ ] AI hoạt động offline cho tính năng cơ bản
- [ ] AI không crash app khi API lỗi

### Bảo mật
- [ ] AI không gửi dữ liệu lên server không phải Supabase
- [ ] AI không tự xóa dữ liệu học tập
- [ ] AI không tự sửa điểm số
- [ ] User có thể tắt hoàn toàn AI (permissions)

---

## 📁 File Structure Đề Xuất

```
lib/core/ai/
├── ai_router.dart                    # Điều phối model (có sẵn)
├── ai_context.dart                  # Build context (có sẵn)
├── ai_chat_actions.dart             # Parse actions (có sẵn)
├── ai_copilot_service.dart          # Thực thi actions (có sẵn)
├── ai_insights.dart                 # Gợi ý proactive (có sẵn)
├── ai_daily_briefing.dart           # Briefing hàng ngày (có sẵn)
├── ai_refresh_service.dart          # Data change bridge (có sẵn)
├── ai_sprint4_planner.dart          # Lập kế hoạch (có sẵn)
├── ai_weakness_analyzer.dart        # Phân tích điểm yếu (có sẵn)
├── readiness_score.dart             # Điểm 0-100 (có sẵn)
├── study_rhythm.dart                # Phân tích rhythm (có sẵn)
├── flashcard_service.dart           # Flashcard SM-2 (có sẵn)
├── ai_memory_service.dart           # MỚI: Conversation memory
├── ai_feedback_learner.dart         # MỚI: Học từ feedback
├── predictive_engine.dart           # MỚI: Dự đoán điểm số
├── early_warning_service.dart       # MỚI: Cảnh báo sớm
├── cross_subject_analyzer.dart      # MỚI: Correlation giữa các môn
├── ai_notification_service.dart     # MỚI: Notification thông minh
├── auto_scheduler_service.dart      # MỚI: Tự động sắp xếp lịch
├── smart_task_generator.dart        # MỚI: Tạo task từ syllabus
├── voice_input_service.dart         # MỚI: Speech-to-text
├── semantic_search_service.dart     # MỚI: Tìm kiếm ngữ nghĩa
├── adaptive_quiz_engine.dart        # MỚI: Quiz thích ứng
├── ai_response_cache.dart           # MỚI: Cache response
├── model_selector.dart              # MỚI: Chọn model thông minh
└── context_optimizer.dart           # MỚI: Tối ưu context
```

---

## 🎯 Tóm Tắt — 3 Nguyên Tắc Cốt Lõi

1. **Dữ liệu thật → AI thật:** Mọi suggestion đều truy về dữ liệu thật. Không bịa. Không đoán.
2. **Tự động hóa có kiểm soát:** AI tự làm việc nhỏ, đề xuất việc lớn. User luôn là người quyết định cuối.
3. **Học hỏi không ngừng:** AI càng dùng càng thông minh — học từ feedback, học từ pattern, học từ lỗi.
