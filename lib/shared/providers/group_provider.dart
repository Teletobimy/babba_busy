import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/membership.dart';
import '../models/family.dart';
import 'auth_provider.dart';

/// 그룹 전환 상태 관리
class GroupTransitionState {
  final bool isTransitioning;
  final String? targetGroupId;
  final String? targetGroupName;

  const GroupTransitionState({
    this.isTransitioning = false,
    this.targetGroupId,
    this.targetGroupName,
  });

  GroupTransitionState copyWith({
    bool? isTransitioning,
    String? targetGroupId,
    String? targetGroupName,
  }) {
    return GroupTransitionState(
      isTransitioning: isTransitioning ?? this.isTransitioning,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      targetGroupName: targetGroupName ?? this.targetGroupName,
    );
  }
}

/// 그룹 전환 상태 Provider
final groupTransitionProvider = StateProvider<GroupTransitionState>((ref) {
  return const GroupTransitionState();
});

/// 현재 선택된 그룹 ID
/// FutureProvider 의존성 제거 - 초기화는 initializeSelectedGroup()에서 처리
final selectedGroupIdProvider = StateProvider<String?>((ref) {
  // 사용자의 첫 번째 멤버십의 그룹을 기본값으로 설정
  // FutureProvider watch 제거 - 불필요한 재계산 방지
  final memberships = ref.watch(userMembershipsProvider).value ?? [];
  debugPrint('[selectedGroupIdProvider] 🔍 Recalculating... memberships.length=${memberships.length}');
  if (memberships.isEmpty) {
    debugPrint('[selectedGroupIdProvider] ⚠️ No memberships, returning null');
    return null;
  }

  // 첫 번째 그룹을 기본값으로 (로컬 저장소 값은 initializeSelectedGroup에서 처리)
  final firstGroupId = memberships.first.groupId;
  debugPrint('[selectedGroupIdProvider] 🎯 Returning first group: $firstGroupId');
  return firstGroupId;
});

/// 선택된 그룹 초기화 완료 여부
final selectedGroupInitializedProvider = StateProvider<bool>((ref) => false);

/// 앱 시작 시 로컬 저장소에서 마지막 선택 그룹 복원
/// main.dart 또는 앱 초기화 시점에 한 번만 호출
Future<void> initializeSelectedGroup(WidgetRef ref) async {
  // 이미 초기화되었으면 스킵
  if (ref.read(selectedGroupInitializedProvider)) return;

  final prefs = await SharedPreferences.getInstance();
  final lastSelected = prefs.getString('last_selected_group_id');

  if (lastSelected != null) {
    final memberships = ref.read(userMembershipsProvider).value ?? [];
    if (memberships.any((m) => m.groupId == lastSelected)) {
      ref.read(selectedGroupIdProvider.notifier).state = lastSelected;
    }
  }

  ref.read(selectedGroupInitializedProvider.notifier).state = true;
}

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
  debugPrint('[completeOnboarding] 📝 Marking onboarding as completed...');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('onboarding_status', 'completed');
  ref.read(onboardingCompletedProvider.notifier).state = true;
  debugPrint('[completeOnboarding] ✅ Onboarding marked as completed');
}

/// 그룹 전환 (부드러운 전환 애니메이션 지원)
/// [withTransition]이 true이면 전환 오버레이를 표시하고 지연 후 전환
Future<void> switchGroup(
  dynamic ref,
  String groupId, {
  String? groupName,
  bool withTransition = true,
  Duration transitionDuration = const Duration(milliseconds: 300),
}) async {
  // 현재 그룹과 같으면 무시
  final currentGroupId = ref.read(selectedGroupIdProvider);
  if (currentGroupId == groupId) return;

  if (withTransition) {
    // 전환 상태 시작
    ref.read(groupTransitionProvider.notifier).state = GroupTransitionState(
      isTransitioning: true,
      targetGroupId: groupId,
      targetGroupName: groupName,
    );

    // 전환 애니메이션을 위한 짧은 지연
    await Future.delayed(const Duration(milliseconds: 150));
  }

  // 그룹 ID 변경
  ref.read(selectedGroupIdProvider.notifier).state = groupId;

  // 로컬 저장소에 저장 (비동기로 처리)
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString('last_selected_group_id', groupId);
  });

  if (withTransition) {
    // 데이터 로딩을 위한 추가 지연
    await Future.delayed(transitionDuration);

    // 전환 상태 종료
    ref.read(groupTransitionProvider.notifier).state = const GroupTransitionState();
  }

  debugPrint('[GroupProvider] Switched to group: $groupId');
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
