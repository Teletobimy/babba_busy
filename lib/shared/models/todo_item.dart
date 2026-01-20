import 'package:cloud_firestore/cloud_firestore.dart';
import 'recurrence.dart';

/// 일정 타입
enum EventType {
  todo,      // 할일 - 개인적인 작은 할일
  schedule,  // 일정 - 일반적인 스케줄
  event,     // 이벤트 - 중요한 행사/약속
}

extension EventTypeExtension on EventType {
  String get label {
    switch (this) {
      case EventType.todo:
        return '할일';
      case EventType.schedule:
        return '일정';
      case EventType.event:
        return '이벤트';
    }
  }

  String get value {
    switch (this) {
      case EventType.todo:
        return 'todo';
      case EventType.schedule:
        return 'schedule';
      case EventType.event:
        return 'event';
    }
  }

  static EventType fromString(String value) {
    switch (value) {
      case 'todo':
        return EventType.todo;
      case 'schedule':
        return EventType.schedule;
      case 'event':
        return EventType.event;
      default:
        return EventType.todo;
    }
  }
}

/// 할일 모델
class TodoItem {
  final String id;
  final String familyId;
  final String title;
  final String? note;
  final String? assigneeId;
  final bool isCompleted;
  final DateTime? dueDate;
  final String? repeatType; // 'daily', 'weekly', 'monthly', null
  final int priority; // 0: 낮음, 1: 보통, 2: 높음
  final DateTime createdAt;
  final String createdBy;
  final EventType eventType; // 일정 타입

  // 시간 관련 필드 (Day View 지원)
  final DateTime? startTime;    // 시작 시간
  final DateTime? endTime;      // 종료 시간
  final bool hasTime;           // 시간 정보 유무
  final DateTime? completedAt;  // 완료 시간 (UX용)

  // Event 통합 필드
  final List<String> participants;     // 다중 참여자 (기존 assigneeId 대체)
  final String? location;              // 위치
  final String? calendarGroupId;       // 캘린더 그룹 ID
  final bool isPersonal;               // 개인 일정 여부
  final String? color;                 // 색상
  final RecurrenceType recurrenceType; // 반복 유형 (기존 repeatType 대체)
  final List<int>? recurrenceDays;     // 반복 요일 (1=월, 7=일)
  final DateTime? recurrenceEndDate;   // 반복 종료일
  final bool excludeHolidays;          // 공휴일 제외 여부
  final String? parentTodoId;          // 반복 인스턴스 추적용
  final bool isAllDay;                 // 종일 여부

  TodoItem({
    required this.id,
    required this.familyId,
    required this.title,
    this.note,
    this.assigneeId,
    required this.isCompleted,
    this.dueDate,
    this.repeatType,
    this.priority = 1,
    required this.createdAt,
    required this.createdBy,
    this.eventType = EventType.todo,
    this.startTime,
    this.endTime,
    this.hasTime = false,
    this.completedAt,
    this.participants = const [],
    this.location,
    this.calendarGroupId,
    this.isPersonal = false,
    this.color,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceDays,
    this.recurrenceEndDate,
    this.excludeHolidays = false,
    this.parentTodoId,
    this.isAllDay = false,
  });

  /// 시간이 지정된 할일인지 여부
  bool get isTimedTodo => hasTime && startTime != null;

  /// 반복 일정인지
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  /// 반복 인스턴스인지 (원본이 아닌 가상 복사본)
  bool get isRecurringInstance => parentTodoId != null;

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final assigneeId = data['assigneeId'] as String?;

    return TodoItem(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      title: data['title'] ?? '',
      note: data['note'],
      assigneeId: assigneeId,
      isCompleted: data['isCompleted'] ?? false,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      repeatType: data['repeatType'],
      priority: data['priority'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      eventType: EventTypeExtension.fromString(data['eventType'] ?? 'todo'),
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      hasTime: data['hasTime'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      // Event 통합 필드 (하위 호환성)
      participants: data['participants'] != null
          ? List<String>.from(data['participants'])
          : (assigneeId != null ? [assigneeId] : []),
      location: data['location'],
      calendarGroupId: data['calendarGroupId'],
      isPersonal: data['isPersonal'] ?? false,
      color: data['color'],
      recurrenceType: _parseRecurrenceType(data),
      recurrenceDays: data['recurrenceDays'] != null
          ? List<int>.from(data['recurrenceDays'])
          : null,
      recurrenceEndDate: (data['recurrenceEndDate'] as Timestamp?)?.toDate(),
      excludeHolidays: data['excludeHolidays'] ?? false,
      parentTodoId: data['parentTodoId'],
      isAllDay: data['isAllDay'] ?? !(data['hasTime'] ?? false),
    );
  }

  /// RecurrenceType 파싱 (기존 repeatType과 새 recurrenceType 모두 지원)
  static RecurrenceType _parseRecurrenceType(Map<String, dynamic> data) {
    // 새 필드 우선
    if (data['recurrenceType'] != null) {
      final value = data['recurrenceType'] as String;
      switch (value) {
        case 'daily':
          return RecurrenceType.daily;
        case 'weekly':
          return RecurrenceType.weekly;
        case 'monthly':
          return RecurrenceType.monthly;
        case 'yearly':
          return RecurrenceType.yearly;
        default:
          return RecurrenceType.none;
      }
    }

    // 기존 repeatType으로 폴백 (하위 호환성)
    if (data['repeatType'] != null) {
      final value = data['repeatType'] as String;
      switch (value) {
        case 'daily':
          return RecurrenceType.daily;
        case 'weekly':
          return RecurrenceType.weekly;
        case 'monthly':
          return RecurrenceType.monthly;
        default:
          return RecurrenceType.none;
      }
    }

    return RecurrenceType.none;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'title': title,
      'note': note,
      'assigneeId': assigneeId,
      'isCompleted': isCompleted,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'repeatType': repeatType,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'eventType': eventType.value,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'hasTime': hasTime,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
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
          ? Timestamp.fromDate(recurrenceEndDate!)
          : null,
      'excludeHolidays': excludeHolidays,
      'parentTodoId': parentTodoId,
      'isAllDay': isAllDay,
    };
  }

  TodoItem copyWith({
    String? id,
    String? familyId,
    String? title,
    String? note,
    String? assigneeId,
    bool? isCompleted,
    DateTime? dueDate,
    String? repeatType,
    int? priority,
    DateTime? createdAt,
    String? createdBy,
    EventType? eventType,
    DateTime? startTime,
    DateTime? endTime,
    bool? hasTime,
    DateTime? completedAt,
    List<String>? participants,
    String? location,
    String? calendarGroupId,
    bool? isPersonal,
    String? color,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool? excludeHolidays,
    String? parentTodoId,
    bool? isAllDay,
  }) {
    return TodoItem(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      title: title ?? this.title,
      note: note ?? this.note,
      assigneeId: assigneeId ?? this.assigneeId,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      repeatType: repeatType ?? this.repeatType,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      eventType: eventType ?? this.eventType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hasTime: hasTime ?? this.hasTime,
      completedAt: completedAt ?? this.completedAt,
      participants: participants ?? this.participants,
      location: location ?? this.location,
      calendarGroupId: calendarGroupId ?? this.calendarGroupId,
      isPersonal: isPersonal ?? this.isPersonal,
      color: color ?? this.color,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      excludeHolidays: excludeHolidays ?? this.excludeHolidays,
      parentTodoId: parentTodoId ?? this.parentTodoId,
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }
}
