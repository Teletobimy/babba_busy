import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/event_provider.dart';
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
            ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59)
            : _combineDateAndTime(_endDate, _endTime),
        isAllDay: _isAllDay,
        participants: _selectedParticipants,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
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
                    activeColor: AppColors.calendarColor,
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
