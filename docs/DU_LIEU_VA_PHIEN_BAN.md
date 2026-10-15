# Dữ liệu cục bộ & phiên bản (mục 7.1 kế hoạch)

Tài liệu này là **bản kiểm kê (inventory)** các dữ liệu app lưu trên máy, và
quy tắc **phiên bản hoá** chúng. Mục tiêu:

- Ai cũng biết khoá nào đang tồn tại ở đâu, thuộc loại nào.
- Đổi data model phải đi kèm migration idempotent, **không mất dữ liệu**.
- Không lưu nội dung học tập/nội dung chat thô vào analytics.

Mọi dữ liệu dưới đây lưu trong `SharedPreferences` qua `StorageService`
(`lib/core/utils/storage_service.dart`). Khoá là chuỗi thường (snake_case);
khoá dạng bản ghi dùng tiền tố + `id` (vd `task_<id>`).

## 1. Phân loại dữ liệu

| Loại | Khoá | Ở đâu | Ghi chú |
| --- | --- | --- | --- |
| Trạng thái app | `onboarding_done` | `StorageService` | bool |
| Hồ sơ người dùng | `user_name`, `user_target`, `account_role`, `email_verified`, `user_uuid` | `StorageService` | `account_role` ∈ {`student`,`parent`} |
| Vai trò/tài khoản | `auth_remember_email` | `AuthScreen` | chỉ email gợi ý, không mật khẩu |
| Chuỗi & XP | `streak`, `streak_record`, `streak_freeze_count`, `last_study_date`, `user_xp` | `StorageService` | số nguyên/ngày ISO |
| Kỳ thi | `exam_ids` (StringList), `exam_<id>` (JSON), `primary_exam_id` | `StorageService` | |
| Nhiệm vụ | `today_task_ids` (StringList), `task_<id>` (JSON) | `StorageService` | JSON `TodayTask` |
| Phiên focus | `study_session_ids`, `study_session_<id>` | `StorageService` | JSON `StudySession` |
| Nhật ký học cũ | `study_log_ids`, `study_log_<id>` | `StorageService` | dữ liệu legacy, đã ngưng sinh |
| Ghi chú | `study_note_ids`, `study_note_<id>`, `note_draft_v1` | `StorageService` | `note_draft_v1` là bản nháp tự lưu |
| Điểm thi thử | `mock_score_ids`, `mock_score_<id>` | `StorageService` | JSON `MockScore` |
| Tài liệu đính kèm | `task_attachments_<taskId>` (StringList), `task_attachment_<taskId>_<id>` | `StorageService` | base64 tách khỏi JSON task |
| Mục tiêu môn | `subject_targets` | `SupabaseService` | map môn → điểm mục tiêu |
| Linh vật | `mascot_enabled`, `mascot_equipped_accessory`, `mascot_bond_exp`, `mascot_last_fortune_date`, `mascot_last_fortune_text` | `StorageService` | |
| Giao diện | `appearance_font_scale`, `appearance_high_contrast`, `reduce_motion`, `desktop_sidebar_collapsed` | `AppearanceService`/`AccountScreen` | a11y |
| Phản hồi/rung | `sound_enabled`, `haptics_enabled` | `FeedbackService` | |
| Nhắc nhở | `reminder_enabled`, `reminder_hour`, `reminder_minute`, `daily_study_reminder`, `notif_digest_enabled`, `notif_advanced_enabled`, `notif_in_focus`, `notif_last_open` | `NotificationService`/`AdaptivePolicy` | `notif_in_focus` là cờ phiên |
| Gia đình | `my_family`, `child_reports`, `email_digest`, `family_live_share`, `family_last_checkin`, `family_live_fingerprint`, `family_notify_enabled`, `family_notify_seen` | `core/family/*` | có consent |
| Đồng bộ | `sync_outbox_v1`, `last_cloud_sync_ms`, `exam_pending_deletes`, `sync_outbox_corrupt` | `core/sync/*` | hàng đợi ý định |
| Sao lưu/khôi phục | `backup_blob_index`, `backup_prev_snapshot`, `backup_schema`, `backup_device_id`, `backup_fingerprint`, `backup_synced_at_ms` | `BackupService` | |
| Cloud config | `supabase_url`, `supabase_anon_key` | `StorageService` | fallback compile-time |
| AI cấu hình (BYOK) | `ai_gemini_key`, `ai_openrouter_key`, `ai_tavily_key`, `ai_model`, `ai_permission_read`, `ai_permission_analyze`, `ai_auto_read_image` | `core/ai/*` | 3 khoá AI lưu trong **kho an toàn OS** (`SecureStore`), **không log**; phần còn lại trong `SharedPreferences` |
| AI cache/bộ nhớ | `ai_memory_summary`, `ai_feedback_ids`, `ai_feedback_patterns_v1`, `ai_response_cache_v1`, `ai_briefing_v1`, `ai_briefing_day_v1`, `ai_insights_v1`, `ai_insights_time_v1`, `ai_weekly_report_v1`, `ai_chat_history_v1`, `free_models_cache_v1`, `free_models_cache_time_v1`, `adaptive_quiz_performance_v1`, `flashcard_ids`, `content_urls` | `core/ai/*` | cache có thể xoá an toàn |
| Sự kiện sản phẩm | `analytics_consent`, `product_events` | `ProductAnalytics` | opt-in, cục bộ, không PII |
| Phiên bản schema | `data_schema_version` | `DataMigration` | số nguyên |

Ghi chú chung:

- **Khoá dạng `prefix_<id>`** là bản ghi riêng lẻ; danh sách id đi kèm ở khoá
  `<prefix>_ids`. Xoá bản ghi luôn đi đôi với gỡ id khỏi danh sách.
- **Cache** (`ai_response_cache_v1`, `free_models_cache_v1`, `content_urls`,
  `ai_briefing_v1`, …) có thể bị xoá bất cứ lúc nào mà không mất dữ liệu người
  dùng.
- **Không** lưu mật khẩu, token phiên hay nội dung bài học/chat thô vào
  `SharedPreferences` ngoài phạm vi trên.

## 2. Phiên bản hoá

- Phiên bản schema dữ liệu local nằm ở khoá `data_schema_version`
  (hằng `DataMigration.currentSchemaVersion`).
- Khi đổi data model → **tăng** `currentSchemaVersion` và thêm một
  `MigrationStep` **idempotent** vào `DataMigration.defaultSteps()`.
- `DataMigration.run()` chạy lúc khởi động (`main.dart`) theo trình tự:
  1. Snapshot toàn bộ prefs.
  2. Chạy từng bước; lỗi giữa chừng → **rollback + restore snapshot**.
  3. Thành công → ghi `data_schema_version`.
- Lịch sử phiên bản: v1 (chuẩn hoá `TodayTask`), v2 (backfill timestamp, heal
  `status`/`isDone`, cứu task mồ côi — BE-2.3), v3 (xoá `StudyLog` Pomodoro
  trùng — STUDY-LOG-MERGE).
- JSON bản ghi hỏng **được giữ nguyên**, không tự xoá; người dùng có thể xuất
  dữ liệu để tự soát.

## 3. Quy tắc khi thêm dữ liệu mới

1. Ưu tiên thêm field vào model với giá trị mặc định + parse tương thích ngược
   (xem `TodayTask.fromJsonString`) trước khi nghĩ tới migration nặng.
2. Nếu buộc đổi shape/location → thêm `MigrationStep` + tăng version.
3. Thêm khoá mới vào bảng kiểm kê ở mục 1.
4. Cập nhật test migration (`test/widget_test.dart` — nhóm "Data migration").
