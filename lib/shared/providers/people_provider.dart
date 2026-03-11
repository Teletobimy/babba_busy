import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/person.dart';
import 'auth_provider.dart';
import 'group_provider.dart';
import '../services/contact_import_service.dart';
import '../utils/people_care_assistant.dart';

/// 실제 Firebase에서 가져오는 사람 목록 Provider
final peopleProvider = StreamProvider<List<Person>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('people')
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Person.fromFirestore(doc)).toList(),
      );
});

/// People 서비스
final peopleServiceProvider = Provider<PeopleService>(
  (ref) => PeopleService(ref),
);

/// 연락처 가져오기 서비스 Provider
final contactImportServiceProvider = Provider<ContactImportService>((ref) {
  return createContactImportService();
});

class PeopleService {
  final Ref _ref;
  PeopleService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  /// 사람 추가
  Future<void> addPerson(Person person) async {
    final membership = _ref.read(currentMembershipProvider);
    final user = _ref.read(currentUserProvider);
    final firestore = _firestore;
    if (membership == null || user == null || firestore == null) return;

    final newPerson = person.copyWith(
      familyId: membership.groupId,
      createdBy: user.uid,
      createdAt: DateTime.now(),
    );

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('people')
        .add(newPerson.toFirestore());
  }

  /// 사람 여러 명 추가 (Firestore WriteBatch 사용)
  ///
  /// Firestore WriteBatch는 최대 500개의 쓰기 작업만 허용하므로,
  /// [people] 목록을 500개 단위로 분할하여 순차적으로 커밋합니다.
  /// 중간 배치 실패 시 이미 커밋된 배치는 롤백되지 않으므로,
  /// 호출부에서 부분 실패를 인지하고 적절히 안내해야 합니다.
  ///
  /// Throws: FirebaseException 등 Firestore 관련 예외가 발생할 수 있음.
  Future<void> addPeople(List<Person> people) async {
    if (people.isEmpty) return;

    final membership = _ref.read(currentMembershipProvider);
    final user = _ref.read(currentUserProvider);
    final firestore = _firestore;
    if (membership == null || user == null || firestore == null) {
      throw StateError('인증되지 않았거나 그룹이 선택되지 않았습니다.');
    }

    final peopleCollection = firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('people');

    // Firestore WriteBatch 제한: 최대 500개 작업/배치
    const batchLimit = 500;
    var committedCount = 0;

    for (var i = 0; i < people.length; i += batchLimit) {
      final end = (i + batchLimit < people.length)
          ? i + batchLimit
          : people.length;
      final batch = firestore.batch();

      for (var j = i; j < end; j++) {
        final person = people[j].copyWith(
          familyId: membership.groupId,
          createdBy: user.uid,
          createdAt: DateTime.now(),
        );
        final docRef = peopleCollection.doc();
        batch.set(docRef, person.toFirestore());
      }

      try {
        await batch.commit();
        committedCount += (end - i);
      } catch (e) {
        throw StateError(
          '$committedCount/${people.length}명 저장 후 오류 발생: $e',
        );
      }
    }
  }

  /// 사람 정보 수정
  Future<void> updatePerson(Person person) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('people')
        .doc(person.id)
        .update(person.toFirestore());
  }

  /// 사람 삭제
  Future<void> deletePerson(String personId) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('people')
        .doc(personId)
        .delete();
  }

  /// 태그 추가
  Future<void> addTag(String personId, String tag) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('people')
        .doc(personId)
        .update({
          'tags': FieldValue.arrayUnion([tag]),
        });
  }

  /// 태그 제거
  Future<void> removeTag(String personId, String tag) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('people')
        .doc(personId)
        .update({
          'tags': FieldValue.arrayRemove([tag]),
        });
  }
}

/// 스마트 사람 목록 Provider
final smartPeopleProvider = Provider<List<Person>>((ref) {
  final peopleAsync = ref.watch(peopleProvider);
  if (peopleAsync.hasError) {
    debugPrint('[smartPeopleProvider] Error: ${peopleAsync.error}');
  }
  return peopleAsync.value ?? [];
});

/// 관계별 사람 목록
final peopleByRelationshipProvider = Provider.family<List<Person>, String?>((
  ref,
  relationship,
) {
  final people = ref.watch(smartPeopleProvider);
  if (relationship == null) return people;
  return people.where((p) => p.relationship == relationship).toList();
});

/// 다가오는 생일 목록 (30일 이내)
final upcomingBirthdaysProvider = Provider<List<Person>>((ref) {
  final people = ref.watch(smartPeopleProvider);
  return people
      .where((p) => p.birthday != null && (p.daysUntilBirthday ?? 999) <= 30)
      .toList()
    ..sort(
      (a, b) =>
          (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999),
    );
});

/// 검색된 사람 목록
final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredPeopleProvider = Provider<List<Person>>((ref) {
  final people = ref.watch(smartPeopleProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  if (query.isEmpty) return people;

  return people.where((p) {
    return p.name.toLowerCase().contains(query) ||
        (p.phone?.contains(query) ?? false) ||
        (p.company?.toLowerCase().contains(query) ?? false) ||
        p.tags.any((tag) => tag.toLowerCase().contains(query));
  }).toList();
});

/// 선택된 관계 필터
final selectedRelationshipFilterProvider = StateProvider<String?>(
  (ref) => null,
);

/// 필터링된 사람 목록 (검색 + 관계)
final displayPeopleProvider = Provider<List<Person>>((ref) {
  final filtered = ref.watch(filteredPeopleProvider);
  final relationship = ref.watch(selectedRelationshipFilterProvider);

  if (relationship == null) return filtered;
  return filtered.where((p) => p.relationship == relationship).toList();
});

/// 챙김 우선순위 대상 목록 (전체 기준)
final peopleCareTargetsProvider = Provider<List<PeopleCareTarget>>((ref) {
  final people = ref.watch(smartPeopleProvider);
  if (people.isEmpty) return const [];
  return buildTopCareTargets(people, limit: people.length);
});

/// 상위 챙김 대상 TOP 3
final topCareTargetsProvider = Provider<List<PeopleCareTarget>>((ref) {
  final targets = ref.watch(peopleCareTargetsProvider);
  if (targets.isEmpty) return const [];
  return targets.take(3).toList();
});

/// 특정 사람의 챙김 타깃 정보
final personCareTargetProvider = Provider.family<PeopleCareTarget?, String>((
  ref,
  personId,
) {
  final targets = ref.watch(peopleCareTargetsProvider);
  for (final target in targets) {
    if (target.person.id == personId) return target;
  }
  return null;
});
