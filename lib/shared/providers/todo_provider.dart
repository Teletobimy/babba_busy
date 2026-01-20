import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_item.dart';
import '../models/recurrence.dart';
import '../models/holiday.dart';
import 'auth_provider.dart';
import 'group_provider.dart';
import 'holiday_provider.dart';

/// 현재 그룹의 Todo 목록
final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('todos')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList());
});

/// 오늘의 할일 목록
final todayTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(todosProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  return todos.where((todo) {
    if (todo.dueDate == null) return false;
    return todo.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
           todo.dueDate!.isBefore(tomorrow);
  }).toList();
});

/// 완료되지 않은 할일 목록
final pendingTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(todosProvider).value ?? [];
  return todos.where((todo) => !todo.isCompleted).toList();
});

/// 특정 구성원의 할일 목록
final memberTodosProvider = Provider.family<List<TodoItem>, String?>((ref, memberId) {
  final todos = ref.watch(todosProvider).value ?? [];
  if (memberId == null) return todos;
  return todos.where((todo) => todo.assigneeId == memberId).toList();
});

/// 특정 날짜의 시간 있는 할일 (Day View용)
final timedTodosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  final todos = ref.watch(todosProvider).value ?? [];
  final targetDate = DateTime(date.year, date.month, date.day);

  return todos.where((todo) {
    if (!todo.hasTime || todo.startTime == null) return false;
    final todoDate = DateTime(
      todo.startTime!.year,
      todo.startTime!.month,
      todo.startTime!.day,
    );
    return todoDate.isAtSameMomentAs(targetDate);
  }).toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
});

/// 완료된 할일 목록
final completedTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(todosProvider).value ?? [];
  return todos.where((todo) => todo.isCompleted).toList()
    ..sort((a, b) {
      // completedAt이 있으면 그걸로 정렬, 없으면 createdAt으로
      final aTime = a.completedAt ?? a.createdAt;
      final bTime = b.completedAt ?? b.createdAt;
      return bTime.compareTo(aTime); // 최근 완료된 것이 위로
    });
});

/// 오늘 완료된 할일 목록
final todayCompletedTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(completedTodosProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return todos.where((todo) {
    final completedDate = todo.completedAt ?? todo.createdAt;
    final todoDate = DateTime(completedDate.year, completedDate.month, completedDate.day);
    return todoDate.isAtSameMomentAs(today);
  }).toList();
});

/// 특정 월의 확장된 todos (반복 인스턴스 포함)
final expandedTodosForMonthProvider = Provider.family<List<TodoItem>, ({int year, int month})>((ref, params) {
  final todos = ref.watch(todosProvider).value ?? [];
  final holidays = ref.watch(allHolidaysForYearProvider(params.year));

  final startOfMonth = DateTime(params.year, params.month, 1);
  final endOfMonth = DateTime(params.year, params.month + 1, 0, 23, 59, 59);

  return _expandRecurringTodos(todos, startOfMonth, endOfMonth, holidays);
});

/// 특정 날짜의 todos (반복 인스턴스 포함)
final todosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  final todos = ref.watch(todosProvider).value ?? [];
  final holidays = ref.watch(allHolidaysForYearProvider(date.year));
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final expandedTodos = _expandRecurringTodos(todos, startOfDay, endOfDay, holidays);

  return expandedTodos.where((todo) {
    if (todo.startTime != null) {
      return todo.startTime!.isBefore(endOfDay) &&
             (todo.endTime ?? todo.startTime!).isAfter(startOfDay);
    } else if (todo.dueDate != null) {
      final dueDay = DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
      return dueDay.isAtSameMomentAs(startOfDay);
    }
    return false;
  }).toList();
});

/// 반복 todos 확장 함수
List<TodoItem> _expandRecurringTodos(
  List<TodoItem> todos,
  DateTime rangeStart,
  DateTime rangeEnd,
  List<Holiday> holidays,
) {
  final result = <TodoItem>[];

  for (final todo in todos) {
    if (!todo.isRecurring) {
      // 일반 todo - 날짜 범위 확인
      if (todo.startTime != null) {
        final endTime = todo.endTime ?? todo.startTime!;
        if (todo.startTime!.isBefore(rangeEnd) && endTime.isAfter(rangeStart)) {
          result.add(todo);
        }
      } else if (todo.dueDate != null) {
        if (todo.dueDate!.isBefore(rangeEnd) && todo.dueDate!.isAfter(rangeStart.subtract(const Duration(days: 1)))) {
          result.add(todo);
        }
      } else {
        // 날짜 없는 todo는 포함 안 함
      }
    } else {
      // 반복 todo 확장
      final instances = _generateRecurringInstances(todo, rangeStart, rangeEnd, holidays);
      result.addAll(instances);
    }
  }

  result.sort((a, b) {
    final aTime = a.startTime ?? a.dueDate ?? a.createdAt;
    final bTime = b.startTime ?? b.dueDate ?? b.createdAt;
    return aTime.compareTo(bTime);
  });
  return result;
}

