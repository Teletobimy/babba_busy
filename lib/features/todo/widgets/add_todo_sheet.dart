import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/todo_provider.dart';
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
  EventType _eventType = EventType.todo;

  // Event 통합 필드
  final List<String> _selectedParticipants = [];
  bool _showLocationField = false;
  bool _isAllDay = false;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  final List<int> _recurrenceDays = [];
  DateTime? _recurrenceEndDate;
  bool _excludeHolidays = false;
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    // initialDate가 있으면 설정
    if (widget.initialDate != null) {
      _dueDate = widget.initialDate;
    }
    // 수정 모드인 경우 기존 값 로드
    if (widget.todoId != null) {
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
      _isAllDay = todo.isAllDay;
      _recurrenceType = todo.recurrenceType;
      _recurrenceDays.clear();
      if (todo.recurrenceDays != null) {
        _recurrenceDays.addAll(todo.recurrenceDays!);
      }
      _recurrenceEndDate = todo.recurrenceEndDate;
      _excludeHolidays = todo.excludeHolidays;
      _selectedColor = todo.color;
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
          isAllDay: _isAllDay,
          recurrenceType: _recurrenceType,
          recurrenceDays: _recurrenceDays.isEmpty ? null : _recurrenceDays,
          recurrenceEndDate: _recurrenceEndDate,
          excludeHolidays: _excludeHolidays,
          color: _selectedColor,
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
          isAllDay: _isAllDay,
          recurrenceType: _recurrenceType,
          recurrenceDays: _recurrenceDays.isEmpty ? null : _recurrenceDays,
          recurrenceEndDate: _recurrenceEndDate,
          excludeHolidays: _excludeHolidays,
          color: _selectedColor,
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
              children: EventType.values.map((type) {
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

            // 종일 토글 (날짜가 선택된 경우에만 표시)
            if (_dueDate != null) ...[
              Row(
                children: [
                  Checkbox(
                    value: _isAllDay,
                    onChanged: (value) {
                      setState(() {
                        _isAllDay = value ?? false;
                        if (_isAllDay) {
                          _hasTime = false;
                          _startTime = null;
                          _endTime = null;
                        }
                      });
                    },
                  ),
                  Text('종일', style: Theme.of(context).textTheme.bodyMedium),
                ],
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
                              _isAllDay = false;
                            })
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // 시간 선택 (날짜가 선택되고 종일이 아닌 경우에만 표시)
                  if (_dueDate != null && !_isAllDay) ...[
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
                ],
              ),
            ),
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
                                  if (_selectedAssigneeId == null) {
                                    _selectedAssigneeId = member.id;
                                  }
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
