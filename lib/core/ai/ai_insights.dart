import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;

import 'ai_config.dart';
import '../utils/storage_service.dart';
import 'ai_context.dart';
import 'ai_models.dart';
import 'ai_router.dart';

/// Một gợi ý do AI đưa ra kèm bằng chứng từ dữ liệu học sinh.
class AiInsight {
  const AiInsight({required this.text, this.evidence});

  final String text;

  /// Cụm ngắn chỉ ra gợi ý này dựa trên số liệu nào — để học sinh tin được
  /// thay vì thấy lời khuyên chung chung.
  final String? evidence;

  Map<String, dynamic> toJson() => {'text': text, 'evidence': evidence};

  factory AiInsight.fromJson(Map<String, dynamic> j) => AiInsight(
        text: (j['text'] ?? '').toString(),
        evidence: j['evidence'] as String?,
      );
}

/// Một lần AI phân tích, dùng lại trong [ttl] trước khi gọi lại model.
class AiInsightBundle {
  const AiInsightBundle({
    required this.items,
    required this.generatedAt,
  });

  final List<AiInsight> items;
  final DateTime generatedAt;

  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory AiInsightBundle.fromJson(Map<String, dynamic> j) => AiInsightBundle(
        generatedAt:
            DateTime.tryParse(j['generatedAt'] ?? '') ?? DateTime.now(),
        items: (j['items'] as List? ?? const [])
            .map((e) => AiInsight.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// AI tự chủ động gợi ý việc cần làm (đặc tả mục 10.3).
///
/// Thay vì bắt học sinh ngồi gõ câu hỏi, [AiInsights] lấy đúng khối ngữ
/// cảnh mà `AiStudyContext` dựng sẵn, nhờ model rút ra 2–3 việc cụ thể nên
/// làm ngay, rồi cache lại để mở Home không phải chờ mạng mỗi lần.
///
/// Nguyên tắc:
/// - **Không gọi model khi chưa đủ dữ liệu.** Học sinh mới cài app hoặc đã tắt
///   quyền cho AI đọc dữ liệu thì không có gì để phân tích — gọi lên chỉ tốn
///   quota rồi nhận lời khuyên rỗng.
/// - **Trả về null thay vì ném lỗi.** Model lỗi/429/mất mạng thì Home giữ
///   nguyên gợi ý quy tắc sẵn có; người dùng không thấy card lỗi AI.
/// - Chỉ dùng model free + [AiRouter] failover nên không tốn tiền.
class AiInsights {
  AiInsights._();

  static const String _cacheKey = 'ai_insights_v1';
  static const String _timeKey = 'ai_insights_time_v1';

  /// Bao lâu thì phân tích lại. Đủ để gợi ý "mỗi ngày" nhưng không gọi model
  /// mỗi lần mở app.
  static const Duration ttl = Duration(hours: 6);

  /// Model ưu tiên: nhanh, free, đủ dùng cho việc rút gợi ý ngắn.
  /// [AiRouter] vẫn tự failover nếu model này hết quota.
  static const String _preferredSlug = 'nvidia/nemotron-3.5-lightning:free';

  static const int _maxItems = 3;

  /// Tăng mỗi khi có phân tích mới được ghi cache.
  ///
  /// Card ở Home lắng nghe giá trị này để làm mới ngay khi phân tích xong,
  /// thay vì bắt học sinh điều hướng ra rồi vào lại mới thấy.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Học sinh có đồng ý cho AI phân tích tiến độ không
  /// (công tắc `ai_permission_analyze` trong Tài khoản, mặc định bật).
  static bool get _allowed =>
      StorageService.getBool('ai_permission_analyze') != false;

  /// Có đủ dữ liệu để phân tích không — dùng chính context mà chat dùng để
  /// đảm bảo "AI thấy ở Home" khớp "AI thấy trong khung chat".
  static bool get _hasData => AiStudyContext.build().isNotEmpty;

  /// Đọc bản cache còn hạn. Trả null nếu hết hạn hoặc không có.
  static AiInsightBundle? cached({DateTime? now}) {
    if (!_allowed) return null;
    final raw = StorageService.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    final at = DateTime.tryParse(StorageService.getString(_timeKey) ?? '');
    if (at == null) return null;
    final t = now ?? DateTime.now();
    if (t.difference(at) > ttl) return null;
    try {
      final bundle =
          AiInsightBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return bundle.isEmpty ? null : bundle;
    } catch (_) {
      return null;
    }
  }

  /// Lấy gợi ý: dùng cache nếu còn hạn, ngược lại gọi model.
  static Future<AiInsightBundle?> load({bool force = false}) async {
    if (!_allowed) return null;
    if (!force) {
      final hit = cached();
      if (hit != null) return hit;
    }
    if (!_hasData) return null;
    return refresh();
  }

  /// Gọi model phân tích lại từ đầu. Trả null nếu không thể.
  static Future<AiInsightBundle?> refresh() async {
    if (!_allowed) return null;

    // Chỉ gọi khi có kênh gọi thật (web đi proxy, native cần API key).
    // Không đủ điều kiện → giữ gợi ý quy tắc/cũ, tránh gọi mù và tránh
    // để lại timer treo trong môi trường test.
    if (!(kIsWeb || AiConfig.openRouterApiKey.isNotEmpty)) return null;

    final context = AiStudyContext.build();
    if (context.isEmpty) return null;

    final answer = await AiRouter.chat(
      model: AIModel.fromSlug(_preferredSlug),
      history: const [],
      userMessage: _prompt(context),
      searchWeb: false,
    );

    final items = parse(answer);
    if (items.isEmpty) return null;

    final bundle = AiInsightBundle(items: items, generatedAt: DateTime.now());
    try {
      StorageService.setString(_cacheKey, jsonEncode(bundle.toJson()));
      StorageService.setString(_timeKey, bundle.generatedAt.toIso8601String());
    } catch (_) {
      // Không lưu được cache thì vẫn trả kết quả cho lần hiển thị này.
    }
    revision.value += 1;
    return bundle;
  }

  /// Xoá cache — dùng khi học sinh vừa đổi dữ liệu lớn (đổi kỳ thi chính,
  /// nhập điểm mới) nên phân tích lại ngay.
  static void invalidate() {
    StorageService.setString(_cacheKey, '');
    StorageService.setString(_timeKey, '');
    revision.value += 1;
  }

  static String _prompt(String context) => '''
Dựa trên ngữ cảnh học tập dưới đây của học sinh, hãy đưa ra 2–3 việc cụ thể
học sinh nên làm NGAY BÂY GIỜ, xếp theo mức độ quan trọng.

Quy tắc:
- Cụ thể và làm được hôm nay. Tuyệt đối tránh lời khuyên chung chung kiểu
  "hãy chăm chỉ", "hãy ôn tập đều đặn".
- Bám sát số liệu trong ngữ cảnh: môn đang yếu, số ngày còn lại, nhiệm vụ
  chưa làm hoặc bị bỏ qua, môn đang học nhiều nhưng điểm vẫn thấp.
- Nếu dữ liệu cho thấy học sinh đang ổn (đều đặn, điểm tăng), hãy nói ra
  điều đó thay vì bịa thêm việc.
- Tối đa 3 việc, mỗi việc 1–2 câu ngắn, giọng thân thiện, không ép buộc.

Trả về đúng 3 dòng, mỗi dòng một việc theo mẫu, không thêm tiêu đề hay
giải thích nào khác:
<việc cụ thể> | <bằng chứng ngắn lấy từ số liệu>

Ví dụ:
Dồn buổi ôn Hóa tối nay, điểm môn này đang thấp nhất | Hóa TB 6.0/10, thấp hơn Toán 1.5 điểm

--- NGỮ CẢNH HỌC TẬP ---
$context''';

  /// Đọc câu trả lời của model thành danh sách gợi ý.
  ///
  /// Cố tình "nhạy" với định dạng: model free đôi khi thêm gạch đầu dòng,
  /// số thứ tự hoặc bọc ngoặn. Vì vậy bỏ qua dòng không khớp mẫu thay vì ném
  /// lỗi, và nếu không lấy được gì thì trả list rỗng để caller giữ nguyên
  /// gợi ý quy tắc cũ.
  static List<AiInsight> parse(String raw) {
    final out = <AiInsight>[];
    for (final line in raw.split('\n')) {
      if (out.length >= _maxItems) break;
      final cleaned = _stripBullet(line);
      if (cleaned.length < 12) continue;

      // Chỉ nhận dòng có dạng "<việc> | <bằng chứng>".
      final parts = cleaned.split('|');
      if (parts.length < 2) continue;
      final text = parts.first.trim();
      final evidence = parts[1].trim();
      if (text.length < 12) continue;
      // Bằng chứng quá dài thì cắt lại cho gọn.
      final ev = evidence.length > 90
          ? '${evidence.substring(0, 90).trimRight()}…'
          : evidence;
      out.add(AiInsight(text: text, evidence: ev.isEmpty ? null : ev));
    }
    return out;
  }

  static String _stripBullet(String line) {
    var s = line.trim();
    // Bỏ gạch đầu dòng, bullet, số thứ tự ở đầu dòng.
    s = s.replaceFirst(RegExp(r'^[-*•·•]+\s*'), '');
    s = s.replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
    return s.trim();
  }
}
