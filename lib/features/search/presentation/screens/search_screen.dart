import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';

/// Local search across tasks and notes. No query leaves the device.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<TodayTask> _tasks = const [];
  List<StudyNote> _notes = const [];

  @override
  void initState() { super.initState(); _load(); _controller.addListener(() => setState(() {})); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _load() {
    _tasks = StorageService.getTodayTaskIds().map(StorageService.getTodayTaskJson).whereType<String>().map((value) { try { return TodayTask.fromJsonString(value); } catch (_) { return null; } }).whereType<TodayTask>().toList();
    _notes = StorageService.getStudyNoteIds().map(StorageService.getStudyNoteJson).whereType<String>().map((value) { try { return StudyNote.fromJsonString(value); } catch (_) { return null; } }).whereType<StudyNote>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final tasks = query.isEmpty ? const <TodayTask>[] : _tasks.where((task) => '${task.title} ${task.subject} ${task.topic ?? ''} ${task.note ?? ''}'.toLowerCase().contains(query)).toList();
    final notes = query.isEmpty ? const <StudyNote>[] : _notes.where((note) => '${note.title} ${note.body} ${note.tags.join(' ')}'.toLowerCase().contains(query)).toList();
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Tìm kiếm', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _controller, autofocus: true, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Tìm nhiệm vụ, ghi chú, chủ đề…', suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Xóa tìm kiếm', icon: const Icon(Icons.clear_rounded), onPressed: _controller.clear))),
          const SizedBox(height: 16),
          Expanded(child: query.isEmpty ? const Center(child: Text('Nhập từ khóa để tìm trong dữ liệu trên thiết bị.')) : (tasks.isEmpty && notes.isEmpty ? const Center(child: Text('Không tìm thấy kết quả phù hợp.')) : ListView(children: [if (tasks.isNotEmpty) const _SearchSection('Nhiệm vụ'), ...tasks.map((task) => GlassCard(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.checklist_rounded, color: AppColors.primary), title: Text(task.title), subtitle: Text('${task.subject} • ${task.estimateMinutes} phút')))), if (notes.isNotEmpty) const _SearchSection('Ghi chú'), ...notes.map((note) => GlassCard(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.sticky_note_2_outlined, color: AppColors.blue), title: Text(note.title.isEmpty ? 'Chưa có tiêu đề' : note.title), subtitle: Text(note.body, maxLines: 1, overflow: TextOverflow.ellipsis))))]))),
        ]),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)));
}
