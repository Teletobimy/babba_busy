import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/person.dart';
import 'auth_provider.dart';
import 'group_provider.dart';
import '../services/contact_import_service.dart';

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

  /// 사람 여러 명 추가 (batch)
  Future<void> addPeople(List<Person> people) async {
    if (people.isEmpty) return;

    final membership = _ref.read(currentMembershipProvider);
    final user = _ref.read(currentUserProvider);
    final firestore = _firestore;
    if (membership == null || user == null || firestore == null) return;

    final peopleCollection = firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('people');

    const batchLimit = 500;
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

      await batch.commit();
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
  return ref.watch(peopleProvider).value ?? [];
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
