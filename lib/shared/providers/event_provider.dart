import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/holiday.dart';
import '../models/recurrence.dart';
import 'auth_provider.dart';
import 'group_provider.dart';
import 'holiday_provider.dart';

/// 현재 그룹의 이벤트 목록 (원본만)
final eventsProvider = StreamProvider<List<Event>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('events')
      .orderBy('startAt')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList());
});

/// 특정 월의 확장된 이벤트 (반복 이벤트 인스턴스 포함)
final expandedEventsForMonthProvider = Provider.family<List<Event>, ({int year, int month})>((ref, params) {
  final events = ref.watch(eventsProvider).value ?? [];
  final holidays = ref.watch(allHolidaysForYearProvider(params.year));

  final startOfMonth = DateTime(params.year, params.month, 1);
  final endOfMonth = DateTime(params.year, params.month + 1, 0, 23, 59, 59);

  return _expandRecurringEvents(events, startOfMonth, endOfMonth, holidays);
});

/// 특정 날짜의 이벤트 (반복 이벤트 인스턴스 포함)
final eventsForDateProvider = Provider.family<List<Event>, DateTime>((ref, date) {
  final events = ref.watch(eventsProvider).value ?? [];
  final holidays = ref.watch(allHolidaysForYearProvider(date.year));
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final expandedEvents = _expandRecurringEvents(events, startOfDay, endOfDay, holidays);

  return expandedEvents.where((event) {
    return event.startAt.isBefore(endOfDay) && event.endAt.isAfter(startOfDay);
  }).toList();
});

/// 이번 주 이벤트 (반복 이벤트 인스턴스 포함)
final thisWeekEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventsProvider).value ?? [];
  final now = DateTime.now();
  final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));
  final holidays = ref.watch(allHolidaysForYearProvider(now.year));

  final expandedEvents = _expandRecurringEvents(events, startOfWeek, endOfWeek, holidays);

  return expandedEvents.where((event) {
    return event.startAt.isBefore(endOfWeek) && event.endAt.isAfter(startOfWeek);
  }).toList();
});

/// 다가오는 이벤트 (7일 이내, 반복 이벤트 인스턴스 포함)
final upcomingEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventsProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekLater = today.add(const Duration(days: 7));
  final holidays = ref.watch(allHolidaysForYearProvider(now.year));

  final expandedEvents = _expandRecurringEvents(events, today, weekLater, holidays);

  return expandedEvents.where((event) {
    return event.startAt.isAfter(now) && event.startAt.isBefore(weekLater);
  }).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
});

/// 반복 이벤트 확장 함수
List<Event> _expandRecurringEvents(
  List<Event> events,
  DateTime rangeStart,
  DateTime rangeEnd,
  List<Holiday> holidays,
) {
  final result = <Event>[];

  for (final event in events) {
    if (!event.isRecurring) {
      // 일반 이벤트
      if (event.startAt.isBefore(rangeEnd) && event.endAt.isAfter(rangeStart)) {
        result.add(event);
      }
    } else {
      // 반복 이벤트 확장
      final instances = _generateRecurringInstances(event, rangeStart, rangeEnd, holidays);
      result.addAll(instances);
    }
  }

  result.sort((a, b) => a.startAt.compareTo(b.startAt));
  return result;
}

/// 반복 이벤트 인스턴스 생성
List<Event> _generateRecurringInstances(
  Event event,
  DateTime rangeStart,
  DateTime rangeEnd,
  List<Holiday> holidays,
) {
  final instances = <Event>[];
  final duration = event.duration;

  // 반복 종료일 확인
  final effectiveEndDate = event.recurrenceEndDate ?? rangeEnd;
  final actualEndDate = effectiveEndDate.isBefore(rangeEnd) ? effectiveEndDate : rangeEnd;

  // 시작 날짜 계산 (원본 이벤트 날짜부터 시작)
  var currentDate = event.startAt;

  // 범위 시작일 이전이면 범위 시작일에 맞춰 조정
  if (currentDate.isBefore(rangeStart)) {
    currentDate = _adjustStartDate(event, currentDate, rangeStart);
  }

  // 최대 100개 인스턴스까지만 생성 (무한 루프 방지)
  int count = 0;
  const maxInstances = 100;

  while (currentDate.isBefore(actualEndDate) && count < maxInstances) {
    final instanceEndAt = currentDate.add(duration);

    // 범위 내 인스턴스인지 확인
    if (instanceEndAt.isAfter(rangeStart)) {
      // 공휴일 제외 옵션 확인
      bool shouldAdd = true;
      if (event.excludeHolidays) {
        final isHoliday = holidays.any((h) => h.isSameDate(currentDate));
        if (isHoliday) {
          shouldAdd = false;
        }
      }

      if (shouldAdd) {
        instances.add(event.copyWith(
          id: '${event.id}_${currentDate.millisecondsSinceEpoch}',
          startAt: currentDate,
          endAt: instanceEndAt,
          parentEventId: event.id,
        ));
      }
    }

    // 다음 반복 날짜 계산
    currentDate = _getNextOccurrence(event, currentDate);
    if (currentDate == event.startAt) break; // 무한 루프 방지
    count++;
  }

  return instances;
}

/// 범위 시작일에 맞춰 시작 날짜 조정
DateTime _adjustStartDate(Event event, DateTime originalStart, DateTime rangeStart) {
  var current = originalStart;

  while (current.isBefore(rangeStart)) {
    current = _getNextOccurrence(event, current);
  }

  return current;
}

/// 다음 반복 날짜 계산
DateTime _getNextOccurrence(Event event, DateTime current) {
  switch (event.recurrenceType) {
    case RecurrenceType.daily:
      return current.add(const Duration(days: 1));

    case RecurrenceType.weekly:
      if (event.recurrenceDays == null || event.recurrenceDays!.isEmpty) {
        return current.add(const Duration(days: 7));
      }
      // 다음 반복 요일 찾기
      return _getNextWeeklyOccurrence(current, event.recurrenceDays!);

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
DateTime _getNextWeeklyOccurrence(DateTime current, List<int> recurrenceDays) {
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

/// 이벤트 서비스
final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(ref);
});

class EventService {
  final Ref _ref;

  EventService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String? get _familyId => _ref.read(currentMembershipProvider)?.groupId;

  CollectionReference? get _eventsCollection {
    if (_familyId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_familyId).collection('events');
  }

  /// 이벤트 추가 (더 이상 사용 안 함)
  @Deprecated('Use TodoService.addTodo() instead. Events are now managed as Todos.')
  Future<void> addEvent({
    required String title,
    String? description,
    required DateTime startAt,
    required DateTime endAt,
    bool isAllDay = false,
    required List<String> participants,
    String? location,
    String? color,
    String? calendarGroupId,
    RecurrenceType recurrenceType = RecurrenceType.none,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool excludeHolidays = false,
  }) async {
    throw UnimplementedError(
      'Creating new events is deprecated. Use TodoService.addTodo() instead.',
    );
  }

  /// 이벤트 수정 (더 이상 사용 안 함)
  @Deprecated('Use TodoService.updateTodo() instead. Events are now managed as Todos.')
  Future<void> updateEvent(String eventId, {
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    List<String>? participants,
    String? location,
    String? color,
    String? calendarGroupId,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool? excludeHolidays,
  }) async {
    throw UnimplementedError(
      'Updating events is deprecated. Use TodoService.updateTodo() instead.',
    );
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String eventId) async {
    final eventsRef = _eventsCollection;
    if (eventsRef == null) return;
    await eventsRef.doc(eventId).delete();
  }
}
