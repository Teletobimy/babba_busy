import 'package:cloud_firestore/cloud_firestore.dart';

/// 반복 유형
enum RecurrenceType {
  none,    // 반복 안 함
  daily,   // 매일
  weekly,  // 매주
  monthly, // 매월
  yearly,  // 매년 (기념일)
}

/// RecurrenceType 확장 메서드
extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.none:
        return '반복 안 함';
      case RecurrenceType.daily:
        return '매일';
      case RecurrenceType.weekly:
        return '매주';
      case RecurrenceType.monthly:
        return '매월';
      case RecurrenceType.yearly:
        return '매년';
    }
  }

  String get shortName {
    switch (this) {
      case RecurrenceType.none:
        return '';
      case RecurrenceType.daily:
        return '매일';
      case RecurrenceType.weekly:
        return '매주';
      case RecurrenceType.monthly:
        return '매월';
      case RecurrenceType.yearly:
        return '매년';
    }
  }
}

/// 일정/이벤트 모델
class Event {
  final String id;
  final String familyId;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final bool isAllDay;
  final List<String> participants;
  final String? location;
  final String? color;
  final String createdBy;
  final DateTime createdAt;
  final String? calendarGroupId; // 캘린더 그룹 ID (개인/가족/친구 등 구분)
  final bool isPersonal; // 개인 일정 여부 (빠른 필터용)

  // 반복 관련 필드
  final RecurrenceType recurrenceType; // 반복 유형
  final List<int>? recurrenceDays; // 반복 요일 (1=월, 7=일) - weekly용
  final DateTime? recurrenceEndDate; // 반복 종료일
  final bool excludeHolidays; // 공휴일 제외 여부
  final String? parentEventId; // 원본 이벤트 ID (반복 인스턴스 표시용)

  Event({
    required this.id,
    required this.familyId,
    required this.title,
    this.description,
    required this.startAt,
    required this.endAt,
    this.isAllDay = false,
    required this.participants,
    this.location,
    this.color,
    required this.createdBy,
    required this.createdAt,
    this.calendarGroupId,
    this.isPersonal = false,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceDays,
    this.recurrenceEndDate,
    this.excludeHolidays = false,
    this.parentEventId,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (data['endAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAllDay: data['isAllDay'] ?? false,
      participants: List<String>.from(data['participants'] ?? []),
      location: data['location'],
      color: data['color'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      calendarGroupId: data['calendarGroupId'],
      isPersonal: data['isPersonal'] ?? false,
      recurrenceType: _parseRecurrenceType(data['recurrenceType']),
      recurrenceDays: data['recurrenceDays'] != null
          ? List<int>.from(data['recurrenceDays'])
          : null,
      recurrenceEndDate: (data['recurrenceEndDate'] as Timestamp?)?.toDate(),
      excludeHolidays: data['excludeHolidays'] ?? false,
      parentEventId: data['parentEventId'],
    );
  }

  static RecurrenceType _parseRecurrenceType(String? value) {
    if (value == null) return RecurrenceType.none;
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

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'title': title,
      'description': description,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'isAllDay': isAllDay,
      'participants': participants,
      'location': location,
      'color': color,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'calendarGroupId': calendarGroupId,
      'isPersonal': isPersonal,
      'recurrenceType': recurrenceType == RecurrenceType.none
          ? null
          : recurrenceType.name,
      'recurrenceDays': recurrenceDays,
      'recurrenceEndDate': recurrenceEndDate != null
          ? Timestamp.fromDate(recurrenceEndDate!)
          : null,
      'excludeHolidays': excludeHolidays,
      'parentEventId': parentEventId,
    };
  }

  Event copyWith({
    String? id,
    String? familyId,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    List<String>? participants,
    String? location,
    String? color,
    String? createdBy,
    DateTime? createdAt,
    String? calendarGroupId,
    bool? isPersonal,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    bool? excludeHolidays,
    String? parentEventId,
  }) {
    return Event(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isAllDay: isAllDay ?? this.isAllDay,
      participants: participants ?? this.participants,
      location: location ?? this.location,
      color: color ?? this.color,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      calendarGroupId: calendarGroupId ?? this.calendarGroupId,
      isPersonal: isPersonal ?? this.isPersonal,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      excludeHolidays: excludeHolidays ?? this.excludeHolidays,
      parentEventId: parentEventId ?? this.parentEventId,
    );
  }

  /// 이벤트 시간 포맷 (시:분)
  String get formattedTime {
    final hour = startAt.hour.toString().padLeft(2, '0');
    final minute = startAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 이벤트 기간 (시간)
  Duration get duration => endAt.difference(startAt);

  /// 여러 날에 걸친 이벤트인지
  bool get isMultiDay {
    return startAt.day != endAt.day ||
        startAt.month != endAt.month ||
        startAt.year != endAt.year;
  }

  /// 반복 일정인지
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  /// 반복 인스턴스인지 (원본이 아닌 가상 복사본)
  bool get isRecurringInstance => parentEventId != null;

  /// 반복 설명 텍스트
  String get recurrenceDescription {
    if (!isRecurring) return '';

    final buffer = StringBuffer(recurrenceType.shortName);

    if (recurrenceType == RecurrenceType.weekly && recurrenceDays != null) {
      final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
      final days = recurrenceDays!.map((d) => dayNames[d - 1]).join(', ');
      buffer.write(' ($days)');
    }

    if (excludeHolidays) {
      buffer.write(' (공휴일 제외)');
    }

    return buffer.toString();
  }
}

/// 요일 상수
class Weekdays {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 3;
  static const int thursday = 4;
  static const int friday = 5;
  static const int saturday = 6;
  static const int sunday = 7;

  static const List<int> weekdays = [monday, tuesday, wednesday, thursday, friday];
  static const List<int> weekend = [saturday, sunday];
  static const List<int> all = [monday, tuesday, wednesday, thursday, friday, saturday, sunday];

  static String getName(int day) {
    switch (day) {
      case monday:
        return '월';
      case tuesday:
        return '화';
      case wednesday:
        return '수';
      case thursday:
        return '목';
      case friday:
        return '금';
      case saturday:
        return '토';
      case sunday:
        return '일';
      default:
        return '';
    }
  }

  static String getFullName(int day) {
    switch (day) {
      case monday:
        return '월요일';
      case tuesday:
        return '화요일';
      case wednesday:
        return '수요일';
      case thursday:
        return '목요일';
      case friday:
        return '금요일';
      case saturday:
        return '토요일';
      case sunday:
        return '일요일';
      default:
        return '';
    }
  }
}
