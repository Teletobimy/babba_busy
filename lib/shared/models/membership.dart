import 'package:cloud_firestore/cloud_firestore.dart';

/// 멤버십 모델 (사용자와 그룹 간의 관계)
class Membership {
  final String id;
  final String userId;
  final String groupId;
  final String groupName; // 캐시된 그룹 이름 (빠른 조회용)
  final String name; // 그룹별 닉네임
  final String color; // 그룹별 색상
  final String role; // 'admin' or 'member'
  final String? avatarUrl; // 사용자 프로필 사진 URL (Google 등)
  final DateTime joinedAt;
  final List<String> sharedEventTypes; // 공유할 일정 타입 ['todo', 'schedule', 'event']
  final String? statusMessage; // 상태 메시지
  final DateTime? statusUpdatedAt; // 상태 메시지 업데이트 시각

  Membership({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.groupName,
    required this.name,
    required this.color,
    required this.role,
    this.avatarUrl,
    required this.joinedAt,
    this.sharedEventTypes = const ['todo', 'schedule', 'event'], // 기본값: 모든 타입 공유
    this.statusMessage,
    this.statusUpdatedAt,
  });

  factory Membership.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Membership(
      id: doc.id,
      userId: data['userId'] ?? '',
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      name: data['name'] ?? '',
      color: data['color'] ?? '#FFCBA4',
      role: data['role'] ?? 'member',
      avatarUrl: data['avatarUrl'],
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sharedEventTypes: _normalizeSharedEventTypes(data['sharedEventTypes']),
      statusMessage: data['statusMessage'],
      statusUpdatedAt: (data['statusUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 하위 호환성: 'personal' -> 'schedule' 변환
  static List<String> _normalizeSharedEventTypes(dynamic types) {
    final list = types != null
        ? List<String>.from(types)
        : ['todo', 'schedule', 'event'];
    // 'personal' -> 'schedule' 변환
    return list.map((t) => t == 'personal' ? 'schedule' : t).toList();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'groupId': groupId,
      'groupName': groupName,
      'name': name,
      'color': color,
      'role': role,
      'avatarUrl': avatarUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'sharedEventTypes': sharedEventTypes,
      'statusMessage': statusMessage,
      'statusUpdatedAt': statusUpdatedAt != null ? Timestamp.fromDate(statusUpdatedAt!) : null,
    };
  }

  Membership copyWith({
    String? id,
    String? userId,
    String? groupId,
    String? groupName,
    String? name,
    String? color,
    String? role,
    String? avatarUrl,
    DateTime? joinedAt,
    List<String>? sharedEventTypes,
    String? statusMessage,
    DateTime? statusUpdatedAt,
  }) {
    return Membership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      name: name ?? this.name,
      color: color ?? this.color,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      sharedEventTypes: sharedEventTypes ?? this.sharedEventTypes,
      statusMessage: statusMessage ?? this.statusMessage,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
    );
  }
}
