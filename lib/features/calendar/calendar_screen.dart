import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/models/event.dart';
import 'widgets/add_event_sheet.dart';
import 'widgets/event_card.dart';
import 'widgets/week_view.dart';
import 'widgets/day_view.dart';
import 'widgets/calendar_filter_sheet.dart';

/// 캘린더 뷰 모드
enum CalendarViewMode {
  month, // 월간 뷰
  week,  // 주간 뷰
  day,   // 일간 뷰
}

/// 선택된 날짜 Provider
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 캘린더 뷰 모드 Provider
final calendarViewModeProvider = StateProvider<CalendarViewMode>((ref) => CalendarViewMode.month);

/// 캘린더 포맷 Provider (TableCalendar용)
final calendarFormatProvider = StateProvider<CalendarFormat>((ref) => CalendarFormat.month);

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(calendarViewModeProvider);
    final calendarFormat = ref.watch(calendarFormatProvider);
    final events = ref.watch(filteredEventsProvider);
    final selectedEvents = ref.watch(smartEventsForDateProvider(selectedDate));
    final members = ref.watch(smartMembersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '캘린더',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ).animate().fadeIn(duration: 300.ms),
                  Row(
                    children: [
                      // 캘린더 필터 버튼
                      const CalendarFilterButton(),
                      // 뷰 모드 전환 버튼
                      _ViewModeButton(
                        currentMode: viewMode,
                        onModeChanged: (mode) {
                          ref.read(calendarViewModeProvider.notifier).state = mode;
                        },
                      ),
                      // 오늘로 이동
                      TextButton(
                        onPressed: () {
                          ref.read(selectedDateProvider.notifier).state = DateTime.now();
                        },
                        child: const Text('오늘'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 뷰 모드에 따른 컨텐츠
            Expanded(
              child: _buildContent(
                context,
                ref,
                viewMode,
                selectedDate,
                calendarFormat,
                events,
                selectedEvents,
                members,
                isDark,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventSheet(context, selectedDate),
        backgroundColor: AppColors.calendarColor,
        child: const Icon(Iconsax.add),
      ).animate().scale(delay: 500.ms, duration: 300.ms),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    CalendarViewMode viewMode,
    DateTime selectedDate,
    CalendarFormat calendarFormat,
    List<Event> events,
    List<Event> selectedEvents,
    List members,
    bool isDark,
  ) {
    switch (viewMode) {
      case CalendarViewMode.month:
        return _MonthView(
          selectedDate: selectedDate,
          calendarFormat: calendarFormat,
          events: events,
          selectedEvents: selectedEvents,
          members: members,
          isDark: isDark,
          onDaySelected: (day) {
            ref.read(selectedDateProvider.notifier).state = day;
            // 날짜 선택시 팝업으로 일정 표시
            _showEventsPopup(context, ref, day, members);
          },
          onFormatChanged: (format) {
            ref.read(calendarFormatProvider.notifier).state = format;
          },
          onAddEvent: () => _showAddEventSheet(context, selectedDate),
        );
      case CalendarViewMode.week:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: WeekView(
            focusedDay: selectedDate,
            onDaySelected: (day) {
              ref.read(selectedDateProvider.notifier).state = day;
            },
          ),
        );
      case CalendarViewMode.day:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: DayView(
            selectedDay: selectedDate,
            onPreviousDay: (day) {
              ref.read(selectedDateProvider.notifier).state = day;
            },
            onNextDay: (day) {
              ref.read(selectedDateProvider.notifier).state = day;
            },
          ),
        );
    }
  }

  void _showAddEventSheet(BuildContext context, DateTime selectedDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventSheet(initialDate: selectedDate),
    );
  }

  void _showEventsPopup(BuildContext context, WidgetRef ref, DateTime date, List members) {
    final events = ref.read(smartEventsForDateProvider(date));
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventsPopup(
        date: date,
        events: events,
        members: members,
        onAddEvent: () {
          Navigator.pop(context);
          _showAddEventSheet(context, date);
        },
      ),
    );
  }
}

