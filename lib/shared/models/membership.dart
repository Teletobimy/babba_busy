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
  final DateTime joinedAt;

  Membership({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.groupName,
    required this.name,
    required this.color,
    required this.role,
    required this.joinedAt,
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
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'groupId': groupId,
      'groupName': groupName,
      'name': name,
      'color': color,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
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
    DateTime? joinedAt,
  }) {
    return Membership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      name: name ?? this.name,
      color: color ?? this.color,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
