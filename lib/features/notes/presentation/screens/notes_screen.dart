import 'package:flutter/material.dart';

import '../../../../core/ai/ai_refresh_service.dart';
import '../../../../core/ai/smart_note_linker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/gamification/achievement_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';
import '../widgets/note_editor_view.dart';
import '../widgets/notes_empty.dart';

/// Simple, offline-first notes with search and tags. The editor deliberately
/// uses native text fields so it stays fast and works without connectivity.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _searchController = TextEditingController();
  List<StudyNote> _notes = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _notes = StorageService.getStudyNoteIds()
        .map(StorageService.getStudyNoteJson)
        .whereType<String>()
        .map((value) {
          try {
            return StudyNote.fromJsonString(value);
          } catch (_) {
            return null;
          }
        })
        .whereType<StudyNote>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<StudyNote> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _notes;
    return _notes
        .where((note) =>
            note.title.toLowerCase().contains(query) ||
            note.body.toLowerCase().contains(query) ||
            note.tags.any((tag) => tag.toLowerCase().contains(query)))
        .toList();
  }

  void _save(StudyNote note) {
    StorageService.setStudyNoteJson(note.id, note.toJsonString());
    final ids = StorageService.getStudyNoteIds();
    if (!ids.contains(note.id)) {
      StorageService.setStudyNoteIds([...ids, note.id]);
    }
    AiRefreshService.notifyDataChanged();
    setState(_load);
    _celebrateNewAchievements();
  }

  /// Xét huy hiệu sau khi lưu ghi chú (P2 — gamification).
  void _celebrateNewAchievements() {
    final newly = AchievementService.instance.reconcile();
    if (newly.isEmpty || !mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        content:
            Text('${newly.first.emoji} Huy hiệu mới: ${newly.first.title}'),
        duration: const Duration(seconds: 2),
      ));
  }

  void _delete(StudyNote note) {
    StorageService.removeStudyNote(note.id);
    AiRefreshService.notifyDataChanged();
    setState(_load);
  }

  Future<void> _openEditor([StudyNote? initial]) async {
    final result =
        await Navigator.of(context).push<StudyNote>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NoteEditorView(note: initial),
    ));
    if (result != null) _save(result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          title: const Text('Ghi chú',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openEditor,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Ghi chú mới'),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Tìm trong ghi chú, nhãn…',
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: _searchController.clear),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? NotesEmpty(onCreate: () => _openEditor())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final note = _filtered[index];
                      final related = SmartNoteLinker.relatedTo(note, _notes);
                      return Dismissible(
                        key: ValueKey(note.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(18)),
                            child: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white)),
                        confirmDismiss: (_) async =>
                            await _confirmDelete(context),
                        onDismissed: (_) => _delete(note),
                        child: GlassCard(
                          onTap: () => _openEditor(note),
                          padding: const EdgeInsets.all(15),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    note.title.isEmpty
                                        ? 'Chưa có tiêu đề'
                                        : note.title,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                if (note.body.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(note.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary))
                                ],
                                if (note.tags.isNotEmpty) ...[
                                  const SizedBox(height: 9),
                                  Wrap(
                                      spacing: 6,
                                      children: note.tags
                                          .map((tag) => Chip(
                                              label: Text('#$tag',
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                              visualDensity:
                                                  VisualDensity.compact))
                                          .toList())
                                ],
                                if (related.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(spacing: 6, runSpacing: 5, children: [
                                    const Icon(Icons.auto_awesome_rounded,
                                        size: 13, color: AppColors.purple),
                                    ...related.map((link) => InkWell(
                                          onTap: () => _openEditor(link.note),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 4),
                                            decoration: BoxDecoration(
                                                color: AppColors.purpleSoft,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(
                                                'Liên quan: ${link.note.title}',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.purple)),
                                          ),
                                        )),
                                  ]),
                                ],
                                // Liên kết task/subject + ảnh (mục 14).
                                if (note.taskId != null ||
                                    note.subject != null ||
                                    note.imageBase64 != null) ...[
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, children: [
                                    if (note.taskId != null)
                                      const Icon(Icons.link_rounded,
                                          size: 13, color: AppColors.blue),
                                    if (note.subject != null)
                                      Text(note.subject!,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                    if (note.imageBase64 != null)
                                      const Icon(Icons.image_rounded,
                                          size: 13, color: AppColors.blue),
                                  ]),
                                ],
                              ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );

  Future<bool> _confirmDelete(BuildContext context) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Xóa ghi chú?'),
                  content: const Text('Thao tác này không thể hoàn tác.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Xóa'))
                  ])) ??
      false;
}

/// API công khai để tính năng khác mở editor tạo ghi chú liên kết
/// task (Task-linked — mục 14). Lưu thẳng vào storage sau khi đóng.
class NoteEditor {
  NoteEditor._();

  static Future<void> openLinked(
    BuildContext context, {
    required TodayTask task,
  }) async {
    final result = await Navigator.of(context).push<StudyNote>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NoteEditorView(
          initialTaskId: task.id,
          initialSubject: task.subject,
        ),
      ),
    );
    if (result == null) return;
    StorageService.setStudyNoteJson(result.id, result.toJsonString());
    final ids = StorageService.getStudyNoteIds();
    if (!ids.contains(result.id)) {
      StorageService.setStudyNoteIds([...ids, result.id]);
    }
    AiRefreshService.notifyDataChanged();
  }
}
