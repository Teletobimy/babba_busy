import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/holiday_provider.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/models/holiday.dart';
import '../../shared/models/family_member.dart';
import '../../shared/widgets/member_avatar.dart';
import 'widgets/todo_card.dart';
import 'widgets/week_view.dart';
import 'widgets/day_view.dart';
import 'widgets/calendar_filter_sheet.dart';
import '../todo/widgets/add_todo_sheet.dart';
import '../../shared/providers/todo_provider.dart';

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

/// 캘린더 멤버 필터
final calendarMemberFilterProvider = StateProvider<String?>((ref) => null);

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(calendarViewModeProvider);
    final calendarFormat = ref.watch(calendarFormatProvider);
    final todos = ref.watch(filteredTodosProvider);
    final selectedTodos = ref.watch(smartTodosForDateProvider(selectedDate));
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
                todos,
                selectedTodos,
                members,
                isDark,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoSheet(context, selectedDate),
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
    List<TodoItem> todos,
    List<TodoItem> selectedTodos,
    List<FamilyMember> members,
    bool isDark,
  ) {
    // 현재 보이는 연도의 공휴일 가져오기
    final holidays = ref.watch(allHolidaysForYearProvider(selectedDate.year));

    switch (viewMode) {
      case CalendarViewMode.month:
        return _MonthView(
          selectedDate: selectedDate,
          calendarFormat: calendarFormat,
          todos: todos,
          selectedTodos: selectedTodos,
          members: members,
          holidays: holidays,
          isDark: isDark,
          onDaySelected: (day) {
            ref.read(selectedDateProvider.notifier).state = day;
            // 날짜 선택시 팝업으로 일정 표시
            _showTodosPopup(context, ref, day, members);
          },
          onFormatChanged: (format) {
            ref.read(calendarFormatProvider.notifier).state = format;
          },
          onAddTodo: () => _showAddTodoSheet(context, selectedDate),
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

  void _showAddTodoSheet(BuildContext context, DateTime selectedDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTodoSheet(initialDate: selectedDate),
    );
  }

  void _showTodosPopup(BuildContext context, WidgetRef ref, DateTime date, List members) {
    final todos = ref.read(smartTodosForDateProvider(date));
    final holiday = ref.read(holidayForDateProvider(date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _TodosPopup(
        date: date,
        todos: todos,
        members: members,
        holiday: holiday,
        onAddTodo: () {
          Navigator.pop(context);
          _showAddTodoSheet(context, date);
        },
      ),
    );
  }
}

/// 할일 팝업 (날짜 클릭시 표시)
class _TodosPopup extends ConsumerWidget {
  final DateTime date;
  final List<TodoItem> todos;
  final List members;
  final Holiday? holiday;
  final VoidCallback onAddTodo;

  const _TodosPopup({
    required this.date,
    required this.todos,
    required this.members,
    this.holiday,
    required this.onAddTodo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        Row(
                          children: [
                            if (isToday)
                              Container(
                                margin: const EdgeInsets.only(top: 4, right: 6),
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
                            if (holiday != null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.errorLight.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  holiday!.name,
                                  style: TextStyle(
                                    color: AppColors.errorLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // 일정 추가 버튼
                IconButton(
                  onPressed: onAddTodo,
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
            child: todos.isEmpty
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
                          onPressed: onAddTodo,
                          icon: const Icon(Iconsax.add, size: 18),
                          label: const Text('일정 추가하기'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                        child: Consumer(
                          builder: (context, ref, child) {
                            return GestureDetector(
                              onTap: () => _showTodoActionsSheet(context, ref, todo),
                              child: TodoCard(
                                todo: todo,
                                members: members,
                              ),
                            );
                          },
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

  void _showTodoActionsSheet(BuildContext context, WidgetRef ref, TodoItem todo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 반복 인스턴스의 경우 원본 ID 추출
    final actualTodoId = todo.parentTodoId ?? todo.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 핸들
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
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
              // 제목
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL, vertical: AppTheme.spacingM),
                child: Text(
                  todo.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 수정 버튼
              ListTile(
                leading: const Icon(Iconsax.edit),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddTodoSheet(todoId: actualTodoId),
                  );
                },
              ),
              // 삭제 버튼
              ListTile(
                leading: Icon(Iconsax.trash, color: AppColors.errorLight),
                title: Text('삭제', style: TextStyle(color: AppColors.errorLight)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(context, ref, todo, actualTodoId);
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, TodoItem todo, String todoId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${todo.title}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final todoService = ref.read(todoServiceProvider);
              try {
                await todoService.deleteTodo(todoId);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e')),
                  );
                }
              }
            },
            child: Text('삭제', style: TextStyle(color: AppColors.errorLight)),
          ),
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
class _MonthView extends ConsumerWidget {
  final DateTime selectedDate;
  final CalendarFormat calendarFormat;
  final List<TodoItem> todos;
  final List<TodoItem> selectedTodos;
  final List<FamilyMember> members;
  final List<Holiday> holidays;
  final bool isDark;
  final Function(DateTime) onDaySelected;
  final Function(CalendarFormat) onFormatChanged;
  final VoidCallback onAddTodo;

  const _MonthView({
    required this.selectedDate,
    required this.calendarFormat,
    required this.todos,
    required this.selectedTodos,
    required this.members,
    required this.holidays,
    required this.isDark,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onAddTodo,
  });

  /// 특정 날짜의 공휴일 찾기
  Holiday? _getHolidayForDay(DateTime day) {
    for (final holiday in holidays) {
      if (holiday.isSameDate(day)) {
        return holiday;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMemberId = ref.watch(calendarMemberFilterProvider);

    // 화면 높이에 맞춰 rowHeight 계산
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    // 헤더(약 80) + 요일행(50) + 달력헤더(60) + 멤버필터(60) + 하단 여백 계산
    final availableHeight = screenHeight - safeAreaTop - safeAreaBottom - 80 - 50 - 60 - 60 - 100;
    final rowHeight = (availableHeight / 6).clamp(65.0, 95.0);

    // 반복 확장된 월간 데이터 사용 (점 표시용)
    final expandedTodos = ref.watch(expandedTodosForMonthProvider((
      year: selectedDate.year,
      month: selectedDate.month,
    )));

    // 선택된 멤버에 따라 Todo 필터링
    final filteredTodos = selectedMemberId == null
        ? expandedTodos
        : expandedTodos.where((todo) => todo.assigneeId == selectedMemberId).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // 멤버 필터 아바타 행
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: MemberAvatarList(
              members: members,
              selectedMemberId: selectedMemberId,
              onMemberSelected: (id) {
                ref.read(calendarMemberFilterProvider.notifier).state = id;
              },
              size: 40,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          // 캘린더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
              ),
              child: TableCalendar<TodoItem>(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: selectedDate,
                calendarFormat: calendarFormat,
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  onDaySelected(selectedDay);
                },
                onFormatChanged: onFormatChanged,
                eventLoader: (day) {
                  // 해당 날짜의 Todo 필터링
                  return filteredTodos.where((todo) => _isTodoOnDate(todo, day)).toList();
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
                    return _buildDayCell(context, day, false, false, filteredTodos);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildDayCell(context, day, true, false, filteredTodos);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final isSelected = isSameDay(selectedDate, day);
                    return _buildDayCell(context, day, isSelected, true, filteredTodos);
                  },
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          ),
        ],
      ),
    );
  }

  /// 해당 날짜에 todo가 있는지 확인하는 공통 함수
  bool _isTodoOnDate(TodoItem todo, DateTime day) {
    if (todo.dueDate == null && todo.startTime == null) return false;

    if (todo.hasTime && todo.startTime != null) {
      // 시간 있음: 시간 범위 비교
      final dayEnd = day.add(const Duration(days: 1));
      final endTime = todo.endTime ?? todo.startTime!.add(const Duration(hours: 1));
      return todo.startTime!.isBefore(dayEnd) && endTime.isAfter(day);
    } else if (todo.dueDate != null) {
      // 시간 미정: 날짜만 비교 (정규화)
      final targetDate = DateTime(day.year, day.month, day.day);
      final todoDate = DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
      return todoDate.isAtSameMomentAs(targetDate);
    }
    return false;
  }

  Widget _buildDayCell(BuildContext context, DateTime day, bool isSelected, bool isToday, List<TodoItem> filteredTodos) {
    final dayTodos = filteredTodos.where((todo) => _isTodoOnDate(todo, day)).toList();
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final holiday = _getHolidayForDay(day);
    final isHoliday = holiday != null;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.calendarColor
            : isToday
                ? AppColors.calendarColor.withValues(alpha: 0.15)
                : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                  : (isHoliday || isWeekend)
                      ? AppColors.errorLight
                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            ),
          ),
          // 공휴일 이름 표시
          if (isHoliday && !isSelected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                _shortenHolidayName(holiday.name),
                style: TextStyle(
                  fontSize: 8,
                  color: AppColors.errorLight,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          // 멤버별 색상 점 표시
          if (dayTodos.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildMemberDots(dayTodos, isSelected),
              ),
            ),
        ],
      ),
    );
  }

  /// 공휴일 이름 축약
  String _shortenHolidayName(String name) {
    // 긴 공휴일 이름을 2~3글자로 축약
    if (name.contains('설날')) return '설날';
    if (name.contains('추석')) return '추석';
    if (name.contains('부처님')) return '석가탄신';
    if (name.contains('어린이')) return '어린이날';
    if (name.contains('현충')) return '현충일';
    if (name.contains('광복')) return '광복절';
    if (name.contains('개천')) return '개천절';
    if (name.contains('한글')) return '한글날';
    if (name.contains('크리스마스')) return '성탄절';
    if (name.contains('신정')) return '신정';
    if (name.contains('삼일')) return '삼일절';
    return name.length > 4 ? name.substring(0, 4) : name;
  }

  /// 멤버별 색상 점 표시
  Widget _buildMemberDots(List<TodoItem> dayTodos, bool isSelected) {
    // 멤버별 Todo 개수 집계
    final memberCounts = <String, int>{};
    for (final todo in dayTodos) {
      final assignee = todo.assigneeId ?? 'unknown';
      memberCounts[assignee] = (memberCounts[assignee] ?? 0) + 1;
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: memberCounts.entries.take(4).map((entry) {
        final member = members.cast<dynamic>().firstWhere(
          (m) => m.id == entry.key,
          orElse: () => null,
        );
        final color = member != null ? _parseColor(member.color) : AppColors.calendarColor;

        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : color,
            shape: BoxShape.circle,
          ),
        );
      }).toList(),
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
