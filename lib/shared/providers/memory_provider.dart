import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memory.dart';
import 'auth_provider.dart';

/// 추억 목록 스트림
final memoriesProvider = StreamProvider<List<Memory>>((ref) {
  final member = ref.watch(currentMemberProvider).value;
  final firestore = ref.watch(firestoreProvider);
  if (member == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(member.familyId)
      .collection('memories')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Memory.fromFirestore(doc)).toList());
});

/// 카테고리별 추억 목록
final memoriesByCategoryProvider = 
    Provider.family<List<Memory>, String?>((ref, category) {
  final memories = ref.watch(memoriesProvider).value ?? [];
  if (category == null || category.isEmpty) return memories;
  return memories.where((m) => m.category == category).toList();
});

/// 특정 추억의 댓글 목록
final memoryCommentsProvider = 
    StreamProvider.family<List<MemoryComment>, String>((ref, memoryId) {
  final member = ref.watch(currentMemberProvider).value;
  final firestore = ref.watch(firestoreProvider);
  if (member == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(member.familyId)
      .collection('memories')
      .doc(memoryId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => MemoryComment.fromFirestore(doc)).toList());
});

/// 추억 서비스
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService(ref);
});

class MemoryService {
  final Ref _ref;

  MemoryService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String? get _familyId => _ref.read(currentMemberProvider).value?.familyId;
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  CollectionReference? get _memoriesRef {
    if (_familyId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_familyId).collection('memories');
  }

  /// 추억 추가
  Future<String?> addMemory({
    required String title,
    String? description,
    required double latitude,
    required double longitude,
    required String placeName,
    required String category,
    required DateTime date,
    required List<String> photoUrls,
  }) async {
    final memoriesRef = _memoriesRef;
    if (memoriesRef == null || _userId == null) return null;

    final docRef = await memoriesRef.add({
      'familyId': _familyId,
      'title': title,
      'description': description,
      'location': {'lat': latitude, 'lng': longitude},
      'placeName': placeName,
      'category': category,
      'date': Timestamp.fromDate(date),
      'photoUrls': photoUrls,
      'createdBy': _userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// 추억 수정
  Future<void> updateMemory(String memoryId, {
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? placeName,
    String? category,
    DateTime? date,
    List<String>? photoUrls,
  }) async {
    final memoriesRef = _memoriesRef;
    if (memoriesRef == null) return;
    
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (latitude != null && longitude != null) {
      updates['location'] = {'lat': latitude, 'lng': longitude};
    }
    if (placeName != null) updates['placeName'] = placeName;
    if (category != null) updates['category'] = category;
    if (date != null) updates['date'] = Timestamp.fromDate(date);
    if (photoUrls != null) updates['photoUrls'] = photoUrls;

    if (updates.isNotEmpty) {
      await memoriesRef.doc(memoryId).update(updates);
    }
  }

  /// 추억 삭제
  Future<void> deleteMemory(String memoryId) async {
    final memoriesRef = _memoriesRef;
    if (memoriesRef == null) return;
    await memoriesRef.doc(memoryId).delete();
  }

  /// 댓글 추가
  Future<void> addComment(String memoryId, String text) async {
    final memoriesRef = _memoriesRef;
    if (memoriesRef == null || _userId == null) return;

    await memoriesRef.doc(memoryId).collection('comments').add({
      'memoryId': memoryId,
      'userId': _userId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 댓글 삭제
  Future<void> deleteComment(String memoryId, String commentId) async {
    final memoriesRef = _memoriesRef;
    if (memoriesRef == null) return;
    await memoriesRef.doc(memoryId).collection('comments').doc(commentId).delete();
  }
}

/// 추억 카테고리
class MemoryCategory {
  static const String travel = 'travel';
  static const String food = 'food';
  static const String daily = 'daily';
  static const String special = 'special';

  static const Map<String, String> labels = {
    travel: '여행',
    food: '맛집',
    daily: '일상',
    special: '특별한 날',
  };

  static String getLabel(String category) {
    return labels[category] ?? '기타';
  }

  static List<String> get all => [travel, food, daily, special];
}
