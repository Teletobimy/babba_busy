import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/todo_item.dart';
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
        // 시간 미정 섹션
        _UndecidedWeekSection(
          days: days,
          isDark: isDark,
        ),
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
    // 주간 Todo 가져오기
    final allTodos = <DateTime, List<TodoItem>>{};
    for (final day in days) {
      allTodos[day] = ref.watch(smartTodosForDateProvider(day));
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
            // 각 날짜별 할일 열
            ...days.map((day) {
              final todos = allTodos[day] ?? [];
              // 시간 있는 할일만 필터링
              final timedTodos = todos.where((t) => t.hasTime && t.startTime != null).toList();
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
                        // 할일 블록
                        ...timedTodos.map((todo) {
                          return _TodoBlock(
                            todo: todo,
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

class _TodoBlock extends StatelessWidget {
  final TodoItem todo;
  final bool isDark;

  const _TodoBlock({
    required this.todo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (todo.startTime == null) return const SizedBox.shrink();

    final startHour = todo.startTime!.hour + todo.startTime!.minute / 60;
    final endTime = todo.endTime ?? todo.startTime!.add(const Duration(hours: 1));
    final endHour = endTime.hour + endTime.minute / 60;
    final duration = endHour - startHour;

    // 최소 30분 (0.5시간) 높이 보장
    final height = (duration < 0.5 ? 0.5 : duration) * 60;
    final top = startHour * 60;

    final todoColor = _getEventTypeColor(todo.eventType);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: todoColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              todo.title,
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
                DateFormat('HH:mm').format(todo.startTime!),
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

  Color _getEventTypeColor(TodoEventType eventType) {
    switch (eventType) {
      case TodoEventType.event:
        return AppColors.calendarColor;
      case TodoEventType.todo:
        return AppColors.todoColor;
      case TodoEventType.schedule:
        return AppColors.primaryLight;
    }
  }
}

/// 주간 뷰 상단 - 시간 미정 todos 섹션
class _UndecidedWeekSection extends ConsumerWidget {
  final List<DateTime> days;
  final bool isDark;

  const _UndecidedWeekSection({
    required this.days,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 각 요일별 미정 todos 수집
    final undecidedMap = <DateTime, List<TodoItem>>{};
    bool hasAny = false;

    for (final day in days) {
      final undecided = ref.watch(smartUndecidedTodosForDateProvider(day));
      undecidedMap[day] = undecided;
      if (undecided.isNotEmpty) hasAny = true;
    }

    // 미정 todos가 없으면 표시 안 함
    if (!hasAny) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          bottom: BorderSide(
            color: (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight)
                .withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // 라벨 영역 (시간 라벨과 동일한 너비 45px)
          SizedBox(
            width: 45,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.clock,
                  size: 10,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 2),
                Text(
                  '미정',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // 각 요일별 미정 todos
          ...days.map((day) {
            final todos = undecidedMap[day] ?? [];
            return Expanded(
              child: _UndecidedDayCell(
                todos: todos,
                isDark: isDark,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 요일별 미정 todos 셀
class _UndecidedDayCell extends StatelessWidget {
  final List<TodoItem> todos;
  final bool isDark;

  const _UndecidedDayCell({
    required this.todos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: todos.take(2).map((todo) {
          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.coral[100]?.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: AppColors.coral[300]!.withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.tick_square,
                  size: 8,
                  color: AppColors.coral[600],
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    todo.title,
                    style: TextStyle(
                      fontSize: 8,
                      color: AppColors.coral[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
