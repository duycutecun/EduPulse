import 'package:flutter/material.dart';

import '../../../../core/ai/ai_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Thẻ "Cloud & AI": nhập cấu hình ngay trong app.
///
/// Bản web lấy Supabase/Firebase/API key từ biến môi trường của Vercel lúc
/// build. Bản cài trên máy (`.ipa`/`.apk`) chỉ có những giá trị đó nếu người
/// build truyền `--dart-define` — thiếu là "không kết nối được database,
/// không dùng được AI" mà người dùng không có cách nào sửa. Thẻ này cho dán
/// thẳng khoá vào máy (lưu cục bộ, không gửi đi đâu khác) để bản cài dùng
/// được ngay, không cần build lại.
class CloudAiCard extends StatefulWidget {
  const CloudAiCard({super.key});

  @override
  State<CloudAiCard> createState() => _CloudAiCardState();
}

class _CloudAiCardState extends State<CloudAiCard> {
  bool _expanded = false;
  bool _obscureKeys = true;

  late final TextEditingController _urlCtrl;
  late final TextEditingController _anonCtrl;
  late final TextEditingController _openRouterCtrl;
  late final TextEditingController _geminiCtrl;

  @override
  void initState() {
    super.initState();
    // Ô Supabase hiện giá trị đang có hiệu lực (để người dùng thấy bản cài đã
    // có sẵn cấu hình hay chưa); ô API key chỉ hiện key người dùng đã dán,
    // không bao giờ in key đóng gói trong bản build ra màn hình.
    _urlCtrl = TextEditingController(text: StorageService.getSupabaseUrl());
    _anonCtrl = TextEditingController(text: StorageService.getSupabaseAnonKey());
    _openRouterCtrl =
        TextEditingController(text: AiConfig.storedOpenRouterKey);
    _geminiCtrl = TextEditingController(text: AiConfig.storedGeminiKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _anonCtrl.dispose();
    _openRouterCtrl.dispose();
    _geminiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloudReady = SupabaseService.isConfigured;
    final aiReady = AiConfig.hasOpenRouter || AiConfig.hasGemini;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                cloudReady || aiReady
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                tileSize: 36,
                iconSize: 18,
                color: cloudReady || aiReady
                    ? AppColors.primary
                    : AppColors.orange,
                bg: cloudReady || aiReady
                    ? AppColors.greenSoft
                    : AppColors.orangeSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cloud & AI của bản cài này',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      'Database: ${cloudReady ? 'đã kết nối' : 'chưa cấu hình'} • '
                      'AI: ${aiReady ? 'sẵn sàng' : 'thiếu API key'}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: cloudReady && aiReady
                              ? AppColors.textSecondary
                              : AppColors.orangeDark),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('cloud-ai-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Đóng' : 'Thiết lập'),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            const Text(
              'Dán cấu hình của bạn vào đây. Chỉ lưu trên máy này, không gửi '
              'tới server nào khác.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.35, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            _field(
              key: const Key('cloud-supabase-url'),
              controller: _urlCtrl,
              label: 'Supabase URL',
              hint: 'https://xxxx.supabase.co',
            ),
            const SizedBox(height: 10),
            _field(
              key: const Key('cloud-supabase-anon'),
              controller: _anonCtrl,
              label: 'Supabase anon key',
              hint: 'eyJhbGciOi…',
              obscure: _obscureKeys,
            ),
            const SizedBox(height: 10),
            _field(
              key: const Key('cloud-openrouter-key'),
              controller: _openRouterCtrl,
              label: 'OpenRouter API key (cho AI)',
              hint: 'sk-or-v1-…',
              obscure: _obscureKeys,
            ),
            const SizedBox(height: 10),
            _field(
              key: const Key('cloud-gemini-key'),
              controller: _geminiCtrl,
              label: 'Gemini API key (tùy chọn)',
              hint: 'AIza…',
              obscure: _obscureKeys,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _obscureKeys = !_obscureKeys),
                  icon: Icon(
                    _obscureKeys
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 16,
                  ),
                  label: Text(_obscureKeys ? 'Hiện khoá' : 'Ẩn khoá',
                      style: const TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('cloud-ai-clear'),
                  onPressed: _clearAll,
                  child: const Text('Xoá khoá đã dán',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              key: const Key('cloud-ai-save'),
              onTap: _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.primaryDark,
                        blurRadius: 0,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: const Center(
                  child: Text('Lưu cấu hình',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AiConfig.hasBuildTimeOpenRouter
                  ? 'Bản build đã có sẵn API key — chỉ cần dán khi bạn muốn dùng key riêng.'
                  : 'Bản build này chưa nhúng API key, nên AI chỉ chạy sau khi bạn dán key ở trên.',
              style: const TextStyle(
                  fontSize: 11, height: 1.35, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextField(
          key: key,
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  void _save() {
    final url = _urlCtrl.text.trim();
    final anon = _anonCtrl.text.trim();
    // Cấu hình cloud chỉ được đọc lúc khởi động (Supabase client là singleton),
    // nên đổi URL/key cần mở lại app — nói thẳng thay vì để người dùng tưởng
    // đã xong mà vẫn thấy "chưa kết nối".
    final cloudChanged = url != StorageService.getSupabaseUrl().trim() ||
        anon != StorageService.getSupabaseAnonKey().trim();

    StorageService.setSupabaseUrl(url);
    StorageService.setSupabaseAnonKey(anon);
    AiConfig.setOpenRouterApiKey(_openRouterCtrl.text);
    AiConfig.setGeminiApiKey(_geminiCtrl.text);

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        cloudChanged
            ? 'Đã lưu. Mở lại app để kết nối Database bằng cấu hình mới.'
            : 'Đã lưu — AI dùng key mới ngay, không cần mở lại app.',
      ),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _clearAll() {
    StorageService.setSupabaseUrl('');
    StorageService.setSupabaseAnonKey('');
    AiConfig.setOpenRouterApiKey('');
    AiConfig.setGeminiApiKey('');
    AiConfig.setTavilyApiKey('');
    _urlCtrl.text = '';
    _anonCtrl.text = '';
    _openRouterCtrl.text = '';
    _geminiCtrl.text = '';
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã xoá cấu hình bạn dán — app quay về cấu hình của bản build.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
