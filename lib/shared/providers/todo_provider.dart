import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_item.dart';
import '../models/recurrence.dart';
import '../models/holiday.dart';
import '../utils/date_utils.dart' as date_utils;
import 'auth_provider.dart';
import 'group_provider.dart';
import 'holiday_provider.dart';
import 'calendar_filter_provider.dart';

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

/// 현재 그룹에 공유된 다른 멤버들의 Todo (CollectionGroup 쿼리)
/// Firestore 인덱스 필요: todos 컬렉션 그룹에 (sharedGroups, visibility) 복합 인덱스
final sharedTodosProvider = StreamProvider<List<TodoItem>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || user == null || firestore == null) {
    return Stream.value([]);
  }

  // CollectionGroup 쿼리: users/{userId}/todos에서 현재 그룹에 공유된 todos 가져오기
  return firestore
      .collectionGroup('todos')
      .where('sharedGroups', arrayContains: membership.groupId)
      .where('visibility', isEqualTo: 'shared')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TodoItem.fromFirestore(doc))
          .where((todo) => todo.ownerId != user.uid) // 내 것 제외
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
///
/// `Provider<AsyncValue>`로 구현하여 StreamProvider의 불필요한 래핑 제거.
/// - 기존 StreamProvider는 Stream.value()로 단발성 값을 반환하면서도
///   isLoading 시 ref.read()로 빈 리스트를 반환하는 문제가 있었음.
/// - 이제 userTodos/sharedTodos의 AsyncValue 상태를 직접 전달하여
///   로딩/에러/데이터 상태를 정확히 표현함.
/// - 소비자 측 코드 (.value ?? [], .isLoading 등)는 변경 없이 호환됨.
final todosProvider = Provider<AsyncValue<List<TodoItem>>>((ref) {
  final userTodos = ref.watch(userTodosProvider);
  final sharedTodos = ref.watch(sharedTodosProvider);

  // 둘 다 에러인 경우에만 에러 전파
  if (userTodos.hasError && sharedTodos.hasError) {
    return AsyncValue.error(
      userTodos.error!,
      userTodos.stackTrace ?? StackTrace.current,
    );
  }

  // 둘 다 로딩 중이면 로딩 상태 전파
  // 하나만 로딩 중이면 다른 하나의 데이터와 합쳐서 보여줌 (부분 로딩 허용)
  if (userTodos.isLoading && sharedTodos.isLoading) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(ref.watch(currentGroupTodosProvider));
});

/// 오늘의 할일 목록
final todayTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(todosProvider).value ?? [];
  final now = DateTime.now();
  final today = date_utils.normalizeDate(now);

  return todos.where((todo) {
    if (todo.dueDate == null) return false;
    final normalizedDueDate = date_utils.normalizeDate(todo.dueDate!);
    return normalizedDueDate.isAtSameMomentAs(today);
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
  return todos.where((todo) => todo.isAssignedTo(memberId)).toList();
});

/// 특정 날짜의 시간 있는 할일 (Day View용)
final timedTodosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  final todos = ref.watch(todosProvider).value ?? [];
  final targetDate = date_utils.normalizeDate(date);

  return todos.where((todo) {
    if (!todo.hasTime || todo.startTime == null) return false;
    final todoDate = date_utils.normalizeDate(todo.startTime!);
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
  final today = date_utils.normalizeDate(now);

  return todos.where((todo) {
    final completedDate = todo.completedAt ?? todo.createdAt;
    final todoDate = date_utils.normalizeDate(completedDate);
    return todoDate.isAtSameMomentAs(today);
  }).toList();
});

/// 월 키 정규화 (캐싱 효율성 향상)
typedef MonthKey = ({int year, int month});

/// 특정 월의 확장된 todos (반복 인스턴스 포함)
/// 메모리 최적화: 최대 31개 인스턴스만 생성 (월 범위)
final expandedTodosForMonthProvider = Provider.family<List<TodoItem>, MonthKey>((ref, params) {
  var todos = ref.watch(todosProvider).value ?? [];
  final holidays = ref.watch(allHolidaysForYearProvider(params.year));

  final startOfMonth = DateTime(params.year, params.month, 1);
  final endOfMonth = DateTime(params.year, params.month + 1, 0, 23, 59, 59);

  // 월 범위에 맞게 반복 인스턴스 생성 제한
  todos = _expandRecurringTodos(todos, startOfMonth, endOfMonth, holidays, maxInstancesPerTodo: 31);

  // Apply shared event types filter
  final memberships = ref.watch(groupMembershipsProvider).valueOrNull ?? [];
  final membershipByUserId = {for (var m in memberships) m.userId: m};

  todos = todos.where((todo) {
    if (todo.createdBy.isEmpty) return true;
    final creatorMembership = membershipByUserId[todo.createdBy];
    final sharedTypes = creatorMembership?.sharedEventTypes ?? ['todo', 'schedule', 'event'];
    return sharedTypes.contains(todo.eventType.value);
  }).toList();

  // Apply visibility filter: private 일정은 본인만 볼 수 있음
  final currentUserId = ref.watch(currentUserProvider)?.uid;
  todos = todos.where((todo) {
    if (todo.visibility == TodoVisibility.private) {
      return todo.ownerId == currentUserId || todo.createdBy == currentUserId;
    }
    return true;
  }).toList();

  // Apply completed filter
  final showCompleted = ref.watch(showCompletedInCalendarProvider);
  if (!showCompleted) {
    todos = todos.where((t) => !t.isCompleted).toList();
  }

  return todos;
});

