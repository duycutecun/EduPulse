import 'dart:convert';
import 'package:http/http.dart' as http;

/// Kết quả tra cứu web thời gian thực.
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
/// - Trên Web: gọi endpoint serverless `/api/search` (cùng origin, key Tavily
///   giữ phía Vercel — không lộ trong client, không gặp lỗi CORS).
/// - Trên mobile (không có serverless): fallback Wikipedia (tĩnh).
/// - Mọi trường hợp khi endpoint lỗi/không có → fallback Wikipedia.
class WebSearchService {
  static const String _userAgent = 'EduPulse/1.0 (study assistant)';

  /// Tra cứu thời gian thực. Trả về `null` nếu không tìm được nguồn.
  static Future<WebLookup?> lookup(String query, {String? tavilyApiKey}) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    if (_onWeb) {
      final result = await _viaProxy(q);
      if (result != null) return result;
    } else {
      final result = await _viaServer(q, tavilyApiKey);
      if (result != null) return result;
      // Server-direct chỉ dùng khi có key; nếu fail thử Wikipedia.
    }

    return _wikipedia(q);
  }

  /// Đang chạy trên nền web (browser) — sử dụng proxies cùng nguồn.
  static bool get _onWeb {
    try {
      return Uri.base.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Gọi endpoint serverless cùng origin (chống CORS, key ẩn phía server).
  static Future<WebLookup?> _viaProxy(String query) async {
    final base = Uri.base.resolve('/api/search');
    final url = base.replace(queryParameters: {'q': query});
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 18));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final extract = (data['extract'] as String?)?.trim() ?? '';
      if (extract.isEmpty) return null;
      return WebLookup(
        title: (data['title'] as String?)?.trim() ?? 'Kết quả',
        extract: extract,
        pageUrl: (data['pageUrl'] as String?)?.trim() ?? 'https://tavily.com',
      );
    } catch (_) {
      return null;
    }
  }

  /// Gọi thẳng Tavily từ client (không dùng trên web vì CORS).
  static Future<WebLookup?> _viaServer(String query, String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) return null;
    try {
      final resp = await http
          .post(
            Uri.parse('https://api.tavily.com/search'),
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
      final answer = (data['answer'] as String?)?.trim() ?? '';
      if (answer.isNotEmpty) {
        return WebLookup(
            title: 'Tavily', extract: answer, pageUrl: 'https://tavily.com');
      }
      final results = (data['results'] as List?) ?? [];
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      return WebLookup(
        title: (first['title'] as String?)?.trim() ?? 'Kết quả',
        extract: (first['content'] as String?)?.trim() ?? '',
        pageUrl: (first['url'] as String?)?.trim() ?? '',
      );
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
