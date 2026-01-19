import 'package:cloud_firestore/cloud_firestore.dart';

/// 사람에 대한 이벤트 (생일, 기념일 등)
class PersonEvent {
  final String id;
  final String title;
  final DateTime date;
  final bool isYearly; // 매년 반복
  final String? note;

  PersonEvent({
    required this.id,
    required this.title,
    required this.date,
    this.isYearly = true,
    this.note,
  });

  factory PersonEvent.fromMap(Map<String, dynamic> data) {
    return PersonEvent(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isYearly: data['isYearly'] ?? true,
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': Timestamp.fromDate(date),
      'isYearly': isYearly,
      'note': note,
    };
  }

  PersonEvent copyWith({
    String? id,
    String? title,
    DateTime? date,
    bool? isYearly,
    String? note,
  }) {
    return PersonEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      isYearly: isYearly ?? this.isYearly,
      note: note ?? this.note,
    );
  }
}

/// 사람 모델 (연락처/인맥 관리)
class Person {
  final String id;
  final String familyId;
  final String name;
  final String? profilePhotoUrl;
  final DateTime? birthday;
  final String? mbti;
  final String? phone;
  final String? email;
  final String? address;
  final String? personality; // 성격 메모
  final String? relationship; // 관계 (친구, 가족, 직장동료 등)
  final String? company; // 회사/학교
  final String? note; // 자유 메모
  final List<PersonEvent> events; // 이벤트 (기념일 등)
  final Map<String, String> customFields; // 확장 가능한 커스텀 필드
  final List<String> tags; // 태그
  final DateTime createdAt;
  final String createdBy;

  Person({
    required this.id,
    required this.familyId,
    required this.name,
    this.profilePhotoUrl,
    this.birthday,
    this.mbti,
    this.phone,
    this.email,
    this.address,
    this.personality,
    this.relationship,
    this.company,
    this.note,
    this.events = const [],
    this.customFields = const {},
    this.tags = const [],
    required this.createdAt,
    required this.createdBy,
  });

  factory Person.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Person(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      name: data['name'] ?? '',
      profilePhotoUrl: data['profilePhotoUrl'],
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      mbti: data['mbti'],
      phone: data['phone'],
      email: data['email'],
      address: data['address'],
      personality: data['personality'],
      relationship: data['relationship'],
      company: data['company'],
      note: data['note'],
      events: (data['events'] as List<dynamic>?)
              ?.map((e) => PersonEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      customFields: Map<String, String>.from(data['customFields'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'name': name,
      'profilePhotoUrl': profilePhotoUrl,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'mbti': mbti,
      'phone': phone,
      'email': email,
      'address': address,
      'personality': personality,
      'relationship': relationship,
      'company': company,
      'note': note,
      'events': events.map((e) => e.toMap()).toList(),
      'customFields': customFields,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  Person copyWith({
    String? id,
    String? familyId,
    String? name,
    String? profilePhotoUrl,
    DateTime? birthday,
    String? mbti,
    String? phone,
    String? email,
    String? address,
    String? personality,
    String? relationship,
    String? company,
    String? note,
    List<PersonEvent>? events,
    Map<String, String>? customFields,
    List<String>? tags,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Person(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      birthday: birthday ?? this.birthday,
      mbti: mbti ?? this.mbti,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      personality: personality ?? this.personality,
      relationship: relationship ?? this.relationship,
      company: company ?? this.company,
      note: note ?? this.note,
      events: events ?? this.events,
      customFields: customFields ?? this.customFields,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// 다가오는 생일까지 남은 일수
  int? get daysUntilBirthday {
    if (birthday == null) return null;
    final now = DateTime.now();
    var nextBirthday = DateTime(now.year, birthday!.month, birthday!.day);
    if (nextBirthday.isBefore(now)) {
      nextBirthday = DateTime(now.year + 1, birthday!.month, birthday!.day);
    }
    return nextBirthday.difference(now).inDays;
  }

  /// 나이 계산
  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    var age = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }
}

/// 관계 타입
class PersonRelationship {
  static const String family = 'family';
  static const String friend = 'friend';
  static const String colleague = 'colleague';
  static const String school = 'school';
  static const String neighbor = 'neighbor';
  static const String other = 'other';

  static const List<String> all = [
    family,
    friend,
    colleague,
    school,
    neighbor,
    other,
  ];

  static String getLabel(String type) {
    switch (type) {
      case family:
        return '가족/친척';
      case friend:
        return '친구';
      case colleague:
        return '직장동료';
      case school:
        return '학교';
      case neighbor:
        return '이웃';
      case other:
        return '기타';
      default:
        return type;
    }
  }
}

/// MBTI 타입
class MbtiType {
  static const List<String> all = [
    'ISTJ', 'ISFJ', 'INFJ', 'INTJ',
    'ISTP', 'ISFP', 'INFP', 'INTP',
    'ESTP', 'ESFP', 'ENFP', 'ENTP',
    'ESTJ', 'ESFJ', 'ENFJ', 'ENTJ',
  ];
}
