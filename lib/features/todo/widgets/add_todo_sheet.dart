import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/todo_provider.dart';
import '../../../shared/providers/group_provider.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/models/recurrence.dart';

/// 할일 추가/수정 바텀 시트
class AddTodoSheet extends ConsumerStatefulWidget {
  final String? todoId;
  final DateTime? initialDate;

  const AddTodoSheet({super.key, this.todoId, this.initialDate});

  @override
  ConsumerState<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends ConsumerState<AddTodoSheet> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedAssigneeId;
  DateTime? _dueDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _hasTime = false;
  bool _isLoading = false;
  bool _showNoteField = false;
  TodoEventType _eventType = TodoEventType.todo;

  // Event 통합 필드
  final List<String> _selectedParticipants = [];
  bool _showLocationField = false;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  final List<int> _recurrenceDays = [];
  DateTime? _recurrenceEndDate;
  bool _excludeHolidays = false;
  String? _selectedColor;

  // Phase 2: 공개 범위 및 공유 그룹
  TodoVisibility _visibility = TodoVisibility.shared;
  final List<String> _sharedGroups = [];

  // 알림 설정
  final List<int> _reminderMinutes = [];

  @override
  void initState() {
    super.initState();
    // initialDate가 있으면 설정
    if (widget.initialDate != null) {
      _dueDate = widget.initialDate;
    }

    // 수정 모드가 아닌 경우에만 현재 사용자/그룹 기본 선택
    if (widget.todoId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentMember = ref.read(smartCurrentMemberProvider);
        final currentMembership = ref.read(currentMembershipProvider);
        if (mounted) {
          setState(() {
            if (currentMember != null) {
              _selectedParticipants.add(currentMember.id);
              _selectedAssigneeId = currentMember.id;
            }
            // Phase 2: 현재 그룹을 기본 공유 그룹으로 설정
            if (currentMembership != null) {
              _sharedGroups.add(currentMembership.groupId);
            }
          });
        }
      });
    } else {
      // 수정 모드인 경우 기존 값 로드
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTodoData();
      });
    }
  }

  void _loadTodoData() {
    final todos = ref.read(todosProvider).value ?? [];
    final todo = todos.firstWhere(
      (t) => t.id == widget.todoId,
      orElse: () => throw Exception('Todo not found'),
    );

    setState(() {
      _titleController.text = todo.title;
      _noteController.text = todo.note ?? '';
      _selectedAssigneeId = todo.assigneeId;
      _dueDate = todo.dueDate;
      _hasTime = todo.hasTime;
      _showNoteField = todo.note != null && todo.note!.isNotEmpty;
      _eventType = todo.eventType;

      if (todo.startTime != null) {
        _startTime = TimeOfDay.fromDateTime(todo.startTime!);
      }
      if (todo.endTime != null) {
        _endTime = TimeOfDay.fromDateTime(todo.endTime!);
      }

      // Event 통합 필드
      _selectedParticipants.clear();
      _selectedParticipants.addAll(todo.participants);
      _locationController.text = todo.location ?? '';
      _showLocationField = todo.location != null && todo.location!.isNotEmpty;
      _recurrenceType = todo.recurrenceType;
      _recurrenceDays.clear();
      if (todo.recurrenceDays != null) {
        _recurrenceDays.addAll(todo.recurrenceDays!);
      }
      _recurrenceEndDate = todo.recurrenceEndDate;
      _excludeHolidays = todo.excludeHolidays;
      _selectedColor = todo.color;
      // Phase 2 필드
      _visibility = todo.visibility;
      _sharedGroups.clear();
      _sharedGroups.addAll(todo.sharedGroups);
      // 알림 설정
      _reminderMinutes.clear();
      _reminderMinutes.addAll(todo.reminderMinutes);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _locationController.dispose();
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

      // 수정 모드인 경우
      if (widget.todoId != null) {
        await todoService.updateTodo(
          widget.todoId!,
          title: _titleController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          assigneeId: _selectedAssigneeId,
          dueDate: _dueDate,
          hasTime: _hasTime,
          startTime: startDateTime,
          endTime: endDateTime,
          eventType: _eventType,
          participants: _selectedParticipants,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          recurrenceType: _recurrenceType,
          recurrenceDays: _recurrenceDays.isEmpty ? null : _recurrenceDays,
          recurrenceEndDate: _recurrenceEndDate,
          excludeHolidays: _excludeHolidays,
          color: _selectedColor,
          // Phase 2 필드
          visibility: _visibility,
          sharedGroups: _sharedGroups,
          // 알림 설정
          reminderMinutes: _reminderMinutes,
        );
      } else {
        // 추가 모드
        await todoService.addTodo(
          title: _titleController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          assigneeId: _selectedAssigneeId,
          dueDate: _dueDate,
          hasTime: _hasTime,
          startTime: startDateTime,
          endTime: endDateTime,
          eventType: _eventType,
          participants: _selectedParticipants,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          recurrenceType: _recurrenceType,
          recurrenceDays: _recurrenceDays.isEmpty ? null : _recurrenceDays,
          recurrenceEndDate: _recurrenceEndDate,
          excludeHolidays: _excludeHolidays,
          color: _selectedColor,
          // Phase 2 필드
          visibility: _visibility,
          sharedGroups: _sharedGroups,
          // 알림 설정
          reminderMinutes: _reminderMinutes,
        );
      }
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

  Future<void> _showRecurrenceSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecurrenceSheet(
        initialType: _recurrenceType,
        initialDays: _recurrenceDays,
        initialEndDate: _recurrenceEndDate,
        initialExcludeHolidays: _excludeHolidays,
        onSave: (type, days, endDate, excludeHolidays) {
          setState(() {
            _recurrenceType = type;
            _recurrenceDays.clear();
            _recurrenceDays.addAll(days);
            _recurrenceEndDate = endDate;
            _excludeHolidays = excludeHolidays;
          });
        },
      ),
    );
  }

  String _getRecurrenceLabel() {
    if (_recurrenceType == RecurrenceType.none) return '반복';
    String label = _recurrenceType.shortName;
    if (_recurrenceType == RecurrenceType.weekly && _recurrenceDays.isNotEmpty) {
      final dayNames = _recurrenceDays.map((d) => Weekdays.getName(d)).join(',');
      label += ' ($dayNames)';
    }
    return label;
  }

  Future<void> _showReminderSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReminderSheet(
        initialReminders: _reminderMinutes,
        onSave: (reminders) {
          setState(() {
            _reminderMinutes.clear();
            _reminderMinutes.addAll(reminders);
          });
        },
      ),
    );
  }

  String _getReminderLabel() {
    if (_reminderMinutes.isEmpty) return '알림';
    if (_reminderMinutes.length == 1) {
      return ReminderPresets.getLabel(_reminderMinutes.first);
    }
    return '알림 ${_reminderMinutes.length}개';
  }

  /// Phase 2: 공개 범위 선택 위젯
  Widget _buildVisibilitySection(BuildContext context, bool isDark) {
    final memberships = ref.watch(filteredUserMembershipsProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '공개 범위',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        // 나만 보기 / 그룹 공유 토글
        Row(
          children: [
            // 나만 보기
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _visibility = TodoVisibility.private;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _visibility == TodoVisibility.private
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppTheme.radiusSmall),
                    ),
                    border: Border.all(
                      color: _visibility == TodoVisibility.private
                          ? AppColors.primaryLight
                          : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.lock,
                        size: 16,
                        color: _visibility == TodoVisibility.private
                            ? AppColors.primaryLight
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '나만 보기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _visibility == TodoVisibility.private
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _visibility == TodoVisibility.private
                              ? AppColors.primaryLight
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 그룹 공유
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _visibility = TodoVisibility.shared;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _visibility == TodoVisibility.shared
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(AppTheme.radiusSmall),
                    ),
                    border: Border.all(
                      color: _visibility == TodoVisibility.shared
                          ? AppColors.primaryLight
                          : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.people,
                        size: 16,
                        color: _visibility == TodoVisibility.shared
                            ? AppColors.primaryLight
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '그룹 공유',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _visibility == TodoVisibility.shared
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _visibility == TodoVisibility.shared
                              ? AppColors.primaryLight
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // 그룹 공유 시 그룹 선택 표시
        if (_visibility == TodoVisibility.shared && memberships.length > 1) ...[
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '공유할 그룹',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: memberships.map((membership) {
              final isSelected = _sharedGroups.contains(membership.groupId);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      // 최소 1개 그룹은 선택되어야 함
                      if (_sharedGroups.length > 1) {
                        _sharedGroups.remove(membership.groupId);
                      }
                    } else {
                      _sharedGroups.add(membership.groupId);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : Colors.transparent,
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
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      Text(
                        membership.groupName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppColors.primaryLight
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(smartMembersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
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
        child: SingleChildScrollView(
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
              widget.todoId != null ? '할일 수정' : '새 할일',
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

            // 타입 선택
            Row(
              children: TodoEventType.values.map((type) {
                final isSelected = _eventType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _eventType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryLight.withValues(alpha: 0.15)
                              : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryLight
                                : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight)
                                    .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          type.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primaryLight
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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

            // 위치 입력 (토글)
            if (_showLocationField) ...[
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: '위치 (선택)',
                  prefixIcon: Icon(Iconsax.location),
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

                  // 위치 추가 버튼
                  _OptionChip(
                    icon: Iconsax.location,
                    label: '위치',
                    isSelected: _showLocationField,
                    onTap: () => setState(() => _showLocationField = !_showLocationField),
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

                  // 반복 설정
                  if (_dueDate != null) ...[
                    _OptionChip(
                      icon: Iconsax.repeat,
                      label: _getRecurrenceLabel(),
                      isSelected: _recurrenceType != RecurrenceType.none,
                      onTap: _showRecurrenceSheet,
                      onClear: _recurrenceType != RecurrenceType.none
                          ? () => setState(() {
                                _recurrenceType = RecurrenceType.none;
                                _recurrenceDays.clear();
                                _recurrenceEndDate = null;
                                _excludeHolidays = false;
                              })
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],

                  // 알림 설정
                  if (_dueDate != null) ...[
                    _OptionChip(
                      icon: Iconsax.notification,
                      label: _getReminderLabel(),
                      isSelected: _reminderMinutes.isNotEmpty,
                      onTap: _showReminderSheet,
                      onClear: _reminderMinutes.isNotEmpty
                          ? () => setState(() => _reminderMinutes.clear())
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Phase 2: 공개 범위 선택
            _buildVisibilitySection(context, isDark),
            const SizedBox(height: AppTheme.spacingM),

            // 참여자 선택 (다중 선택)
            Text(
              '참여자',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: members
                    .map((member) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: MemberAvatar(
                            member: member,
                            size: 40,
                            isSelected: _selectedParticipants.contains(member.id),
                            onTap: () {
                              setState(() {
                                if (_selectedParticipants.contains(member.id)) {
                                  _selectedParticipants.remove(member.id);
                                  // assigneeId 업데이트
                                  if (_selectedAssigneeId == member.id) {
                                    _selectedAssigneeId =
                                        _selectedParticipants.isNotEmpty
                                            ? _selectedParticipants.first
                                            : null;
                                  }
                                } else {
                                  _selectedParticipants.add(member.id);
                                  // 첫 번째 참여자를 assigneeId로 설정
                                  _selectedAssigneeId ??= member.id;
                                }
                              });
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // 추가/저장 버튼
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
                    : Text(widget.todoId != null ? '저장' : '추가'),
              ),
            ),
            ],
          ),
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

class _RecurrenceSheet extends StatefulWidget {
  final RecurrenceType initialType;
  final List<int> initialDays;
  final DateTime? initialEndDate;
  final bool initialExcludeHolidays;
  final Function(RecurrenceType, List<int>, DateTime?, bool) onSave;

  const _RecurrenceSheet({
    required this.initialType,
    required this.initialDays,
    required this.initialEndDate,
    required this.initialExcludeHolidays,
    required this.onSave,
  });

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  late RecurrenceType _type;
  late List<int> _days;
  DateTime? _endDate;
  late bool _excludeHolidays;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _days = List.from(widget.initialDays);
    _endDate = widget.initialEndDate;
    _excludeHolidays = widget.initialExcludeHolidays;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('반복 설정', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTheme.spacingM),
          // 반복 유형 선택
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RecurrenceType.values.map((type) {
              final isSelected = _type == type;
              return GestureDetector(
                onTap: () => setState(() => _type = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryLight
                          : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    type.displayName,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryLight
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // 매주 선택 시 요일 선택
          if (_type == RecurrenceType.weekly) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text('반복 요일', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Weekdays.all.map((day) {
                final isSelected = _days.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _days.remove(day);
                      } else {
                        _days.add(day);
                      }
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryLight
                            : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)
                                .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        Weekdays.getName(day),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // 반복 종료일
          if (_type != RecurrenceType.none) ...[
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: Text('반복 종료일',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                  child: Text(_endDate != null
                      ? DateFormat('yyyy/M/d').format(_endDate!)
                      : '설정 안 함'),
                ),
                if (_endDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _endDate = null),
                  ),
              ],
            ),
            // 공휴일 제외
            Row(
              children: [
                Checkbox(
                  value: _excludeHolidays,
                  onChanged: (value) =>
                      setState(() => _excludeHolidays = value ?? false),
                ),
                Text('공휴일 제외', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacingL),
          // 저장 버튼
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_type, _days, _endDate, _excludeHolidays);
                Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림 설정 시트
class _ReminderSheet extends StatefulWidget {
  final List<int> initialReminders;
  final Function(List<int>) onSave;

  const _ReminderSheet({
    required this.initialReminders,
    required this.onSave,
  });

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late List<int> _selectedReminders;
  final _customController = TextEditingController();
  String _customUnit = 'minutes'; // 'minutes' | 'hours' | 'days'

  @override
  void initState() {
    super.initState();
    _selectedReminders = List.from(widget.initialReminders);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggleReminder(int minutes) {
    setState(() {
      if (_selectedReminders.contains(minutes)) {
        _selectedReminders.remove(minutes);
      } else {
        _selectedReminders.add(minutes);
        _selectedReminders.sort();
      }
    });
  }

  void _addCustomReminder() {
    final value = int.tryParse(_customController.text);
    if (value == null || value <= 0) return;

    int minutes;
    switch (_customUnit) {
      case 'hours':
        minutes = value * 60;
        break;
      case 'days':
        minutes = value * 1440;
        break;
      default:
        minutes = value;
    }

    if (!_selectedReminders.contains(minutes)) {
      setState(() {
        _selectedReminders.add(minutes);
        _selectedReminders.sort();
      });
    }

    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('알림 설정', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTheme.spacingM),

          // 프리셋 칩 목록
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReminderPresets.all.map((minutes) {
              final isSelected = _selectedReminders.contains(minutes);
              return GestureDetector(
                onTap: () => _toggleReminder(minutes),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      Text(
                        ReminderPresets.getLabel(minutes),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryLight
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppTheme.spacingM),

          // 커스텀 시간 입력
          Text('커스텀 알림', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              // 숫자 입력
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '숫자',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _addCustomReminder(),
                ),
              ),
              const SizedBox(width: 8),

              // 단위 선택
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight)
                        .withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _customUnit,
                    items: const [
                      DropdownMenuItem(value: 'minutes', child: Text('분 전')),
                      DropdownMenuItem(value: 'hours', child: Text('시간 전')),
                      DropdownMenuItem(value: 'days', child: Text('일 전')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _customUnit = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 추가 버튼
              IconButton(
                onPressed: _addCustomReminder,
                icon: Icon(
                  Icons.add_circle,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),

          // 선택된 알림 목록
          if (_selectedReminders.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text('선택됨', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedReminders.map((minutes) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ReminderPresets.getLabel(minutes),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _toggleReminder(minutes),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: AppTheme.spacingL),

          // 저장 버튼
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_selectedReminders);
                Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}
