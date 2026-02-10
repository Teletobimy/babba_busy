import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/album.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 파일 확장자에서 표준 MIME 타입 반환
String _getContentType(String extension) {
  switch (extension.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
    case 'heif':
      return 'image/heif';
    case 'bmp':
      return 'image/bmp';
    default:
      return 'application/octet-stream';
  }
}

/// 앨범 뷰 모드
enum AlbumViewMode {
  timeline('시간순'),
  person('사람별'),
  location('장소별');

  final String label;
  const AlbumViewMode(this.label);
}

/// 뷰 모드 Provider
final albumViewModeProvider = StateProvider<AlbumViewMode>((ref) {
  return AlbumViewMode.timeline;
});

/// 선택된 앨범 타입 필터
final selectedAlbumTypeProvider = StateProvider<AlbumType?>((ref) => null);

/// 선택된 사람 필터 (사람별 보기에서 사용)
final selectedPersonProvider = StateProvider<String?>((ref) => null);

/// 앨범 목록 표시 형식 (그리드/리스트)
final albumDisplayModeProvider = StateProvider<bool>(
  (ref) => true,
); // true = 그리드

/// 사용자의 모든 앨범 스트림 (본인이 만든 앨범)
final userAlbumsProvider = StreamProvider<List<Album>>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('albums')
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Album.fromFirestore(doc)).toList(),
      );
});

/// 현재 그룹에 공유된 앨범 스트림
final sharedAlbumsProvider = StreamProvider<List<Album>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  // collectionGroup을 사용하여 모든 사용자의 앨범 중 현재 그룹에 공유된 것 조회
  return firestore
      .collectionGroup('albums')
      .where('sharedGroups', arrayContains: membership.groupId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Album.fromFirestore(doc)).toList(),
      );
});

/// 통합 앨범 목록 (내 앨범 + 공유된 앨범, 중복 제거)
final combinedAlbumsProvider = Provider<List<Album>>((ref) {
  final userAlbums = ref.watch(userAlbumsProvider).value ?? [];
  final sharedAlbums = ref.watch(sharedAlbumsProvider).value ?? [];

  // 중복 제거 (ID 기준)
  final albumMap = <String, Album>{};
  for (final album in userAlbums) {
    albumMap[album.id] = album;
  }
  for (final album in sharedAlbums) {
    albumMap[album.id] = album;
  }

  final combined = albumMap.values.toList();
  // 날짜순 정렬 (최신순)
  combined.sort((a, b) => b.date.compareTo(a.date));
  return combined;
});

/// 필터링된 앨범 목록
final filteredAlbumsProvider = Provider<List<Album>>((ref) {
  final albums = ref.watch(combinedAlbumsProvider);
  final selectedType = ref.watch(selectedAlbumTypeProvider);
  final selectedPerson = ref.watch(selectedPersonProvider);
  final viewMode = ref.watch(albumViewModeProvider);

  var filtered = albums;

  // 타입 필터
  if (selectedType != null) {
    filtered = filtered.where((a) => a.albumType == selectedType).toList();
  }

  // 사람별 보기에서 사람 필터
  if (viewMode == AlbumViewMode.person && selectedPerson != null) {
    filtered = filtered
        .where((a) => a.participants.contains(selectedPerson))
        .toList();
  }

  // 장소별 보기에서는 위치 있는 것만
  if (viewMode == AlbumViewMode.location) {
    filtered = filtered.where((a) => a.hasLocation).toList();
  }

  return filtered;
});

/// 스마트 앨범 Provider (데모/실제 데이터 자동 전환 용)
final smartAlbumsProvider = Provider<List<Album>>((ref) {
  return ref.watch(filteredAlbumsProvider);
});

/// 타입별 앨범 목록
final albumsByTypeProvider = Provider.family<List<Album>, AlbumType?>((
  ref,
  type,
) {
  final albums = ref.watch(combinedAlbumsProvider);
  if (type == null) return albums;
  return albums.where((a) => a.albumType == type).toList();
});

