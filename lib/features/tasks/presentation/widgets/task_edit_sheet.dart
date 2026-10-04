import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../study/domain/models/study_models.dart';

/// Kết quả trả về từ form — thêm mới hoặc cập nhật nhiệm vụ (FE-2.3).
///
/// `isNew == false` ⇒ `id` và `createdAt` được giữ nguyên từ nhiệm vụ gốc,
/// nhờ đó lịch sử phiên học đã tham chiếu tới task không bị đứt đoạn.
class TaskFormResult {
  final TodayTask task;
  final bool isNew;

  const TaskFormResult({required this.task, required this.isNew});
}

/// Form Tạo mới / Chỉnh sửa nhiệm vụ (FE-2.3).
///
/// Một form duy nhất cho cả create và edit — đặc tả §5.4 yêu cầu không tạo
/// "ngôn ngữ hình ảnh" riêng cho việc sửa.
class TaskEditSheet extends StatefulWidget {
  /// `null` ⇒ tạo mới.
  final TodayTask? initialTask;

  final ValueChanged<TaskFormResult> onSave;

  const TaskEditSheet({
    super.key,
    this.initialTask,
    required this.onSave,
  });

  /// Mở form và trả về kết quả (null nếu người dùng huỷ).
  static Future<TaskFormResult?> show(
    BuildContext context, {
    TodayTask? initialTask,
  }) {
    return showModalBottomSheet<TaskFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskEditSheet(
        initialTask: initialTask,
        onSave: (result) => Navigator.of(context).pop(result),
      ),
    );
  }

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  static const List<int> _durations = [15, 25, 30, 45, 60, 90];

  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  final _noteController = TextEditingController();

  late String _subject;
  late String _priority;
  late int _minutes;
  DateTime? _deadline;
  late DateTime _scheduledAt;
  String? _titleError;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController.text = task?.title ?? '';
    _topicController.text = task?.topic ?? '';
    _noteController.text = task?.note ?? '';

    // Task cũ có thể lưu subject dạng không emoji → chuẩn hoá khi mở form.
    _subject = AppSubjects.normalize(task?.subject);
    _priority = _normalizePriority(task?.priority);
    _minutes = task?.estimateMinutes ?? 45;
    _deadline = task?.deadline;
    _scheduledAt = task?.scheduledAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _normalizePriority(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return 'high';
      case 'low':
        return 'low';
      default:
        return 'medium';
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Vui lòng nhập tên bài học');
      return;
    }

    final existing = widget.initialTask;
    final scheduledDay = DateUtils.dateOnly(_scheduledAt);

    final result = existing == null
        // Tạo mới — ngày mặc định là hôm nay để task lập tức xuất hiện ở Hôm nay.
        ? TodayTask(
            id: const Uuid().v4(),
            title: title,
            subject: _subject,
            topic: _emptyToNull(_topicController.text),
            priority: _priority,
            estimateMinutes: _minutes,
            deadline: _deadline,
            scheduledAt: DateTime(
              _scheduledAt.year,
              _scheduledAt.month,
              _scheduledAt.day,
              _scheduledAt.hour,
              _scheduledAt.minute,
            ),
            note: _emptyToNull(_noteController.text),
            createdAt: DateTime.now(),
          )
        // Sửa — copyWith giữ nguyên id, createdAt, status, rescheduleCount,
        // subtasks, goalId, recurrence và lịch sử liên kết.
        : existing.copyWith(
            title: title,
            subject: _subject,
            topic: _emptyToNull(_topicController.text),
            priority: _priority,
            estimateMinutes: _minutes,
            deadline: _deadline,
            scheduledAt: DateTime(
              _scheduledAt.year,
              _scheduledAt.month,
              _scheduledAt.day,
              _scheduledAt.hour,
              _scheduledAt.minute,
            ),
            note: _emptyToNull(_noteController.text),
          );

    // Chọn ngày khác hôm nay ⇒ coi như dời lịch: đưa task về trạng thái sẵn
    // sàng làm trên ngày mới thay vì giữ trạng thái của ngày cũ.
    final movedDay = existing != null &&
        existing.scheduledAt != null &&
        scheduledDay != DateUtils.dateOnly(existing.scheduledAt!);
    if (movedDay && !result.isDone) {
      result
        ..status = 'todo'
        ..rescheduleCount = existing.rescheduleCount + 1
        ..skipReason = null;
    }

    widget.onSave(TaskFormResult(task: result, isNew: existing == null));
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset + AppTokens.space8),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: AppTokens.rXl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space20,
                AppTokens.space12,
                AppTokens.space20,
                AppTokens.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: AppTokens.space20),
                  _titleField(),
                  const SizedBox(height: AppTokens.space20),
                  _subjectSection(),
                  const SizedBox(height: AppTokens.space20),
                  _durationSection(),
                  const SizedBox(height: AppTokens.space20),
                  _prioritySection(),
                  const SizedBox(height: AppTokens.space20),
                  _scheduleSection(),
                  const SizedBox(height: AppTokens.space20),
                  _noteField(),
                ],
              ),
            ),
          ),
          // Thanh hành động dính đáy — luôn nhìn thấy kể cả khi bàn phím che.
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space20,
              AppTokens.space12,
              AppTokens.space20,
              AppTokens.space20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Hủy',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: _isEditing ? 'Lưu thay đổi' : 'Tạo nhiệm vụ',
                    icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Chỉnh sửa nhiệm vụ' : 'Thêm nhiệm vụ',
                style: AppTokens.heading2,
              ),
              if (_isEditing)
                Text(
                  'ID và lịch sử học tập được giữ nguyên',
                  style: AppTokens.caption,
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 20),
          color: AppColors.textMuted,
          tooltip: 'Đóng',
        ),
      ],
    );
  }

  Widget _titleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Tên bài học', required: true),
        const SizedBox(height: AppTokens.space8),
        TextField(
          controller: _titleController,
          autofocus: !_isEditing,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'VD: Ôn tập hàm số lũy thừa',
            errorText: _titleError,
            border: OutlineInputBorder(
              borderRadius: AppTokens.brMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space14,
            ),
          ),
          onChanged: (_) {
            if (_titleError != null) setState(() => _titleError = null);
          },
        ),
      ],
    );
  }

  Widget _subjectSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Môn học'),
        const SizedBox(height: AppTokens.space8),
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: AppSubjects.all.map((subject) {
            final isSelected = _subject == subject.name;
            final color = subject.color;
            return ChoiceChip(
              selected: isSelected,
              avatar: Icon(
                subject.icon,
                size: 15,
                color: isSelected ? color : AppColors.textMuted,
              ),
              label: Text(subject.plainName),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
              selectedColor: color.withValues(alpha: 0.14),
              backgroundColor: AppColors.cardLight,
              side: BorderSide(
                color: isSelected ? color : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) setState(() => _subject = subject.name);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _durationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Thời lượng dự kiến'),
        const SizedBox(height: AppTokens.space8),
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: _durations.map((mins) {
            final isSelected = _minutes == mins;
            return ChoiceChip(
              selected: isSelected,
              label: Text('$mins phút'),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
              selectedColor: AppColors.primaryLight,
              backgroundColor: AppColors.cardLight,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) setState(() => _minutes = mins);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _prioritySection() {
    const options = [
      ('low', '🌱 Nhẹ', AppColors.textMuted),
      ('medium', '⭐ Vừa', AppColors.blue),
      ('high', '🔥 Quan trọng', AppColors.red),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Mức độ ưu tiên'),
        const SizedBox(height: AppTokens.space8),
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: options.map((option) {
            final isSelected = _priority == option.$1;
            final color = option.$3;
            return ChoiceChip(
              selected: isSelected,
              label: Text(option.$2),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
              selectedColor: color.withValues(alpha: 0.14),
              backgroundColor: AppColors.cardLight,
              side: BorderSide(
                color: isSelected ? color : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) setState(() => _priority = option.$1);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _scheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Lịch học'),
        const SizedBox(height: AppTokens.space8),
        _dateTile(
          icon: Icons.event_available_rounded,
          label: 'Học vào ngày',
          value: _formatDate(_scheduledAt),
          highlight: DateUtils.dateOnly(_scheduledAt) !=
              DateUtils.dateOnly(DateTime.now()),
          onTap: _pickScheduledDate,
        ),
        const SizedBox(height: AppTokens.space8),
        _dateTile(
          icon: Icons.flag_outlined,
          label: 'Hạn chót (không bắt buộc)',
          value: _deadline == null ? 'Không có' : _formatDate(_deadline!),
          highlight: false,
          onClear:
              _deadline == null ? null : () => setState(() => _deadline = null),
          onTap: _pickDeadline,
        ),
        if (_deadline != null &&
            DateUtils.dateOnly(_deadline!)
                .isBefore(DateUtils.dateOnly(_scheduledAt)))
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.space8),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: AppTokens.space6),
                Expanded(
                  child: Text(
                    'Hạn chót sớm hơn ngày học — nhiệm vụ có thể không kịp.',
                    style: AppTokens.caption
                        .copyWith(color: AppColors.warningDark),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dateTile({
    required IconData icon,
    required String label,
    required String value,
    required bool highlight,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.brMd,
      child: Container(
        constraints:
            const BoxConstraints(minHeight: AppTokens.standardTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space10,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: highlight ? AppColors.primary : AppColors.border,
          ),
          borderRadius: AppTokens.brMd,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: highlight ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: AppTokens.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTokens.caption),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTokens.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: highlight
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.all(AppTokens.space4),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Ghi chú (không bắt buộc)'),
        const SizedBox(height: AppTokens.space8),
        TextField(
          controller: _noteController,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Nội dung cần chú ý, tài liệu tham khảo…',
            border: OutlineInputBorder(
              borderRadius: AppTokens.brMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.all(AppTokens.space12),
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text, style: AppTokens.heading3),
        if (required)
          Text(' *', style: AppTokens.heading3.copyWith(color: AppColors.red)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final day = DateUtils.dateOnly(date);
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    String prefix;
    if (day == today) {
      prefix = 'Hôm nay';
    } else if (day == tomorrow) {
      prefix = 'Ngày mai';
    } else if (day == yesterday) {
      prefix = 'Hôm qua';
    } else {
      const weekdays = [
        'Thứ hai',
        'Thứ ba',
        'Thứ tư',
        'Thứ năm',
        'Thứ sáu',
        'Thứ bảy',
        'Chủ nhật',
      ];
      prefix = weekdays[day.weekday - 1];
    }
    return '$prefix · ${date.day}/${date.month}/${date.year}';
  }

  Future<void> _pickScheduledDate() async {
    final picked = await _pickDate(_scheduledAt, hint: 'Chọn ngày học');
    if (picked == null) return;
    setState(() {
      _scheduledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await _pickDate(
      _deadline ?? _scheduledAt,
      hint: 'Chọn hạn chót',
    );
    if (picked == null) return;
    setState(() {
      _deadline = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
      );
    });
  }

  /// Ngày cho phép chọn: deadline có thể nằm trong quá khứ (task quá hạn vẫn
  /// hợp lệ — học sinh cần nhìn thấy nó), ngày học thì không.
  Future<DateTime?> _pickDate(DateTime initial, {required String hint}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: hint,
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderStrong,
            borderRadius: AppTokens.brFull,
          ),
        ),
      ),
    );
  }
}