/// 날짜 키 정규화 (시간 제거하여 캐시 히트율 향상)
/// DateTime 대신 정규화된 날짜 문자열(yyyyMMdd) 사용으로 재생성 방지
final normalizedDateKeyProvider = Provider.family<DateTime, DateTime>((ref, date) {
  return date_utils.normalizeDate(date);
});

/// 특정 날짜의 todos (반복 인스턴스 포함)
/// 캐싱 최적화: 날짜를 정규화하여 동일 날짜에 대한 중복 계산 방지
final todosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  // 날짜 정규화 (시간 제거)
  final normalizedDate = date_utils.normalizeDate(date);
  final todos = ref.watch(todosProvider).value ?? [];
  final holidays = ref.watch(allHolidaysForYearProvider(normalizedDate.year));
  final startOfDay = normalizedDate;
  final endOfDay = startOfDay.add(const Duration(days: 1));

  // 단일 날짜이므로 최대 1개의 인스턴스만 필요
  final expandedTodos = _expandRecurringTodos(todos, startOfDay, endOfDay, holidays, maxInstancesPerTodo: 1);

  return expandedTodos.where((todo) {
    if (todo.startTime != null) {
      return todo.startTime!.isBefore(endOfDay) &&
             (todo.endTime ?? todo.startTime!).isAfter(startOfDay);
    } else if (todo.dueDate != null) {
      final dueDay = date_utils.normalizeDate(todo.dueDate!);
      return dueDay.isAtSameMomentAs(startOfDay);
    }
    return false;
  }).toList();
});

