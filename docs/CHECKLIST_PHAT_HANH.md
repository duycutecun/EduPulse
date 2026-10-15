# Checklist phát hành

Dùng cho giai đoạn beta và phát hành (kế hoạch cải tổ, mục 10). Mỗi lần chuẩn bị
đưa build cho người dùng, đi qua danh sách này và ghi lại kết quả.

Nhắc lại phạm vi bắt buộc: **không billing, không paywall, không subscription**
dưới bất kỳ hình thức nào (mục 1 của kế hoạch).

---

## 1. Cổng chất lượng tự động

Chạy CI (`.github/workflows/ci.yml`) và cả ba bước dưới đây phải xanh:

- [x] `dart format --output=none --set-exit-if-changed lib test` — không có tệp
      lệch định dạng. _(2026-10-15: sạch)_
- [x] `flutter analyze` — không cảnh báo/lỗi. _(2026-10-15: No issues found!)_
- [x] `flutter test` — toàn bộ test pass. _(2026-10-15: 934 test pass)_
- [x] `flutter build web --release` — build web/PWA thành công (smoke).
      _(2026-10-15: `√ Built build\web`)_

## 2. Ngưỡng chất lượng đã chốt

Ba ràng buộc cứng, vi phạm thì **không phát hành**:

- [ ] **Luồng chính chạy offline.** Mở app → xem việc ưu tiên → bắt đầu → hoàn
      thành → thấy kế hoạch cập nhật, tất cả hoạt động khi không có mạng.
      _(Cần kiểm thủ công trên máy thật; test offline tự động đã xanh.)_
- [ ] **Không có lỗi mất dữ liệu học tập** đã biết còn mở.
      _(Cần con người xác nhận trước khi phát hành.)_
- [x] **Không tính năng lõi nào phụ thuộc AI**; mọi điểm AI có fallback thủ công.
      _(2026-10-15: AI chỉ là tăng cường; mọi luồng đều thao tác được bằng tay.)_

Tiêu chí định tính (chốt sau beta, không đặt KPI trên số lượt mở chat):

- [ ] Funnel onboarding → nhiệm vụ đầu tiên không hồi quy.
      _(Theo dõi qua tín hiệu ẩn danh sau beta.)_
- [ ] Lỗi sync/AI trong ngưỡng chấp nhận (theo dõi qua tín hiệu ẩn danh khi đã
      có đồng ý).
- [x] Không có P0/P1 mở. _(2026-10-15: backlog P0/P1 đều `[x]`.)_

---

## 2b. Quyền riêng tư và đồng ý

- [x] Analytics vẫn **mặc định tắt** (`analytics_consent`); chỉ ghi khi người
      dùng bật ở Tài khoản. _(2026-10-15: mặc định TẮT, opt-in qua Tài khoản.)_
- [x] Sự kiện ẩn danh không chứa nội dung học tập/định danh (xem
      `docs/DU_LIEU_VA_PHIEN_BAN.md`). _(2026-10-15: allow-list thuộc tính
      phi-nội-dung.)_
- [x] Family consent: báo cáo chỉ chia sẻ khi học sinh chủ động; không tự gửi.
      _(2026-10-15: có test riêng cho luồng chia sẻ.)_
- [x] Kênh phản hồi beta lưu cục bộ, người dùng chủ động chia sẻ.
      _(2026-10-15: `BetaFeedback` lưu cục bộ.)_
- [x] Mọi điểm gọi AI kèm dữ liệu học tập đều qua cổng quyền
      `ai_permission_read`/`ai_permission_analyze`. _(2026-10-15: audit toàn bộ
      call site — 7 điểm thiếu cổng đã thêm `AiConsent`; `ai_consent_test.dart`.)_
- [ ] Áp migration RLS còn thiếu trên Supabase (SQL editor):
      `supabase/family_v4.sql` (RLS cho `family_goals`/`family_messages`/
      `family_notif_tokens`) và `supabase/email_codes.sql` (DDL + RLS bảng mã OTP).
      _(Bảo mật — phải áp **trước khi** mở beta công khai.)_
