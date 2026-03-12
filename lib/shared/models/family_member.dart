import 'package:cloud_firestore/cloud_firestore.dart';

/// 가족 구성원 모델
class FamilyMember {
  final String id;
  final String familyId;
  final String name;
  final String email;
  final String color;
  final String? avatarUrl;
  final String role; // 'admin' or 'member'
  final DateTime createdAt;
  final String avatarType; // 'color' | 'emoji' | 'image'
  final String? avatarEmoji;
  final String? statusMessage;
  final DateTime? statusUpdatedAt;

  FamilyMember({
    required this.id,
    required this.familyId,
    required this.name,
    required this.email,
    required this.color,
    this.avatarUrl,
    required this.role,
    required this.createdAt,
    this.avatarType = 'color',
    this.avatarEmoji,
    this.statusMessage,
    this.statusUpdatedAt,
  });

  factory FamilyMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyMember(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      color: data['color'] ?? '#FFCBA4',
      avatarUrl: data['avatarUrl'],
      role: data['role'] ?? 'member',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      avatarType: data['avatarType'] ?? 'color',
      avatarEmoji: data['avatarEmoji'],
      statusMessage: data['statusMessage'],
      statusUpdatedAt: (data['statusUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'name': name,
      'email': email,
      'color': color,
      'avatarUrl': avatarUrl,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'avatarType': avatarType,
      'avatarEmoji': avatarEmoji,
      'statusMessage': statusMessage,
      'statusUpdatedAt': statusUpdatedAt != null ? Timestamp.fromDate(statusUpdatedAt!) : null,
    };
  }

  FamilyMember copyWith({
    String? id,
    String? familyId,
    String? name,
    String? email,
    String? color,
    String? avatarUrl,
    String? role,
    DateTime? createdAt,
    String? avatarType,
    String? avatarEmoji,
    String? statusMessage,
    DateTime? statusUpdatedAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      email: email ?? this.email,
      color: color ?? this.color,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      avatarType: avatarType ?? this.avatarType,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      statusMessage: statusMessage ?? this.statusMessage,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
    );
  }
}
