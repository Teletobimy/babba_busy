import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/todo_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../calendar_screen.dart';
import '../../todo/widgets/add_todo_sheet.dart';

/// 일간 뷰 위젯
class DayView extends ConsumerStatefulWidget {
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
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTodos = ref.watch(smartTodosForDateProvider(widget.selectedDay));
    final selectedMemberId = ref.watch(calendarMemberFilterProvider);
    final todos = selectedMemberId == null ? allTodos
        : allTodos.where((t) => t.isAssignedTo(selectedMemberId)).toList();
    // 시간 있는 Todo
    final timedTodos = todos.where((t) => t.hasTime && t.startTime != null).toList();
    // 시간 미정 Todo
    final undecidedTodos = todos.where((t) => !t.hasTime).toList();
    final isToday = widget.selectedDay.year == _currentTime.year &&
                    widget.selectedDay.month == _currentTime.month &&
                    widget.selectedDay.day == _currentTime.day;

    return Column(
      children: [
        // 날짜 네비게이션 헤더
        _DayHeader(
          selectedDay: widget.selectedDay,
          isToday: isToday,
          onPreviousDay: widget.onPreviousDay,
          onNextDay: widget.onNextDay,
          isDark: isDark,
        ),
        const SizedBox(height: AppTheme.spacingS),

        // 시간 미정 할일
        if (undecidedTodos.isNotEmpty) ...[
          _UndecidedTodosSection(
            todos: undecidedTodos,
            isDark: isDark,
          ),
          const SizedBox(height: AppTheme.spacingS),
        ],

        // 시간별 할일 그리드
        Expanded(
          child: _TimelineGrid(
            todos: timedTodos,
            isDark: isDark,
            isToday: isToday,
            currentTime: _currentTime,
            selectedDay: widget.selectedDay,
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
          Semantics(
            label: '이전 날짜로 이동',
            button: true,
            child: IconButton(
              onPressed: () => onPreviousDay?.call(
                selectedDay.subtract(const Duration(days: 1)),
              ),
              icon: const Icon(Iconsax.arrow_left_2, size: 20),
            ),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Semantics(
            label: '다음 날짜로 이동',
            button: true,
            child: IconButton(
              onPressed: () => onNextDay?.call(
                selectedDay.add(const Duration(days: 1)),
              ),
              icon: const Icon(Iconsax.arrow_right_3, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineGrid extends ConsumerWidget {
  final List<TodoItem> todos;
  final bool isDark;
  final bool isToday;
  final DateTime currentTime;
  final DateTime selectedDay;

  const _TimelineGrid({
    required this.todos,
    required this.isDark,
    required this.isToday,
    required this.currentTime,
    required this.selectedDay,
  });

  /// Calculate column assignments for overlapping events.
  /// Returns a map from todo.id to (column index, total columns in group).
  static Map<String, ({int column, int totalColumns})> _calculateEventColumns(
    List<TodoItem> timedTodos,
    DateTime day,
  ) {
    if (timedTodos.isEmpty) return {};

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Build a list of (id, visibleStartMinutes, visibleEndMinutes)
    final events = <({String id, double start, double end})>[];
    for (final todo in timedTodos) {
      if (todo.startTime == null) continue;
      final startTime = todo.startTime!;
      final rawEnd = todo.endTime ?? startTime.add(const Duration(hours: 1));
      final endTime = rawEnd.isAfter(startTime)
          ? rawEnd
          : startTime.add(const Duration(minutes: 30));
      if (!endTime.isAfter(dayStart) || !startTime.isBefore(dayEnd)) continue;

      final visibleStart = startTime.isBefore(dayStart) ? dayStart : startTime;
      final visibleEnd = endTime.isAfter(dayEnd) ? dayEnd : endTime;
      final startMin = visibleStart.difference(dayStart).inMinutes.toDouble();
      final endMin = visibleEnd.difference(dayStart).inMinutes.toDouble();
      // Ensure minimum 30min for overlap detection (matching render logic)
      final effectiveEnd = (endMin - startMin) < 30 ? startMin + 30 : endMin;
      events.add((id: todo.id, start: startMin, end: effectiveEnd));
    }

    // Sort by start time, then by longer duration first
    events.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return (b.end - b.start).compareTo(a.end - a.start);
    });

    // Greedy column assignment
    final columnMap = <String, int>{};
    // Track end times per column
    final columnEnds = <double>[];

    for (final event in events) {
      // Find the lowest column where this event doesn't overlap
      int assignedColumn = -1;
      for (int c = 0; c < columnEnds.length; c++) {
        if (columnEnds[c] <= event.start) {
          assignedColumn = c;
          break;
        }
      }
      if (assignedColumn == -1) {
        assignedColumn = columnEnds.length;
        columnEnds.add(0);
      }
      columnEnds[assignedColumn] = event.end;
      columnMap[event.id] = assignedColumn;
    }

    // Determine total columns per overlap group using a sweep approach.
    // For each event, totalColumns = max columns used by any event it overlaps with (including itself).
    final result = <String, ({int column, int totalColumns})>{};

    for (final event in events) {
      // Find all events that overlap with this one
      int maxCol = columnMap[event.id]!;
      for (final other in events) {
        if (other.start < event.end && event.start < other.end) {
          final otherCol = columnMap[other.id]!;
          if (otherCol > maxCol) maxCol = otherCol;
        }
      }
      result[event.id] = (column: columnMap[event.id]!, totalColumns: maxCol + 1);
    }

    // Normalize: for each overlap cluster, all members should share the same totalColumns
    // (the max totalColumns among overlapping events)
    bool changed = true;
    while (changed) {
      changed = false;
      for (final event in events) {
        final current = result[event.id]!;
        for (final other in events) {
          if (other.start < event.end && event.start < other.end) {
            final otherInfo = result[other.id]!;
            if (otherInfo.totalColumns > current.totalColumns) {
              result[event.id] = (column: current.column, totalColumns: otherInfo.totalColumns);
              changed = true;
              break;
            }
          }
        }
        if (changed) break;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnInfo = _calculateEventColumns(todos, selectedDay);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          return SingleChildScrollView(
            child: Stack(
              children: [
                // 시간 그리드
                Column(
                  children: List.generate(24, (hour) {
                    return _TimeSlot(
                      hour: hour,
                      isDark: isDark,
                      selectedDay: selectedDay,
                    );
                  }),
                ),
                // 현재 시간 표시 (오늘인 경우)
                if (isToday)
                  _CurrentTimeLine(
                    currentTime: currentTime,
                  ),
                // 할일 블록들
                ...todos.map((todo) {
                  final info = columnInfo[todo.id];
                  return _DayTodoBlock(
                    todo: todo,
                    isDark: isDark,
                    day: selectedDay,
                    column: info?.column ?? 0,
                    totalColumns: info?.totalColumns ?? 1,
                    totalWidth: totalWidth,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimeSlot extends ConsumerWidget {
  final int hour;
  final bool isDark;
  final DateTime selectedDay;

  const _TimeSlot({
    required this.hour,
    required this.isDark,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<TodoItem>(
      onAcceptWithDetails: (details) async {
        final todo = details.data;
        final newStart = DateTime(
          selectedDay.year, selectedDay.month, selectedDay.day,
          hour,
        );
        final duration = (todo.endTime != null && todo.startTime != null)
            ? todo.endTime!.difference(todo.startTime!)
            : const Duration(hours: 1);
        final newEnd = newStart.add(duration);
        final resolvedId = todo.parentTodoId ?? todo.id;

        // 반복 일정인 경우 확인 다이얼로그
        if (todo.parentTodoId != null) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('반복 일정 변경'),
              content: const Text('이 변경은 원본 일정에 적용됩니다.\n모든 반복 인스턴스의 시간이 변경됩니다.\n\n계속하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('변경'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }

        ref.read(todoServiceProvider).updateTodo(
          resolvedId,
          startTime: newStart,
          endTime: newEnd,
          dueDate: newStart,
          hasTime: true,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${todo.title} → ${hour.toString().padLeft(2, '0')}:00으로 이동'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () {
              ref.read(todoServiceProvider).updateTodo(
                resolvedId,
                startTime: todo.startTime,
                endTime: todo.endTime,
                dueDate: todo.dueDate,
                hasTime: todo.hasTime,
              );
            },
          ),
        ));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: isHovered ? AppColors.primaryLight.withValues(alpha: 0.1) : null,
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
                      fontSize: 12,
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
      },
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

class _DayTodoBlock extends ConsumerWidget {
  final TodoItem todo;
  final bool isDark;
  final DateTime day;
  final int column;
  final int totalColumns;
  final double totalWidth;

  const _DayTodoBlock({
    required this.todo,
    required this.isDark,
    required this.day,
    this.column = 0,
    this.totalColumns = 1,
    this.totalWidth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (todo.startTime == null) return const SizedBox.shrink();

    final startTime = todo.startTime!;
    final rawEndTime = todo.endTime ?? startTime.add(const Duration(hours: 1));
    final endTime = rawEndTime.isAfter(startTime)
        ? rawEndTime
        : startTime.add(const Duration(minutes: 30));

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 이 날에 보이지 않으면 렌더링하지 않음
    if (!endTime.isAfter(dayStart) || !startTime.isBefore(dayEnd)) {
      return const SizedBox.shrink();
    }

    // 현재 날짜 경계에 맞게 클램프
    final visibleStart = startTime.isBefore(dayStart) ? dayStart : startTime;
    final visibleEnd = endTime.isAfter(dayEnd) ? dayEnd : endTime;
    final durationMinutes = visibleEnd.difference(visibleStart).inMinutes;

    // 최소 30분 높이 보장
    final height = (durationMinutes < 30 ? 30 : durationMinutes).toDouble();
    final top = visibleStart.difference(dayStart).inMinutes.toDouble();

    final todoColor = _getEventTypeColor(todo.eventType);

    // Calculate horizontal position based on column assignment
    const double hourLabelWidth = 55;
    const double rightMargin = 8;
    final double availableWidth = totalWidth - hourLabelWidth - rightMargin;
    final double columnWidth = availableWidth / totalColumns;
    final double left = hourLabelWidth + (column * columnWidth);
    final double width = columnWidth - (totalColumns > 1 ? 2 : 0); // 2px gap between columns

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: LongPressDraggable<TodoItem>(
        data: todo,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 200,
            height: 50,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: todoColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              todo.title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildTodoContainer(todoColor, height, context, ref),
        ),
        child: _buildTodoContainer(todoColor, height, context, ref),
      ),
    );
  }

  Widget _buildTodoContainer(Color todoColor, double height, BuildContext context, WidgetRef ref) {
    final endTime = todo.endTime ?? todo.startTime!.add(const Duration(hours: 1));
    return Semantics(
        label: '${todo.title} ${todo.isCompleted ? "완료됨" : "미완료"}',
        button: true,
        child: GestureDetector(
        onTap: () => _openEditSheet(context),
        onLongPress: () => _showContextMenu(context, ref),
        child: Container(
          decoration: BoxDecoration(
            color: todo.isCompleted
                ? todoColor.withValues(alpha: 0.4)
                : todoColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: todoColor,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            boxShadow: [
              BoxShadow(
                color: todoColor.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // 체크박스
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: todo.isCompleted ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: todo.isCompleted
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: todoColor,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (height > 40) ...[
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
                            '${DateFormat('HH:mm').format(todo.startTime!)} - ${DateFormat('HH:mm').format(endTime)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                todo.isCompleted ? Iconsax.close_circle : Iconsax.tick_circle,
              ),
              title: Text(todo.isCompleted ? '완료 취소' : '완료 처리'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleComplete(ref);
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.edit),
              title: const Text('편집'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.clock),
              title: const Text('시간 변경'),
              onTap: () {
                Navigator.pop(ctx);
                _showTimePickerForTodo(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePickerForTodo(BuildContext context, WidgetRef ref) async {
    final startTime = todo.startTime ?? DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startTime),
    );
    if (pickedTime == null || !context.mounted) return;

    final duration = todo.endTime != null
        ? todo.endTime!.difference(todo.startTime!)
        : const Duration(hours: 1);
    final newStart = DateTime(
      startTime.year, startTime.month, startTime.day,
      pickedTime.hour, pickedTime.minute,
    );
    final newEnd = newStart.add(duration);
    final resolvedId = todo.parentTodoId ?? todo.id;

    ref.read(todoServiceProvider).updateTodo(
      resolvedId,
      startTime: newStart,
      endTime: newEnd,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${todo.title} → ${pickedTime.format(context)}으로 변경'),
      duration: const Duration(seconds: 8),
    ));
  }

  void _openEditSheet(BuildContext context) {
    final todoId = todo.parentTodoId ?? todo.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTodoSheet(todoId: todoId),
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

  /// 현재 사용자가 이 할일을 완료할 수 있는지 확인
  bool _canComplete(WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;
    return todo.canComplete(currentUser.uid);
  }

  Future<void> _toggleComplete(WidgetRef ref) async {
    // 권한 체크
    if (!_canComplete(ref)) return;

    final resolvedId = todo.parentTodoId ?? todo.id;
    await ref.read(todoServiceProvider).toggleTodo(
      resolvedId,
      !todo.isCompleted,
      ownerId: todo.ownerId,
    );
  }
}

/// 시간 미정 할일 섹션
class _UndecidedTodosSection extends ConsumerWidget {
  final List<TodoItem> todos;
  final bool isDark;

  const _UndecidedTodosSection({
    required this.todos,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Iconsax.clock,
                size: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                '시간 미정',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const Spacer(),
              Text(
                '${todos.length}개',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),

          // Todo 목록
          ...todos.map((todo) => _UndecidedTodoItem(
            todo: todo,
            isDark: isDark,
          )),
        ],
      ),
    );
  }
}

/// 시간 미정 할일 아이템
class _UndecidedTodoItem extends ConsumerWidget {
  final TodoItem todo;
  final bool isDark;

  const _UndecidedTodoItem({
    required this.todo,
    required this.isDark,
  });

  /// 현재 사용자가 이 할일을 완료할 수 있는지 확인
  bool _canComplete(WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;
    return todo.canComplete(currentUser.uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canComplete = _canComplete(ref);

    return Semantics(
      label: '${todo.title}, 시간 미정, ${todo.isCompleted ? "완료됨" : "미완료"}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.coral[100]?.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: AppColors.coral[300]!.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // 체크박스 (완료 권한이 있는 경우에만 활성화)
            // 터치 타겟 최소 44x44px 보장
            Semantics(
              label: todo.isCompleted ? '완료 취소' : '완료 처리',
              button: true,
              enabled: canComplete,
              child: GestureDetector(
                onTap: canComplete
                    ? () async {
                        final resolvedId = todo.parentTodoId ?? todo.id;
                        await ref.read(todoServiceProvider).toggleTodo(
                          resolvedId,
                          !todo.isCompleted,
                          ownerId: todo.ownerId,
                        );
                      }
                    : null,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: todo.isCompleted ? AppColors.coral[500] : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: canComplete
                            ? AppColors.coral[500]!
                            : AppColors.coral[500]!.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: todo.isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),

            // 제목
            Expanded(
              child: Text(
                todo.title,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
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
}
