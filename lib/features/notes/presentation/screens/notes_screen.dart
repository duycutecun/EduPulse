import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
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
                            // Liên kết task/subject + ảnh (mục 14).
                            if (note.taskId != null || note.subject != null || note.imageBase64 != null) ...[
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, children: [
                                if (note.taskId != null)
                                  const Icon(Icons.link_rounded, size: 13, color: AppColors.blue),
                                if (note.subject != null)
                                  Text(note.subject!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                if (note.imageBase64 != null)
                                  const Icon(Icons.image_rounded, size: 13, color: AppColors.blue),
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
      await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Xóa ghi chú?'), content: const Text('Thao tác này không thể hoàn tác.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa'))])) ?? false;
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
        builder: (_) => _NoteEditor(
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
  }
}

class _NotesEmpty extends StatelessWidget {
  const _NotesEmpty();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.sticky_note_2_outlined, size: 44, color: AppColors.textMuted), SizedBox(height: 10), Text('Chưa có ghi chú', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Lưu công thức, lỗi sai và ý tưởng để ôn lại sau.', textAlign: TextAlign.center)])));
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({this.note, this.initialTaskId, this.initialSubject});
  final StudyNote? note;

  /// Task/subject điền sẵn khi tạo từ một nhiệm vụ (Task-linked — mục 14).
  final String? initialTaskId;
  final String? initialSubject;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  bool _preview = false;

  // Liên kết (mục 14 — Task/Subject/Session-linked).
  String? _taskId;
  String? _subject;
  String? _sessionId;

  // Ảnh đính kèm (base64, giới hạn ~250KB).
  static const int _maxImageBytes = 250 * 1024;
  String? _imageBase64;
  bool _imageTooBig = false;

  // Autosave / draft recovery (mục 14 + 35 — Offline notes).
  Timer? _autosaveTimer;
  bool _draftRestored = false;
  static const String _draftKey = 'note_draft_v1';

  @override
  void initState() {
    super.initState();
    _taskId = widget.note?.taskId ?? widget.initialTaskId;
    _subject = widget.note?.subject ?? widget.initialSubject;
    _sessionId = widget.note?.sessionId;
    _imageBase64 = widget.note?.imageBase64;

    // Draft recovery: chỉ khi mở ghi chú MỚI (không đè note đang sửa).
    String? bodyText = widget.note?.body;
    if (widget.note == null) {
      final draft = StorageService.getString(_draftKey);
      if (draft != null && draft.isNotEmpty) {
        try {
          final restored = StudyNote.fromJsonString(draft);
          bodyText = restored.body;
          _taskId = restored.taskId;
          _subject = restored.subject;
          _draftRestored = true;
        } catch (_) {
          StorageService.prefs.remove(_draftKey);
        }
      }
    }

    _title = TextEditingController(text: widget.note?.title);
    _body = TextEditingController(text: bodyText);
    _tags = TextEditingController(text: widget.note?.tags.join(', '));

    // Autosave 3s sau khi ngừng gõ — chỉ cho ghi chú mới (note có sẵn
    // được lưu khi bấm Lưu như cũ).
    _body.addListener(_onBodyChanged);
  }

  void _onBodyChanged() {
    if (widget.note != null) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), _saveDraft);
  }

  void _saveDraft() {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    final draft = StudyNote(
      id: 'draft',
      title: _title.text.trim(),
      body: text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      taskId: _taskId,
      subject: _subject,
    );
    StorageService.setString(_draftKey, draft.toJsonString());
  }

  void _clearDraft() {
    _autosaveTimer?.cancel();
    StorageService.prefs.remove(_draftKey);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    final bytes = await result.first.readAsBytes();
    setState(() {
      // base64 phình ~4/3 — chặn trước khi encode để không phình prefs.
      _imageTooBig = bytes.length > _maxImageBytes;
      if (!_imageTooBig) {
        _imageBase64 = base64Encode(bytes);
      }
    });
  }

  Future<void> _pickLink() async {
    // Gộp 2 bước: chọn task (kèm subject tự điền) hoặc bỏ liên kết.
    final tasks = StorageService.getTodayTaskIds()
        .map(StorageService.getTodayTaskJson)
        .whereType<String>()
        .map((v) {
          try {
            return TodayTask.fromJsonString(v);
          } catch (_) {
            return null;
          }
        })
        .whereType<TodayTask>()
        .toList();
    if (!mounted) return;
    final picked = await showModalBottomSheet<TodayTask>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Liên kết với nhiệm vụ',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.link_off_rounded),
              title: const Text('Bỏ liên kết'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ...tasks.map((task) => ListTile(
                  leading: const Icon(Icons.checklist_rounded),
                  title: Text(task.title),
                  subtitle: Text(task.subject),
                  onTap: () => Navigator.pop(sheetContext, task),
                )),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (picked == null) {
        _taskId = null;
        _subject = null;
      } else {
        _taskId = picked.id;
        _subject = picked.subject; // Subject-linked tự điền (mục 14).
      }
    });
  }

  void _save() {
    _clearDraft();
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
        taskId: _taskId,
        subject: _subject,
        sessionId: _sessionId,
        imageBase64: _imageBase64,
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

  Future<void> _askAiSummarize() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy nhập nội dung ghi chú để AI tóm tắt nhé!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!PwaService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần kết nối mạng để dùng AI tóm tắt!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('AI đang tóm tắt & trích công thức...'),
          ],
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final prompt = '''
Hãy đọc nội dung ghi chú sau và tạo phần tóm tắt ngắn gọn gồm:
1. Các công thức hoặc định nghĩa quan trọng nhất
2. Lưu ý bẫy trắc nghiệm hay gặp
3. Checklist 3 ý cần nhớ

Định dạng Markdown đẹp, súc tích.

--- NỘI DUNG GHI CHÚ ---
$text
''';
      final res = await AiRouter.chat(
        model: AIModel.defaultModel,
        history: const [],
        userMessage: prompt,
        searchWeb: false,
      );

      if (!mounted) return;
      final current = _body.text;
      final newText = '$current\n\n---\n### 💡 AI Tóm tắt & Trọng tâm:\n$res';
      _body.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã bổ sung tóm tắt từ AI vào ghi chú!'),
          backgroundColor: AppColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildToolbar() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _tool('✨ AI', 'AI Trợ lý tóm tắt & trích công thức', _askAiSummarize),
          const SizedBox(width: 6),
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
            // Draft recovery banner (mục 35 — Offline notes: draft recovery).
            if (_draftRestored)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.history_rounded,
                      size: 16, color: AppColors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Đã khôi phục bản nháp chưa lưu lần trước.',
                        style: TextStyle(fontSize: 12)),
                  ),
                  GestureDetector(
                    onTap: () {
                      _clearDraft();
                      setState(() {
                        _draftRestored = false;
                        _body.clear();
                        _title.clear();
                        _taskId = null;
                        _subject = null;
                      });
                    },
                    child: const Text('Bỏ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blue)),
                  ),
                ]),
              ),
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
            const SizedBox(height: 6),
            // Hàng liên kết + ảnh (mục 14 — Note features).
            Row(children: [
              // Task/subject link chip.
              ActionChip(
                avatar: Icon(
                  _taskId != null
                      ? Icons.link_rounded
                      : Icons.add_link_rounded,
                  size: 15,
                  color:
                      _taskId != null ? AppColors.primary : AppColors.textMuted,
                ),
                label: Text(
                  _taskId != null
                      ? 'Đã liên kết nhiệm vụ${_subject != null ? ' • $_subject' : ''}'
                      : 'Liên kết nhiệm vụ',
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: _pickLink,
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(
                  _imageBase64 != null
                      ? Icons.image_rounded
                      : Icons.add_photo_alternate_outlined,
                  size: 15,
                  color: _imageBase64 != null
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                label: Text(
                  _imageBase64 != null ? 'Đã có ảnh' : 'Ảnh',
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: _pickImage,
              ),
              if (_imageBase64 != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Gỡ ảnh',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => setState(() => _imageBase64 = null),
                ),
              ],
            ]),
            if (_imageTooBig)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Ảnh quá lớn (> 250KB) — chọn ảnh khác nhẹ hơn.',
                    style: TextStyle(fontSize: 12, color: AppColors.orange)),
              ),
            if (_imageBase64 != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(_imageBase64!),
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ],
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
