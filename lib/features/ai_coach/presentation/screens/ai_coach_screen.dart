import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/animated_pulse.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final List<ChatMessage> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  final _uuid = const Uuid();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  AIModel _model = AIModel.defaultModel;

  @override
  void initState() {
    super.initState();
    _model = AIModel.fromSlug(StorageService.getAiModel());
    _messages.add(ChatMessage(
      id: _uuid.v4(),
      text: 'Chào bạn! Tôi là AI Coach EduPulse — trợ lý giải đề & luyện thi.\n\n- 📷 OCR quét ảnh bài tập\n- 🧠 Chỉ ra bẫy trắc nghiệm\n- 🗺️ Lộ trình cá nhân hóa\n\nHãy đặt câu hỏi hoặc tải ảnh bài tập!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedImageBytes = file.bytes;
            _selectedImageName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _clearImage() {
    setState(() { _selectedImageBytes = null; _selectedImageName = null; });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _selectedImageBytes == null) return;
    final messageText = text.trim();
    _ctrl.clear();
    final attachedImage = _selectedImageBytes;
    final attachedName = _selectedImageName;
    _clearImage();

    final userMsg = ChatMessage(id: _uuid.v4(), text: messageText, isUser: true, timestamp: DateTime.now(), imageBytes: attachedImage, imageName: attachedName);
    final loadingMsg = ChatMessage(id: _uuid.v4(), text: '', isUser: false, timestamp: DateTime.now(), isLoading: true);

    setState(() { _messages.add(userMsg); _messages.add(loadingMsg); _isLoading = true; });
    _scrollToBottom();

    final response = await AiRouter.chat(
      model: _model,
      history: _messages.where((m) => !m.isLoading).toList(),
      userMessage: messageText,
      imageBytes: attachedImage,
    );

    setState(() {
      _messages.remove(loadingMsg);
      _messages.add(ChatMessage(id: _uuid.v4(), text: response, isUser: false, timestamp: DateTime.now()));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  'Chọn model AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Nhiều model miễn phí, tự động chuyển khi hết lượt.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: AIModel.definitions.length,
                  itemBuilder: (ctx, i) {
                    final m = AIModel.definitions[i];
                    final selected = m.slug == _model.slug;
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      borderColor: selected ? AppColors.green : AppColors.border,
                      customColor: selected ? AppColors.green.withValues(alpha: 0.08) : AppColors.cardWhite,
                      onTap: () {
                        setState(() => _model = m);
                        StorageService.setAiModel(m.slug);
                        Navigator.pop(ctx);
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: selected ? AppColors.green : AppColors.bgPage,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(aiModelIcon(m.slug),
                                size: 18, color: selected ? Colors.white : AppColors.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? AppColors.green : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.description,
                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle, color: AppColors.green, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3))],
            ),
            child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('AI Coach',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showModelPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(aiModelIcon(_model.slug), size: 11, color: AppColors.green),
                            const SizedBox(width: 4),
                            Text(_model.label.split(' ').first,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _model.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_messages.length > 1)
            GestureDetector(
              onTap: () { setState(() => _messages.removeRange(1, _messages.length)); },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shadows: const [],
          child: const TypingDotsIndicator(),
        ),
      );
    }

    final isUser = msg.isUser;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: const [
              BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (msg.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(msg.imageBytes!, fit: BoxFit.cover, height: 150),
                ),
                if (msg.text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (msg.text.isNotEmpty)
                _buildRichText(msg.text, isUser: true),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        borderRadius: 18,
        shadows: const [],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(msg.imageBytes!, fit: BoxFit.cover, height: 150),
              ),
              if (msg.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (msg.text.isNotEmpty)
              _buildRichText(msg.text, isUser: false),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép')),
                );
              },
              child: Icon(Icons.copy, size: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichText(String text, {required bool isUser}) {
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final regex = RegExp(r'\$\$(.*?)\$\$|(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)');
    final matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text.replaceAll('**', ''),
        style: TextStyle(fontSize: 14, color: textColor, height: 1.45),
      );
    }

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final plainText = text.substring(lastEnd, match.start).replaceAll('**', '');
        if (plainText.isNotEmpty) {
          spans.add(TextSpan(
            text: plainText,
            style: TextStyle(fontSize: 14, color: textColor, height: 1.45),
          ));
        }
      }

      final latex = match.group(1) ?? match.group(2) ?? '';
      if (latex.isNotEmpty) {
        spans.add(WidgetSpan(
          child: _buildLatexWidget(latex, textColor: textColor),
          alignment: PlaceholderAlignment.middle,
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).replaceAll('**', '');
      if (remaining.isNotEmpty) {
        spans.add(TextSpan(
          text: remaining,
          style: TextStyle(fontSize: 14, color: textColor, height: 1.45),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildLatexWidget(String latex, {required Color textColor}) {
    final converted = _convertLatexToUnicode(latex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: textColor == Colors.white
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.bgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor == Colors.white
              ? Colors.white.withValues(alpha: 0.3)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Text(
        converted,
        style: TextStyle(
          fontSize: 15,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _convertLatexToUnicode(String latex) {
    String result = latex;

    // Fractions: \frac{a}{b} → a/b
    result = result.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (m) => '${m.group(1)}/${m.group(2)}',
    );

    // Square root: \sqrt{x} → √x
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (m) => '√(${m.group(1)})',
    );

    // Powers: x^{2} → x², x^{3} → x³
    final superscriptMap = {'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾'};
    result = result.replaceAllMapped(
      RegExp(r'\^{([^}]+)}'),
      (m) {
        final inner = m.group(1)!;
        return inner.split('').map((c) => superscriptMap[c] ?? c).join();
      },
    );

    // Subscripts: x_{1} → x₁
    final subscriptMap = {'0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉', '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎'};
    result = result.replaceAllMapped(
      RegExp(r'_{([^}]+)}'),
      (m) {
        final inner = m.group(1)!;
        return inner.split('').map((c) => subscriptMap[c] ?? c).join();
      },
    );

    // Greek letters
    result = result.replaceAll('\\alpha', 'α');
    result = result.replaceAll('\\beta', 'β');
    result = result.replaceAll('\\gamma', 'γ');
    result = result.replaceAll('\\delta', 'δ');
    result = result.replaceAll('\\epsilon', 'ε');
    result = result.replaceAll('\\theta', 'θ');
    result = result.replaceAll('\\lambda', 'λ');
    result = result.replaceAll('\\mu', 'μ');
    result = result.replaceAll('\\pi', 'π');
    result = result.replaceAll('\\sigma', 'σ');
    result = result.replaceAll('\\phi', 'φ');
    result = result.replaceAll('\\omega', 'ω');
    result = result.replaceAll('\\Delta', 'Δ');
    result = result.replaceAll('\\Sigma', 'Σ');
    result = result.replaceAll('\\Omega', 'Ω');

    // Math symbols
    result = result.replaceAll('\\times', '×');
    result = result.replaceAll('\\div', '÷');
    result = result.replaceAll('\\pm', '±');
    result = result.replaceAll('\\mp', '∓');
    result = result.replaceAll('\\leq', '≤');
    result = result.replaceAll('\\geq', '≥');
    result = result.replaceAll('\\neq', '≠');
    result = result.replaceAll('\\approx', '≈');
    result = result.replaceAll('\\equiv', '≡');
    result = result.replaceAll('\\infty', '∞');
    result = result.replaceAll('\\partial', '∂');
    result = result.replaceAll('\\nabla', '∇');
    result = result.replaceAll('\\forall', '∀');
    result = result.replaceAll('\\exists', '∃');
    result = result.replaceAll('\\in', '∈');
    result = result.replaceAll('\\notin', '∉');
    result = result.replaceAll('\\subset', '⊂');
    result = result.replaceAll('\\supset', '⊃');
    result = result.replaceAll('\\cup', '∪');
    result = result.replaceAll('\\cap', '∩');
    result = result.replaceAll('\\emptyset', '∅');
    result = result.replaceAll('\\rightarrow', '→');
    result = result.replaceAll('\\leftarrow', '←');
    result = result.replaceAll('\\Rightarrow', '⇒');
    result = result.replaceAll('\\Leftarrow', '⇐');
    result = result.replaceAll('\\leftrightarrow', '↔');
    result = result.replaceAll('\\cdot', '·');
    result = result.replaceAll('\\ldots', '…');
    result = result.replaceAll('\\cdots', '⋯');

    // Summation and integral
    result = result.replaceAll('\\sum', '∑');
    result = result.replaceAll('\\prod', '∏');
    result = result.replaceAll('\\int', '∫');

    // Clean up remaining backslashes
    result = result.replaceAll('\\', '');

    return result;
  }

  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedImageBytes != null)
          GlassCard(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderColor: AppColors.green,
            shadows: const [],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_selectedImageBytes!, width: 36, height: 36, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedImageName ?? 'Ảnh',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearImage,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: AppColors.red),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.borderDark, blurRadius: 0, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 20, color: AppColors.blue),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  enabled: !_isLoading,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _selectedImageBytes != null ? 'Ghi chú cho ảnh...' : 'Hỏi AI bài tập...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isLoading ? null : () => _sendMessage(_ctrl.text),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isLoading ? AppColors.border : AppColors.green,
                    shape: BoxShape.circle,
                    boxShadow: _isLoading ? null : const [
                      BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Icon(
                    Icons.send,
                    color: _isLoading ? AppColors.textMuted : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
