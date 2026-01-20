import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/todo_provider.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 할일 추가 바텀 시트
class AddTodoSheet extends ConsumerStatefulWidget {
  const AddTodoSheet({super.key});

  @override
  ConsumerState<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends ConsumerState<AddTodoSheet> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAssigneeId;
  DateTime? _dueDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _hasTime = false;
  bool _isLoading = false;
  bool _showNoteField = false;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final todoService = ref.read(todoServiceProvider);

      // 시작/종료 시간을 DateTime으로 변환
      DateTime? startDateTime;
      DateTime? endDateTime;

      if (_hasTime && _dueDate != null && _startTime != null) {
        startDateTime = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );

        if (_endTime != null) {
          endDateTime = DateTime(
            _dueDate!.year,
            _dueDate!.month,
            _dueDate!.day,
            _endTime!.hour,
            _endTime!.minute,
          );
          // 종료 시간이 시작 시간보다 이전이면 다음 날로 설정
          if (endDateTime.isBefore(startDateTime)) {
            endDateTime = endDateTime.add(const Duration(days: 1));
          }
        } else {
          // 종료 시간이 없으면 시작 시간 + 1시간
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }
      }

      await todoService.addTodo(
        title: _titleController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        assigneeId: _selectedAssigneeId,
        dueDate: _dueDate,
        hasTime: _hasTime,
        startTime: startDateTime,
        endTime: endDateTime,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _hasTime = true;
        // 종료 시간이 없거나 시작 시간보다 이전이면 1시간 후로 설정
        if (_endTime == null || _isEndTimeBeforeStart(picked, _endTime!)) {
          final endHour = (picked.hour + 1) % 24;
          _endTime = TimeOfDay(hour: endHour, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  bool _isEndTimeBeforeStart(TimeOfDay start, TimeOfDay end) {
    return end.hour < start.hour || (end.hour == start.hour && end.minute <= start.minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(smartMembersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacingL,
          right: AppTheme.spacingL,
          top: AppTheme.spacingM,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 핸들바
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 타이틀
            Text(
              '새 할일',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 제목 입력
            TextField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleAdd(),
              decoration: const InputDecoration(
                hintText: '할 일을 입력하세요',
                prefixIcon: Icon(Iconsax.tick_square),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 노트 입력 (토글)
            if (_showNoteField) ...[
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '메모 (선택)',
                  prefixIcon: Icon(Iconsax.note_1),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],

            // 옵션 버튼들
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 노트 추가 버튼
                  _OptionChip(
                    icon: Iconsax.note_1,
                    label: '메모',
                    isSelected: _showNoteField,
                    onTap: () => setState(() => _showNoteField = !_showNoteField),
                  ),
                  const SizedBox(width: 8),

                  // 날짜 선택
                  _OptionChip(
                    icon: Iconsax.calendar_1,
                    label: _dueDate != null
                        ? DateFormat('M/d').format(_dueDate!)
                        : '날짜',
                    isSelected: _dueDate != null,
                    onTap: _selectDate,
                    onClear: _dueDate != null
                        ? () => setState(() {
                              _dueDate = null;
                              _hasTime = false;
                              _startTime = null;
                              _endTime = null;
                            })
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // 시간 선택 (날짜가 선택된 경우에만 표시)
                  if (_dueDate != null) ...[
                    _OptionChip(
                      icon: Iconsax.clock,
                      label: _hasTime && _startTime != null
                          ? _formatTimeOfDay(_startTime!)
                          : '시작',
                      isSelected: _hasTime,
                      onTap: _selectStartTime,
                      onClear: _hasTime
                          ? () => setState(() {
                                _hasTime = false;
                                _startTime = null;
                                _endTime = null;
                              })
                          : null,
                    ),
                    const SizedBox(width: 8),
                    if (_hasTime && _startTime != null) ...[
                      _OptionChip(
                        icon: Iconsax.clock_1,
                        label: _endTime != null
                            ? _formatTimeOfDay(_endTime!)
                            : '종료',
                        isSelected: _endTime != null,
                        onTap: _selectEndTime,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],

                  // 담당자 선택
                  ...members.map((member) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: MemberAvatar(
                          member: member,
                          size: 36,
                          isSelected: _selectedAssigneeId == member.id,
                          onTap: () {
                            setState(() {
                              if (_selectedAssigneeId == member.id) {
                                _selectedAssigneeId = null;
                              } else {
                                _selectedAssigneeId = member.id;
                              }
                            });
                          },
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // 추가 버튼
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAdd,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _OptionChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.15)
              : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryLight
                : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight)
                    .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primaryLight
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? AppColors.primaryLight
                    : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
