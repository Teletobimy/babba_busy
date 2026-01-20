import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_group.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 현재 그룹의 캘린더 그룹 목록
/// 그룹별로 캘린더 그룹이 저장됨 (families/{groupId}/calendar_groups)
final calendarGroupsProvider = StreamProvider<List<CalendarGroup>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('calendar_groups')
      .orderBy('createdAt')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => CalendarGroup.fromFirestore(doc)).toList());
});

/// 캘린더 그룹 서비스
final calendarGroupServiceProvider =
    Provider<CalendarGroupService>((ref) => CalendarGroupService(ref));

class CalendarGroupService {
  final Ref _ref;
  CalendarGroupService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  /// 기본 캘린더 그룹 생성 (그룹 생성 시 호출)
  Future<void> createDefaultCalendarGroups(String groupId) async {
    final user = _ref.read(currentUserProvider);
    final firestore = _firestore;
    if (user == null || firestore == null) return;

    final batch = firestore.batch();
    final collection =
        firestore.collection('families').doc(groupId).collection('calendar_groups');

    // 개인 일정 캘린더
    batch.set(collection.doc(), CalendarGroup(
      id: '',
      name: '내 일정',
      type: CalendarGroupType.personal,
      color: '#7C83FD',
      memberIds: [user.uid],
      ownerId: user.uid,
      isDefault: true,
      createdAt: DateTime.now(),
    ).toFirestore());

    // 가족 공유 캘린더
    batch.set(collection.doc(), CalendarGroup(
      id: '',
      name: '가족',
      type: CalendarGroupType.family,
      color: '#FF9F43',
      memberIds: [], // 모든 그룹 멤버가 볼 수 있음
      ownerId: user.uid,
      isDefault: false,
      createdAt: DateTime.now(),
    ).toFirestore());

    await batch.commit();
  }

  /// 캘린더 그룹 추가
  Future<void> addCalendarGroup(CalendarGroup group) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('calendar_groups')
        .add(group.toFirestore());
  }

  /// 캘린더 그룹 수정
  Future<void> updateCalendarGroup(CalendarGroup group) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('calendar_groups')
        .doc(group.id)
        .update(group.toFirestore());
  }

  /// 캘린더 그룹 삭제
  Future<void> deleteCalendarGroup(String groupId) async {
    final membership = _ref.read(currentMembershipProvider);
    final firestore = _firestore;
    if (membership == null || firestore == null) return;

    await firestore
        .collection('families')
        .doc(membership.groupId)
        .collection('calendar_groups')
        .doc(groupId)
        .delete();
  }
}
