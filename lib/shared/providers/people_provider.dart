import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/person.dart';
import '../../app/router.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 데모 사람 목록
final demoPeopleProvider = Provider<List<Person>>((ref) {
  final now = DateTime.now();
  
  return [
    Person(
      id: 'person1',
      familyId: 'family1',
      name: '김민수',
      birthday: DateTime(1995, 3, 15),
      mbti: 'ENFP',
      phone: '010-1234-5678',
      email: 'minsu@example.com',
      address: '서울시 강남구 역삼동',
      personality: '활발하고 긍정적인 성격. 모임에서 분위기 메이커 역할.',
      relationship: 'friend',
      company: '카카오',
      note: '대학 동기, 같이 창업 동아리 했음',
      tags: ['대학동기', '창업동아리'],
      events: [
        PersonEvent(
          id: 'event1',
          title: '생일',
          date: DateTime(1995, 3, 15),
          isYearly: true,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 100)),
      createdBy: 'member1',
    ),
    Person(
      id: 'person2',
      familyId: 'family1',
      name: '이서연',
      birthday: DateTime(1998, 7, 22),
      mbti: 'INFJ',
      phone: '010-2345-6789',
      address: '서울시 마포구 상암동',
      personality: '조용하지만 깊은 대화를 좋아함. 예술적 감각이 뛰어남.',
      relationship: 'friend',
      company: '넷플릭스 코리아',
      note: '고등학교 친구',
      tags: ['고등학교', '예술'],
      events: [
        PersonEvent(
          id: 'event2',
          title: '생일',
          date: DateTime(1998, 7, 22),
          isYearly: true,
        ),
        PersonEvent(
          id: 'event3',
          title: '우정 기념일',
          date: DateTime(2013, 9, 1),
          isYearly: true,
          note: '같은 반이 된 날',
        ),
      ],
      createdAt: now.subtract(const Duration(days: 200)),
      createdBy: 'member1',
    ),
    Person(
      id: 'person3',
      familyId: 'family1',
      name: '박지훈',
      birthday: DateTime(1990, 11, 8),
      mbti: 'ESTJ',
      phone: '010-3456-7890',
      email: 'jihun.park@company.com',
      address: '서울시 송파구 잠실동',
      personality: '리더십이 강하고 체계적. 약속 시간 철저히 지킴.',
      relationship: 'colleague',
      company: '삼성전자',
      note: '전 직장 팀장님, 멘토',
      tags: ['멘토', '전직장'],
      customFields: {
        '직급': '부장',
        '부서': 'AI연구소',
      },
      createdAt: now.subtract(const Duration(days: 300)),
      createdBy: 'member1',
    ),
    Person(
      id: 'person4',
      familyId: 'family1',
      name: '최유진',
      birthday: DateTime(2000, 1, 30),
      mbti: 'ESFP',
      phone: '010-4567-8901',
      personality: '밝고 사교적. 패션 감각이 좋음.',
      relationship: 'school',
      company: '서울대학교',
      note: '동생 친구, 가끔 집에 놀러옴',
      tags: ['동생친구'],
      createdAt: now.subtract(const Duration(days: 50)),
      createdBy: 'member3',
    ),
    Person(
      id: 'person5',
      familyId: 'family1',
      name: '정현우',
      birthday: DateTime(1988, 5, 5),
      mbti: 'INTP',
      phone: '010-5678-9012',
      email: 'hyunwoo@startup.io',
      address: '경기도 성남시 분당구',
      personality: '분석적이고 논리적. IT에 관심 많음.',
      relationship: 'friend',
      company: '스타트업 대표',
      note: '창업 스터디에서 만남',
      tags: ['창업', 'IT'],
      customFields: {
        '회사명': '테크노바',
        '투자단계': 'Series A',
      },
      createdAt: now.subtract(const Duration(days: 150)),
      createdBy: 'member2',
    ),
    Person(
      id: 'person6',
      familyId: 'family1',
      name: '한소희',
      birthday: DateTime(1992, 9, 18),
      phone: '010-6789-0123',
      personality: '차분하고 배려심 깊음.',
      relationship: 'neighbor',
      address: '같은 아파트 1203호',
      note: '이웃집 아주머니, 가끔 반찬 나눔',
      tags: ['이웃', '반찬나눔'],
      createdAt: now.subtract(const Duration(days: 30)),
      createdBy: 'member1',
    ),
    Person(
      id: 'person7',
      familyId: 'family1',
      name: '김태희',
      birthday: DateTime(1960, 12, 25),
      phone: '010-7890-1234',
      relationship: 'family',
      address: '부산시 해운대구',
      personality: '따뜻하고 자상함.',
      note: '이모, 명절마다 연락',
      tags: ['가족', '부산'],
      events: [
        PersonEvent(
          id: 'event4',
          title: '생일',
          date: DateTime(1960, 12, 25),
          isYearly: true,
        ),
      ],
      createdAt: now.subtract(const Duration(days: 500)),
      createdBy: 'member1',
    ),
    Person(
      id: 'person8',
      familyId: 'family1',
      name: '오승환',
      birthday: DateTime(1993, 4, 12),
      mbti: 'ISTP',
      phone: '010-8901-2345',
      email: 'sh.oh@game.com',
      personality: '과묵하지만 실력있음. 게임 좋아함.',
      relationship: 'colleague',
      company: '넥슨',
      note: '현 직장 동료, 점심 자주 먹음',
      tags: ['직장동료', '게임'],
      createdAt: now.subtract(const Duration(days: 80)),
      createdBy: 'member2',
    ),
  ];
});

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
      .map((snapshot) =>
          snapshot.docs.map((doc) => Person.fromFirestore(doc)).toList());
});

/// People 서비스
final peopleServiceProvider = Provider<PeopleService>((ref) => PeopleService(ref));

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

/// 스마트 사람 목록 Provider (데모/실제 자동 선택)
final smartPeopleProvider = Provider<List<Person>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoPeopleProvider);
  return ref.watch(peopleProvider).value ?? [];
});

/// 관계별 사람 목록
final peopleByRelationshipProvider = Provider.family<List<Person>, String?>((ref, relationship) {
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
    ..sort((a, b) => (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));
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
final selectedRelationshipFilterProvider = StateProvider<String?>((ref) => null);

/// 필터링된 사람 목록 (검색 + 관계)
final displayPeopleProvider = Provider<List<Person>>((ref) {
  final filtered = ref.watch(filteredPeopleProvider);
  final relationship = ref.watch(selectedRelationshipFilterProvider);
  
  if (relationship == null) return filtered;
  return filtered.where((p) => p.relationship == relationship).toList();
});
