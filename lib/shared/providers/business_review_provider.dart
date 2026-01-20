import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_review.dart';
import 'auth_provider.dart';

/// 사업 검토 히스토리 StreamProvider
final businessReviewsProvider = StreamProvider<List<BusinessReview>>((ref) {
  final userId = ref.watch(currentUserProvider)?.uid;
  final firestore = ref.watch(firestoreProvider);

  if (userId == null || firestore == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('users')
      .doc(userId)
      .collection('business_reviews')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => BusinessReview.fromFirestore(doc))
          .toList());
});

/// BusinessReviewService Provider
final businessReviewServiceProvider = Provider<BusinessReviewService>((ref) {
  return BusinessReviewService(ref);
});

/// 사업 검토 히스토리 관리 서비스
class BusinessReviewService {
  final Ref _ref;

  BusinessReviewService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  /// 검토 결과 저장
  Future<String?> saveReview(BusinessReview review) async {
    if (_userId == null || _firestore == null) return null;

    try {
      final docRef = await _firestore!
          .collection('users')
          .doc(_userId)
          .collection('business_reviews')
          .add(review.toFirestore());

      return docRef.id;
    } catch (e) {
      // Failed to save business review: $e
      return null;
    }
  }

  /// 검토 결과 삭제
  Future<void> deleteReview(String reviewId) async {
    if (_userId == null || _firestore == null) return;

    try {
      await _firestore!
          .collection('users')
          .doc(_userId)
          .collection('business_reviews')
          .doc(reviewId)
          .delete();
    } catch (e) {
      // Failed to delete business review: $e
    }
  }
}
