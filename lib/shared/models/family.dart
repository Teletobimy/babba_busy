import 'package:cloud_firestore/cloud_firestore.dart';

/// 가족 그룹 모델
class FamilyGroup {
  final String id;
  final String name;
  final String inviteCode;
  final DateTime createdAt;
  final String? photoUrl;

  FamilyGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    this.photoUrl,
  });

  factory FamilyGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyGroup(
      id: doc.id,
      name: data['name'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'photoUrl': photoUrl,
    };
  }

  FamilyGroup copyWith({
    String? id,
    String? name,
    String? inviteCode,
    DateTime? createdAt,
    String? photoUrl,
  }) {
    return FamilyGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