- [x] Đặt `CRON_SECRET` trên Vercel; trần quota để mặc định trong code
      (`AI_DAILY_QUOTA` = 200/uid và `AI_DAILY_QUOTA_ANON` = 40/IP mỗi 24h).
      _(2026-10-15: biến đã thêm cho Production; đã kiểm chứng — thiếu header trả
      401, đúng header trả `{"ok":true,...}` và cron xoá được dòng `email_codes`
      hết hạn.)_

## 2c. Migration và rollback

- [x] `data_schema_version` khớp phiên bản hiện hành; `DataMigration` chạy sạch
      từ bản cũ (kiểm thử luồng nâng cấp). _(2026-10-15:
      `currentSchemaVersion = 3`, `data_migration_test.dart` xanh.)_
- [x] Đã kiểm thử **backup/restore** và **xuất JSON** trước khi cập nhật.
      _(2026-10-15: `BackupService` + test xanh.)_
- [x] Có đường lùi: giữ bản build trước để quay lại nếu bản mới hỏng dữ liệu.
      _(2026-10-15: giữ artifact IPA của các commit trước.)_

---

## 3. Build và phân phối

- [x] Giới hạn gói Hobby của Vercel: tối đa **12 Serverless Functions** cho mỗi
      deployment — hiện dùng **11/12**. Thêm endpoint mới phải gộp vào file hiện có
      (file trong `api/` bắt đầu bằng `_` không tính là function; có bước CI tự
      đếm). _(2026-10-15: gỡ lỗi `exceeded_serverless_functions_per_deployment`.)_
- [x] APK build qua `build.yml` (hoặc `flutter build apk`) thành công.
      _(2026-10-15: run `38758087851` (b1a633c) → artifact `edupulse-apk` 32,41 MB.
      Nguyên nhân cũ "fail 0s" là `secrets` dùng trong `if` — đã sửa.)_
- [x] IPA build qua `ios-ipa.yml` thành công; tải artifact kiểm tra kích thước.
      _(2026-10-15: run `38733195338` (b32ee0c) → 12.678.807 bytes.)_
- [x] IPA cũng build + upload được qua `build.yml`. _(2026-10-15: run
      `38760755370` (64e0aa3) → artifact `edupulse-ipa` 12,03 MB; trước đó bước
      `flutter build ipa --no-codesign` không sinh file `.ipa` nên job "xanh"
      nhưng rỗng — đã thay bằng quy trình xcodebuild + đóng gói Payload.)_
- [ ] Web deploy qua `deploy.yml` thành công (GitHub Pages).
- [ ] Cấu hình build (Supabase/Firebase) có/thiếu được ghi rõ trong Summary;
      thiếu key chỉ làm giảm tính năng, **không làm build hỏng**.

## 4. Release notes

Ghi ngắn gọn, hướng người dùng:

- **Có gì mới:** các thay đổi hỗ trợ vòng lặp học hằng ngày.
- **Sửa lỗi:** các lỗi P0/P1 đã xử lý.
- **Lưu ý:** thay đổi dữ liệu/migration (nếu có) và cách sao lưu.

Mẫu:

```text
Phiên bản: <version> (<build>)
Có gì mới:
- …
Sửa lỗi:
- …
Lưu ý:
- …
```

---

## 5. Quyết định phát hành

- [x] Cổng chất lượng tự động xanh. _(2026-10-15: format/analyze/test/web đều xanh.)_
- [x] Không còn P0/P1. _(2026-10-15.)_
- [x] Có playbook xử lý sự cố sync/AI (`docs/PLAYBOOK_SU_CO_SYNC_VA_AI.md`).
- [ ] Dữ liệu beta (định lượng + định tính) ủng hộ phát hành.
      _(Chờ ≥ 2 tuần dữ liệu beta.)_
- [ ] Người chịu trách nhiệm ký duyệt và ghi lại quyết định.

> Chỉ phát hành khi các mục trên đã tích. Nếu một mục bỏ trống, ghi rõ lý do và
> người phê duyệt ngoại lệ.