/// 사람별 앨범 그룹화
final albumsByPersonProvider = Provider<Map<String, List<Album>>>((ref) {
  final albums = ref.watch(combinedAlbumsProvider);
  final groupedAlbums = <String, List<Album>>{};

  for (final album in albums) {
    for (final personId in album.participants) {
      groupedAlbums.putIfAbsent(personId, () => []).add(album);
    }
    // participants가 비어있으면 '기타'에 추가
    if (album.participants.isEmpty) {
      groupedAlbums.putIfAbsent('_other', () => []).add(album);
    }
  }

  return groupedAlbums;
});

/// 장소별 앨범 그룹화
final albumsByLocationProvider = Provider<Map<String, List<Album>>>((ref) {
  final albums = ref.watch(combinedAlbumsProvider);
  final groupedAlbums = <String, List<Album>>{};

  for (final album in albums.where(
    (a) => a.hasLocation && a.placeName != null,
  )) {
    groupedAlbums.putIfAbsent(album.placeName!, () => []).add(album);
  }

  return groupedAlbums;
});

/// 월별 앨범 그룹화 (타임라인 뷰용)
final albumsByMonthProvider = Provider<Map<String, List<Album>>>((ref) {
  final albums = ref.watch(filteredAlbumsProvider);
  final groupedAlbums = <String, List<Album>>{};

  for (final album in albums) {
    final key = '${album.date.year}년 ${album.date.month}월';
    groupedAlbums.putIfAbsent(key, () => []).add(album);
  }

  return groupedAlbums;
});

/// 특정 앨범의 댓글 스트림
final albumCommentsProvider = StreamProvider.family<List<AlbumComment>, String>(
  (ref, albumId) {
    final membership = ref.watch(currentMembershipProvider);
    final firestore = ref.watch(firestoreProvider);
    if (membership == null || firestore == null) return Stream.value([]);

    return firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('album_comments')
        .where('albumId', isEqualTo: albumId)
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map((doc) => AlbumComment.fromFirestore(doc))
              .toList();
          comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return comments;
        });
  },
);

/// 앨범 서비스 Provider
final albumServiceProvider = Provider<AlbumService>((ref) {
  return AlbumService(ref);
});

/// 앨범 서비스
class AlbumService {
  final Ref _ref;

