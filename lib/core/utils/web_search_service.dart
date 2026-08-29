import 'dart:convert';
import 'package:http/http.dart' as http;

/// Kết quả tra cứu web thời gian thực từ Tavily Search API.
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
    return '--- THAM KHẢO TỪ WEB (Tra cứu thời gian thực: $title) ---\n'
        '$ex\n'
        '(Nguồn: $pageUrl)\n'
        '--- HẾT THAM KHẢO ---';
  }
}

/// Tra cứu web thời gian thực cho AI Coach.
///
/// Ưu tiên Tavily Search API (kết quả real-time, thiết kế cho LLM), do app
/// owner cấp key `TAVILY_API_KEY`. Nếu chưa có key, fallback về Wikipedia
/// (miễn phí, không tìm được dữ liệu thời gian thực).
class WebSearchService {
  static const String _tavilyUrl = 'https://api.tavily.com/search';
  static const String _userAgent = 'EduPulse/1.0 (study assistant)';

  /// Tra cứu thời gian thực qua Tavily. Trả về `null` nếu thất bại.
  static Future<WebLookup?> lookup(String query, {String? tavilyApiKey}) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    // Nếu có Tavily key → tra cứu real-time.
    if (tavilyApiKey != null && tavilyApiKey.isNotEmpty) {
      final result = await _tavily(q, tavilyApiKey);
      if (result != null) return result;
      // Tavily fail → fallback Wikipedia bên dưới.
    }

    return _wikipedia(q);
  }

  static Future<WebLookup?> _tavily(String query, String apiKey) async {
    try {
      final resp = await http
          .post(
            Uri.parse(_tavilyUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'api_key': apiKey,
              'query': query,
              'max_results': 3,
              'search_depth': 'basic',
              'include_answer': true,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      // Ưu tiên câu trả lời ngắn (answer) do Tavily tổng hợp.
      final answer = (data['answer'] as String?)?.trim() ?? '';
      if (answer.isNotEmpty) {
        return WebLookup(
          title: 'Tavily',
          extract: answer,
          pageUrl: 'https://tavily.com',
        );
      }

      final results = (data['results'] as List?) ?? [];
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final content = (first['content'] as String?)?.trim() ?? '';
      final title = (first['title'] as String?)?.trim() ?? 'Kết quả';
      final url = (first['url'] as String?)?.trim() ?? '';
      if (content.isEmpty) return null;
      return WebLookup(title: title, extract: content, pageUrl: url);
    } catch (_) {
      return null;
    }
  }

  static Future<WebLookup?> _wikipedia(String query) async {
    final slug = _slugify(query);
    for (final lang in ['vi', 'en']) {
      final url = 'https://$lang.wikipedia.org/api/rest_v1/page/summary/$slug';
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
      } catch (_) {}
    }
    return null;
  }

  /// Chuyển truy vấn thành slug chuẩn (thay khoảng trắng bằng gạch dưới).
  static String _slugify(String s) {
    final trimmed = s.trim().replaceAll(RegExp(r'\s+'), '_');
    return Uri.encodeComponent(trimmed);
  }
}
