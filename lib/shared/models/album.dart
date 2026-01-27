import 'package:cloud_firestore/cloud_firestore.dart';

/// 앨범 타입
enum AlbumType {
  kids('kids', '아이'),
  family('family', '가족'),
  event('event', '행사'),
  moment('moment', '일상');

  final String value;
  final String label;
  const AlbumType(this.value, this.label);

  static AlbumType fromValue(String value) {
    return AlbumType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AlbumType.moment,
    );
  }

  static List<AlbumType> get all => AlbumType.values;
}

/// 앨범 가시성
enum AlbumVisibility {
  private('private'),
  shared('shared');

  final String value;
  const AlbumVisibility(this.value);

  static AlbumVisibility fromValue(String value) {
    return AlbumVisibility.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AlbumVisibility.private,
    );
  }
}

/// 앨범 모델
/// Memory를 대체하며 멀티 그룹 공유를 지원합니다
class Album {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final List<String> photoUrls;
  final String createdBy;
  final DateTime createdAt;

  // 멀티 그룹 공유
  final List<String> sharedGroups; // 공유된 그룹 ID 목록
  final AlbumVisibility visibility;

  // 앨범 분류
  final AlbumType albumType;

  // 선택적 위치 정보
  final bool hasLocation;
  final double? latitude;
  final double? longitude;
  final String? placeName;

  // 메타데이터
  final List<String> participants; // 앨범에 나오는 사람 ID
  final List<String> tags; // 태그 목록

  Album({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.photoUrls,
    required this.createdBy,
    required this.createdAt,
    required this.sharedGroups,
    this.visibility = AlbumVisibility.private,
    this.albumType = AlbumType.moment,
    this.hasLocation = false,
    this.latitude,
    this.longitude,
    this.placeName,
    this.participants = const [],
    this.tags = const [],
  });

  factory Album.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Album(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sharedGroups: List<String>.from(data['sharedGroups'] ?? []),
      visibility: AlbumVisibility.fromValue(data['visibility'] ?? 'private'),
      albumType: AlbumType.fromValue(data['albumType'] ?? 'moment'),
      hasLocation: data['hasLocation'] ?? false,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      placeName: data['placeName'],
      participants: List<String>.from(data['participants'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'photoUrls': photoUrls,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'sharedGroups': sharedGroups,
      'visibility': visibility.value,
      'albumType': albumType.value,
      'hasLocation': hasLocation,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'participants': participants,
      'tags': tags,
    };
  }

  Album copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    List<String>? photoUrls,
    String? createdBy,
    DateTime? createdAt,
    List<String>? sharedGroups,
    AlbumVisibility? visibility,
    AlbumType? albumType,
    bool? hasLocation,
    double? latitude,
    double? longitude,
    String? placeName,
    List<String>? participants,
    List<String>? tags,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      photoUrls: photoUrls ?? this.photoUrls,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      sharedGroups: sharedGroups ?? this.sharedGroups,
      visibility: visibility ?? this.visibility,
      albumType: albumType ?? this.albumType,
      hasLocation: hasLocation ?? this.hasLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      participants: participants ?? this.participants,
      tags: tags ?? this.tags,
    );
  }

  /// 특정 그룹에 공유되어 있는지 확인
  bool isSharedWith(String groupId) {
    return sharedGroups.contains(groupId);
  }

  /// 특정 사용자가 소유자인지 확인
  bool isOwnedBy(String userId) {
    return createdBy == userId;
  }
}

/// 앨범 댓글 모델
class AlbumComment {
  final String id;
  final String albumId;
  final String userId;
  final String text;
  final DateTime createdAt;

  AlbumComment({
    required this.id,
    required this.albumId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory AlbumComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlbumComment(
      id: doc.id,
      albumId: data['albumId'] ?? '',
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'albumId': albumId,
      'userId': userId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
