import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';

/// Global search (đặc tả mục 15): tìm đủ Tasks, Goals/Exams, Calendar
/// (task đã xếp lịch), Notes, Study sessions, AI conversations.
/// Chạy hoàn toàn trên dữ liệu local — không có query nào rời thiết bị.
/// Semantic search cần embedding model — ghi rõ ở empty state thay vì
/// giả vờ ("thử từ khóa khác" là gợi ý thật, mục 10.8).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchHit {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String section;

  const _SearchHit({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.section,
  });
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<TodayTask> _tasks = const [];
  List<StudyNote> _notes = const [];
  List<StudySession> _sessions = const [];
  List<ExamModel> _exams = const [];
  String? _aiConversation;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    List<T> safeParse<T>(List<String> raws, T? Function(String) parse) =>
        raws.map(parse).whereType<T>().toList();

    _tasks = safeParse(
      StorageService.getTodayTaskIds()
          .map(StorageService.getTodayTaskJson)
          .whereType<String>()
          .toList(),
      (v) {
        try {
          return TodayTask.fromJsonString(v);
        } catch (_) {
          return null;
        }
      },
    );
    _notes = safeParse(
      StorageService.getStudyNoteIds()
          .map(StorageService.getStudyNoteJson)
          .whereType<String>()
          .toList(),
      (v) {
        try {
          return StudyNote.fromJsonString(v);
        } catch (_) {
          return null;
        }
      },
    );
    _sessions = StudySessionRepository.instance.getAll();
    _exams = safeParse(
      StorageService.getExamIds()
          .map(StorageService.getExamJson)
          .whereType<String>()
          .toList(),
      (v) {
        try {
          return ExamModel.fromJsonString(v);
        } catch (_) {
          return null;
        }
      },
    );
    _aiConversation = StorageService.getAiChatHistory();
  }

  List<_SearchHit> _search(String query) {
    final q = query.toLowerCase();
    final hits = <_SearchHit>[];

    // Tasks (bao gồm cả Calendar — task có scheduledAt/deadline).
    for (final task in _tasks) {
      final haystack =
          '${task.title} ${task.subject} ${task.topic ?? ''} ${task.note ?? ''} ${task.status}'
              .toLowerCase();
      if (haystack.contains(q)) {
        final when = task.scheduledAt ?? task.deadline;
        hits.add(_SearchHit(
          icon: Icons.checklist_rounded,
          color: AppColors.primary,
          title: task.title,
          subtitle:
              '${task.subject} • ${task.estimateMinutes} phút${when != null ? ' • ${when.day}/${when.month}' : ''}',
          section: 'Nhiệm vụ',
        ));
      }
    }

    // Goals / Exams.
    for (final exam in _exams) {
      final haystack =
          '${exam.name} ${exam.description ?? ''} ${exam.type.name}'
              .toLowerCase();
      if (haystack.contains(q)) {
        hits.add(_SearchHit(
          icon: Icons.flag_rounded,
          color: AppColors.orange,
          title: exam.name,
          subtitle:
              'Mục tiêu • ${exam.dateTime.day}/${exam.dateTime.month}${exam.targetScore != null ? ' • target ${exam.targetScore!.toStringAsFixed(1)}' : ''}',
          section: 'Mục tiêu & Kỳ thi',
        ));
      }
    }

    // Notes.
    for (final note in _notes) {
      final haystack =
          '${note.title} ${note.body} ${note.tags.join(' ')} ${note.subject ?? ''}'
              .toLowerCase();
      if (haystack.contains(q)) {
        hits.add(_SearchHit(
          icon: Icons.sticky_note_2_outlined,
          color: AppColors.blue,
          title: note.title.isEmpty ? 'Chưa có tiêu đề' : note.title,
          subtitle: note.body,
          section: 'Ghi chú',
        ));
      }
    }

    // Study sessions.
    for (final s in _sessions) {
      final haystack = '${s.subject} ${s.reflectionNote ?? ''}'.toLowerCase();
      if (haystack.contains(q)) {
        hits.add(_SearchHit(
          icon: Icons.timer_outlined,
          color: AppColors.purple,
          title: 'Focus ${s.subject}',
          subtitle:
              '${s.actualMinutes} phút • ${s.completedAt.day}/${s.completedAt.month}${s.reflectionNote != null ? ' • ${s.reflectionNote}' : ''}',
          section: 'Phiên học',
        ));
      }
    }

    // AI conversations — tìm trong toàn bộ lịch sử chat đã lưu.
    if (_aiConversation != null && _aiConversation!.toLowerCase().contains(q)) {
      // Trích đoạn quanh vị trí khớp để người dùng thấy ngữ cảnh.
      final idx = _aiConversation!.toLowerCase().indexOf(q);
      final start = (idx - 40).clamp(0, _aiConversation!.length);
      final end = (idx + q.length + 60).clamp(0, _aiConversation!.length);
      final snippet =
          _aiConversation!.substring(start, end).replaceAll('\n', ' ').trim();
      hits.add(_SearchHit(
        icon: Icons.auto_awesome_rounded,
        color: AppColors.purple,
        title: 'Trong hội thoại AI',
        subtitle: snippet,
        section: 'Hội thoại AI',
      ));
    }

    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final hits = query.isEmpty ? const <_SearchHit>[] : _search(query);

    // Gom theo section, giữ thứ tự section xuất hiện.
    final sections = <String, List<_SearchHit>>{};
    for (final hit in hits) {
      (sections[hit.section] ??= []).add(hit);
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
          title: const Text('Tìm kiếm',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText:
                  'Tìm nhiệm vụ, mục tiêu, ghi chú, phiên học, hội thoại AI…',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: _controller.clear),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: query.isEmpty
                ? const Center(
                    child: Text(
                        'Nhập từ khóa để tìm trong dữ liệu trên thiết bị.'))
                : hits.isEmpty
                    ? _NoResults(query: query)
                    : ListView(
                        children: [
                          for (final entry in sections.entries) ...[
                            _SearchSection(entry.key),
                            ...entry.value.map((hit) => GlassCard(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(hit.icon, color: hit.color),
                                    title: Text(hit.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(hit.subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                )),
                          ],
                        ],
                      ),
          ),
        ]),
      ),
    );
  }
}

/// Không có kết quả (mục 15): thông báo + gợi ý query khác thật.
class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    // Gợi ý từ chính query: từ đầu tiên nếu user gõ cả cụm.
    final firstWord = query.split(' ').first;
    final suggestion = query.contains(' ') ? firstWord : query;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded,
              size: 44, color: AppColors.textMuted),
          const SizedBox(height: 10),
          const Text('Không tìm thấy kết quả phù hợp.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            query.contains(' ')
                ? 'Thử chỉ tìm "$suggestion" hoặc từ khóa ngắn hơn.'
                : 'Thử từ khóa khác, ví dụ tên môn hoặc chủ đề cụ thể hơn.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ]),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: AppColors.textSecondary)));
}
