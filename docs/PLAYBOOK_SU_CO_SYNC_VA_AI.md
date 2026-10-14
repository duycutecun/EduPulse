# Playbook xử lý sự cố sync và AI

Tài liệu vận hành cho giai đoạn beta (kế hoạch cải tổ, mục 10 — "có playbook hỗ
trợ lỗi sync/AI"). Mục tiêu: khi có sự cố, bất kỳ ai trực cũng biết **kiểm tra
gì, ở đâu, và làm gì tiếp** mà không cần đọc lại toàn bộ mã nguồn.

Nguyên tắc chung:

- App phải **dùng được khi offline** và **khi AI không khả dụng**. Không có
  tính năng lõi nào phụ thuộc AI để hoạt động.
- Không thu thập nội dung học tập để điều tra sự cố. Chỉ dùng tín hiệu ẩn danh
  (`ProductAnalytics`, xem `docs/DU_LIEU_VA_PHIEN_BAN.md`) khi người dùng đã
  bật đồng ý, cộng với phản hồi người dùng tự gửi.

---

## 1. Sự cố đồng bộ (sync)

### 1.1. Dấu hiệu

- Thanh trạng thái đồng bộ báo lỗi hoặc treo ở "đang đồng bộ".
- Dữ liệu tạo trên một thiết bị không xuất hiện trên thiết bị khác.
- Sau khi khôi phục mạng, thay đổi cục bộ không được đẩy lên cloud.

### 1.2. Kiểm tra nhanh (theo thứ tự)

1. **Mạng và đăng nhập.** Xác nhận thiết bị có mạng và đã đăng nhập Supabase.
   Nếu chưa đăng nhập, sync là no-op — không phải lỗi.
2. **Trạng thái hiển thị.** `SyncStatusBar` đọc trạng thái từ `SyncState`
   (`lib/core/sync/sync_state.dart`). Phân biệt: đang chờ, đang chạy, thất bại.
3. **Tín hiệu ẩn danh.** Nếu người dùng đã bật đồng ý, `ProductAnalytics` có
   `sync_succeeded` / `sync_failed` — xem tỉ lệ và thời điểm gần nhất.
4. **Dữ liệu cục bộ còn nguyên?** Kiểm tra prefs/backup: dữ liệu phải còn trên
   máy kể cả khi đẩy lên cloud thất bại (local-first).

### 1.3. Hướng xử lý

| Tình huống | Hành động |
| --- | --- |
| Lỗi mạng tạm thời | Để người dùng thử lại; hàng đợi cục bộ giữ thay đổi và đẩy lại sau. |
| Xung đột dữ liệu | Không ghi đè âm thầm; ưu tiên bản mới nhất theo dấu thời gian, ghi log để rà soát. |
| Sync treo lâu | Khởi động lại app; nếu vẫn treo, dùng **Xuất JSON (đầy đủ)** để sao lưu trước khi thao tác gì thêm. |
| Nghi mất dữ liệu | Dừng ghi đè, trích **Xuất JSON** từ thiết bị còn dữ liệu, đối chiếu thủ công trước khi đồng bộ lại. |

### 1.4. Sau sự cố

- Ghi lại cách tái hiện, phạm vi ảnh hưởng và thời điểm.
- Bổ sung test hồi quy vào `test/` (xem các test sync sẵn có) trước khi đóng
  sự cố.

---

## 2. Sự cố AI

### 2.1. Dấu hiệu

- AI trả lời lỗi, treo trạng thái tải, hoặc không phản hồi sau thời gian chờ.
- Hành động AI đề xuất không xuất hiện preview/confirm.
- Chất lượng câu trả lời suy giảm rõ rệt.

### 2.2. Kiểm tra nhanh

1. **Fallback không-AI.** Mọi điểm vào AI phải có cách thao tác thủ công
   (tạo task tay, không dùng AI). Xác nhận luồng chính vẫn chạy.
2. **Trạng thái tải/lỗi.** UI phải hiện trạng thái tải, lỗi dễ hiểu, nút **thử
   lại** — không để màn trắng.
3. **Tín hiệu ẩn danh.** Khi đã đồng ý: `ai_action_requested`,
   `ai_action_applied`, `ai_action_failed` (chỉ loại hành động, không nội dung).
4. **Cấu hình.** AI managed đi qua backend serverless; người dùng có thể tự dán
   key BYOK trong **Tài khoản → Cloud & AI**. Thiếu cấu hình là nguyên nhân phổ
   biến — kiểm tra thông báo lỗi có nêu rõ không.

### 2.3. Hướng xử lý

| Tình huống | Hành động |
| --- | --- |
| AI không khả dụng | Người dùng tiếp tục app bình thường; không chặn luồng học. |
| Action AI sai/không mong muốn | Cho phép **từ chối** và **hoàn tác**; không tự sửa kế hoạch/xoá dữ liệu. |
| Phản hồi chậm | Timeout + retry giới hạn; hiện tiến trình thay vì treo. |
| Nội dung không chính xác | Hiện mức độ tin cậy và nguồn khi có tra cứu; nhắc người dùng kiểm chứng. |

### 2.4. Sau sự cố

- Bổ sung/cập nhật fixture kiểm thử cho prompt liên quan (parse kế hoạch, tạo
  task) để chống tái diễn.
- Không ghi lại nội dung hội thoại của người dùng vào log.

---

## 3. Liên hệ và kênh phản hồi

- **Trong app:** Tài khoản → **Gửi phản hồi beta**. Phản hồi lưu cục bộ; người
  dùng chủ động **chia sẻ** khi muốn gửi cho nhóm phát triển.
- Khi nhận báo lỗi: hỏi phiên bản build, thiết bị, các bước tái hiện và thời
  điểm — không hỏi nội dung học tập.

---

## 4. Ngưỡng leo thang

- Lỗi làm **mất hoặc sai dữ liệu học tập** → xử lý như sự cố P0, dừng phát hành.
- Sync hoặc AI hỏng toàn cục cho nhiều người → thông báo tạm thời, ưu tiên
  fallback thủ công.
- Lỗi lẻ, có cách vòng tránh → đưa vào backlog P1/P2, kèm test hồi quy.