/// 반복 todo 인스턴스 생성
List<TodoItem> _generateRecurringInstances(
  TodoItem todo,
  DateTime rangeStart,
  DateTime rangeEnd,
  List<Holiday> holidays,
) {
  final instances = <TodoItem>[];
  final baseDuration = todo.endTime != null && todo.startTime != null
      ? todo.endTime!.difference(todo.startTime!)
      : const Duration(hours: 1);

  // 반복 종료일 확인
  final effectiveEndDate = todo.recurrenceEndDate ?? rangeEnd;
  final actualEndDate = effectiveEndDate.isBefore(rangeEnd) ? effectiveEndDate : rangeEnd;

  // 시작 날짜 계산
  var baseDate = todo.startTime ?? todo.dueDate ?? todo.createdAt;
  var currentDate = baseDate;

  // 범위 시작일 이전이면 범위 시작일에 맞춰 조정
  if (currentDate.isBefore(rangeStart)) {
    currentDate = _adjustStartDateForTodo(todo, currentDate, rangeStart);
  }

  // 최대 100개 인스턴스까지만 생성 (무한 루프 방지)
  int count = 0;
  const maxInstances = 100;

  while (currentDate.isBefore(actualEndDate) && count < maxInstances) {
    final instanceEndTime = todo.startTime != null
        ? currentDate.add(baseDuration)
        : currentDate;

    // 범위 내 인스턴스인지 확인
    if (currentDate.isAfter(rangeStart.subtract(const Duration(days: 1)))) {
      // 공휴일 제외 옵션 확인
      bool shouldAdd = true;
      if (todo.excludeHolidays) {
        final isHoliday = holidays.any((h) => h.isSameDate(currentDate));
        if (isHoliday) {
          shouldAdd = false;
        }
      }

      if (shouldAdd) {
        instances.add(todo.copyWith(
          id: '${todo.id}_${currentDate.millisecondsSinceEpoch}',
          startTime: todo.startTime != null ? currentDate : null,
          endTime: todo.startTime != null ? instanceEndTime : null,
          dueDate: currentDate,
          parentTodoId: todo.id,
        ));
      }
    }

    // 다음 반복 날짜 계산
    final nextDate = _getNextOccurrenceForTodo(todo, currentDate);
    if (nextDate == currentDate) break; // 무한 루프 방지
    currentDate = nextDate;
    count++;
  }

  return instances;
}

/// 범위 시작일에 맞춰 시작 날짜 조정
DateTime _adjustStartDateForTodo(TodoItem todo, DateTime originalStart, DateTime rangeStart) {
  var current = originalStart;

  while (current.isBefore(rangeStart)) {
    current = _getNextOccurrenceForTodo(todo, current);
  }

  return current;
}

/// 다음 반복 날짜 계산
DateTime _getNextOccurrenceForTodo(TodoItem todo, DateTime current) {
  switch (todo.recurrenceType) {
    case RecurrenceType.daily:
      return current.add(const Duration(days: 1));

    case RecurrenceType.weekly:
      if (todo.recurrenceDays == null || todo.recurrenceDays!.isEmpty) {
        return current.add(const Duration(days: 7));
      }
      // 다음 반복 요일 찾기
      return _getNextWeeklyOccurrenceForTodo(current, todo.recurrenceDays!);

    case RecurrenceType.monthly:
      return DateTime(
        current.year,
        current.month + 1,
        current.day,
        current.hour,
        current.minute,
      );

    case RecurrenceType.yearly:
      return DateTime(
        current.year + 1,
        current.month,
        current.day,
        current.hour,
        current.minute,
      );

    case RecurrenceType.none:
      return current; // 반복 없음
  }
}

/// 다음 주간 반복 날짜 계산
DateTime _getNextWeeklyOccurrenceForTodo(DateTime current, List<int> recurrenceDays) {
  // recurrenceDays: 1=월요일, 7=일요일
  final currentWeekday = current.weekday; // 1=월, 7=일

  // 정렬된 반복 요일 목록
  final sortedDays = List<int>.from(recurrenceDays)..sort();

  // 현재 요일 이후의 다음 반복 요일 찾기
  for (final day in sortedDays) {
    if (day > currentWeekday) {
      return current.add(Duration(days: day - currentWeekday));
    }
  }

  // 이번 주에 남은 반복 요일이 없으면 다음 주 첫 반복 요일로
  final firstDay = sortedDays.first;
  final daysUntilNextWeek = 7 - currentWeekday + firstDay;
  return current.add(Duration(days: daysUntilNextWeek));
}

