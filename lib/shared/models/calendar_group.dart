import 'package:cloud_firestore/cloud_firestore.dart';

/// 캘린더 그룹 타입
enum CalendarGroupType {
  personal, // 개인 일정
  family,   // 가족 공유
  friends,  // 친구 그룹
  work,     // 직장/업무
  other,    // 기타
}

/// 캘린더 그룹 모델
/// 개인 캘린더, 가족 공유 캘린더, 친구 그룹 캘린더 등을 구분
class CalendarGroup {
  final String id;
  final String name;
  final CalendarGroupType type;
  final String color; // Hex color code
  final List<String> memberIds; // 그룹에 속한 멤버 ID 목록
  final String ownerId; // 그룹 생성자
  final bool isDefault; // 기본 캘린더 여부
  final DateTime createdAt;

  CalendarGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.memberIds,
    required this.ownerId,
    this.isDefault = false,
    required this.createdAt,
  });

  factory CalendarGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarGroup(
      id: doc.id,
      name: data['name'] ?? '',
      type: CalendarGroupType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => CalendarGroupType.other,
      ),
      color: data['color'] ?? '#7C83FD',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      ownerId: data['ownerId'] ?? '',
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'color': color,
      'memberIds': memberIds,
      'ownerId': ownerId,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  CalendarGroup copyWith({
    String? id,
    String? name,
    CalendarGroupType? type,
    String? color,
    List<String>? memberIds,
    String? ownerId,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return CalendarGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      memberIds: memberIds ?? this.memberIds,
      ownerId: ownerId ?? this.ownerId,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 타입에 따른 아이콘 이름 반환 (Iconsax용)
  String get iconName {
    switch (type) {
      case CalendarGroupType.personal:
        return 'user';
      case CalendarGroupType.family:
        return 'home';
      case CalendarGroupType.friends:
        return 'people';
      case CalendarGroupType.work:
        return 'briefcase';
      case CalendarGroupType.other:
        return 'calendar';
    }
  }

  /// 타입에 따른 한글 라벨
  String get typeLabel {
    switch (type) {
      case CalendarGroupType.personal:
        return '개인';
      case CalendarGroupType.family:
        return '가족';
      case CalendarGroupType.friends:
        return '친구';
      case CalendarGroupType.work:
        return '업무';
      case CalendarGroupType.other:
        return '기타';
    }
  }
}
