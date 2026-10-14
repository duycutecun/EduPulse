# Checklist phát hành

Dùng cho giai đoạn beta và phát hành (kế hoạch cải tổ, mục 10). Mỗi lần chuẩn bị
đưa build cho người dùng, đi qua danh sách này và ghi lại kết quả.

Nhắc lại phạm vi bắt buộc: **không billing, không paywall, không subscription**
dưới bất kỳ hình thức nào (mục 1 của kế hoạch).

---

## 1. Cổng chất lượng tự động

Chạy CI (`.github/workflows/ci.yml`) và cả ba bước dưới đây phải xanh:

- [ ] `dart format --output=none --set-exit-if-changed lib test` — không có tệp
      lệch định dạng.
- [ ] `flutter analyze` — không cảnh báo/lỗi.
- [ ] `flutter test` — toàn bộ test pass.
- [ ] `flutter build web --release` — build web/PWA thành công (smoke).

## 2. Ngưỡng chất lượng đã chốt

Ba ràng buộc cứng, vi phạm thì **không phát hành**:

- [ ] **Luồng chính chạy offline.** Mở app → xem việc ưu tiên → bắt đầu → hoàn
      thành → thấy kế hoạch cập nhật, tất cả hoạt động khi không có mạng.
- [ ] **Không có lỗi mất dữ liệu học tập** đã biết còn mở.
- [ ] **Không tính năng lõi nào phụ thuộc AI**; mọi điểm AI có fallback thủ công.

Tiêu chí định tính (chốt sau beta, không đặt KPI trên số lượt mở chat):

- [ ] Funnel onboarding → nhiệm vụ đầu tiên không hồi quy.
- [ ] Lỗi sync/AI trong ngưỡng chấp nhận (theo dõi qua tín hiệu ẩn danh khi đã
      có đồng ý).
- [ ] Không có P0/P1 mở.

---

## 2b. Quyền riêng tư và đồng ý

- [ ] Analytics vẫn **mặc định tắt** (`analytics_consent`); chỉ ghi khi người
      dùng bật ở Tài khoản.
- [ ] Sự kiện ẩn danh không chứa nội dung học tập/định danh (xem
      `docs/DU_LIEU_VA_PHIEN_BAN.md`).
- [ ] Family consent: báo cáo chỉ chia sẻ khi học sinh chủ động; không tự gửi.
- [ ] Kênh phản hồi beta lưu cục bộ, người dùng chủ động chia sẻ.

## 2c. Migration và rollback

- [ ] `data_schema_version` khớp phiên bản hiện hành; `DataMigration` chạy sạch
      từ bản cũ (kiểm thử luồng nâng cấp).
- [ ] Đã kiểm thử **backup/restore** và **xuất JSON** trước khi cập nhật.
- [ ] Có đường lùi: giữ bản build trước để quay lại nếu bản mới hỏng dữ liệu.

---

## 3. Build và phân phối

- [ ] APK build qua `build.yml` (hoặc `flutter build apk`) thành công.
- [ ] IPA build qua `ios-ipa.yml` thành công; tải artifact kiểm tra kích thước.
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

- [ ] Cổng chất lượng tự động xanh.
- [ ] Không còn P0/P1.
- [ ] Có playbook xử lý sự cố sync/AI (`docs/PLAYBOOK_SU_CO_SYNC_VA_AI.md`).
- [ ] Dữ liệu beta (định lượng + định tính) ủng hộ phát hành.
- [ ] Người chịu trách nhiệm ký duyệt và ghi lại quyết định.

> Chỉ phát hành khi các mục trên đã tích. Nếu một mục bỏ trống, ghi rõ lý do và
> người phê duyệt ngoại lệ.
