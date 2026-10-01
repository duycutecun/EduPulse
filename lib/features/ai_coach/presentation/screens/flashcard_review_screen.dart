import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/ai_refresh_service.dart';
import '../../../../core/ai/flashcard_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/adaptive_policy.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../study/domain/models/study_models.dart';

/// Màn hình ôn flashcard theo lịch ngắt quãng.
///
/// Liên kết với phần còn lại của app qua AI trung gian:
/// - Thẻ sinh từ **Ghi chú** (subject của ghi chú điền sẵn) hoặc từ chủ đề.
/// - Số thẻ đến hạn được [AiStudyContext] kể cho AI nghe — AI tư vấn
///   "còn 12 thẻ Hóa đến hạn" nhất quán với màn hình này.
/// - Kết quả ôn (thẻ khó) ảnh hưởng ease/hạn — AI nhìn thấy xu hướng.
class FlashcardReviewScreen extends StatefulWidget {
  /// Thẻ đến hạn ban đầu (nếu null sẽ đọc từ [FlashcardService]).
  final List<Flashcard>? dueCards;

  const FlashcardReviewScreen({super.key, this.dueCards});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> {
  List<Flashcard> _cards = [];
  int _index = 0;
  bool _showBack = false;
  int _doneAgain = 0;
  int _doneHard = 0;
  int _doneGood = 0;
  int _doneEasy = 0;

  @override
  void initState() {
    super.initState();
    _cards = widget.dueCards ?? FlashcardService.dueCards();
  }

  Flashcard? get _current =>
      _index < _cards.length ? _cards[_index] : null;

  void _grade(ReviewGrade g) {
    final card = _current;
    if (card == null) return;
    HapticFeedback.selectionClick();
    FlashcardService.grade(card, g);
    switch (g) {
      case ReviewGrade.again:
        _doneAgain++;
        // Thẻ "quên" đưa xuống cuối stack để ôn lại trong cùng buổi.
        _cards.add(card);
        break;
      case ReviewGrade.hard:
        _doneHard++;
        break;
      case ReviewGrade.good:
        _doneGood++;
        break;
      case ReviewGrade.easy:
        _doneEasy++;
        break;
    }
    setState(() {
      _index++;
      _showBack = false;
    });
  }

  Future<void> _generateSheet() async {
    if (!PwaService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cần kết nối mạng để AI sinh flashcard!'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final sourceCtrl = TextEditingController();
    final subjects = ['Toán', 'Vật lý', 'Hóa học', 'Tiếng Anh', 'Ngữ văn', 'Sinh học', 'Lịch sử', 'Địa lý', 'Tổng hợp'];
    var subject = subjects.first;
    var fromNote = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 18, 20, 20 + MediaQuery.viewInsetsOf(sheetCtx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨ Sinh flashcard bằng AI',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                // Nguồn: ghi chú có sẵn hoặc chủ đề tự nhập.
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Từ ghi chú'),
                      selected: fromNote,
                      onSelected: (_) => setSheetState(() => fromNote = true),
                    ),
                    ChoiceChip(
                      label: const Text('Từ chủ đề'),
                      selected: !fromNote,
                      onSelected: (_) => setSheetState(() => fromNote = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (fromNote) ...[
                  _NotePicker(
                    onPicked: (title, body, subj) {
                      Navigator.pop(sheetCtx);
                      _generateAndReload(
                          source: body, subject: subj, noteTitle: title);
                    },
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: subject,
                    decoration: const InputDecoration(labelText: 'Môn'),
                    items: subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => subject = v ?? subject),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sourceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chủ đề',
                      hintText: 'VD: Đạo hàm lớp 12 — quy tắc & bẫy thường gặp',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (sourceCtrl.text.trim().isEmpty) return;
                        Navigator.pop(sheetCtx);
                        _generateAndReload(
                            source: sourceCtrl.text.trim(), subject: subject);
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Tạo 8 thẻ flashcard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndReload({
    required String source,
    required String subject,
    String? noteTitle,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.purple),
            SizedBox(height: 16),
            Text('AI đang soạn flashcard...'),
          ],
        ),
      ),
    );
    try {
      final cards = await FlashcardService.generate(
        source: source,
        subject: subject,
        noteTitle: noteTitle,
      );
      if (!mounted) return;
      // Đóng dialog loading (đẩy trên root navigator).
      Navigator.of(context, rootNavigator: true).pop();
      if (cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('AI chưa tạo được thẻ — thử lại nhé!'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Đã tạo ${cards.length} thẻ — đến hạn ôn ngay'),
        backgroundColor: AppColors.purple,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _cards = [...cards, ..._cards];
      });
      // Thẻ mới đến hạn ngay → dời lời nhắc SM-2 cho khớp lịch mới.
      AdaptivePolicy.syncFlashcardReminder();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _current;
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('Ôn flashcard 🃏',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Sinh thẻ mới bằng AI',
            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.purple),
            onPressed: _generateSheet,
          ),
        ],
      ),
      body: card == null ? _buildDone() : _buildCard(card),
    );
  }

  Widget _buildCard(Flashcard card) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          // Thanh tiến độ
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _cards.isEmpty ? 0 : _index / _cards.length,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.purple),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${_index + 1}/${_cards.length}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.purpleSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(card.subject,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.purple)),
            ),
          ),
          // Mặt thẻ
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_showBack) {
                  HapticFeedback.lightImpact();
                  setState(() => _showBack = true);
                }
              },
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.purple, width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: AppColors.purple,
                            blurRadius: 0,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showBack ? 'ĐÁP ÁN' : 'CÂU HỎI',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _showBack ? card.back : card.front,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.5,
                              color: AppColors.textPrimary),
                        ),
                        if (!_showBack) ...[
                          const SizedBox(height: 16),
                          Text('Chạm để lật thẻ 👆',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Nút chấm SM-2 (chỉ hiện sau khi lật)
          if (_showBack)
            Row(
              children: [
                Expanded(
                  child: _gradeBtn('Quên', AppColors.red, ReviewGrade.again),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _gradeBtn('Khó', AppColors.orange, ReviewGrade.hard),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _gradeBtn('Được', AppColors.primary, ReviewGrade.good),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _gradeBtn('Dễ', AppColors.blue, ReviewGrade.easy),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _showBack = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('LẬT THẺ',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradeBtn(String label, Color color, ReviewGrade g) {
    return ElevatedButton(
      onPressed: () => _grade(g),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildDone() {
    final total = _doneAgain + _doneHard + _doneGood + _doneEasy;
    if (total > 0) {
      // Chu trình AI: lịch SM-2 vừa đổi → dời lời nhắc thẻ đến hạn và mời
      // AI nhìn lại dữ liệu (readiness/nhịp học thay đổi sau buổi ôn).
      AdaptivePolicy.syncFlashcardReminder();
      AiRefreshService.notifyDataChanged();
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Hoàn thành $total thẻ!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Quên: $_doneAgain · Khó: $_doneHard · Được: $_doneGood · Dễ: $_doneEasy\n'
              'Thẻ khó sẽ quay lại sớm hơn — lịch ôn đã được AI cập nhật.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('XONG',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chọn ghi chú có sẵn để sinh flashcard — danh sách ghi chú là cầu nối
/// Notes ↔ Flashcards.
class _NotePicker extends StatelessWidget {
  final void Function(String title, String body, String subject) onPicked;

  const _NotePicker({required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final notes = <(String, String, String)>[]; // (title, body, subject)
    for (final id in StorageService.getStudyNoteIds()) {
      final raw = StorageService.getStudyNoteJson(id);
      if (raw == null) continue;
      try {
        final n = StudyNote.fromJsonString(raw);
        notes.add((
          n.title.isEmpty ? '(không tiêu đề)' : n.title,
          n.body,
          n.subject ?? 'Tổng hợp'
        ));
      } catch (_) {
        continue;
      }
    }

    if (notes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Chưa có ghi chú nào — hãy tạo ghi chú trước, hoặc dùng "Từ chủ đề".',
            style: TextStyle(fontSize: 12.5)),
      );
    }

    return SizedBox(
      height: 260,
      child: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (ctx, i) => ListTile(
          dense: true,
          leading: const Icon(Icons.sticky_note_2_rounded,
              color: AppColors.purple, size: 20),
          title: Text(notes[i].$1,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          subtitle: Text(notes[i].$3,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          onTap: () => onPicked(notes[i].$1, notes[i].$2, notes[i].$3),
        ),
      ),
    );
  }
}
