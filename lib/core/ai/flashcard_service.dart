import 'dart:convert';

import '../utils/storage_service.dart';
import 'ai_models.dart';
import 'ai_router.dart';

/// Một thẻ flashcard với lịch ôn ngắt quãng (SM-2 rút gọn).
class Flashcard {
  final String id;
  final String front; // câu hỏi / khái niệm
  final String back; // đáp án / định nghĩa
  final String subject;

  // --- Lịch SM-2 rút gọn ---
  int repetitions; // số lần trả lời đúng liên tiếp
  double easeFactor; // 1.3..2.5 — độ "dễ" của thẻ
  int intervalDays; // số ngày đến lần ôn kế tiếp
  DateTime dueAt; // ngày thẻ đến hạn ôn
  final DateTime createdAt;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.subject = 'Tổng hợp',
    this.repetitions = 0,
    this.easeFactor = 2.0,
    this.intervalDays = 0,
    DateTime? dueAt,
    DateTime? createdAt,
  })  : dueAt = dueAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isDue =>
      DateTime.now().isAfter(DateTime(dueAt.year, dueAt.month, dueAt.day));

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'subject': subject,
        'repetitions': repetitions,
        'easeFactor': easeFactor,
        'intervalDays': intervalDays,
        'dueAt': dueAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        id: (j['id'] ?? '').toString(),
        front: (j['front'] ?? '').toString(),
        back: (j['back'] ?? '').toString(),
        subject: (j['subject'] ?? 'Tổng hợp').toString(),
        repetitions: (j['repetitions'] as num?)?.toInt() ?? 0,
        easeFactor: (j['easeFactor'] as num?)?.toDouble() ?? 2.0,
        intervalDays: (j['intervalDays'] as num?)?.toInt() ?? 0,
        dueAt: DateTime.tryParse((j['dueAt'] ?? '').toString()) ?? DateTime.now(),
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory Flashcard.fromJsonString(String raw) =>
      Flashcard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Kết quả chấm 1 lượt ôn một thẻ.
enum ReviewGrade {
  /// Quên — thẻ quay lại vòng lặp ngắn.
  again,

  /// Đúng nhưng căng — khoảng cách tăng ít.
  hard,

  /// Đúng thoải mái — khoảng cách tăng chuẩn.
  good,

  /// Đúng rất dễ — tăng nhanh + cộng ease.
  easy,
}

/// Trình sinh & quản lý flashcard AI + lịch ôn ngắt quãng.
///
/// Vì sao là SM-2: thuật toán này là nền của Anki/SuperMemo, chứng minh lâu
/// trong thực tế học tập; bản rút gọn 4 mức (again/hard/good/easy) vừa đủ
/// cho học sinh phổ thông mà không phải cấu hình gì.
///
/// Tất cả lưu local-first qua [StorageService] — AI khác phần khác của app
/// (AiStudyContext) sẽ "nhìn thấy" số thẻ đến hạn để tư vấn nhất quán.
class FlashcardService {
  FlashcardService._();

  static const String _idsKey = 'flashcard_ids';

  // --- CRUD -----------------------------------------------------------

  static List<String> get ids =>
      StorageService.prefs.getStringList(_idsKey) ?? const [];