/// 반복 todos 확장 함수
/// [maxInstancesPerTodo]: todo당 최대 인스턴스 수 (메모리 최적화)
List<TodoItem> _expandRecurringTodos(
  List<TodoItem> todos,
  DateTime rangeStart,
  DateTime rangeEnd,
  List<Holiday> holidays, {
  int maxInstancesPerTodo = 100,
}) {
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
        final normalizedDue = date_utils.normalizeDate(todo.dueDate!);
        final normalizedStart = date_utils.normalizeDate(rangeStart);
        final normalizedEnd = date_utils.normalizeDate(rangeEnd);
        if (!normalizedDue.isAfter(normalizedEnd) && !normalizedDue.isBefore(normalizedStart)) {
          result.add(todo);
        }
      } else {
        // 날짜 없는 todo는 포함 안 함
      }
    } else {
      // 반복 todo 확장 (인스턴스 수 제한)
      final instances = _generateRecurringInstances(
        todo, rangeStart, rangeEnd, holidays,
        maxInstances: maxInstancesPerTodo,
      );
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
/// [maxInstances]: 이 todo에서 생성할 최대 인스턴스 수 (범위에 따라 동적 조정)
List<TodoItem> _generateRecurringInstances(
  TodoItem todo,
  DateTime rangeStart,
  DateTime rangeEnd,
  List<Holiday> holidays, {
  int maxInstances = 100,
}) {
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

  int count = 0;

  // 종료일 당일도 포함하기 위해 inclusiveEndDate 사용
  final inclusiveEndDate = DateTime(actualEndDate.year, actualEndDate.month, actualEndDate.day, 23, 59, 59);

  while (!currentDate.isAfter(inclusiveEndDate) && count < maxInstances) {
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
          id: '${todo.id}_${currentDate.year}${currentDate.month.toString().padLeft(2, '0')}${currentDate.day.toString().padLeft(2, '0')}',
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

  if (count >= maxInstances && maxInstances > 31) {
    debugPrint('⚠️ Recurring todo "${todo.title}" exceeded max instances ($maxInstances)');
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
      var nextMonth = current.month + 1;
      var nextYear = current.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      // 월말 안전 처리: 다음 달의 최대 일수 확인
      final maxDayMonthly = DateTime(nextYear, nextMonth + 1, 0).day;
      final safeDayMonthly = current.day > maxDayMonthly ? maxDayMonthly : current.day;
      return DateTime(nextYear, nextMonth, safeDayMonthly, current.hour, current.minute);

    case RecurrenceType.yearly:
      // 윤년 안전 처리: 2월 29일 → 비윤년에서는 2월 28일
      final nextYearValue = current.year + 1;
      final maxDayYearly = DateTime(nextYearValue, current.month + 1, 0).day;
      final safeDayYearly = current.day > maxDayYearly ? maxDayYearly : current.day;
      return DateTime(
        nextYearValue,
        current.month,
        safeDayYearly,
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

  /// 다음 알림 시간 계산 (미발송 알림 중 가장 빠른 시간)
  static Timestamp? _calculateNextReminderAt(
    DateTime? eventTime,
    List<int> reminderMinutes,
    List<int> remindersSent,
  ) {
    if (eventTime == null || reminderMinutes.isEmpty) return null;

    final pendingMinutes = reminderMinutes
        .where((m) => !remindersSent.contains(m))
        .toList();
    if (pendingMinutes.isEmpty) return null;

    // 미발송 알림 중 가장 빠른 시간 찾기 (가장 큰 minutes 값)
    final maxMinutes = pendingMinutes.reduce((a, b) => a > b ? a : b);
    final nextTime = eventTime.subtract(Duration(minutes: maxMinutes));
    return Timestamp.fromDate(nextTime);
  }

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
    // 알림 설정
    List<int> reminderMinutes = const [],
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
      // 알림 설정
      'reminderMinutes': reminderMinutes.isEmpty ? null : reminderMinutes,
      'remindersSent': null,
      'nextReminderAt': _calculateNextReminderAt(
        startTime ?? dueDate,
        reminderMinutes,
        [],
      ),
    };

    // users/{userId}/todos에 저장 (CollectionGroup 쿼리로 다른 사용자가 조회)
    await userTodosRef.add(todoData);
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
  /// 데이터 무결성: startTime/dueDate/reminderMinutes 변경 시 nextReminderAt 자동 재계산
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
    // 알림 설정
    List<int>? reminderMinutes,
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

    // 알림 관련 필드 변경 시 nextReminderAt 재계산 필요
    final needsReminderRecalc = reminderMinutes != null ||
        startTime != null ||
        dueDate != null;

    if (reminderMinutes != null) {
      updates['reminderMinutes'] = reminderMinutes.isEmpty ? null : reminderMinutes;
      updates['remindersSent'] = []; // 알림 시간 변경 시 발송 기록 초기화
    }

    // nextReminderAt 재계산 (데이터 무결성 보장)
    if (needsReminderRecalc) {
      // 현재 문서 조회하여 기존 값과 병합
      final currentDoc = await userTodosRef.doc(todoId).get();
      if (currentDoc.exists) {
        final currentData = currentDoc.data() as Map<String, dynamic>;

        // 이벤트 시간 결정 (새 값 우선, 없으면 기존 값)
        final effectiveStartTime = startTime ??
            (currentData['startTime'] as Timestamp?)?.toDate();
        final effectiveDueDate = dueDate ??
            (currentData['dueDate'] as Timestamp?)?.toDate();
        final eventTime = effectiveStartTime ?? effectiveDueDate;

        // 알림 설정 결정
        final effectiveReminderMinutes = reminderMinutes ??
            (currentData['reminderMinutes'] != null
                ? List<int>.from(currentData['reminderMinutes'])
                : <int>[]);

        // remindersSent (reminderMinutes 변경 시 초기화됨)
        final effectiveRemindersSent = reminderMinutes != null
            ? <int>[]
            : (currentData['remindersSent'] != null
                ? List<int>.from(currentData['remindersSent'])
                : <int>[]);

        // nextReminderAt 재계산
        updates['nextReminderAt'] = _calculateNextReminderAt(
          eventTime,
          effectiveReminderMinutes,
          effectiveRemindersSent,
        );
      }
    }

    if (updates.isNotEmpty) {
      await userTodosRef.doc(todoId).update(updates);
    }
  }

  /// 할일 삭제 (Phase 2: 사용자 레벨)
  Future<void> deleteTodo(String todoId) async {
    // Prevent deletion of recurring instances (ID format: {parentId}_{yyyyMMdd})
    if (RegExp(r'_\d{8}$').hasMatch(todoId)) {
      debugPrint('⚠️ Cannot delete recurring instance: $todoId');
      throw Exception('반복 인스턴스는 삭제할 수 없습니다. 원본 일정을 삭제해주세요.');
    }
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
