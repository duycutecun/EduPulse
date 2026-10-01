import '../../features/study/domain/models/study_models.dart';

/// Một liên kết ghi chú có thể giải thích được. Không gọi LLM và không gửi
/// nội dung ghi chú ra mạng: liên kết dựa trên môn học, nhãn và từ khóa chung.
class NoteLink {
  const NoteLink(
      {required this.note, required this.reason, required this.score});

  final StudyNote note;
  final String reason;
  final double score;
}

class SmartNoteLinker {
  SmartNoteLinker._();

  static List<NoteLink> relatedTo(
    StudyNote source,
    Iterable<StudyNote> candidates, {
    int limit = 3,
  }) {
    final sourceWords =
        _words('${source.title} ${source.body} ${source.tags.join(' ')}');
    if (sourceWords.isEmpty) return const [];
    final links = <NoteLink>[];
    for (final note in candidates) {
      if (note.id == source.id) continue;
      final targetWords =
          _words('${note.title} ${note.body} ${note.tags.join(' ')}');
      if (targetWords.isEmpty) continue;
      final common = sourceWords.intersection(targetWords);
      final sameSubject = source.subject != null &&
          source.subject!.trim().isNotEmpty &&
          source.subject!.trim().toLowerCase() ==
              note.subject?.trim().toLowerCase();
      final score = common.length / sourceWords.union(targetWords).length +
          (sameSubject ? .35 : 0);
      if (score < .12) continue;
      final reason = sameSubject
          ? 'Cùng môn ${source.subject}${common.isEmpty ? '' : ' · ${common.take(2).join(', ')}'}'
          : 'Cùng ý: ${common.take(3).join(', ')}';
      links.add(NoteLink(note: note, reason: reason, score: score));
    }
    links.sort((a, b) => b.score.compareTo(a.score));
    return links.take(limit).toList(growable: false);
  }

  static const _ignored = {
    'và',
    'của',
    'cho',
    'các',
    'một',
    'những',
    'được',
    'trong',
    'với',
    'the',
    'and',
    'for',
    'that',
    'this',
    'from',
    'các',
    'khi',
    'là',
    'về',
  };

  static Set<String> _words(String text) => RegExp(r"[A-Za-zÀ-ỹ0-9]{3,}")
      .allMatches(text.toLowerCase())
      .map((m) => m.group(0)!)
      .where((word) => !_ignored.contains(word))
      .toSet();
}
