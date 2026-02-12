import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 전체 커뮤니티 목록 (최신 갱신순)
final communitiesProvider = StreamProvider<List<CommunitySpace>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  if (firestore == null) return Stream.value(const []);

  return firestore
      .collection('communities')
      .orderBy('updatedAt', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => CommunitySpace.fromFirestore(doc))
            .toList(),
      );
});

/// 단일 커뮤니티
final communityProvider = StreamProvider.family<CommunitySpace?, String>((
  ref,
  communityId,
) {
  final firestore = ref.watch(firestoreProvider);
  if (firestore == null || communityId.isEmpty) {
    return Stream.value(null);
  }

  return firestore.collection('communities').doc(communityId).snapshots().map((
    doc,
  ) {
    if (!doc.exists) return null;
    return CommunitySpace.fromFirestore(doc);
  });
});

/// 커뮤니티 게시글 목록
final communityPostsProvider =
    StreamProvider.family<List<CommunityPost>, String>((ref, communityId) {
      final firestore = ref.watch(firestoreProvider);
      if (firestore == null || communityId.isEmpty) {
        return Stream.value(const []);
      }

      return firestore
          .collection('communities')
          .doc(communityId)
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CommunityPost.fromFirestore(doc))
                .toList(),
          );
    });

/// 게시글 댓글 목록
final communityCommentsProvider =
    StreamProvider.family<
      List<CommunityComment>,
      ({String communityId, String postId})
    >((ref, params) {
      final firestore = ref.watch(firestoreProvider);
      if (firestore == null ||
          params.communityId.isEmpty ||
          params.postId.isEmpty) {
        return Stream.value(const []);
      }

      return firestore
          .collection('communities')
          .doc(params.communityId)
          .collection('posts')
          .doc(params.postId)
          .collection('comments')
          .orderBy('createdAt')
          .limit(500)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CommunityComment.fromFirestore(doc))
                .toList(),
          );
    });

final communityServiceProvider = Provider<CommunityService>(
  (ref) => CommunityService(ref),
);

class CommunityService {
  final Ref _ref;

  CommunityService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String _resolveAuthorName() {
    final membershipName =
        _ref.read(currentMembershipProvider)?.name.trim() ?? '';
    if (membershipName.isNotEmpty) return membershipName;

    final userDataName = _ref.read(currentUserDataProvider).value?.name.trim();
    if (userDataName != null && userDataName.isNotEmpty) return userDataName;

    final authUser = _ref.read(currentUserProvider);
    final displayName = authUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return authUser?.email?.split('@').first ?? '사용자';
  }

  List<String> _normalizeTags(List<String> tags) {
    final normalized = tags
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    normalized.sort();
    return normalized.take(8).toList();
  }

  Future<String?> createCommunity({
    required String name,
    String description = '',
    List<String> tags = const [],
  }) async {
    final firestore = _firestore;
    final authUser = _ref.read(currentUserProvider);
    if (firestore == null || authUser == null) return null;

    final normalizedName = name.trim();
    final normalizedDescription = description.trim();
    if (normalizedName.length < 2 || normalizedName.length > 50) {
      throw ArgumentError('커뮤니티 이름은 2~50자로 입력해주세요.');
    }
    if (normalizedDescription.length > 300) {
      throw ArgumentError('커뮤니티 설명은 300자 이내로 입력해주세요.');
    }

    final doc = await firestore.collection('communities').add({
      'name': normalizedName,
      'description': normalizedDescription,
      'tags': _normalizeTags(tags),
      'createdBy': authUser.uid,
      'createdByName': _resolveAuthorName(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isArchived': false,
    });

    return doc.id;
  }

  Future<String?> createPost({
    required String communityId,
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final firestore = _firestore;
    final authUser = _ref.read(currentUserProvider);
    if (firestore == null || authUser == null || communityId.isEmpty) {
      return null;
    }

    final normalizedTitle = title.trim();
    final normalizedContent = content.trim();
    if (normalizedTitle.isEmpty || normalizedTitle.length > 120) {
      throw ArgumentError('제목은 1~120자로 입력해주세요.');
    }
    if (normalizedContent.isEmpty || normalizedContent.length > 5000) {
      throw ArgumentError('본문은 1~5000자로 입력해주세요.');
    }

    final postDoc = await firestore
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .add({
          'communityId': communityId,
          'title': normalizedTitle,
          'content': normalizedContent,
          'tags': _normalizeTags(tags),
          'authorId': authUser.uid,
          'authorName': _resolveAuthorName(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    await firestore.collection('communities').doc(communityId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return postDoc.id;
  }

  Future<String?> addComment({
    required String communityId,
    required String postId,
    required String content,
  }) async {
    final firestore = _firestore;
    final authUser = _ref.read(currentUserProvider);
    if (firestore == null ||
        authUser == null ||
        communityId.isEmpty ||
        postId.isEmpty) {
      return null;
    }

    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty || normalizedContent.length > 2000) {
      throw ArgumentError('댓글은 1~2000자로 입력해주세요.');
    }

    final commentDoc = await firestore
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
          'communityId': communityId,
          'postId': postId,
          'content': normalizedContent,
          'authorId': authUser.uid,
          'authorName': _resolveAuthorName(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    return commentDoc.id;
  }

  Future<void> deletePost({
    required String communityId,
    required String postId,
  }) async {
    final firestore = _firestore;
    final authUser = _ref.read(currentUserProvider);
    if (firestore == null || authUser == null) return;

    final postRef = firestore
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .doc(postId);
    final postDoc = await postRef.get();
    if (!postDoc.exists) return;

    final data = postDoc.data() ?? {};
    if (data['authorId'] != authUser.uid) return;

    final comments = await postRef.collection('comments').get();
    final batch = firestore.batch();
    for (final comment in comments.docs) {
      batch.delete(comment.reference);
    }
    batch.delete(postRef);
    await batch.commit();
  }

  Future<void> deleteComment({
    required String communityId,
    required String postId,
    required String commentId,
  }) async {
    final firestore = _firestore;
    final authUser = _ref.read(currentUserProvider);
    if (firestore == null || authUser == null) return;

    final commentRef = firestore
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final commentDoc = await commentRef.get();
    if (!commentDoc.exists) return;

    final data = commentDoc.data() ?? {};
    if (data['authorId'] != authUser.uid) return;
    await commentRef.delete();
  }
}