  static List<Flashcard> loadAll() {
    final out = <Flashcard>[];
    for (final id in ids) {
      final raw = StorageService.getString('flashcard_$id');
      if (raw == null || raw.isEmpty) continue;
      try {
        out.add(Flashcard.fromJsonString(raw));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  static void save(Flashcard card) {
    StorageService.setString('flashcard_${card.id}', card.toJsonString());
    final list = ids;
    if (!list.contains(card.id)) {
      list.add(card.id);
      StorageService.prefs.setStringList(_idsKey, list);
    }
  }

  static void remove(String id) {
    StorageService.prefs.remove('flashcard_$id');
    StorageService.prefs.setStringList(
        _idsKey, ids.where((x) => x != id).toList());
  }

  /// Các thẻ đến hạn hôm nay (quá hạn đưa lên trước).
  static List<Flashcard> dueCards() {
    final all = loadAll()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return all.where((c) => c.isDue).toList();
  }

  static int get dueCount => dueCards().length;

  // --- Chấm điểm & lịch SM-2 rút gọn ---------------------------------

  /// Áp dụng kết quả ôn vào thẻ: cập nhật ease, khoảng cách, hạn tới.
  ///
  /// SM-2 chuẩn: again → interval=1, repetitions=0, ease −0.2; hard → ×1.2;
  /// good → ×ease (lần 2: 6 ngày); easy → ×ease×1.3, ease +0.15.
  static void grade(Flashcard card, ReviewGrade g) {
    switch (g) {
      case ReviewGrade.again:
        card.repetitions = 0;
        card.easeFactor = (card.easeFactor - 0.2).clamp(1.3, 2.8);
        card.intervalDays = 1;
        break;
      case ReviewGrade.hard:
        card.easeFactor = (card.easeFactor - 0.05).clamp(1.3, 2.8);
        card.intervalDays = card.repetitions == 0 ? 1 : (card.intervalDays * 1.2).ceil();
        card.repetitions += 1;
        break;
      case ReviewGrade.good:
        card.intervalDays = card.repetitions == 0
            ? 1
            : card.repetitions == 1
                ? 6
                : (card.intervalDays * card.easeFactor).ceil();
        card.repetitions += 1;
        break;
      case ReviewGrade.easy:
        card.easeFactor = (card.easeFactor + 0.15).clamp(1.3, 2.8);
        card.intervalDays = card.repetitions == 0
            ? 3
            : (card.intervalDays * card.easeFactor * 1.3).ceil();
        card.repetitions += 1;
        break;
    }
    card.dueAt = DateTime.now().add(Duration(days: card.intervalDays));
    save(card);
  }

  // --- Sinh thẻ bằng AI ------------------------------------------------

  /// Sinh flashcards từ nội dung (body ghi chú) hoặc từ chủ đề môn học.
  /// Trả về danh sách thẻ đã lưu. Ném lỗi khi offline/lỗi AI để caller hiển thị.
  static Future<List<Flashcard>> generate({
    required String source,
    required String subject,
    String? noteTitle,
    int count = 8,
  }) async {
    final isTopic = noteTitle == null;
    final prompt = '''
Bạn là giáo viên luyện thi. Hãy tạo $count thẻ flashcard ${
      isTopic ? 'cho chủ đề "$source" môn $subject' : 'từ nội dung ghi chú "$noteTitle" môn $subject'
    } để học sinh ôn theo phương pháp ngắt quãng (spaced repetition).

Yêu cầu:
- Trả về ĐÚNG định dạng JSON, KHÔNG kèm markdown, KHÔNG kèm text khác.
- JSON dạng: {"cards":[{"front":"câu hỏi/khái niệm","back":"đáp án/định nghĩa ngắn gọn"}]}
- Mặt trước: 1 câu hỏi ngắn hoặc 1 khái niệm cần nhớ. Mặt sau: đáp án súc tích (≤ 25 từ).
- Bám sát nội dung trọng tâm, ưu tiên định nghĩa, công thức, mốc thời gian, bẫy hay sai.
''';

    final raw = await AiRouter.chat(
      model: AIModel.defaultModel,
      history: const [],
      userMessage: prompt,
      searchWeb: false,
    );

    final cards = _parseCards(raw, subject);
    for (final c in cards) {
      save(c);
    }
    return cards;
  }

  /// Parse JSON AI trả về thành danh sách thẻ (linh hoạt giống parseQuiz).
  static List<Flashcard> _parseCards(String raw, String subject) {
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
    if (start != -1 && end > start) {
      text = text.substring(start, end + 1);
    }

    try {
      final data = jsonDecode(text);
      final list = (data is Map<String, dynamic> ? data['cards'] : data);
      if (list is! List) return const [];
      final now = DateTime.now();
      final base = now.microsecondsSinceEpoch;
      var index = 0;
      return list
          .whereType<Map<String, dynamic>>()
          .map((j) {
            final front = (j['front'] ?? '').toString().trim();
            final back = (j['back'] ?? '').toString().trim();
            if (front.isEmpty || back.isEmpty) return null;
            return Flashcard(
              id: 'fc_${base}_${index++}',
              front: front,
              back: back,
              subject: subject,
              dueAt: now, // thẻ mới đến hạn ngay để ôn lần đầu
            );
          })
          .whereType<Flashcard>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