  AlbumService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);
  String? get _userId => _ref.read(currentUserProvider)?.uid;
  String? get _groupId => _ref.read(currentMembershipProvider)?.groupId;

  CollectionReference? get _albumsCollection {
    if (_userId == null || _firestore == null) return null;
    return _firestore!.collection('users').doc(_userId).collection('albums');
  }

  CollectionReference? get _albumCommentsCollection {
    if (_groupId == null || _firestore == null) return null;
    return _firestore!
        .collection('families')
        .doc(_groupId)
        .collection('album_comments');
  }

  /// 앨범 추가
  Future<String?> addAlbum({
    required String title,
    String? description,
    required DateTime date,
    required List<String> photoUrls,
    required List<String> sharedGroups,
    AlbumVisibility visibility = AlbumVisibility.private,
    AlbumType albumType = AlbumType.moment,
    bool hasLocation = false,
    double? latitude,
    double? longitude,
    String? placeName,
    List<String> participants = const [],
    List<String> tags = const [],
  }) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null || _userId == null) return null;

    final docRef = await albumsRef.add({
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'photoUrls': photoUrls,
      'createdBy': _userId,
      'createdAt': FieldValue.serverTimestamp(),
      'sharedGroups': sharedGroups,
      'visibility': visibility.value,
      'albumType': albumType.value,
      'hasLocation': hasLocation,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'participants': participants,
      'tags': tags,
    });

    return docRef.id;
  }

  /// 앨범 수정
  Future<void> updateAlbum(
    String albumId, {
    String? title,
    String? description,
    DateTime? date,
    List<String>? photoUrls,
    List<String>? sharedGroups,
    AlbumVisibility? visibility,
    AlbumType? albumType,
    bool? hasLocation,
    double? latitude,
    double? longitude,
    String? placeName,
    List<String>? participants,
    List<String>? tags,
  }) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (date != null) updates['date'] = Timestamp.fromDate(date);
    if (photoUrls != null) updates['photoUrls'] = photoUrls;
    if (sharedGroups != null) updates['sharedGroups'] = sharedGroups;
    if (visibility != null) updates['visibility'] = visibility.value;
    if (albumType != null) updates['albumType'] = albumType.value;
    if (hasLocation != null) updates['hasLocation'] = hasLocation;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;
    if (placeName != null) updates['placeName'] = placeName;
    if (participants != null) updates['participants'] = participants;
    if (tags != null) updates['tags'] = tags;

    if (updates.isNotEmpty) {
      await albumsRef.doc(albumId).update(updates);
    }
  }

  /// 앨범 삭제
  Future<void> deleteAlbum(String albumId) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;
    await albumsRef.doc(albumId).delete();
  }

  /// 공유 그룹 추가
  Future<void> addSharedGroup(String albumId, String groupId) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;

    await albumsRef.doc(albumId).update({
      'sharedGroups': FieldValue.arrayUnion([groupId]),
      'visibility': AlbumVisibility.shared.value,
    });
  }

  /// 공유 그룹 제거
  Future<void> removeSharedGroup(String albumId, String groupId) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;

    await albumsRef.doc(albumId).update({
      'sharedGroups': FieldValue.arrayRemove([groupId]),
    });
  }

  /// 사진 추가
  Future<void> addPhotos(String albumId, List<String> newPhotoUrls) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;

    await albumsRef.doc(albumId).update({
      'photoUrls': FieldValue.arrayUnion(newPhotoUrls),
    });
  }

  /// 사진 제거
  Future<void> removePhoto(String albumId, String photoUrl) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;

    await albumsRef.doc(albumId).update({
      'photoUrls': FieldValue.arrayRemove([photoUrl]),
    });
  }

  /// 참여자 추가
  Future<void> addParticipant(String albumId, String userId) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;

    await albumsRef.doc(albumId).update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  /// 참여자 제거
  Future<void> removeParticipant(String albumId, String userId) async {
    final albumsRef = _albumsCollection;
    if (albumsRef == null) return;

    await albumsRef.doc(albumId).update({
      'participants': FieldValue.arrayRemove([userId]),
    });
  }

  /// 댓글 추가
  Future<void> addComment(String albumId, String text) async {
    final commentsRef = _albumCommentsCollection;
    if (commentsRef == null || _userId == null) return;

    await commentsRef.add({
      'albumId': albumId,
      'userId': _userId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 댓글 삭제
  Future<void> deleteComment(String albumId, String commentId) async {
    final commentsRef = _albumCommentsCollection;
    if (commentsRef == null) return;
    if (albumId.isEmpty) return;

    await commentsRef.doc(commentId).delete();
  }

  /// 이미지 파일들을 Firebase Storage에 업로드하고 URL 목록 반환
  /// [localPaths] 로컬 파일 경로 목록
  /// [onProgress] 업로드 진행률 콜백 (0.0 ~ 1.0)
  Future<List<String>> uploadPhotos(
    List<String> localPaths, {
    void Function(double progress)? onProgress,
  }) async {
    if (_userId == null) return [];

    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    int completed = 0;

    for (final path in localPaths) {
      StreamSubscription<TaskSnapshot>? progressSubscription;

      try {
        final file = File(path);
        if (!file.existsSync()) continue;

        // 고유한 파일명 생성 (userId/albums/timestamp_index.ext)
        final ext = path.split('.').last.toLowerCase();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${urls.length}.$ext';
        final ref = storage.ref('users/$_userId/albums/$fileName');

        // 표준 MIME 타입으로 업로드
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: _getContentType(ext)),
        );

        // 진행률 콜백 (구독 저장)
        if (onProgress != null) {
          progressSubscription = uploadTask.snapshotEvents.listen((event) {
            final progress =
                (completed + (event.bytesTransferred / event.totalBytes)) /
                localPaths.length;
            onProgress(progress);
          });
        }

        await uploadTask;

        // 구독 취소 (메모리 누수 방지)
        await progressSubscription?.cancel();

        final url = await ref.getDownloadURL();
        urls.add(url);
        completed++;
      } catch (e) {
        // 구독 취소 (에러 시에도)
        await progressSubscription?.cancel();

        // 개별 파일 업로드 실패 시 로그만 남기고 계속 진행
        debugPrint('Failed to upload photo: $path, error: $e');
      }
    }

    return urls;
  }
}