/// 할일 서비스
final todoServiceProvider = Provider<TodoService>((ref) {
  return TodoService(ref);
});

class TodoService {
  final Ref _ref;

  TodoService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String? get _groupId => _ref.read(currentMembershipProvider)?.groupId;
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  CollectionReference? get _todosCollection {
    if (_groupId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_groupId).collection('todos');
  }

  /// 할일 추가
  Future<void> addTodo({
    required String title,
    String? note,
    String? assigneeId,
    DateTime? dueDate,
    String? repeatType,
    int priority = 1,
    DateTime? startTime,
    DateTime? endTime,
    bool hasTime = false,
    EventType eventType = EventType.todo,
    List<String> participants = const [],
    String? location,
    String? calendarGroupId,
    bool isPersonal = false,
    String? color,
    RecurrenceType recurrenceType = RecurrenceType.none,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool excludeHolidays = false,
    bool isAllDay = false,
  }) async {
    final todosRef = _todosCollection;
    if (todosRef == null || _userId == null) return;

    await todosRef.add({
      'familyId': _groupId,
      'title': title,
      'note': note,
      'assigneeId': assigneeId,
      'isCompleted': false,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'repeatType': repeatType,
      'priority': priority,
      'createdBy': _userId,
      'createdAt': FieldValue.serverTimestamp(),
      'eventType': eventType.value,
      'startTime': startTime != null ? Timestamp.fromDate(startTime) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime) : null,
      'hasTime': hasTime,
      'completedAt': null,
      // Event 통합 필드
      'participants': participants,
      'location': location,
      'calendarGroupId': calendarGroupId,
      'isPersonal': isPersonal,
      'color': color,
      'recurrenceType': recurrenceType == RecurrenceType.none
          ? null
          : recurrenceType.name,
      'recurrenceDays': recurrenceDays,
      'recurrenceEndDate': recurrenceEndDate != null
          ? Timestamp.fromDate(recurrenceEndDate)
          : null,
      'excludeHolidays': excludeHolidays,
      'isAllDay': isAllDay,
    });
  }

  /// 할일 완료 상태 토글
  Future<void> toggleTodo(String todoId, bool isCompleted) async {
    final todosRef = _todosCollection;
    if (todosRef == null) return;
    await todosRef.doc(todoId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  /// 할일 수정
  Future<void> updateTodo(String todoId, {
    String? title,
    String? note,
    String? assigneeId,
    DateTime? dueDate,
    String? repeatType,
    int? priority,
    DateTime? startTime,
    DateTime? endTime,
    bool? hasTime,
    EventType? eventType,
    List<String>? participants,
    String? location,
    String? calendarGroupId,
    bool? isPersonal,
    String? color,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool? excludeHolidays,
    bool? isAllDay,
  }) async {
    final todosRef = _todosCollection;
    if (todosRef == null) return;

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (note != null) updates['note'] = note;
    if (assigneeId != null) updates['assigneeId'] = assigneeId;
    if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);
    if (repeatType != null) updates['repeatType'] = repeatType;
    if (priority != null) updates['priority'] = priority;
    if (startTime != null) updates['startTime'] = Timestamp.fromDate(startTime);
    if (endTime != null) updates['endTime'] = Timestamp.fromDate(endTime);
    if (hasTime != null) updates['hasTime'] = hasTime;
    if (eventType != null) updates['eventType'] = eventType.value;
    // Event 통합 필드
    if (participants != null) updates['participants'] = participants;
    if (location != null) updates['location'] = location;
    if (calendarGroupId != null) updates['calendarGroupId'] = calendarGroupId;
    if (isPersonal != null) updates['isPersonal'] = isPersonal;
    if (color != null) updates['color'] = color;
    if (recurrenceType != null) {
      updates['recurrenceType'] = recurrenceType == RecurrenceType.none
          ? null
          : recurrenceType.name;
    }
    if (recurrenceDays != null) updates['recurrenceDays'] = recurrenceDays;
    if (recurrenceEndDate != null) {
      updates['recurrenceEndDate'] = Timestamp.fromDate(recurrenceEndDate);
    }
    if (excludeHolidays != null) updates['excludeHolidays'] = excludeHolidays;
    if (isAllDay != null) updates['isAllDay'] = isAllDay;

    if (updates.isNotEmpty) {
      await todosRef.doc(todoId).update(updates);
    }
  }

  /// 할일 삭제
  Future<void> deleteTodo(String todoId) async {
    final todosRef = _todosCollection;
    if (todosRef == null) return;
    await todosRef.doc(todoId).delete();
  }
}
