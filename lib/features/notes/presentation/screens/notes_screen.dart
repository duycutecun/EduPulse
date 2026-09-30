import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/note_markdown.dart';
import '../../../study/domain/models/study_models.dart';

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
    return _notes.where((note) =>
        note.title.toLowerCase().contains(query) ||
        note.body.toLowerCase().contains(query) ||
        note.tags.any((tag) => tag.toLowerCase().contains(query))).toList();
  }

  void _save(StudyNote note) {
    StorageService.setStudyNoteJson(note.id, note.toJsonString());
    final ids = StorageService.getStudyNoteIds();
    if (!ids.contains(note.id)) StorageService.setStudyNoteIds([...ids, note.id]);
    setState(_load);
  }

  void _delete(StudyNote note) {
    StorageService.removeStudyNote(note.id);
    setState(_load);
  }

  Future<void> _openEditor([StudyNote? initial]) async {
    final result = await Navigator.of(context).push<StudyNote>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NoteEditor(note: initial),
    ));
    if (result != null) _save(result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          title: const Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.w800)),
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
                suffixIcon: _searchController.text.isEmpty ? null : IconButton(tooltip: 'Xóa tìm kiếm', icon: const Icon(Icons.clear_rounded), onPressed: _searchController.clear),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const _NotesEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final note = _filtered[index];
                      return Dismissible(
                        key: ValueKey(note.id),
                        direction: DismissDirection.endToStart,
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.delete_outline_rounded, color: Colors.white)),
                        confirmDismiss: (_) async => await _confirmDelete(context),
                        onDismissed: (_) => _delete(note),
                        child: GlassCard(
                          onTap: () => _openEditor(note),
                          padding: const EdgeInsets.all(15),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(note.title.isEmpty ? 'Chưa có tiêu đề' : note.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            if (note.body.isNotEmpty) ...[const SizedBox(height: 5), Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary))],
                            if (note.tags.isNotEmpty) ...[const SizedBox(height: 9), Wrap(spacing: 6, children: note.tags.map((tag) => Chip(label: Text('#$tag', style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)).toList())],
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );

  Future<bool> _confirmDelete(BuildContext context) async =>
      await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Xóa ghi chú?'), content: const Text('Thao tác này không thể hoàn tác.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa'))])) ?? false;
}

class _NotesEmpty extends StatelessWidget {
  const _NotesEmpty();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.sticky_note_2_outlined, size: 44, color: AppColors.textMuted), SizedBox(height: 10), Text('Chưa có ghi chú', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Lưu công thức, lỗi sai và ý tưởng để ôn lại sau.', textAlign: TextAlign.center)])));
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({this.note});
  final StudyNote? note;
  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title);
    _body = TextEditingController(text: widget.note?.body);
    _tags = TextEditingController(text: widget.note?.tags.join(', '));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _save() {
    final now = DateTime.now();
    Navigator.pop(
      context,
      StudyNote(
        id: widget.note?.id ?? const Uuid().v4(),
        title: _title.text.trim(),
        body: _body.text.trim(),
        createdAt: widget.note?.createdAt ?? now,
        updatedAt: now,
        tags: _tags.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Markdown toolbar helpers (đặc tả mục 58.5)
  // ------------------------------------------------------------------

  /// Bọc vùng chọn (hoặc vị trí con trỏ) bằng cặp marker Markdown.
  void _wrapSelection(String marker, [String? endMarker]) {
    final end = endMarker ?? marker;
    final text = _body.text;
    final selection = _body.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final stop = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, stop);
    final newText =
        text.replaceRange(start, stop, '$marker$selected$end');
    _body.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + marker.length + selected.length,
      ),
    );
  }

  /// Chèn prefix vào đầu dòng hiện tại (heading, list, quote…).
  void _prefixLine(String prefix) {
    final text = _body.text;
    final pos =
        _body.selection.baseOffset < 0 ? text.length : _body.selection.baseOffset;
    final lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    _body.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  Widget _tool(String label, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgPageSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _tool('H', 'Tiêu đề', () => _prefixLine('# ')),
          const SizedBox(width: 6),
          _tool('B', 'Đậm', () => _wrapSelection('**')),
          const SizedBox(width: 6),
          _tool('I', 'Nghiêng', () => _wrapSelection('*')),
          const SizedBox(width: 6),
          _tool('S̶', 'Gạch ngang', () => _wrapSelection('~~')),
          const SizedBox(width: 6),
          _tool('</>', 'Code', () => _wrapSelection('`')),
          const SizedBox(width: 6),
          _tool('▢', 'Khối code', () => _wrapSelection('\n```\n', '\n```\n')),
          const SizedBox(width: 6),
          _tool('•', 'Danh sách', () => _prefixLine('- ')),
          const SizedBox(width: 6),
          _tool('1.', 'Đánh số', () => _prefixLine('1. ')),
          const SizedBox(width: 6),
          _tool('☑', 'Checklist', () => _prefixLine('- [ ] ')),
          const SizedBox(width: 6),
          _tool('❝', 'Trích dẫn', () => _prefixLine('> ')),
          const SizedBox(width: 6),
          _tool(r'$x²$', 'Công thức', () => _wrapSelection(r'$', r'$')),
          const SizedBox(width: 6),
          _tool('—', 'Đường kẻ', () => _prefixLine('\n---\n')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(widget.note == null ? 'Ghi chú mới' : 'Chỉnh sửa ghi chú',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          // Xem trước Markdown thay vì raw text.
          IconButton(
            tooltip: _preview ? 'Chỉnh sửa' : 'Xem trước',
            icon: Icon(_preview
                ? Icons.edit_rounded
                : Icons.visibility_outlined),
            onPressed: () => setState(() => _preview = !_preview),
          ),
          TextButton(onPressed: _save, child: const Text('Lưu')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                  hintText: 'Tiêu đề', border: InputBorder.none),
            ),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                  labelText: 'Nhãn', hintText: 'Toán, công thức, lỗi sai'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _preview
                  ? SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: double.infinity,
                        child: NoteMarkdown(
                            body: _body.text.isEmpty
                                ? '*Chưa có nội dung để xem trước.*'
                                : _body.text),
                      ),
                    )
                  : Column(
                      children: [
                        _buildToolbar(),
                        const SizedBox(height: 6),
                        Expanded(
                          child: TextField(
                            controller: _body,
                            expands: true,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText: 'Viết ghi chú của bạn… Hỗ trợ Markdown: **đậm**, *nghiêng*, `code`, # tiêu đề, - danh sách, công thức \$x^2\$',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
