import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;

import 'ai_config.dart';
import '../utils/storage_service.dart';
import 'ai_context.dart';
import 'ai_models.dart';
import 'ai_router.dart';
import 'readiness_score.dart';
import 'study_rhythm.dart';

/// Một mục trong bản tin AI hằng ngày.
class BriefingItem {
  final String title;
  final String? detail;

  const BriefingItem({required this.title, this.detail});

  Map<String, dynamic> toJson() => {'title': title, 'detail': detail};

  factory BriefingItem.fromJson(Map<String, dynamic> j) => BriefingItem(
        title: (j['title'] ?? '').toString(),
        detail: j['detail']?.toString(),
      );
}

/// Bản tin AI hằng ngày.
class DailyBriefing {
  final String greeting;
  final List<BriefingItem> focus; // 3 việc ưu tiên
  final List<BriefingItem> risks; // cảnh báo
  final String source; // 'ai' | 'offline'
  final DateTime generatedAt;

  const DailyBriefing({
    required this.greeting,
    required this.focus,
    required this.risks,
    required this.source,
    required this.generatedAt,
  });

  bool get isEmpty => focus.isEmpty && risks.isEmpty;

  Map<String, dynamic> toJson() => {
        'greeting': greeting,
        'focus': focus.map((e) => e.toJson()).toList(),
        'risks': risks.map((e) => e.toJson()).toList(),
        'source': source,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory DailyBriefing.fromJson(Map<String, dynamic> j) => DailyBriefing(
        greeting: (j['greeting'] ?? '').toString(),
        focus: (j['focus'] as List? ?? const [])
            .map((e) =>
                BriefingItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        risks: (j['risks'] as List? ?? const [])
            .map((e) =>
                BriefingItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        source: (j['source'] ?? 'offline').toString(),
        generatedAt: DateTime.tryParse((j['generatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

/// Bản tin AI hằng ngày (một lần/ngày, cache cứng để không tốn quota).
///
/// Cấu trúc: chào theo buổi + chỉ số sẵn sàng thi ([ReadinessScore]) +
/// 3 việc ưu tiên + cảnh báo rủi ro. Nguồn có 2 lớp:
/// 1. **AI sinh** (nếu online + đã cho phép + còn quota) — lời văn tự nhiên
///    bám sát ngữ cảnh [AiStudyContext].
/// 2. **Offline tổng hợp** (quy tắc cứng từ ReadinessScore + dữ liệu local) —
///    đảm bảo mở app lúc 5h sáng vẫn luôn có bản tin, kể cả offline.
///
/// Cache key theo ngày: trong cùng ngày trả cache, sang ngày mới tự tái sinh.
class AiDailyBriefing {
  AiDailyBriefing._();

  static const String _cacheKey = 'ai_briefing_v1';
  static const String _cacheDayKey = 'ai_briefing_day_v1';

  /// Tăng mỗi khi có bản tin mới — UI lắng nghe để làm mới không cần điều hướng.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Bản tin hôm nay: cache → AI → offline. Không bao giờ ném lỗi.
  static Future<DailyBriefing> load({bool force = false}) async {
    final today = _todayKey();
    final cachedDay = StorageService.getString(_cacheDayKey);
    if (!force && cachedDay == today) {
      final raw = StorageService.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          return DailyBriefing.fromJson(
              jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
    }

    // Offline → luôn dùng bản offline (không thử AI).
    // Online → thử AI, hỏng thì fallback offline.
    DailyBriefing briefing = _offlineBriefing();
    if (_canCallAi) {
      try {
        briefing = await _aiBriefing();
      } catch (_) {
        briefing = _offlineBriefing();
      }
    }

    try {
      StorageService.setString(_cacheKey, jsonEncode(briefing.toJson()));
      StorageService.setString(_cacheDayKey, today);
    } catch (_) {}
    revision.value += 1;
    return briefing;
  }

  /// Xoá cache — gọi khi dữ liệu lớn đổi (nhập điểm, thêm kỳ thi chính...).
  static void invalidate() {
    StorageService.setString(_cacheDayKey, '');
    revision.value += 1;
  }

  /// Chỉ gọi AI khi có kênh gọi thật: web đi proxy serverless, native cần
  /// API key build-time. Không đủ điều kiện → dùng bản offline tổng hợp,
  /// tránh gọi mù (fail) và tránh để lại timer treo trong môi trường test.
  static bool get _canCallAi {
    if (StorageService.getBool('ai_permission_analyze') == false) return false;
    return kIsWeb || AiConfig.openRouterApiKey.isNotEmpty;
  }

  // --- AI briefing -----------------------------------------------------

  static Future<DailyBriefing> _aiBriefing() async {
    final context = AiStudyContext.build();
    if (context.isEmpty) return _offlineBriefing();

    final readiness = ReadinessScore.compute();
    final readinessBlock = readiness == null
        ? 'Chưa đủ dữ liệu tính chỉ số sẵn sàng.'
        : 'CHỈ SỐ SẴN SÀNG THI: ${readiness.score}/100 (${readiness.band}). '
            'Thành phần: ${readiness.factors.map((f) => '${f.label} ${(f.value * 100).round()}%').join(', ')}.';

    // Nhịp học cá nhân phát hiện trên thiết bị — AI dùng để cá nhân hoá
    // thứ tự việc làm, kể cả khi model không có dữ liệu giờ học thật.
    final rhythmBlock = _rhythmBlock();

    final prompt = '''
Dựa trên ngữ cảnh học tập dưới đây, viết BẢN TIN HỌC TẬP HÔM NAY cho học sinh.
$readinessBlock
${rhythmBlock.isEmpty ? '' : '\n$rhythmBlock\n'}
Yêu cầu:
- Giọng thân thiện, ngắn gọn, động viên nhưng trung thực.
- Chọn đúng 3 việc ưu tiên nhất LÀM ĐƯỢC HÔM NAY (cụ thể, có số liệu).
- Nếu có GIỜ VÀNG, việc ưu tiên số 1 nên dính tới khung giờ đó (nếu hợp lý).
- Nếu có NGUY CƠ CHÁY, việc số 1 là mời nghỉ nhẹ nhàng, không bắt học nhiều.
- Chọn tối đa 2 rủi ro cần chú ý (có thể 0 nếu không có).

Trả về ĐÚNG định dạng JSON, không kèm markdown hay text khác:
{"greeting":"chào theo buổi + 1 câu tóm tắt tình hình",
 "focus":[{"title":"việc 1","detail":"số liệu/bằng chứng ngắn"},...],
 "risks":[{"title":"rủi ro","detail":"vì sao + tránh sao"},...]}

--- NGỮ CẢNH HỌC TẬP ---
$context''';

    final raw = await AiRouter.chat(
      model: AIModel.defaultModel,
      history: const [],
      userMessage: prompt,
      searchWeb: false,
    );
    final parsed = _parse(raw);
    if (parsed == null || parsed.isEmpty) return _offlineBriefing();
    return parsed;
  }

  static DailyBriefing? _parse(String raw) {
    var text = raw.trim();
    final fenceStart = text.indexOf('```');
    if (fenceStart != -1) {
      final fenceEnd = text.indexOf('```', fenceStart + 3);
      if (fenceEnd != -1) {
        text = text.substring(fenceStart + 3, fenceEnd);
        final nl = text.indexOf('\n');
        if (nl != -1 &&
            text.substring(0, nl).trim().toLowerCase().contains('json')) {
          text = text.substring(nl + 1);
        }
      }
    }
    text = text.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    text = text.substring(start, end + 1);
    try {
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic>) return null;
      final briefing = DailyBriefing.fromJson({
        ...data,
        'source': 'ai',
      });
      return briefing;
    } catch (_) {
      return null;
    }
  }

  /// Khối nhịp học cho prompt AI — ngắn, chỉ khi có tín hiệu đáng tin.
  static String _rhythmBlock() {
    final lines = <String>[];
    final peak = StudyRhythm.peakHour();
    if (peak != null && peak.confidence >= 0.5) {
      lines.add('GIỜ VÀNG: ${peak.summary} (bằng chứng: ${peak.evidence}).');
    }
    final burnout = StudyRhythm.burnoutRisk();
    if (burnout != null) {
      lines.add('NGUY CƠ CHÁY: ${burnout.summary}.');
    }
    final neglected = StudyRhythm.neglectedSubject();
    if (neglected != null) {
      lines.add('MÔN BỊ BỎ QUÊN: ${neglected.summary}.');
    }
    return lines.join('\n');
  }

  // --- Offline briefing (fallback luôn khả dụng) -----------------------

  static DailyBriefing _offlineBriefing() {
    final h = DateTime.now().hour;
    final name = StorageService.getUserName().trim();
    final who = (name.isEmpty || name == 'Sĩ tử EduPulse') ? '' : ' $name';
    final greeting = h < 12
        ? 'Chào buổi sáng$who!'
        : h < 18
            ? 'Chào buổi chiều$who!'
            : 'Chào buổi tối$who!';

    final readiness = ReadinessScore.compute();
    final focus = <BriefingItem>[];
    final risks = <BriefingItem>[];

    if (readiness != null) {
      // Nhịp học cá nhân (on-device, miễn phí) cá nhân hoá thứ tự ưu tiên:
      // burnout → mời nghỉ nhẹ nhàng TRƯỚC mọi đòn bẩy (Principle 5 Calm,
      // không đe doạ streak); có giờ vàng → môn khó nhất vào khung đó;
      // môn bị bỏ quên → nhắc ghé lại.
      final peak = StudyRhythm.peakHour();
      final burnout = StudyRhythm.burnoutRisk();
      final neglected = StudyRhythm.neglectedSubject();

      if (burnout != null) {
        focus.add(BriefingItem(
          title: 'Hôm nay học nhẹ thôi — tối đa 1 phiên 25 phút',
          detail:
              'Hai phiên gần nhất đều nặng nhọc. Nghỉ ngơi cũng là một phần của kế hoạch.',
        ));
      } else if (peak != null) {
        final window =
            peak.summary.replaceFirst('Học hiệu quả nhất khung ', '');
        focus.add(BriefingItem(
          title: 'Học môn khó nhất trong khung $window',
          detail: peak.evidence,
        ));
      }
      // 3 đòn bẩy = 3 việc ưu tiên hôm nay.
      for (final lever in readiness.levers) {
        focus.add(BriefingItem(title: lever));
      }
      if (neglected != null) {
        focus.add(BriefingItem(
          title: 'Ghé lại môn bị bỏ quên 20 phút',
          detail: neglected.summary,
        ));
      }
      for (final w in readiness.warnings) {
        risks.add(BriefingItem(title: w));
      }
      final intro = readiness.warnings.isEmpty
          ? '$greeting Chỉ số sẵn sàng thi của bạn đang ở mức ${readiness.band.toLowerCase()} (${readiness.score}/100).'
          : '$greeting Sẵn sàng thi ${readiness.score}/100 — có ${readiness.warnings.length} điểm cần chú ý.';
      // Ma thuật vô hình: giờ vàng xuất hiện ngay trong lời chào khi đã đủ
      // dữ liệu, học sinh không cần biết phía sau có bộ phân tích nhịp học.
      final introWithRhythm = (peak != null && burnout == null)
          ? '$intro ${peak.summary.toLowerCase()} — kế hoạch đã xếp theo khung đó.'
          : intro;
      return DailyBriefing(
        greeting: introWithRhythm,
        focus: focus.take(3).toList(),
        risks: risks.take(2).toList(),
        source: 'offline',
        generatedAt: DateTime.now(),
      );
    }

    // Chưa đủ dữ liệu readiness → nhắc dữ kiện cơ bản từ local.
    final streak = StorageService.getStreak();
    final taskCount = StorageService.getTodayTaskIds().length;
    final focusText = streak > 0
        ? 'Chuỗi học $streak ngày — giữ đà bằng 1 phiên focus hôm nay nhé!'
        : 'Bắt đầu với 1 phiên focus 25 phút hôm nay để khởi động nhịp học.';
    focus.add(BriefingItem(
        title: focusText,
        detail:
            taskCount > 0 ? 'Có $taskCount nhiệm vụ trong kế hoạch.' : null));
    return DailyBriefing(
      greeting:
          '$greeting Hãy thêm kỳ thi mục tiêu và nhập điểm thi thử để AI tư vấn sâu hơn.',
      focus: focus,
      risks: const [],
      source: 'offline',
      generatedAt: DateTime.now(),
    );
  }
}
