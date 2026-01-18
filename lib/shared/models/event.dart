import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
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
}
