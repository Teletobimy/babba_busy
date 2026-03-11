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

/// 삶의 컨텍스트 이벤트 (출산 예정, 건강 이슈 등)
class PersonLifeEvent {
  final String id;
  final String type;
  final String title;
  final DateTime? expectedDate;
  final String? note;
  final int importance; // 1~5

  PersonLifeEvent({
    required this.id,
    required this.type,
    required this.title,
    this.expectedDate,
    this.note,
    this.importance = 3,
  });

  factory PersonLifeEvent.fromMap(Map<String, dynamic> data) {
    return PersonLifeEvent(
      id: data['id'] ?? '',
      type: data['type'] ?? 'general',
      title: data['title'] ?? '',
      expectedDate: (data['expectedDate'] as Timestamp?)?.toDate(),
      note: data['note'],
      importance: _safeInt(data['importance'], fallback: 3).clamp(1, 5),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'expectedDate':
          expectedDate != null ? Timestamp.fromDate(expectedDate!) : null,
      'note': note,
      'importance': importance,
    };
  }
}

/// 선물 선호 정보
class GiftPreference {
  final List<String> likes;
  final List<String> dislikes;
  final List<String> taboo;
  final int? budgetMin;
  final int? budgetMax;
  final String? style;

  const GiftPreference({
    this.likes = const [],
    this.dislikes = const [],
    this.taboo = const [],
    this.budgetMin,
    this.budgetMax,
    this.style,
  });

  factory GiftPreference.fromMap(Map<String, dynamic> data) {
    return GiftPreference(
      likes: List<String>.from(data['likes'] ?? const []),
      dislikes: List<String>.from(data['dislikes'] ?? const []),
      taboo: List<String>.from(data['taboo'] ?? const []),
      budgetMin:
          data['budgetMin'] != null ? _safeInt(data['budgetMin'], fallback: 0) : null,
      budgetMax:
          data['budgetMax'] != null ? _safeInt(data['budgetMax'], fallback: 0) : null,
      style: data['style'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'likes': likes,
      'dislikes': dislikes,
      'taboo': taboo,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'style': style,
    };
  }

  bool get isEmpty =>
      likes.isEmpty &&
      dislikes.isEmpty &&
      taboo.isEmpty &&
      budgetMin == null &&
      budgetMax == null &&
      (style == null || style!.trim().isEmpty);
}

/// 선물 히스토리
class GiftHistoryItem {
  final String id;
  final String itemName;
  final DateTime? giftedAt;
  final int? reactionScore; // 1~5
  final String? note;

  GiftHistoryItem({
    required this.id,
    required this.itemName,
    this.giftedAt,
    this.reactionScore,
    this.note,
  });

  factory GiftHistoryItem.fromMap(Map<String, dynamic> data) {
    return GiftHistoryItem(
      id: data['id'] ?? '',
      itemName: data['itemName'] ?? '',
      giftedAt: (data['giftedAt'] as Timestamp?)?.toDate(),
      reactionScore: data['reactionScore'] != null
          ? _safeInt(data['reactionScore'], fallback: 0)
          : null,
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'giftedAt': giftedAt != null ? Timestamp.fromDate(giftedAt!) : null,
      'reactionScore': reactionScore,
      'note': note,
    };
  }
}

/// AI 어시스턴트 요약 스냅샷
class PersonAssistantSnapshot {
  final int? score;
  final String? summary;
  final List<String> recommendations;
  final double? confidence;
  final DateTime? generatedAt;

  const PersonAssistantSnapshot({
    this.score,
    this.summary,
    this.recommendations = const [],
    this.confidence,
    this.generatedAt,
  });

  factory PersonAssistantSnapshot.fromMap(Map<String, dynamic> data) {
    return PersonAssistantSnapshot(
      score: data['score'] != null ? _safeInt(data['score'], fallback: 0) : null,
      summary: data['summary'],
      recommendations: List<String>.from(data['recommendations'] ?? const []),
      confidence: (data['confidence'] as num?)?.toDouble(),
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'summary': summary,
      'recommendations': recommendations,
      'confidence': confidence,
      'generatedAt':
          generatedAt != null ? Timestamp.fromDate(generatedAt!) : null,
    };
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

  // 초개인화 챙김 필드
  final int? carePriority; // 0~100
  final DateTime? lastContactAt;
  final DateTime? lastCareActionAt;
  final DateTime? nextCareDueAt;
  final String? lifeContextSummary; // 예: 어머님이 아프심
  final List<PersonLifeEvent> lifeEvents;
  final GiftPreference? giftPreference;
  final List<GiftHistoryItem> giftHistory;
  final PersonAssistantSnapshot? assistantSnapshot;

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
    this.carePriority,
    this.lastContactAt,
    this.lastCareActionAt,
    this.nextCareDueAt,
    this.lifeContextSummary,
    this.lifeEvents = const [],
    this.giftPreference,
    this.giftHistory = const [],
    this.assistantSnapshot,
    this.customFields = const {},
    this.tags = const [],
    required this.createdAt,
    required this.createdBy,
  });

