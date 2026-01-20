import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/event_provider.dart';
import '../../../shared/models/recurrence.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 이벤트 추가 바텀 시트
class AddEventSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;

  const AddEventSheet({super.key, required this.initialDate});

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isAllDay = false;
  final List<String> _selectedParticipants = [];
  bool _isLoading = false;

  // 반복 설정
  RecurrenceType _recurrenceType = RecurrenceType.none;
  final List<int> _recurrenceDays = [];
  DateTime? _recurrenceEndDate;
  bool _excludeHolidays = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _endDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _handleAdd() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final eventService = ref.read(eventServiceProvider);
      await eventService.addEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startAt: _isAllDay
            ? DateTime(_startDate.year, _startDate.month, _startDate.day)
            : _combineDateAndTime(_startDate, _startTime),
        endAt: _isAllDay
            ? DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1))
            : _combineDateAndTime(_endDate, _endTime),
        isAllDay: _isAllDay,
        participants: _selectedParticipants,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        recurrenceType: _recurrenceType,
        recurrenceDays: _recurrenceType == RecurrenceType.weekly && _recurrenceDays.isNotEmpty
            ? _recurrenceDays
            : null,
        recurrenceEndDate: _recurrenceEndDate,
        excludeHolidays: _excludeHolidays,
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

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _selectRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _recurrenceEndDate = picked;
      });
    }
  }

  void _showRecurrenceOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: AppTheme.spacingL,
            right: AppTheme.spacingL,
            top: AppTheme.spacingM,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingL,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLarge),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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

              Text(
                '반복 설정',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // 반복 유형 선택
              ...RecurrenceType.values.map((type) {
                final isSelected = _recurrenceType == type;
                return ListTile(
                  leading: Icon(
                    _getRecurrenceIcon(type),
                    color: isSelected ? AppColors.calendarColor : null,
                  ),
                  title: Text(
                    type.displayName,
                    style: TextStyle(
                      color: isSelected ? AppColors.calendarColor : null,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Iconsax.tick_circle5, color: AppColors.calendarColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _recurrenceType = type;
                      if (type == RecurrenceType.none) {
                        _recurrenceDays.clear();
                        _recurrenceEndDate = null;
                        _excludeHolidays = false;
                      }
                    });
                    setModalState(() {});
                  },
                );
              }),

              // 주간 반복일 경우 요일 선택
              if (_recurrenceType == RecurrenceType.weekly) ...[
                const Divider(),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  '반복 요일',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Wrap(
                  spacing: 8,
                  children: Weekdays.all.map((day) {
                    final isSelected = _recurrenceDays.contains(day);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _recurrenceDays.remove(day);
                          } else {
                            _recurrenceDays.add(day);
                          }
                        });
                        setModalState(() {});
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.calendarColor
                              : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.calendarColor
                                : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight)
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            Weekdays.getName(day),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (day == Weekdays.saturday || day == Weekdays.sunday)
                                      ? AppColors.errorLight
                                      : null,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // 반복 설정이 있을 경우 추가 옵션
              if (_recurrenceType != RecurrenceType.none) ...[
                const Divider(),
                // 공휴일 제외
                ListTile(
                  leading: const Icon(Iconsax.flag),
                  title: const Text('공휴일 제외'),
                  subtitle: const Text('공휴일에는 반복하지 않음'),
                  trailing: Switch(
                    value: _excludeHolidays,
                    onChanged: (value) {
                      setState(() => _excludeHolidays = value);
                      setModalState(() {});
                    },
                    activeTrackColor: AppColors.calendarColor.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.calendarColor,
                  ),
                ),
                // 반복 종료일
                ListTile(
                  leading: const Icon(Iconsax.calendar_remove),
                  title: const Text('반복 종료일'),
                  subtitle: Text(
                    _recurrenceEndDate != null
                        ? DateFormat('yyyy년 M월 d일').format(_recurrenceEndDate!)
                        : '설정 안 함 (계속 반복)',
                  ),
                  trailing: _recurrenceEndDate != null
                      ? IconButton(
                          icon: const Icon(Iconsax.close_circle),
                          onPressed: () {
                            setState(() => _recurrenceEndDate = null);
                            setModalState(() {});
                          },
                        )
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await _selectRecurrenceEndDate();
                  },
                ),
              ],

              const SizedBox(height: AppTheme.spacingM),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.calendarColor,
                  ),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRecurrenceIcon(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return Iconsax.close_circle;
      case RecurrenceType.daily:
        return Iconsax.calendar_tick;
      case RecurrenceType.weekly:
        return Iconsax.calendar;
      case RecurrenceType.monthly:
        return Iconsax.calendar_1;
      case RecurrenceType.yearly:
        return Iconsax.cake;
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(smartMembersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SingleChildScrollView(
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
              '새 일정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 제목 입력
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '일정 제목',
                prefixIcon: Icon(Iconsax.calendar_edit),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 종일 토글
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.sun_1, size: 20),
                  const SizedBox(width: 12),
                  const Text('종일'),
                  const Spacer(),
                  Switch(
                    value: _isAllDay,
                    onChanged: (value) => setState(() => _isAllDay = value),
                    activeTrackColor: AppColors.calendarColor.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.calendarColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 시작 날짜/시간
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    icon: Iconsax.calendar_1,
                    label: DateFormat('M월 d일').format(_startDate),
                    onTap: () => _selectDate(true),
                  ),
                ),
                if (!_isAllDay) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateTimeButton(
                      icon: Iconsax.clock,
                      label: _startTime.format(context),
                      onTap: () => _selectTime(true),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),

            // 종료 날짜/시간
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    icon: Iconsax.calendar_1,
                    label: DateFormat('M월 d일').format(_endDate),
                    onTap: () => _selectDate(false),
                  ),
                ),
                if (!_isAllDay) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateTimeButton(
                      icon: Iconsax.clock,
                      label: _endTime.format(context),
                      onTap: () => _selectTime(false),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 반복 설정
            GestureDetector(
              onTap: _showRecurrenceOptions,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: _recurrenceType != RecurrenceType.none
                      ? Border.all(color: AppColors.calendarColor, width: 1.5)
                      : Border.all(
                          color: (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.2),
                        ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.repeat,
                      size: 20,
                      color: _recurrenceType != RecurrenceType.none
                          ? AppColors.calendarColor
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recurrenceType == RecurrenceType.none
                                ? '반복 안 함'
                                : _getRecurrenceDescription(),
                            style: TextStyle(
                              color: _recurrenceType != RecurrenceType.none
                                  ? AppColors.calendarColor
                                  : null,
                              fontWeight: _recurrenceType != RecurrenceType.none
                                  ? FontWeight.w600
                                  : null,
                            ),
                          ),
                          if (_recurrenceType != RecurrenceType.none && _excludeHolidays)
                            Text(
                              '공휴일 제외',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 장소
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: '장소 (선택)',
                prefixIcon: Icon(Iconsax.location),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 설명
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '설명 (선택)',
                prefixIcon: Icon(Iconsax.note_1),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 참여자 선택
            Text(
              '참여자',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((member) {
                final isSelected = _selectedParticipants.contains(member.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedParticipants.remove(member.id);
                      } else {
                        _selectedParticipants.add(member.id);
                      }
                    });
                  },
                  child: MemberAvatar(
                    member: member,
                    size: 44,
                    showName: true,
                    isSelected: isSelected,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // 추가 버튼
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calendarColor,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('일정 추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRecurrenceDescription() {
    String desc = _recurrenceType.displayName;

    if (_recurrenceType == RecurrenceType.weekly && _recurrenceDays.isNotEmpty) {
      final sortedDays = List<int>.from(_recurrenceDays)..sort();
      final dayNames = sortedDays.map((d) => Weekdays.getName(d)).join(', ');
      desc = '$desc ($dayNames)';
    }

    if (_recurrenceEndDate != null) {
      desc = '$desc ~ ${DateFormat('M/d').format(_recurrenceEndDate!)}까지';
    }

    return desc;
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight)
                .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.calendarColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
