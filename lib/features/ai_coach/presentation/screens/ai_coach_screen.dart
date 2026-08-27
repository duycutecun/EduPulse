import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/gemini_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/animated_pulse.dart';
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
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _apiKey = StorageService.getGeminiApiKey();
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

    final response = await GeminiService.chat(apiKey: StorageService.getGeminiApiKey(), history: _messages.where((m) => !m.isLoading).toList(), userMessage: messageText, imageBytes: attachedImage);

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

  void _showApiKeyDialog() {
    final keyCtrl = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border, width: 2)),
        title: const Text('Cấu hình Gemini API Key', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nhập khóa API từ aistudio.google.com', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(controller: keyCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'AIzaSy...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () { final k = keyCtrl.text.trim(); StorageService.setGeminiApiKey(k); setState(() => _apiKey = k); Navigator.pop(ctx); },
            child: const Text('Lưu', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
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
    final hasKey = _apiKey.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('AI Coach', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _showApiKeyDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (hasKey ? AppColors.green : AppColors.orange).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasKey ? 'SẴN SÀNG' : 'CÀI API',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: hasKey ? AppColors.green : AppColors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isLoading ? 'Đang phân tích...' : 'Giải bài & OCR 24/7',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_messages.length > 1)
            IconButton(
              icon: Icon(Icons.refresh, size: 20, color: AppColors.textMuted),
              onPressed: () { setState(() => _messages.removeRange(1, _messages.length)); },
            ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: const TypingDotsIndicator(),
        ),
      );
    }

    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isUser ? AppColors.green : AppColors.cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: AppColors.border, width: 2),
          boxShadow: isUser
              ? [const BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.imageBytes != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(msg.imageBytes!, fit: BoxFit.cover, height: 150)),
              if (msg.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (msg.text.isNotEmpty)
              Text(
                msg.text.replaceAll('**', ''),
                style: TextStyle(fontSize: 14, color: isUser ? Colors.white : AppColors.textPrimary, height: 1.45),
              ),
            if (!isUser) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () { Clipboard.setData(ClipboardData(text: msg.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép'))); },
                child: Icon(Icons.copy, size: 14, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedImageBytes != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.green, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(_selectedImageBytes!, width: 32, height: 32, fit: BoxFit.cover)),
                const SizedBox(width: 8),
                Text(_selectedImageName ?? 'Ảnh', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                GestureDetector(onTap: _clearImage, child: Icon(Icons.close, size: 18, color: AppColors.textMuted)),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.camera_alt, size: 22, color: AppColors.blue), onPressed: _pickImage),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  enabled: !_isLoading,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
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
              const SizedBox(width: 6),
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
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
