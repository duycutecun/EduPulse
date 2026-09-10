import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/quiz_models.dart';

/// Màn hình luyện quiz do AI sinh: chọn đáp án từng câu, xem giải thích,
/// chấm điểm khi kết thúc.
class QuizPlayScreen extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizPlayScreen({super.key, required this.questions});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _index = 0;
  int? _selected;
  int _correctCount = 0;
  bool _finished = false;

  QuizQuestion get _q => widget.questions[_index];

  void _choose(int i) {
    if (_selected != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selected = i;
      if (i == _q.correctIndex) _correctCount++;
    });
  }

  void _next() {
    if (_index + 1 >= widget.questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('Luyện quiz 📝', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _finished ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildResult() {
    final total = widget.questions.length;
    final percent = total == 0 ? 0 : (_correctCount / total);
    final color = percent >= 0.8
        ? AppColors.primary
        : (percent >= 0.5 ? AppColors.orange : AppColors.red);
    final title = percent >= 0.8
        ? 'Xuất sắc! 🎉'
        : (percent >= 0.5 ? 'Khá lắm! 💪' : 'Cần ôn thêm 📚');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$_correctCount/$total',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Đúng ${(_correctCount / (total == 0 ? 1 : total) * 100).round()}% — tiếp tục luyện để lên trình!',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: AppColors.primaryDark, blurRadius: 0, offset: Offset(0, 4))],
                ),
                child: const Text('XONG',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / widget.questions.length,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_index + 1}/${widget.questions.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Question
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Text(
              _q.question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Options
          ...List.generate(_q.options.length, (i) {
            final isCorrect = i == _q.correctIndex;
            final isSelected = _selected == i;
            Color bg = AppColors.cardWhite;
            Color border = AppColors.border;
            Color textColor = AppColors.textPrimary;
            IconData? icon;

            if (_selected != null) {
              if (isCorrect) {
                bg = AppColors.primarySoft;
                border = AppColors.primary;
                textColor = AppColors.primaryDark;
                icon = Icons.check_circle_rounded;
              } else if (isSelected) {
                bg = AppColors.redSoft;
                border = AppColors.red;
                textColor = AppColors.redDark;
                icon = Icons.cancel_rounded;
              }
            }

            return GestureDetector(
              onTap: () => _choose(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${String.fromCharCode(65 + i)}. ${_q.options[i]}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor, height: 1.3),
                      ),
                    ),
                    if (icon != null) Icon(icon, color: border, size: 20),
                  ],
                ),
              ),
            );
          }),
          if (_selected != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue, width: 1.5),
              ),
              child: Text(
                _q.explanation.isEmpty
                    ? 'Đáp án: ${String.fromCharCode(65 + _q.correctIndex)}'
                    : '💡 ${_q.explanation}',
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _next,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: AppColors.primaryDark, blurRadius: 0, offset: Offset(0, 4))],
                ),
                child: Center(
                  child: Text(
                    _index + 1 >= widget.questions.length ? 'XEM KẾT QUẢ' : 'CÂU TIẾP THEO →',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}