/// 일정 팝업 (날짜 클릭시 표시)
class _EventsPopup extends StatelessWidget {
  final DateTime date;
  final List<Event> events;
  final List members;
  final VoidCallback onAddEvent;

  const _EventsPopup({
    required this.date,
    required this.events,
    required this.members,
    required this.onAddEvent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.calendarColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.calendarColor,
                            ),
                          ),
                          Text(
                            DateFormat('E', 'ko_KR').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.calendarColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('M월 d일 EEEE', 'ko_KR').format(date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.calendarColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '오늘',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // 일정 추가 버튼
                IconButton(
                  onPressed: onAddEvent,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.calendarColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(
                      Iconsax.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          // 일정 목록
          Flexible(
            child: events.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.calendar_tick,
                          size: 48,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          '이 날짜에 일정이 없습니다',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        TextButton.icon(
                          onPressed: onAddEvent,
                          icon: const Icon(Iconsax.add, size: 18),
                          label: const Text('일정 추가하기'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                        child: EventCard(
                          event: events[index],
                          members: members,
                        ),
                      );
                    },
                  ),
          ),
          
          // 하단 여백
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppTheme.spacingM),
        ],
      ),
    );
  }
}

/// 뷰 모드 전환 버튼
class _ViewModeButton extends StatelessWidget {
  final CalendarViewMode currentMode;
  final Function(CalendarViewMode) onModeChanged;

