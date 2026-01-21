import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_settings.dart';

/// 사용자 모델 (그룹과 독립적인 사용자 정보)
class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? defaultGroupId; // 기본 선택 그룹
  final DateTime createdAt;
  final List<String> fcmTokens; // FCM 토큰 목록 (여러 기기 지원)
  final NotificationSettings notificationSettings; // 알림 설정

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.defaultGroupId,
    required this.createdAt,
    this.fcmTokens = const [],
    this.notificationSettings = const NotificationSettings(),
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'],
      defaultGroupId: data['defaultGroupId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
      notificationSettings: NotificationSettings.fromMap(
        data['notificationSettings'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'defaultGroupId': defaultGroupId,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmTokens': fcmTokens,
      'notificationSettings': notificationSettings.toMap(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? defaultGroupId,
    DateTime? createdAt,
    List<String>? fcmTokens,
    NotificationSettings? notificationSettings,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultGroupId: defaultGroupId ?? this.defaultGroupId,
      createdAt: createdAt ?? this.createdAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }
}
