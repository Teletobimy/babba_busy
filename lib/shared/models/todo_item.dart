import 'package:cloud_firestore/cloud_firestore.dart';
import 'recurrence.dart';

/// 일정 타입
enum TodoEventType {
  todo,      // 할일 - 개인적인 작은 할일
  personal,  // 개인 일정
  event,     // 이벤트/일정 - 그룹 공유 일정
}

/// 하위 호환성을 위한 별칭
typedef EventType = TodoEventType;

/// 공개 범위
enum TodoVisibility {
  private,  // 나만 보기
  shared,   // 선택한 그룹에 공유
}

extension TodoVisibilityExtension on TodoVisibility {
  String get value {
    switch (this) {
      case TodoVisibility.private:
        return 'private';
      case TodoVisibility.shared:
        return 'shared';
    }
  }

  static TodoVisibility fromString(String value) {
    switch (value) {
      case 'private':
        return TodoVisibility.private;
      case 'shared':
        return TodoVisibility.shared;
      default:
        return TodoVisibility.shared;
    }
  }
}

extension TodoEventTypeExtension on TodoEventType {
  String get label {
    switch (this) {
      case TodoEventType.todo:
        return '할일';
      case TodoEventType.personal:
        return '개인';
      case TodoEventType.event:
        return '일정';
    }
  }

  String get value {
    switch (this) {
      case TodoEventType.todo:
        return 'todo';
      case TodoEventType.personal:
        return 'personal';
      case TodoEventType.event:
        return 'event';
    }
  }

  static TodoEventType fromString(String value) {
    switch (value) {
      case 'todo':
        return TodoEventType.todo;
      case 'personal':
        return TodoEventType.personal;
      case 'schedule': // 하위 호환성
        return TodoEventType.event;
      case 'event':
        return TodoEventType.event;
      default:
        return TodoEventType.todo;
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
  final TodoEventType eventType; // 일정 타입

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

  // Phase 2: 사용자 중심 데이터 구조
  final String? ownerId;               // 소유자 userId (사용자 레벨 저장 시 필수)
  final List<String> sharedGroups;     // 공유 그룹 목록
  final TodoVisibility visibility;     // 공개 범위 (private | shared)

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
    this.eventType = TodoEventType.todo,
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
    // Phase 2 필드
    this.ownerId,
    this.sharedGroups = const [],
    this.visibility = TodoVisibility.shared,
  });

  /// 시간이 지정된 할일인지 여부
  bool get isTimedTodo => hasTime && startTime != null;

  /// 반복 일정인지
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  /// 반복 인스턴스인지 (원본이 아닌 가상 복사본)
  bool get isRecurringInstance => parentTodoId != null;

  /// 특정 사용자가 이 할일을 완료할 수 있는지 확인
  /// - 소유자(ownerId) 또는 생성자(createdBy)
  /// - 담당자(assigneeId)
  /// - 참여자(participants)에 포함된 경우
  bool canComplete(String userId) {
    // 소유자 또는 생성자
    if (ownerId == userId || createdBy == userId) return true;
    // 담당자
    if (assigneeId == userId) return true;
    // 참여자
    if (participants.contains(userId)) return true;
    return false;
  }

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
      eventType: TodoEventTypeExtension.fromString(data['eventType'] ?? 'todo'),
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
      // Phase 2 필드
      ownerId: data['ownerId'],
      sharedGroups: data['sharedGroups'] != null
          ? List<String>.from(data['sharedGroups'])
          : [],
      visibility: TodoVisibilityExtension.fromString(
          data['visibility'] ?? 'shared'),
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
      // Phase 2 필드
      'ownerId': ownerId,
      'sharedGroups': sharedGroups,
      'visibility': visibility.value,
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
    TodoEventType? eventType,
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
    // Phase 2 필드
    String? ownerId,
    List<String>? sharedGroups,
    TodoVisibility? visibility,
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
      // Phase 2 필드
      ownerId: ownerId ?? this.ownerId,
      sharedGroups: sharedGroups ?? this.sharedGroups,
      visibility: visibility ?? this.visibility,
    );
  }
}
