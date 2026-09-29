import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../core/constants/app_colors.dart';

/// Renderer Markdown nhẹ cho Ghi chú (đặc tả mục 58.5 — "Markdown-capable
/// editor + toolbar + rich interactions").
///
/// Hỗ trợ: heading `#`, danh sách `-`, checklist `- [ ] / - [x]`, danh sách
/// đánh số `1.`, blockquote `>`, code fence ``` ``` ```, đường kẻ ngang
/// `---`, inline **đậm** / *nghiêng* / ~~gạch ngang~~ / `code` và công
/// thức LaTeX inline `$...$` (tận dụng flutter_math_fork đã có sẵn).
///
/// Renderer này cố tình đơn giản và tự chứa: không thêm dependency, chạy
/// offline, đủ dùng cho ghi chú học tập.
class NoteMarkdown extends StatelessWidget {
  const NoteMarkdown({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          blocks[i],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Block parsing
// ---------------------------------------------------------------------------

List<Widget> _parseBlocks(String body) {
  final lines = body.split('\n');
  final blocks = <Widget>[];
  final paragraph = <String>[];
  final codeBuffer = <String>[];
  var inCode = false;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(_inlineText(paragraph.join(' ')));
    paragraph.clear();
  }

  void flushCode(String? lang) {
    if (codeBuffer.isEmpty && lang == null) return;
    blocks.add(_codeBlock(codeBuffer.join('\n')));
    codeBuffer.clear();
  }

  for (final rawLine in lines) {
    final line = rawLine.trimRight();

    // Code fence mở/đóng.
    if (line.trimLeft().startsWith('```')) {
      if (inCode) {
        flushCode(null);
        inCode = false;
      } else {
        flushParagraph();
        inCode = true;
      }
      continue;
    }
    if (inCode) {
      codeBuffer.add(line);
      continue;
    }

    // Đường kẻ ngang --- (ít nhất 3 dấu).
    if (RegExp(r'^-{3,}$').hasMatch(line.trim())) {
      flushParagraph();
      blocks.add(const Divider(height: 18));
      continue;
    }

    // Heading # .. ######.
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      flushParagraph();
      final level = heading.group(1)!.length;
      blocks.add(_heading(heading.group(2)!, level));
      continue;
    }

    // Checklist - [ ] / - [x].
    final checklist =
        RegExp(r'^[-*]\s+\[( |x|X)\]\s+(.*)$').firstMatch(line);
    if (checklist != null) {
      flushParagraph();
      blocks.add(_checklistRow(
        checklist.group(2)!,
        done: (checklist.group(1) ?? ' ').toLowerCase() == 'x',
      ));
      continue;
    }

    // Danh sách không đánh số.
    final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      flushParagraph();
      blocks.add(_bulletRow(Icons.circle, 6, bullet.group(1)!));
      continue;
    }

    // Danh sách đánh số "1." / "1)".
    final ordered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(line);
    if (ordered != null) {
      flushParagraph();
      blocks.add(_orderedRow(ordered.group(1)!, ordered.group(2)!));
      continue;
    }

    // Blockquote.
    final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
    if (quote != null) {
      flushParagraph();
      blocks.add(_blockquote(quote.group(1)!));
      continue;
    }

    if (line.trim().isEmpty) {
      flushParagraph();
      continue;
    }

    paragraph.add(line.trim());
  }

  // Kết thúc văn bản: tuôn phần còn lại.
  flushParagraph();
  if (inCode) flushCode(null);

  return blocks;
}

// ---------------------------------------------------------------------------
// Block widgets
// ---------------------------------------------------------------------------

Widget _heading(String text, int level) {
  final sizes = [22.0, 19.0, 17.0, 15.5, 14.5, 13.5];
  return Text.rich(
    _buildInlineSpan(text, baseSize: sizes[level - 1], bold: true),
    style: const TextStyle(
        fontWeight: FontWeight.w800, color: AppColors.textPrimary),
  );
}

Widget _bulletRow(IconData icon, double size, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 8),
          child: Icon(icon, size: size, color: AppColors.blue),
        ),
        Expanded(child: _inlineText(text)),
      ],
    ),
  );
}

Widget _orderedRow(String index, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 8, top: 2),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(index,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blueDark)),
          ),
        ),
        Expanded(child: _inlineText(text)),
      ],
    ),
  );
}

Widget _checklistRow(String text, {required bool done}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 8),
          child: Icon(
            done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 19,
            color: done ? AppColors.primary : AppColors.textMuted,
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: done ? 0.55 : 1,
            child: _inlineText(text, strike: done),
          ),
        ),
      ],
    ),
  );
}

Widget _blockquote(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.bgPageSoft,
      border: const Border(
        left: BorderSide(color: AppColors.blue, width: 3),
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: AppColors.textSecondary),
      child: _inlineText(text),
    ),
  );
}

Widget _codeBlock(String code) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.45,
          fontFamily: 'monospace',
          color: AppColors.textPrimary,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Inline parsing: **bold** *italic* ~~strike~~ `code` $latex$
// ---------------------------------------------------------------------------

Widget _inlineText(String text, {double? baseSize, bool? bold, bool strike = false}) {
  return Text.rich(
    _buildInlineSpan(
      text,
      baseSize: baseSize,
      bold: bold,
      strike: strike,
    ),
  );
}

InlineSpan _buildInlineSpan(
  String text, {
  double? baseSize,
  bool? bold,
  bool strike = false,
}) {
  final style = TextStyle(
    fontSize: baseSize ?? 14.5,
    height: 1.45,
    color: AppColors.textPrimary,
    fontWeight: bold != null
        ? (bold ? FontWeight.w800 : FontWeight.w400)
        : null,
    decoration: strike ? TextDecoration.lineThrough : null,
  );

  final spans = <InlineSpan>[];
  // Regex tách các token đặc biệt; $latex$ được ưu tiên để không bị curl
  // nhầm với *italic*.
  const pattern = r'\*\*(.+?)\*\*|\*(.+?)\*|~~(.+?)~~|`([^`]+?)`|\$([^$]+?)\$';
  final regex = RegExp(pattern, dotAll: true);

  var cursor = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ));
    } else if (match.group(2) != null) {
      spans.add(TextSpan(
        text: match.group(2),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ));
    } else if (match.group(3) != null) {
      spans.add(TextSpan(
        text: match.group(3),
        style: const TextStyle(
            decoration: TextDecoration.lineThrough, color: AppColors.textMuted),
      ));
    } else if (match.group(4) != null) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.cardLight,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            match.group(4)!,
            style: const TextStyle(
              fontSize: 12.5,
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ));
    } else if (match.group(5) != null) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          match.group(5)!,
          textStyle: TextStyle(
              fontSize: (baseSize ?? 14.5) - 0.5, color: AppColors.textPrimary),
          onErrorFallback: (_) => Text(
            '\$${match.group(5)}\$',
            style: TextStyle(
                fontSize: baseSize ?? 14.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary),
          ),
        ),
      ));
    }
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }

  return TextSpan(style: style, children: spans);
}
