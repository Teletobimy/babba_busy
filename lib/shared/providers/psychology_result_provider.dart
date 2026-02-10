import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/psychology_test_result.dart';
import 'auth_provider.dart';

/// 사용자의 모든 검사 결과 스트림
final psychologyResultsProvider = StreamProvider<List<PsychologyTestResult>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('psychology_results')
      .orderBy('completedAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => PsychologyTestResult.fromFirestore(doc))
            .toList(),
      );
});

/// 특정 검사 유형의 결과 목록
final resultsByTypeProvider =
    Provider.family<List<PsychologyTestResult>, String>((ref, testType) {
      final results = ref.watch(psychologyResultsProvider).value ?? [];
      return results.where((r) => r.testType == testType).toList();
    });

/// 특정 검사 유형의 최근 결과
final latestResultByTypeProvider =
    Provider.family<PsychologyTestResult?, String>((ref, testType) {
      final results = ref.watch(resultsByTypeProvider(testType));
      return results.isNotEmpty ? results.first : null;
    });

/// 검사 이력 요약 (각 유형별 최근 결과)
final psychologyHistorySummaryProvider =
    Provider<Map<String, PsychologyTestResult?>>((ref) {
      final summary = <String, PsychologyTestResult?>{};
      for (final type in PsychologyTestType.allTypes) {
        summary[type] = ref.watch(latestResultByTypeProvider(type));
      }
      return summary;
    });

/// 완료한 검사 유형 목록
final completedTestTypesProvider = Provider<Set<String>>((ref) {
  final results = ref.watch(psychologyResultsProvider).value ?? [];
  return results.map((r) => r.testType).toSet();
});

/// 총 검사 횟수
final totalTestCountProvider = Provider<int>((ref) {
  final results = ref.watch(psychologyResultsProvider).value ?? [];
  return results.length;
});

/// 심리검사 서비스
final psychologyResultServiceProvider = Provider<PsychologyResultService>((
  ref,
) {
  return PsychologyResultService(ref);
});

class PsychologyResultService {
  final Ref _ref;

  PsychologyResultService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  CollectionReference? get _resultsRef {
    if (_userId == null || _firestore == null) return null;
    return _firestore!
        .collection('users')
        .doc(_userId)
        .collection('psychology_results');
  }

  /// 검사 결과 저장
  Future<String?> saveResult({
    required String testType,
    required List<int> answers,
    required Map<String, dynamic> result,
    String? familyId,
    bool isShared = false,
  }) async {
    final resultsRef = _resultsRef;
    if (resultsRef == null) return null;

    final docRef = await resultsRef.add({
      'userId': _userId,
      'familyId': familyId,
      'testType': testType,
      'answers': answers,
      'result': result,
      'completedAt': FieldValue.serverTimestamp(),
      'isShared': isShared,
    });

    return docRef.id;
  }

  /// 비동기 분석 결과 저장/업데이트 (sessionId 기반 idempotent)
  Future<void> saveResultFromSession({
    required String sessionId,
    required String testType,
    required Map<String, dynamic> result,
    List<int> answers = const [],
    String? familyId,
    bool isShared = false,
  }) async {
    final resultsRef = _resultsRef;
    if (resultsRef == null) return;

    await resultsRef.doc(sessionId).set({
      'userId': _userId,
      'familyId': familyId,
      'testType': testType,
      'answers': answers,
      'result': result,
      'completedAt': FieldValue.serverTimestamp(),
      'isShared': isShared,
      'sourceSessionId': sessionId,
    }, SetOptions(merge: true));
  }

  /// 검사 결과 삭제
  Future<void> deleteResult(String resultId) async {
    final resultsRef = _resultsRef;
    if (resultsRef == null) return;
    await resultsRef.doc(resultId).delete();
  }

  /// 결과 공유 설정 업데이트
  Future<void> updateSharing(
    String resultId, {
    required bool isShared,
    String? familyId,
  }) async {
    final resultsRef = _resultsRef;
    if (resultsRef == null) return;

    await resultsRef.doc(resultId).update({
      'isShared': isShared,
      'familyId': familyId,
    });
  }
}
