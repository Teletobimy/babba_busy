import 'package:cloud_firestore/cloud_firestore.dart';

/// 추억 모델
class Memory {
  final String id;
  final String familyId;
  final String title;
  final String? description;
  final double latitude;
  final double longitude;
  final String placeName;
  final String category; // 'travel', 'food', 'daily', 'special'
  final DateTime date;
  final List<String> photoUrls;
  final String createdBy;
  final DateTime createdAt;

  Memory({
    required this.id,
    required this.familyId,
    required this.title,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.category,
    required this.date,
    required this.photoUrls,
    required this.createdBy,
    required this.createdAt,
  });

  factory Memory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>?;
    return Memory(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
      placeName: data['placeName'] ?? '',
      category: data['category'] ?? 'daily',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'title': title,
      'description': description,
      'location': {'lat': latitude, 'lng': longitude},
      'placeName': placeName,
      'category': category,
      'date': Timestamp.fromDate(date),
      'photoUrls': photoUrls,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Memory copyWith({
    String? id,
    String? familyId,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? placeName,
    String? category,
    DateTime? date,
    List<String>? photoUrls,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Memory(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      category: category ?? this.category,
      date: date ?? this.date,
      photoUrls: photoUrls ?? this.photoUrls,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 추억 댓글 모델
class MemoryComment {
  final String id;
  final String memoryId;
  final String userId;
  final String text;
  final DateTime createdAt;

  MemoryComment({
    required this.id,
    required this.memoryId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory MemoryComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemoryComment(
      id: doc.id,
      memoryId: data['memoryId'] ?? '',
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'memoryId': memoryId,
      'userId': userId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