  const _ViewModeButton({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CalendarViewMode>(
      icon: Icon(_getIconForMode(currentMode)),
      tooltip: '뷰 모드 변경',
      onSelected: onModeChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: CalendarViewMode.month,
          child: Row(
            children: [
              Icon(
                Iconsax.calendar_1,
                size: 20,
                color: currentMode == CalendarViewMode.month
                    ? AppColors.calendarColor
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                '월간',
                style: TextStyle(
                  color: currentMode == CalendarViewMode.month
                      ? AppColors.calendarColor
                      : null,
                  fontWeight: currentMode == CalendarViewMode.month
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: CalendarViewMode.week,
          child: Row(
            children: [
              Icon(
                Iconsax.calendar,
                size: 20,
                color: currentMode == CalendarViewMode.week
                    ? AppColors.calendarColor
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                '주간',
                style: TextStyle(
                  color: currentMode == CalendarViewMode.week
                      ? AppColors.calendarColor
                      : null,
                  fontWeight: currentMode == CalendarViewMode.week
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: CalendarViewMode.day,
          child: Row(
            children: [
              Icon(
                Iconsax.calendar_2,
                size: 20,
                color: currentMode == CalendarViewMode.day
                    ? AppColors.calendarColor
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                '일간',
                style: TextStyle(
                  color: currentMode == CalendarViewMode.day
                      ? AppColors.calendarColor
                      : null,
                  fontWeight: currentMode == CalendarViewMode.day
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForMode(CalendarViewMode mode) {
    switch (mode) {
      case CalendarViewMode.month:
        return Iconsax.calendar_1;
      case CalendarViewMode.week:
        return Iconsax.calendar;
      case CalendarViewMode.day:
        return Iconsax.calendar_2;
    }
  }
}

/// 월간 뷰 - 달력만 표시 (일정 목록 제거)
class _MonthView extends StatelessWidget {
  final DateTime selectedDate;
  final CalendarFormat calendarFormat;
  final List<Event> events;
  final List<Event> selectedEvents;
  final List<dynamic> members;
  final bool isDark;
  final Function(DateTime) onDaySelected;
  final Function(CalendarFormat) onFormatChanged;
  final VoidCallback onAddEvent;

  const _MonthView({
    required this.selectedDate,
    required this.calendarFormat,
    required this.events,
    required this.selectedEvents,
    required this.members,
    required this.isDark,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onAddEvent,
  });

  // 해당 날짜의 참여자들 가져오기
  List<dynamic> _getParticipantsForDay(DateTime day) {
    final dayEvents = events.where((event) {
      return event.startAt.isBefore(day.add(const Duration(days: 1))) &&
          event.endAt.isAfter(day);
    }).toList();

    final participantIds = <String>{};
    for (final event in dayEvents) {
      participantIds.addAll(event.participants);
    }

    return members.where((m) => participantIds.contains(m.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 높이에 맞춰 rowHeight 계산
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    // 헤더(약 80) + 요일행(50) + 달력헤더(60) + 하단 여백 계산
    final availableHeight = screenHeight - safeAreaTop - safeAreaBottom - 80 - 50 - 60 - 100;
    final rowHeight = (availableHeight / 6).clamp(70.0, 100.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
        ),
        child: TableCalendar<Event>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: selectedDate,
          calendarFormat: calendarFormat,
          selectedDayPredicate: (day) => isSameDay(selectedDate, day),
          onDaySelected: (selectedDay, focusedDay) {
            onDaySelected(selectedDay);
          },
          onFormatChanged: onFormatChanged,
          eventLoader: (day) {
            return events.where((event) {
              return event.startAt.isBefore(day.add(const Duration(days: 1))) &&
                  event.endAt.isAfter(day);
            }).toList();
          },
          locale: 'ko_KR',
          rowHeight: rowHeight,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 16),
            leftChevronIcon: Icon(
              Iconsax.arrow_left_2,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            rightChevronIcon: Icon(
              Iconsax.arrow_right_3,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          daysOfWeekHeight: 40,
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            weekendStyle: TextStyle(
              color: AppColors.errorLight.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: const EdgeInsets.all(2),
            todayDecoration: BoxDecoration(
              color: AppColors.calendarColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.calendarColor,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            defaultTextStyle: TextStyle(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            weekendTextStyle: TextStyle(
              color: AppColors.errorLight.withValues(alpha: 0.8),
            ),
            markersMaxCount: 0, // 기본 마커 숨기고 커스텀 빌더 사용
          ),
          calendarBuilders: CalendarBuilders(
            // 커스텀 날짜 셀 빌더 (아바타 포함)
            defaultBuilder: (context, day, focusedDay) {
              return _buildDayCell(context, day, false, false);
            },
            selectedBuilder: (context, day, focusedDay) {
              return _buildDayCell(context, day, true, false);
            },
            todayBuilder: (context, day, focusedDay) {
              final isSelected = isSameDay(selectedDate, day);
              return _buildDayCell(context, day, isSelected, true);
            },
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day, bool isSelected, bool isToday) {
    final dayEvents = events.where((event) {
      return event.startAt.isBefore(day.add(const Duration(days: 1))) &&
          event.endAt.isAfter(day);
    }).toList();
    final participants = _getParticipantsForDay(day);
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.calendarColor
            : isToday
                ? AppColors.calendarColor.withValues(alpha: 0.15)
                : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: isToday && !isSelected
            ? Border.all(color: AppColors.calendarColor, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // 날짜 숫자
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : isWeekend
                      ? AppColors.errorLight.withValues(alpha: 0.8)
                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            ),
          ),
          const SizedBox(height: 2),
          // 참여자 아바타들
          if (participants.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildParticipantAvatars(participants, isSelected),
              ),
            )
          else if (dayEvents.isNotEmpty)
            // 이벤트는 있지만 참여자가 없을 때 점 표시
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.calendarColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatars(List<dynamic> participants, bool isSelected) {
    const maxShow = 3;
    final showCount = participants.length > maxShow ? maxShow : participants.length;
    final remaining = participants.length - maxShow;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        ...participants.take(showCount).map((member) {
          final color = _parseColor(member.color);
          return Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSelected ? 0.9 : 0.8),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0] : '?',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }),
        if (remaining > 0)
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.3)
                  : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white.withValues(alpha: 0.5) : AppColors.calendarColor,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.calendarColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return AppColors.memberColors[0];
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppColors.memberColors[0];
    }
  }
}
