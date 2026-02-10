import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analysis_job.dart';
import 'auth_provider.dart';

/// 사용자의 진행 중인 분석 작업 목록 StreamProvider
final pendingAnalysisJobsProvider = StreamProvider<List<AnalysisJob>>((ref) {
  final userId = ref.watch(currentUserProvider)?.uid;
  final firestore = ref.watch(firestoreProvider);

  if (userId == null || firestore == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('analysis_jobs')
      .where('userId', isEqualTo: userId)
      .where('status', whereIn: ['pending', 'processing'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => AnalysisJob.fromFirestore(doc)).toList(),
      );
});

/// 사용자의 모든 분석 작업 목록 StreamProvider (최근 50개)
final allAnalysisJobsProvider = StreamProvider<List<AnalysisJob>>((ref) {
  final userId = ref.watch(currentUserProvider)?.uid;
  final firestore = ref.watch(firestoreProvider);

  if (userId == null || firestore == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('analysis_jobs')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => AnalysisJob.fromFirestore(doc)).toList(),
      );
});

/// 특정 분석 작업 실시간 StreamProvider
final analysisJobProvider = StreamProvider.family<AnalysisJob?, String>((
  ref,
  jobId,
) {
  final firestore = ref.watch(firestoreProvider);

  if (firestore == null) {
    return Stream.value(null);
  }

  return firestore
      .collection('analysis_jobs')
      .doc(jobId)
      .snapshots()
      .map((doc) => doc.exists ? AnalysisJob.fromFirestore(doc) : null);
});

/// 진행 중인 사업 검토 작업이 있는지 확인
final hasPendingBusinessJobProvider = Provider<bool>((ref) {
  final pendingJobs = ref.watch(pendingAnalysisJobsProvider);
  return pendingJobs.when(
    data: (jobs) =>
        jobs.any((job) => job.jobType == AnalysisJobType.businessReview),
    loading: () => true,
    error: (_, __) => false,
  );
});

/// 진행 중인 심리검사 작업이 있는지 확인
final hasPendingPsychologyJobProvider = Provider<bool>((ref) {
  final pendingJobs = ref.watch(pendingAnalysisJobsProvider);
  return pendingJobs.when(
    data: (jobs) =>
        jobs.any((job) => job.jobType == AnalysisJobType.psychologyTest),
    loading: () => true,
    error: (_, __) => false,
  );
});

/// AnalysisJobService Provider
final analysisJobServiceProvider = Provider<AnalysisJobService>((ref) {
  return AnalysisJobService(ref);
});

/// 분석 작업 서비스
class AnalysisJobService {
  final Ref _ref;

  AnalysisJobService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  /// 작업 취소
  Future<bool> cancelJob(String jobId) async {
    if (_firestore == null) return false;

    try {
      final docRef = _firestore!.collection('analysis_jobs').doc(jobId);
      final doc = await docRef.get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final status = data['status'];

      // 이미 완료되었거나 실패한 작업은 취소 불가
      if (status == 'completed' || status == 'failed') {
        return false;
      }

      await docRef.update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 작업 상태 조회
  Future<AnalysisJob?> getJob(String jobId) async {
    if (_firestore == null) return null;

    try {
      final doc = await _firestore!
          .collection('analysis_jobs')
          .doc(jobId)
          .get();
      if (doc.exists) {
        return AnalysisJob.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 진행 중인 작업 수 조회
  Future<int> getPendingJobsCount() async {
    if (_userId == null || _firestore == null) return 0;

    try {
      final snapshot = await _firestore!
          .collection('analysis_jobs')
          .where('userId', isEqualTo: _userId)
          .where('status', whereIn: ['pending', 'processing'])
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
