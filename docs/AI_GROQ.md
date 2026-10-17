# AI Free — Groq (AI chính)

> Tính từ bản 10/2026: **Groq là AI chính** (free & nhanh nhất), Gemini giữ
> nhiệm vụ **đọc ảnh** + là phương án dự phòng cuối, OpenRouter giữ nguyên
> (không xoá). Tham chiếu đặc tả: `BAN_THAY_DOI V2` mục **M3.4**
> (token đầu < 5s, fallback ≥ 99% / 30 ngày).

## 1. Vì sao Groq

| Provider | Vai trò | Miễn phí | Tốc độ |
| --- | --- | --- | --- |
| **Groq** | AI chính cho câu hỏi chỉ-text (chat, quiz, planner, briefing…) | ~30 req/phút, ~1000 req/ngày | first-token ~0.35s với `openai/gpt-oss-20b` |
| Gemini | Đọc ảnh (model free của Groq **không** nhận image input — decided) + fallback cuối | có | nhanh |
| OpenRouter | Catalog model phụ; giữ nguyên cho ai ghim model cũ | có | tuỳ model |

Giới hạn free của Groq tính **~8K tokens/phút bao gồm cả `max_tokens` của
request**, nên proxy `api/groq.js` đặt `max_tokens` mặc định ~1200 (thấp hơn
2048 của `/api/openrouter`) để tránh bị từ chối vì vượt TPM.

## 2. Kiến trúc đọc nhanh

```
Flutter (AiRouter — lib/core/ai/ai_router.dart)
  ├─ slug 'groq/openai/gpt-oss-20b' | 'groq/openai/gpt-oss-120b'
  │     → GroqService (lib/core/ai/groq_service.dart) → proxy /api/groq
  ├─ slug 'gemini/gemini-3.7-flash' (mọi request kèm ẢNH ưu tiên nhánh này)
  │     → GeminiService (lib/core/utils/gemini_service.dart) → proxy /api/gemini
  └─ slug ':free' của OpenRouter → proxy /api/openrouter
```

- `api/groq.js` — proxy serverless cùng origin; logic thuần nằm
  `api/_groq_logic.js` (test: `api/_groq_logic.test.js`, chạy `node --test`).
- Fallback: `AiRouter` thử tối đa 6 ứng viên, **mỗi model một lần** (không
  vòng lặp): Groq 20b → Groq 120b → OpenRouter → **Gemini luôn giữ một slot**.
  Ảnh → bắt đầu từ Gemini. Lỗi 429/5xx/timeout của Groq đều là chuỗi '❌... '
  để client bấm nhánh kế tiếp.
- Model mặc định khi người dùng **chưa ghim** model nào là Groq 20b; người
  dùng đã ghim vẫn giữ lựa chọn của họ (`StorageService.getAiModel()`).

## 3. Việc Owner cần làm (một lần)

1. Tạo API key miễn phí tại <https://console.groq.com/keys> — không cần thẻ.
2. Đặt trong **Vercel → Project → Settings → Environment Variables**:
   `GROQ_API_KEY=gsk_...` (Production + Preview + Development), rồi deploy lại.
   Kiểm nhanh: mở `GET /api/groq` trên staging/trình duyệt — trả
   `{"ok":true,"configured":true,...}`.
   - Khác với OpenRouter/Gemini, key Groq chỉ đọc phía serverless;
     **KHÔNG** đưa vào dart-define / `.env` build client.
3. Cập nhật `.env` cục bộ theo `env.example` (thêm dòng `GROQ_API_KEY=`)
   nếu bạn chạy proxy ở môi trường dev (`vercel dev` / unit test cần env).

## 4. Privacy (gọn)

- Groq hoạt động theo chế độ **no-training** (dữ liệu không được dùng để
  train model, xem chính sách tại <https://groq.com/privacy>); app vẫn khuyến
  khích bật quyền AI theo mục §8 trong `docs/QUYEN_RIENG_TU_VA_LUU_TRO.md`.
- Nhật ký audit của proxy (`api/_guard.js`) đang khử nhạy cảm sẵn — không ghi
  prompt/nội dung chat.
