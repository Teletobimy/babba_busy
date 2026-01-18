import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/event.dart';
import '../../../shared/providers/smart_provider.dart';

/// 주간 뷰 위젯
class WeekView extends ConsumerWidget {
  final DateTime focusedDay;
  final Function(DateTime) onDaySelected;

  const WeekView({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 주의 시작일 (월요일)
    final startOfWeek = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    final days = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // 요일 헤더
        _WeekHeader(
          days: days,
          today: today,
          selectedDay: focusedDay,
          onDaySelected: onDaySelected,
          isDark: isDark,
        ),
        const SizedBox(height: AppTheme.spacingS),
        // 시간대별 이벤트
        Expanded(
          child: _TimeGrid(
            days: days,
            selectedDay: focusedDay,
            onDaySelected: onDaySelected,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  final List<DateTime> days;
  final DateTime today;
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;
  final bool isDark;

  const _WeekHeader({
    required this.days,
    required this.today,
    required this.selectedDay,
    required this.onDaySelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: days.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          final isToday = day.year == today.year && 
                          day.month == today.month && 
                          day.day == today.day;
          final isSelected = day.year == selectedDay.year && 
                             day.month == selectedDay.month && 
                             day.day == selectedDay.day;
          final isWeekend = index >= 5;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.calendarColor 
                      : (isToday 
                          ? AppColors.calendarColor.withValues(alpha: 0.2) 
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Column(
                  children: [
                    Text(
                      dayNames[index],
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected 
                            ? Colors.white
                            : (isWeekend 
                                ? AppColors.errorLight.withValues(alpha: 0.8)
                                : (isDark 
                                    ? AppColors.textSecondaryDark 
                                    : AppColors.textSecondaryLight)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? Colors.white
                            : (isWeekend 
                                ? AppColors.errorLight.withValues(alpha: 0.8)
                                : (isDark 
                                    ? AppColors.textPrimaryDark 
                                    : AppColors.textPrimaryLight)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TimeGrid extends ConsumerWidget {
  final List<DateTime> days;
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;
  final bool isDark;

  const _TimeGrid({
    required this.days,
    required this.selectedDay,
    required this.onDaySelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 주간 이벤트 가져오기
    final allEvents = <DateTime, List<Event>>{};
    for (final day in days) {
      allEvents[day] = ref.watch(smartEventsForDateProvider(day));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 시간 라벨 (좌측)
            SizedBox(
              width: 45,
              child: Column(
                children: List.generate(24, (hour) {
                  return Container(
                    height: 60,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark 
                            ? AppColors.textSecondaryDark 
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // 각 날짜별 이벤트 열
            ...days.map((day) {
              final events = allEvents[day] ?? [];
              final isSelected = day.year == selectedDay.year && 
                                 day.month == selectedDay.month && 
                                 day.day == selectedDay.day;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDaySelected(day),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: (isDark 
                              ? AppColors.textSecondaryDark 
                              : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      color: isSelected 
                          ? AppColors.calendarColor.withValues(alpha: 0.05)
                          : Colors.transparent,
                    ),
                    child: Stack(
                      children: [
                        // 시간 그리드 라인
                        Column(
                          children: List.generate(24, (hour) {
                            return Container(
                              height: 60,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: (isDark 
                                        ? AppColors.textSecondaryDark 
                                        : AppColors.textSecondaryLight)
                                        .withValues(alpha: 0.1),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        // 이벤트 블록
                        ...events.where((e) => !e.isAllDay).map((event) {
                          return _EventBlock(
                            event: event,
                            isDark: isDark,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EventBlock extends StatelessWidget {
  final Event event;
  final bool isDark;

  const _EventBlock({
    required this.event,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final startHour = event.startAt.hour + event.startAt.minute / 60;
    final endHour = event.endAt.hour + event.endAt.minute / 60;
    final duration = endHour - startHour;
    
    // 최소 30분 (0.5시간) 높이 보장
    final height = (duration < 0.5 ? 0.5 : duration) * 60;
    final top = startHour * 60;

    final eventColor = event.color != null 
        ? _parseColor(event.color!)
        : AppColors.calendarColor;

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: eventColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (height > 35)
              Text(
                event.formattedTime,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppColors.calendarColor;
    }
  }
}
