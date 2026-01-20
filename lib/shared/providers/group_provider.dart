import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/membership.dart';
import '../models/family.dart';
import 'auth_provider.dart';

/// 마지막으로 선택한 그룹 ID를 로컬에 저장/불러오기
final lastSelectedGroupProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('last_selected_group_id');
});

/// 현재 선택된 그룹 ID
final selectedGroupIdProvider = StateProvider<String?>((ref) {
  // 사용자의 첫 번째 멤버십의 그룹을 기본값으로 설정
  final memberships = ref.watch(userMembershipsProvider).value ?? [];
  if (memberships.isEmpty) return null;
  
  // 로컬 저장소에서 불러온 값이 있으면 사용
  final lastSelected = ref.watch(lastSelectedGroupProvider).value;
  if (lastSelected != null && memberships.any((m) => m.groupId == lastSelected)) {
    return lastSelected;
  }
  
  // 없으면 첫 번째 그룹 선택
  return memberships.first.groupId;
});

/// 사용자가 속한 모든 멤버십 목록
final userMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('memberships')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
    final memberships = snapshot.docs.map((doc) => Membership.fromFirestore(doc)).toList();
    // 로컬에서 정렬 (인덱스 생성 전까지 임시 방편)
    memberships.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return memberships;
  });
});

/// 현재 선택된 그룹의 멤버십 정보
final currentMembershipProvider = Provider<Membership?>((ref) {
  final selectedGroupId = ref.watch(selectedGroupIdProvider);
  final memberships = ref.watch(userMembershipsProvider).value ?? [];

  if (selectedGroupId == null || memberships.isEmpty) return null;
  
  try {
    return memberships.firstWhere((m) => m.groupId == selectedGroupId);
  } catch (e) {
    return null;
  }
});

/// 현재 선택된 그룹 정보
final currentGroupProvider = StreamProvider<FamilyGroup?>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value(null);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .snapshots()
      .map((doc) => doc.exists ? FamilyGroup.fromFirestore(doc) : null);
});

/// 현재 그룹의 모든 멤버십 목록
final groupMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('memberships')
      .where('groupId', isEqualTo: membership.groupId)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Membership.fromFirestore(doc)).toList());
});

/// 온보딩 완료 여부 (한 번이라도 봤으면 true)
final onboardingCompletedProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('onboarding_status') == 'completed';
});

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

/// 온보딩 완료 표시
Future<void> completeOnboarding(dynamic ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('onboarding_status', 'completed');
  ref.read(onboardingCompletedProvider.notifier).state = true;
}

/// 그룹 전환
Future<void> switchGroup(dynamic ref, String groupId) async {
  ref.read(selectedGroupIdProvider.notifier).state = groupId;

  // 로컬 저장소에 저장
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_selected_group_id', groupId);
}

/// Membership의 공유 타입 업데이트
Future<void> updateMembershipSharedEventTypes(
  dynamic ref,
  String membershipId,
  List<String> sharedEventTypes,
) async {
  final firestore = ref.read(firestoreProvider);
  if (firestore == null) return;

  await firestore
      .collection('memberships')
      .doc(membershipId)
      .update({'sharedEventTypes': sharedEventTypes});
}
