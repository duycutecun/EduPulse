import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/ai/ai_refresh_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../../domain/models/task_attachment.dart';
import '../../domain/models/task_state.dart';
import '../../domain/repositories/task_repository.dart';
import 'delete_task_dialog.dart';

/// Modal Chi tiết Nhiệm vụ học tập theo đặc tả Sprint 2 (FE-2.2)
class TaskDetailSheet extends StatefulWidget {
  final TodayTask task;
  final ValueChanged<TodayTask> onTaskUpdated;
  final ValueChanged<TodayTask> onStartStudy;
  final ValueChanged<TodayTask> onEdit;
  final ValueChanged<TodayTask> onReschedule;
  final ValueChanged<TodayTask> onDelete;

  /// Chia nhỏ thủ công — luôn có sẵn, không phụ thuộc AI.
  final ValueChanged<TodayTask>? onSplit;
  final ValueChanged<TodayTask>? onAskAi;
  final ValueChanged<TodayTask>? onSplitWithAi;

  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.onStartStudy,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
    this.onSplit,
    this.onAskAi,
    this.onSplitWithAi,
  });

  static Future<void> show(
    BuildContext context, {
    required TodayTask task,
    required ValueChanged<TodayTask> onTaskUpdated,
    required ValueChanged<TodayTask> onStartStudy,
    required ValueChanged<TodayTask> onEdit,
    required ValueChanged<TodayTask> onReschedule,
    required ValueChanged<TodayTask> onDelete,
    ValueChanged<TodayTask>? onSplit,
    ValueChanged<TodayTask>? onAskAi,
    ValueChanged<TodayTask>? onSplitWithAi,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailSheet(
        task: task,
        onTaskUpdated: onTaskUpdated,
        onStartStudy: onStartStudy,
        onEdit: onEdit,
        onReschedule: onReschedule,
        onDelete: onDelete,
        onSplit: onSplit,
        onAskAi: onAskAi,
        onSplitWithAi: onSplitWithAi,
      ),
    );
  }

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late TodayTask _currentTask;

  /// Tài liệu đính kèm + lịch sử phiên học (FE-2.2).
  ///
  /// Nạp ở `initState` chứ không đọc trong `build`: `build` chạy lại mỗi lần
  /// tick hoàn thành, mà đọc storage + giải mã base64 trong build thì vừa
  /// chậm vừa dễ lỗi.
  List<TaskAttachment> _attachments = const [];
  List<StudySession> _sessions = const [];
  bool _loadingAttachments = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _loadRelatedData();
  }

  void _loadRelatedData() {
    final repo = TaskRepository.instance;
    _attachments = repo.listAttachments(_currentTask.id);
    _sessions = StudySessionRepository.instance.getForTask(_currentTask.id);
  }

  void _reloadAttachments() {
    setState(() {
      _attachments = TaskRepository.instance.listAttachments(_currentTask.id);
      _sessions = StudySessionRepository.instance.getForTask(_currentTask.id);
    });
  }

  /// Gắn ảnh từ máy. Giới hạn kích thước do **repository** chặn (không phải
  /// ở đây) để mọi đường ghi đều bị chặn như nhau — UI chỉ báo lỗi.
  Future<void> _pickAttachment() async {
    if (_loadingAttachments) return;
    setState(() => _loadingAttachments = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isEmpty) return;
      final picked = result.first;

      // Chặn trước khi mã hoá base64 — phình ~4/3 sẽ nặng prefs gấp rưỡi.
      final bytes = await picked.readAsBytes();
      if (bytes.length > TaskAttachment.maxBytes) {
        messenger.showSnackBar(SnackBar(
          content: Text(
            'Ảnh nặng ${(bytes.length / 1024).round()}KB — vượt giới hạn '
            '${TaskAttachment.maxBytes ~/ 1024}KB. Hãy chọn ảnh nhẹ hơn.',
          ),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      final added = TaskRepository.instance.addAttachment(
        _currentTask.id,
        name: picked.name,
        bytes: bytes,
      );
      if (!added.success) {
        messenger.showSnackBar(SnackBar(
          content: Text(added.error ?? 'Không gắn được tài liệu.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      AiRefreshService.notifyDataChanged();
      _reloadAttachments();
    } finally {
      if (mounted) setState(() => _loadingAttachments = false);
    }
  }

  Future<void> _confirmRemoveAttachment(TaskAttachment attachment) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Gỡ tài liệu?',
      content: 'Tài liệu này sẽ bị gỡ khỏi nhiệm vụ. Bấm Hoàn tác ngay sau đó '
          'để khôi phục lại.',
      highlightedItem: attachment.name,
      confirmLabel: 'Gỡ tài liệu',
      cancelLabel: 'Giữ lại',
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final removed = TaskRepository.instance
        .removeAttachment(_currentTask.id, attachment.id);
    if (!removed.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(removed.error ?? 'Không gỡ được tài liệu.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final name = attachment.name;
    final taskId = _currentTask.id;
    _reloadAttachments();
    showUndoSnackBar(
      context,
      message: 'Đã gỡ "$name".',
      onUndo: () {
        TaskRepository.instance.restoreAttachment(taskId, attachment);
        _reloadAttachments();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusEnum = TaskStatus.fromString(_currentTask.status);
    final statusLabel = TaskStateMachine.getStatusLabel(statusEnum);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.space24,
        top: AppTokens.space16,
        left: AppTokens.space20,
        right: AppTokens.space20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: AppTokens.rXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppTokens.brFull,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space16),

          // Header: Subject & Actions
          Row(
            children: [
              // Chip môn — dùng danh mục chuẩn để khớp màu với TaskCard.
              // Cả cụm chip co lại được, nút hành động bên phải luôn chạm tới.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: TaskStatusChip(
                        label: AppSubjects.displayName(_currentTask.subject),
                        color: AppSubjects.colorOf(_currentTask.subject),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Flexible(
                      child: TaskStatusChip(
                        label: statusLabel,
                        color: _statusColor(statusEnum),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              // Đánh dấu hoàn thành ngay trong màn chi tiết — trạng thái được
              // ghi qua repository (onTaskUpdated), không sửa cục bộ.
              IconButton(
                tooltip: _currentTask.isDone
                    ? 'Bỏ đánh dấu hoàn thành'
                    : 'Đánh dấu hoàn thành',
                icon: Icon(
                  _currentTask.isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: _currentTask.isDone
                      ? AppColors.green
                      : AppColors.textMuted,
                ),
                onPressed: () {
                  widget.onTaskUpdated(_currentTask);
                  Navigator.of(context).pop();
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onEdit(_currentTask);
                },
                tooltip: 'Sửa nhiệm vụ',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.red),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDelete(_currentTask);
                },
                tooltip: 'Xóa nhiệm vụ',
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),

          // Task Title
          Text(
            _currentTask.title,
            style: AppTokens.heading2.copyWith(fontSize: 18),
          ),
          if (_currentTask.topic != null &&
              _currentTask.topic!.trim().isNotEmpty) ...[
            const SizedBox(height: AppTokens.space4),
            Text(
              'Chủ đề: ${_currentTask.topic}',
              style:
                  AppTokens.bodySubtle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppTokens.space16),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.timer_outlined,
                          title: 'Thời lượng',
                          value: '${_currentTask.estimateMinutes} phút',
                        ),
                      ),
                      const SizedBox(width: AppTokens.space10),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.flag_outlined,
                          title: 'Ưu tiên',
                          value: _getPriorityLabel(_currentTask.priority),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space10),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.calendar_today_outlined,
                          title: 'Hạn chót',
                          value: _currentTask.deadline == null
                              ? 'Không có'
                              : '${_currentTask.deadline!.day}/${_currentTask.deadline!.month}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space16),

                  // Ghi chú nếu có
                  if (_currentTask.note != null &&
                      _currentTask.note!.trim().isNotEmpty) ...[
                    Text('Ghi chú', style: AppTokens.heading3),
                    const SizedBox(height: AppTokens.space6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTokens.space12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: AppTokens.brMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _currentTask.note!,
                        style: AppTokens.body,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],

                  // Danh sách mục con (Checklist / Subtasks)
                  if (_currentTask.subtasks.isNotEmpty) ...[
                    Text('Checklist bài học', style: AppTokens.heading3),
                    const SizedBox(height: AppTokens.space6),
                    ..._currentTask.subtasks.map((sub) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppTokens.space6),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: AppTokens.space8),
                              Expanded(
                                child: Text(sub, style: AppTokens.body),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: AppTokens.space16),
                  ],

                  // Tài liệu kèm theo (FE-2.2)
                  ..._buildAttachmentsSection(),

                  // Lịch sử các phiên học liên quan (FE-2.2)
                  ..._buildSessionHistorySection(),

                  // Các hành động AI theo ngữ cảnh (FE-2.2, AI-2.1)
                  Text('Trợ lý AI ngữ cảnh', style: AppTokens.heading3),
                  const SizedBox(height: AppTokens.space8),
                  Row(
                    children: [
                      if (widget.onSplit != null && !_currentTask.isDone)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTokens.space10,
                              ),
                            ),
                            icon:
                                const Icon(Icons.call_split_rounded, size: 16),
                            label: const Text('Chia nhỏ bài học',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSplit!(_currentTask);
                            },
                          ),
                        ),
                      if (widget.onSplit != null &&
                          !_currentTask.isDone &&
                          widget.onAskAi != null)
                        const SizedBox(width: AppTokens.space8),
                      if (widget.onAskAi != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.blueDark,
                              side: const BorderSide(color: AppColors.blue),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTokens.space10,
                              ),
                            ),
                            icon:
                                const Icon(Icons.psychology_outlined, size: 16),
                            label: const Text('Hỏi AI bài này',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onAskAi!(_currentTask);
                            },
                          ),
                        ),
                      if (widget.onAskAi != null &&
                          widget.onSplitWithAi != null)
                        const SizedBox(width: AppTokens.space8),
                      if (widget.onSplitWithAi != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTokens.space10,
                              ),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded,
                                size: 16),
                            label: const Text('Gợi ý từ AI',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSplitWithAi!(_currentTask);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space16),

          // Primary Actions
          Row(
            children: [
              if (!_currentTask.isDone) ...[
                Expanded(
                  child: SecondaryButton(
                    label: 'Dời lịch',
                    icon: Icons.schedule_rounded,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onReschedule(_currentTask);
                    },
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
              ],
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: _currentTask.isDone
                      ? 'Học lại bài này'
                      : 'Bắt đầu học ngay',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onStartStudy(_currentTask);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Khối "Tài liệu kèm theo" (FE-2.2).
  ///
  /// Hiện cả trạng thái rỗng lẫn danh sách: một màn chi tiết mà mỗi phần đều
  /// "biến mất khi rỗng" khiến người dùng không biết app có hỗ trợ hay không.
  List<Widget> _buildAttachmentsSection() {
    final canAdd = _attachments.length < TaskAttachment.maxCount;

    return [
      Row(
        children: [
          Expanded(
            child: Text('Tài liệu kèm theo', style: AppTokens.heading3),
          ),
          Text(
            '${_attachments.length}/${TaskAttachment.maxCount}',
            style: AppTokens.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: AppTokens.space8),
          IconButton(
            onPressed: canAdd && !_loadingAttachments ? _pickAttachment : null,
            tooltip: canAdd
                ? 'Gắn ảnh (tối đa ${TaskAttachment.maxBytes ~/ 1024}KB)'
                : 'Đã đủ ${TaskAttachment.maxCount} tài liệu',
            visualDensity: VisualDensity.compact,
            icon: _loadingAttachments
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    canAdd
                        ? Icons.add_photo_alternate_outlined
                        : Icons.block_rounded,
                    size: 18,
                    color: canAdd ? AppColors.primary : AppColors.textMuted,
                  ),
          ),
        ],
      ),
      const SizedBox(height: AppTokens.space6),
      if (_attachments.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTokens.space12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppTokens.brMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Chưa có tài liệu. Gắn ảnh chụp bài để mở nhanh khi học '
            '(mỗi ảnh tối đa ${TaskAttachment.maxBytes ~/ 1024}KB).',
            style: AppTokens.caption.copyWith(color: AppColors.textMuted),
          ),
        )
      else
        ..._attachments.map((attachment) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: _buildAttachmentTile(attachment),
            )),
      const SizedBox(height: AppTokens.space16),
    ];
  }

  Widget _buildAttachmentTile(TaskAttachment attachment) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.brSm,
            child: Image.memory(
              _decodeAttachment(attachment),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 44,
                height: 44,
                color: AppColors.border,
                child: const Icon(Icons.broken_image_outlined,
                    size: 18, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: AppTokens.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${attachment.sizeLabel} · thêm ${_dayTitle(attachment.addedAt)}',
                  style: AppTokens.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _confirmRemoveAttachment(attachment),
            tooltip: 'Gỡ tài liệu',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.red),
          ),
        ],
      ),
    );
  }

  /// Khối "Lịch sử phiên học" (FE-2.2) — đọc `StudySession.taskId`.
  List<Widget> _buildSessionHistorySection() {
    final totalMinutes =
        _sessions.fold<int>(0, (sum, session) => sum + session.actualMinutes);

    return [
      Text('Lịch sử phiên học', style: AppTokens.heading3),
      const SizedBox(height: AppTokens.space6),
      if (_sessions.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTokens.space12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppTokens.brMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Chưa có phiên học nào cho nhiệm vụ này. Bắt đầu phiên học để ghi '
            'lại thời gian và cảm nhận của bạn.',
            style: AppTokens.caption.copyWith(color: AppColors.textMuted),
          ),
        )
      else ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTokens.space12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: AppTokens.brMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  'Đã học $totalMinutes phút trong ${_sessions.length} phiên',
                  style: AppTokens.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        ..._sessions.map((session) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: _buildSessionTile(session),
            )),
      ],
      const SizedBox(height: AppTokens.space16),
    ];
  }

  Widget _buildSessionTile(StudySession session) {
    final ratings = <String>[
      if (session.focus != null) 'Tập trung ${session.focus}/5',
      if (session.difficulty != null) 'Khó ${session.difficulty}/5',
      if (session.effectiveness != null) 'Hiệu quả ${session.effectiveness}/5',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_dayTitle(session.completedAt)} · '
                  '${session.actualMinutes}/${session.plannedMinutes} phút',
                  style: AppTokens.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (session.actualMinutes != session.plannedMinutes)
                Icon(
                  session.actualMinutes > session.plannedMinutes
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
            ],
          ),
          if (ratings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ratings.join(' · '),
              style: AppTokens.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (session.reflectionNote != null &&
              session.reflectionNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(session.reflectionNote!,
                style: AppTokens.caption, maxLines: 3),
          ],
        ],
      ),
    );
  }

  /// "Hôm nay" / "16/10" — dùng chung cho tài liệu và phiên học.
  static String _dayTitle(DateTime date) {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == -1) return 'Hôm qua';
    return '${date.day}/${date.month}';
  }

  /// Giải mã base64; ảnh hỏng trả về byte rỗng để `Image.memory` rơi vào
  /// `errorBuilder` thay vì ném exception ra khỏi `build`.
  static Uint8List _decodeAttachment(TaskAttachment attachment) {
    try {
      return base64Decode(attachment.base64);
    } catch (_) {
      return Uint8List(0);
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppTokens.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: AppTokens.caption.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTokens.body.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'Quan trọng';
      case 'low':
        return 'Bình thường';
      case 'medium':
      default:
        return 'Vừa phải';
    }
  }

  /// Màu nhất quán theo trạng thái, dùng chung với TaskCard.
  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return AppColors.green;
      case TaskStatus.notCompleted:
        return AppColors.textMuted;
      case TaskStatus.rescheduled:
        return AppColors.warning;
      case TaskStatus.started:
        return AppColors.blue;
      case TaskStatus.scheduled:
        return AppColors.primary;
    }
  }
}
