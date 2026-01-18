import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/event.dart';
import '../../../shared/providers/smart_provider.dart';

/// 일간 뷰 위젯
class DayView extends ConsumerWidget {
  final DateTime selectedDay;
  final Function(DateTime)? onPreviousDay;
  final Function(DateTime)? onNextDay;

  const DayView({
    super.key,
    required this.selectedDay,
    this.onPreviousDay,
    this.onNextDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final events = ref.watch(smartEventsForDateProvider(selectedDay));
    final allDayEvents = events.where((e) => e.isAllDay).toList();
    final timedEvents = events.where((e) => !e.isAllDay).toList();
    final now = DateTime.now();
    final isToday = selectedDay.year == now.year && 
                    selectedDay.month == now.month && 
                    selectedDay.day == now.day;

    return Column(
      children: [
        // 날짜 네비게이션 헤더
        _DayHeader(
          selectedDay: selectedDay,
          isToday: isToday,
          onPreviousDay: onPreviousDay,
          onNextDay: onNextDay,
          isDark: isDark,
        ),
        const SizedBox(height: AppTheme.spacingS),
        
        // 종일 이벤트
        if (allDayEvents.isNotEmpty) ...[
          _AllDayEventsSection(
            events: allDayEvents,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.spacingS),
        ],
        
        // 시간별 이벤트 그리드
        Expanded(
          child: _TimelineGrid(
            events: timedEvents,
            isDark: isDark,
            isToday: isToday,
            currentTime: now,
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime selectedDay;
  final bool isToday;
  final Function(DateTime)? onPreviousDay;
  final Function(DateTime)? onNextDay;
  final bool isDark;

  const _DayHeader({
    required this.selectedDay,
    required this.isToday,
    this.onPreviousDay,
    this.onNextDay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => onPreviousDay?.call(
              selectedDay.subtract(const Duration(days: 1)),
            ),
            icon: const Icon(Iconsax.arrow_left_2, size: 20),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('M월 d일 EEEE', 'ko_KR').format(selectedDay),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.calendarColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '오늘',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => onNextDay?.call(
              selectedDay.add(const Duration(days: 1)),
            ),
            icon: const Icon(Iconsax.arrow_right_3, size: 20),
          ),
        ],
      ),
    );
  }
}

class _AllDayEventsSection extends StatelessWidget {
  final List<Event> events;
  final bool isDark;

  const _AllDayEventsSection({
    required this.events,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.sun_1,
                size: 14,
                color: isDark 
                    ? AppColors.textSecondaryDark 
                    : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                '종일',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark 
                      ? AppColors.textSecondaryDark 
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: events.map((event) {
              final eventColor = event.color != null 
                  ? _parseColor(event.color!)
                  : AppColors.calendarColor;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: eventColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: eventColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  event.title,
                  style: TextStyle(
                    color: eventColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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

class _TimelineGrid extends StatelessWidget {
  final List<Event> events;
  final bool isDark;
  final bool isToday;
  final DateTime currentTime;

  const _TimelineGrid({
    required this.events,
    required this.isDark,
    required this.isToday,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: SingleChildScrollView(
        child: Stack(
          children: [
            // 시간 그리드
            Column(
              children: List.generate(24, (hour) {
                return _TimeSlot(
                  hour: hour,
                  isDark: isDark,
                );
              }),
            ),
            // 현재 시간 표시 (오늘인 경우)
            if (isToday)
              _CurrentTimeLine(
                currentTime: currentTime,
              ),
            // 이벤트 블록들
            ...events.map((event) {
              return _DayEventBlock(
                event: event,
                isDark: isDark,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TimeSlot extends StatelessWidget {
  final int hour;
  final bool isDark;

  const _TimeSlot({
    required this.hour,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: (isDark 
                ? AppColors.textSecondaryDark 
                : AppColors.textSecondaryLight)
                .withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark 
                      ? AppColors.textSecondaryDark 
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: (isDark 
                        ? AppColors.textSecondaryDark 
                        : AppColors.textSecondaryLight)
                        .withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentTimeLine extends StatelessWidget {
  final DateTime currentTime;

  const _CurrentTimeLine({
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    final top = (currentTime.hour + currentTime.minute / 60) * 60;

    return Positioned(
      top: top,
      left: 45,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.errorLight,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: AppColors.errorLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayEventBlock extends StatelessWidget {
  final Event event;
  final bool isDark;

  const _DayEventBlock({
    required this.event,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final startHour = event.startAt.hour + event.startAt.minute / 60;
    final endHour = event.endAt.hour + event.endAt.minute / 60;
    final duration = endHour - startHour;
    
    // 최소 30분 높이 보장
    final height = (duration < 0.5 ? 0.5 : duration) * 60;
    final top = startHour * 60;

    final eventColor = event.color != null 
        ? _parseColor(event.color!)
        : AppColors.calendarColor;

    return Positioned(
      top: top,
      left: 55,
      right: 8,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: eventColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: eventColor.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (event.isPersonal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '개인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Iconsax.clock,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  '${event.formattedTime} - ${DateFormat('HH:mm').format(event.endAt)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (height > 70 && event.location != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Iconsax.location,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
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
