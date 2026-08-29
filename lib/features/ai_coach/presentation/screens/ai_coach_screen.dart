import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../study/domain/models/study_models.dart';
import '../widgets/ai_coach_header.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/model_picker_sheet.dart';

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

  bool get _isIntroOnly => _messages.length == 1;

  @override
  void initState() {
    super.initState();
    _model = AIModel.fromSlug(StorageService.getAiModel());
    _messages.add(ChatMessage(
      id: _uuid.v4(),
      text: 'Chào bạn! Tôi là AI Coach EduPulse — trợ lý giải đề & luyện thi.\n\n- 📷 OCR quét ảnh bài tập\n- 🧠 Chỉ ra bẫy trắc nghiệm\n- 🗺️ Lộ trình cá nhân hóa\n- 🔍 Tra cứu web để biết thêm thông tin\n\nHãy đặt câu hỏi hoặc tải ảnh bài tập!',
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
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (mounted && bytes.isNotEmpty) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
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
    showModelPickerSheet(
      context: context,
      currentModel: _model,
      onSelect: (m) {
        setState(() => _model = m);
        StorageService.setAiModel(m.slug);
      },
    );
  }

  void _refreshChat() {
    setState(() => _messages.removeRange(1, _messages.length));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AICoachHeader(
          model: _model,
          onModelTap: _showModelPicker,
          onRefresh: _refreshChat,
          showRefresh: _messages.length > 1,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: _messages.length + (_isIntroOnly ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (_isIntroOnly && i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/mascot.png',
                        width: 116,
                        height: 116,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              }
              return ChatBubble(msg: _messages[i - (_isIntroOnly ? 1 : 0)]);
            },
          ),
        ),
        ChatInputBar(
          controller: _ctrl,
          focusNode: _focusNode,
          isLoading: _isLoading,
          selectedImageBytes: _selectedImageBytes,
          selectedImageName: _selectedImageName,
          onPickImage: _pickImage,
          onClearImage: _clearImage,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}
