import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_item.dart';
import '../models/recurrence.dart';
import '../models/holiday.dart';
import 'auth_provider.dart';
import 'group_provider.dart';
import 'holiday_provider.dart';

// ============================================================================
// Phase 2: 사용자 중심 Todo Provider 계층
// ============================================================================

/// 내 모든 Todo (users/{userId}/todos)
final userTodosProvider = StreamProvider<List<TodoItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('todos')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList());
});

/// 현재 그룹에 공유된 다른 멤버들의 Todo
/// 레거시 쿼리: families/{groupId}/todos에서 가져옴
/// Phase 2의 collectionGroup 쿼리는 Firestore 인덱스/보안 규칙 설정 후 추가 예정
final sharedTodosProvider = StreamProvider<List<TodoItem>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || user == null || firestore == null) {
    return Stream.value([]);
  }

  // 레거시 쿼리: 그룹 레벨 컬렉션에서 다른 사람의 todo 가져오기
  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('todos')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TodoItem.fromFirestore(doc))
          .where((todo) => todo.createdBy != user.uid) // 내 것 제외
          .toList());
});

/// 현재 그룹에서 볼 수 있는 모든 Todo (내 것 + 공유된 것)
final currentGroupTodosProvider = Provider<List<TodoItem>>((ref) {
  final userTodos = ref.watch(userTodosProvider).value ?? [];
  final sharedTodos = ref.watch(sharedTodosProvider).value ?? [];
  final membership = ref.watch(currentMembershipProvider);

  if (membership == null) return [];

  // 내 todo 중 현재 그룹에 공유된 것 또는 개인 todo
  final myTodosForGroup = userTodos.where((todo) {
    // 개인 todo는 항상 표시
    if (todo.visibility == TodoVisibility.private) return true;
    // 공유 todo는 현재 그룹에 공유된 경우만 표시
    return todo.sharedGroups.contains(membership.groupId);
  }).toList();

  // 내 것 + 다른 멤버의 공유 todo 합치기
  final allTodos = [...myTodosForGroup, ...sharedTodos];

  // 시간순 정렬
  allTodos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return allTodos;
});

// ============================================================================
// 하위 호환성: 기존 todosProvider 유지 (기존 그룹 레벨 쿼리 + 새 사용자 레벨 통합)
// ============================================================================

/// 현재 그룹의 Todo 목록 (하위 호환성)
/// Phase 2: currentGroupTodosProvider를 사용하여 사용자 중심 구조 지원
final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  // Phase 2: userTodosProvider와 sharedTodosProvider가 변경될 때마다 업데이트
  final userTodos = ref.watch(userTodosProvider);
  final sharedTodos = ref.watch(sharedTodosProvider);

  // 두 스트림 중 하나라도 로딩 중이면 이전 값 유지
  if (userTodos.isLoading || sharedTodos.isLoading) {
    return Stream.value(ref.read(currentGroupTodosProvider));
  }

  // currentGroupTodosProvider의 결과를 스트림으로 반환
  return Stream.value(ref.watch(currentGroupTodosProvider));
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

  // Phase 2: 사용자 레벨 컬렉션 (users/{userId}/todos)
  CollectionReference? get _userTodosCollection {
    if (_userId == null || _firestore == null) return null;
    return _firestore!.collection('users').doc(_userId).collection('todos');
  }

  /// 할일 추가 (Phase 2: 사용자 레벨 저장)
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
    TodoEventType eventType = TodoEventType.todo,
    List<String> participants = const [],
    String? location,
    String? calendarGroupId,
    bool isPersonal = false,
    String? color,
    RecurrenceType recurrenceType = RecurrenceType.none,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool excludeHolidays = false,
    // Phase 2 필드
    TodoVisibility visibility = TodoVisibility.shared,
    List<String>? sharedGroups,
  }) async {
    final userTodosRef = _userTodosCollection;
    if (userTodosRef == null || _userId == null) return;

    // sharedGroups가 없으면 현재 그룹으로 기본 설정
    final effectiveSharedGroups = sharedGroups ??
        (_groupId != null ? [_groupId!] : <String>[]);

    final todoData = {
      // Phase 2 필드
      'ownerId': _userId,
      'sharedGroups': effectiveSharedGroups,
      'visibility': visibility.value,
      // 기존 필드 (하위 호환성)
      'familyId': _groupId,
      'title': title,
      'note': note,
      'assigneeId': assigneeId ?? _userId, // 기본값: 나
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
      'participants': participants.isEmpty ? [_userId] : participants,
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
    };

    // Phase 2: 사용자 레벨 저장
    await userTodosRef.add(todoData);

    // 그룹 공유 시 레거시 경로에도 저장 (하위 호환성)
    // families/{groupId}/todos에 저장해야 다른 사용자가 sharedTodosProvider로 볼 수 있음
    if (visibility == TodoVisibility.shared && effectiveSharedGroups.isNotEmpty) {
      for (final groupId in effectiveSharedGroups) {
        await _firestore!
            .collection('families')
            .doc(groupId)
            .collection('todos')
            .add(todoData);
      }
    }
  }

  /// 할일 완료 상태 토글 (Phase 2: 사용자 레벨)
  /// [ownerId]가 제공되면 해당 소유자의 컬렉션에서 업데이트
  /// 제공되지 않으면 현재 사용자의 컬렉션에서 업데이트
  Future<void> toggleTodo(
    String todoId,
    bool isCompleted, {
    String? ownerId,
  }) async {
    if (_firestore == null) return;

    // 소유자 ID가 있으면 해당 사용자의 컬렉션, 없으면 현재 사용자
    final targetUserId = ownerId ?? _userId;
    if (targetUserId == null) return;

    final todosRef = _firestore!
        .collection('users')
        .doc(targetUserId)
        .collection('todos');

    await todosRef.doc(todoId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  /// 할일 수정 (Phase 2: 사용자 레벨)
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
    TodoEventType? eventType,
    List<String>? participants,
    String? location,
    String? calendarGroupId,
    bool? isPersonal,
    String? color,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool? excludeHolidays,
    // Phase 2 필드
    TodoVisibility? visibility,
    List<String>? sharedGroups,
  }) async {
    final userTodosRef = _userTodosCollection;
    if (userTodosRef == null) return;

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
    // Phase 2 필드
    if (visibility != null) updates['visibility'] = visibility.value;
    if (sharedGroups != null) updates['sharedGroups'] = sharedGroups;

    if (updates.isNotEmpty) {
      await userTodosRef.doc(todoId).update(updates);
    }
  }

  /// 할일 삭제 (Phase 2: 사용자 레벨)
  Future<void> deleteTodo(String todoId) async {
    final userTodosRef = _userTodosCollection;
    if (userTodosRef == null) return;
    await userTodosRef.doc(todoId).delete();
  }

  /// 공유 그룹 업데이트 (Phase 2)
  Future<void> updateSharedGroups(String todoId, List<String> sharedGroups) async {
    final userTodosRef = _userTodosCollection;
    if (userTodosRef == null) return;
    await userTodosRef.doc(todoId).update({
      'sharedGroups': sharedGroups,
    });
  }

  /// 공개 범위 변경 (Phase 2)
  Future<void> updateVisibility(String todoId, TodoVisibility visibility) async {
    final userTodosRef = _userTodosCollection;
    if (userTodosRef == null) return;
    await userTodosRef.doc(todoId).update({
      'visibility': visibility.value,
    });
  }
}
