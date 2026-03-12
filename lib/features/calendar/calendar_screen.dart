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
import '../../shared/providers/calendar_filter_provider.dart';
import '../../shared/providers/group_provider.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/models/holiday.dart';
import '../../shared/models/family_member.dart';
import '../../shared/widgets/member_avatar.dart';
import '../../shared/utils/date_utils.dart' as date_utils;
import '../../shared/utils/color_utils.dart';
import 'widgets/todo_card.dart';
import 'widgets/week_view.dart';
import 'widgets/day_view.dart';
import 'widgets/calendar_filter_sheet.dart';
import '../todo/widgets/add_todo_sheet.dart';
import '../../shared/providers/todo_provider.dart';
import '../../shared/providers/calendar_expense_provider.dart';
import '../../shared/providers/cross_group_provider.dart';

/// 캘린더 뷰 모드
enum CalendarViewMode {
  month, // 월간 뷰
  week, // 주간 뷰
  day, // 일간 뷰
}

/// 선택된 날짜 Provider
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 캘린더 뷰 모드 Provider
final calendarViewModeProvider = StateProvider<CalendarViewMode>(
  (ref) => CalendarViewMode.month,
);

/// 캘린더 포맷 Provider (TableCalendar용)
final calendarFormatProvider = StateProvider<CalendarFormat>(
  (ref) => CalendarFormat.month,
);

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

    // Reset calendar member filter when group changes
    ref.listen(currentMembershipProvider, (previous, next) {
      if (previous?.groupId != next?.groupId) {
        ref.read(calendarMemberFilterProvider.notifier).state = null;
      }
    });

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
                      // 크로스 그룹 토글
                      IconButton(
                        icon: Icon(
                          ref.watch(crossGroupViewEnabledProvider)
                              ? Iconsax.global5
                              : Iconsax.global,
                          size: 22,
                        ),
                        onPressed: () {
                          ref.read(crossGroupViewEnabledProvider.notifier).state =
                              !ref.read(crossGroupViewEnabledProvider);
                        },
                        tooltip: ref.watch(crossGroupViewEnabledProvider)
                            ? '현재 그룹만 보기'
                            : '전체 그룹 보기',
                      ),
                      // 캘린더 필터 버튼
                      const CalendarFilterButton(),
                      // 완료 항목 토글 버튼
                      IconButton(
                        icon: Icon(
                          ref.watch(showCompletedInCalendarProvider)
                              ? Iconsax.tick_circle
                              : Iconsax.tick_circle5,
                        ),
                        onPressed: () {
                          ref
                              .read(showCompletedInCalendarProvider.notifier)
                              .state = !ref.read(
                            showCompletedInCalendarProvider,
                          );
                        },
                        tooltip:
                            '완료 항목 ${ref.watch(showCompletedInCalendarProvider) ? "숨기기" : "표시"}',
                      ),
                      // 오늘로 이동
                      TextButton(
                        onPressed: () {
                          ref.read(selectedDateProvider.notifier).state =
                              DateTime.now();
                        },
                        child: const Text('오늘'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 뷰 모드 세그먼트 컨트롤
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: SegmentedButton<CalendarViewMode>(
                segments: const [
                  ButtonSegment(value: CalendarViewMode.month, label: Text('월')),
                  ButtonSegment(value: CalendarViewMode.week, label: Text('주')),
                  ButtonSegment(value: CalendarViewMode.day, label: Text('일')),
                ],
                selected: {viewMode},
                onSelectionChanged: (s) => ref.read(calendarViewModeProvider.notifier).state = s.first,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),

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
        backgroundColor: AppColors.calendarColorOnWhite,
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
          onPageChanged: (day) {
            // 월 넘길 때는 날짜만 업데이트 (팝업 열지 않음)
            ref.read(selectedDateProvider.notifier).state = day;
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

  void _showTodosPopup(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    List members,
  ) {
    final holiday = ref.read(holidayForDateProvider(date));
    final outerContext = context; // builder 진입 전 캡처

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      builder: (builderContext) => _TodosPopup(
        date: date,
        members: members,
        holiday: holiday,
        onAddTodo: () {
          Navigator.pop(builderContext); // popup의 context로 닫기
          _showAddTodoSheet(outerContext, date); // 외부 context로 시트 열기
        },
      ),
    );
  }
}

/// 할일 팝업 (날짜 클릭시 표시)
class _TodosPopup extends ConsumerWidget {
  final DateTime date;
  final List members;
  final Holiday? holiday;
  final VoidCallback onAddTodo;

  const _TodosPopup({
    required this.date,
    required this.members,
    this.holiday,
    required this.onAddTodo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    // ✅ 모달 내부에서 provider watch - 실시간 업데이트!
    final allTodos = ref.watch(smartTodosForDateProvider(date));
    final selectedMemberId = ref.watch(calendarMemberFilterProvider);
    final todos = selectedMemberId == null ? allTodos
        : allTodos.where((t) => t.isAssignedTo(selectedMemberId)).toList();

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
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            if (isToday)
                              Container(
                                margin: const EdgeInsets.only(top: 4, right: 6),
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
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (holiday != null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.errorLight.withValues(
                                      alpha: 0.5,
                                    ),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                    ),
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacingS,
                        ),
                        child: Consumer(
                          builder: (context, ref, child) {
                            return GestureDetector(
                              onTap: () =>
                                  _showTodoActionsSheet(context, ref, todo),
                              child: TodoCard(todo: todo, members: members),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),

          // 하단 여백
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppTheme.spacingM,
          ),
        ],
      ),
    );
  }

  void _showTodoActionsSheet(
    BuildContext context,
    WidgetRef ref,
    TodoItem todo,
  ) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
                ),
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
                title: Text(
                  '삭제',
                  style: TextStyle(color: AppColors.errorLight),
                ),
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

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    TodoItem todo,
    String todoId,
  ) {
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
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
  final Function(DateTime) onPageChanged;
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
    required this.onPageChanged,
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
    final availableHeight =
        screenHeight - safeAreaTop - safeAreaBottom - 80 - 50 - 60 - 60 - 100;
    final rowHeight = (availableHeight / 6).clamp(65.0, 95.0);

    final dailyExpenses = ref.watch(dailyExpenseProvider);

    // 반복 확장된 월간 데이터 사용 (점 표시용)
    final expandedTodos = ref.watch(
      expandedTodosForMonthProvider((
        year: selectedDate.year,
        month: selectedDate.month,
      )),
    );

    // 선택된 멤버에 따라 Todo 필터링
    final filteredTodos = selectedMemberId == null
        ? expandedTodos
        : expandedTodos
              .where((todo) => todo.isAssignedTo(selectedMemberId))
              .toList();

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
                boxShadow: isDark
                    ? AppTheme.softShadowDark
                    : AppTheme.softShadowLight,
              ),
              child: TableCalendar<TodoItem>(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: selectedDate,
                calendarFormat: calendarFormat,
                availableGestures: AvailableGestures.horizontalSwipe,
                availableCalendarFormats: const {CalendarFormat.month: '월간'},
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  onDaySelected(selectedDay);
                },
                onPageChanged: (focusedDay) {
                  onPageChanged(focusedDay);
                },
                onFormatChanged: onFormatChanged,
                eventLoader: (day) {
                  // 해당 날짜의 Todo 필터링
                  return filteredTodos
                      .where((todo) => _isTodoOnDate(todo, day))
                      .toList();
                },
                locale: 'ko_KR',
                rowHeight: rowHeight,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: Theme.of(context).textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.w600),
                  headerPadding: const EdgeInsets.symmetric(vertical: 16),
                  leftChevronIcon: Icon(
                    Iconsax.arrow_left_2,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  rightChevronIcon: Icon(
                    Iconsax.arrow_right_3,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                daysOfWeekHeight: 40,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
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
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
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
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  weekendTextStyle: TextStyle(
                    color: AppColors.errorLight.withValues(alpha: 0.8),
                  ),
                  markersMaxCount: 0, // 기본 마커 숨기고 커스텀 빌더 사용
                ),
                calendarBuilders: CalendarBuilders(
                  // 커스텀 날짜 셀 빌더 (아바타 포함)
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildDayCell(
                      context,
                      day,
                      false,
                      false,
                      filteredTodos,
                      dailyExpenses: dailyExpenses,
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildDayCell(
                      context,
                      day,
                      true,
                      false,
                      filteredTodos,
                      dailyExpenses: dailyExpenses,
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final isSelected = isSameDay(selectedDate, day);
                    return _buildDayCell(
                      context,
                      day,
                      isSelected,
                      true,
                      filteredTodos,
                      dailyExpenses: dailyExpenses,
                    );
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
    final normalizedDay = date_utils.normalizeDate(day);

    if (todo.dueDate == null && todo.startTime == null) return false;

    if (todo.hasTime && todo.startTime != null) {
      // 시간 있음: 날짜 범위 체크 (정규화)
      final startDate = date_utils.normalizeDate(todo.startTime!);
      final endDate = date_utils.normalizeDate(todo.endTime ?? todo.startTime!);
      return !normalizedDay.isBefore(startDate) &&
          !normalizedDay.isAfter(endDate);
    } else if (todo.dueDate != null) {
      // 시간 미정: 날짜만 비교
      return date_utils
          .normalizeDate(todo.dueDate!)
          .isAtSameMomentAs(normalizedDay);
    }
    return false;
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    bool isSelected,
    bool isToday,
    List<TodoItem> filteredTodos, {
    Map<DateTime, int>? dailyExpenses,
  }) {
    final normalizedDay = date_utils.normalizeDate(day);
    final expense = dailyExpenses?[normalizedDay];
    final dayTodos = filteredTodos
        .where((todo) => _isTodoOnDate(todo, day))
        .toList();
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final holiday = _getHolidayForDay(day);
    final isHoliday = holiday != null;

    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.calendarColor
              : isToday
              ? AppColors.calendarColor.withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(8),
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
                fontWeight: isSelected || isToday
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isHoliday || isWeekend)
                    ? AppColors.errorLight
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
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
            // 멤버별 색상 점 + 개수 표시
            if (dayTodos.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildMemberDots(dayTodos, isSelected),
                ),
              ),
            // 지출 뱃지
            if (expense != null && expense > 0 && !isSelected)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  _formatExpense(expense),
                  style: TextStyle(
                    fontSize: 8,
                    color: AppColors.budgetColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
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

  String _formatExpense(int amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(amount % 10000 == 0 ? 0 : 1)}만';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}천';
    }
    return '$amount';
  }

  /// 멤버별 색상 점 + 개수 표시
  Widget _buildMemberDots(List<TodoItem> dayTodos, bool isSelected) {
    // 멀티데이 이벤트 중복 제거
    final uniqueTodos = <String, TodoItem>{};
    for (final todo in dayTodos) {
      final key = todo.parentTodoId ?? todo.id;
      uniqueTodos[key] = todo;
    }

    // 멤버별 Todo 개수 집계
    final memberCounts = <String, int>{};
    for (final todo in uniqueTodos.values) {
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
        final memberColor = member != null
            ? parseHexColor(member.color, fallback: AppColors.calendarColor)
            : AppColors.calendarColor;
        final count = entry.value;

        // count > 1이면 숫자 배지, 아니면 점만 표시
        if (count > 1) {
          return Container(
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : memberColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? memberColor : Colors.white,
                ),
              ),
            ),
          );
        }

        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : memberColor,
            shape: BoxShape.circle,
          ),
        );
      }).toList(),
    );
  }

}
