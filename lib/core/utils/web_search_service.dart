import 'dart:convert';
import 'package:http/http.dart' as http;

/// Kết quả tra cứu nhanh từ Wikipedia (nguồn miễn phí, không cần key).
class WebLookup {
  final String title;
  final String extract;
  final String pageUrl;

  const WebLookup({
    required this.title,
    required this.extract,
    required this.pageUrl,
  });

  /// Chuỗi ngữ cảnh nhét vào prompt cho AI.
  String toPromptBlock() {
    final ex = extract.trim();
    return '--- THAM KHẢO TỪ WEB (Wikipedia: $title) ---\n'
        '$ex\n'
        '(Nguồn: $pageUrl)\n'
        '--- HẾT THAM KHẢO ---';
  }
}

/// Tra cứu web để cung cấp thông tin tham khảo cho AI Coach.
///
/// Dùng Wikipedia REST Summary API (miễn phí, không cần key, có CORS cho
/// Flutter web). Ưu tiên tiếng Việt, fallback tiếng Anh.
class WebSearchService {
  static const String _userAgent = 'EduPulse/1.0 (study assistant)';

  /// Tra cứu tóm tắt cho [query]. Trả về `null` nếu không tìm thấy nguồn.
  static Future<WebLookup?> lookup(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final slug = _slugify(q);

    for (final lang in ['vi', 'en']) {
      final url =
          'https://$lang.wikipedia.org/api/rest_v1/page/summary/$slug';
      try {
        final resp = await http
            .get(Uri.parse(url), headers: {'Api-User-Agent': _userAgent})
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode != 200) continue;

        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final extract = (data['extract'] as String?)?.trim() ?? '';
        final title = (data['title'] as String?)?.trim() ?? '';
        if (extract.isEmpty || title.isEmpty) continue;

        String pageUrl;
        try {
          pageUrl = data['content_urls']?['desktop']?['page'] as String? ?? '';
        } catch (_) {
          pageUrl = '';
        }
        if (pageUrl.isEmpty) {
          pageUrl = 'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title)}';
        }

        return WebLookup(title: title, extract: extract, pageUrl: pageUrl);
      } catch (_) {
        // Thử ngôn ngữ khác hoặc trả null.
      }
    }
    return null;
  }

  /// Chuyển truy vấn thành slug chuẩn (thay khoảng trắng bằng gạch dưới).
  static String _slugify(String s) {
    final trimmed = s.trim().replaceAll(RegExp(r'\s+'), '_');
    return Uri.encodeComponent(trimmed);
  }
}