  factory Person.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final giftPreferenceRaw = data['giftPreference'];
    final assistantRaw = data['assistantSnapshot'];

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
      carePriority:
          data['carePriority'] != null ? _safeInt(data['carePriority'], fallback: 0) : null,
      lastContactAt: (data['lastContactAt'] as Timestamp?)?.toDate(),
      lastCareActionAt: (data['lastCareActionAt'] as Timestamp?)?.toDate(),
      nextCareDueAt: (data['nextCareDueAt'] as Timestamp?)?.toDate(),
      lifeContextSummary: data['lifeContextSummary'],
      lifeEvents: (data['lifeEvents'] as List<dynamic>?)
              ?.map((e) => PersonLifeEvent.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      giftPreference: giftPreferenceRaw is Map<String, dynamic>
          ? GiftPreference.fromMap(giftPreferenceRaw)
          : null,
      giftHistory: (data['giftHistory'] as List<dynamic>?)
              ?.map((e) => GiftHistoryItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      assistantSnapshot: assistantRaw is Map<String, dynamic>
          ? PersonAssistantSnapshot.fromMap(assistantRaw)
          : null,
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
      'carePriority': carePriority,
      'lastContactAt':
          lastContactAt != null ? Timestamp.fromDate(lastContactAt!) : null,
      'lastCareActionAt': lastCareActionAt != null
          ? Timestamp.fromDate(lastCareActionAt!)
          : null,
      'nextCareDueAt':
          nextCareDueAt != null ? Timestamp.fromDate(nextCareDueAt!) : null,
      'lifeContextSummary': lifeContextSummary,
      'lifeEvents': lifeEvents.map((e) => e.toMap()).toList(),
      'giftPreference': giftPreference?.toMap(),
      'giftHistory': giftHistory.map((e) => e.toMap()).toList(),
      'assistantSnapshot': assistantSnapshot?.toMap(),
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
    int? carePriority,
    DateTime? lastContactAt,
    DateTime? lastCareActionAt,
    DateTime? nextCareDueAt,
    String? lifeContextSummary,
    List<PersonLifeEvent>? lifeEvents,
    GiftPreference? giftPreference,
    List<GiftHistoryItem>? giftHistory,
    PersonAssistantSnapshot? assistantSnapshot,
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
      carePriority: carePriority ?? this.carePriority,
      lastContactAt: lastContactAt ?? this.lastContactAt,
      lastCareActionAt: lastCareActionAt ?? this.lastCareActionAt,
      nextCareDueAt: nextCareDueAt ?? this.nextCareDueAt,
      lifeContextSummary: lifeContextSummary ?? this.lifeContextSummary,
      lifeEvents: lifeEvents ?? this.lifeEvents,
      giftPreference: giftPreference ?? this.giftPreference,
      giftHistory: giftHistory ?? this.giftHistory,
      assistantSnapshot: assistantSnapshot ?? this.assistantSnapshot,
      customFields: customFields ?? this.customFields,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// 다가오는 생일까지 남은 일수
  /// Feb 29 생일인 경우 비윤년에는 Feb 28로 처리
  int? get daysUntilBirthday {
    if (birthday == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextBirthday = _birthdayInYear(now.year);
    if (nextBirthday.isBefore(today)) {
      nextBirthday = _birthdayInYear(now.year + 1);
    }
    return nextBirthday.difference(today).inDays;
  }

  /// 특정 연도에서의 생일 날짜 계산
  /// Feb 29 생일이면서 해당 연도가 윤년이 아닌 경우 Feb 28 반환
  DateTime _birthdayInYear(int year) {
    if (birthday!.month == 2 && birthday!.day == 29) {
      final isLeapYear =
          (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return DateTime(year, 2, isLeapYear ? 29 : 28);
    }
    return DateTime(year, birthday!.month, birthday!.day);
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
    'ISTJ',
    'ISFJ',
    'INFJ',
    'INTJ',
    'ISTP',
    'ISFP',
    'INFP',
    'INTP',
    'ESTP',
    'ESFP',
    'ENFP',
    'ENTP',
    'ESTJ',
    'ESFJ',
    'ENFJ',
    'ENTJ',
  ];
}

int _safeInt(dynamic raw, {required int fallback}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw') ?? fallback;
}
