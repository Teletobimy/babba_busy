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
/// 초기값 null - initializeSelectedGroup()에서 설정됨
/// ⚠️ StateProvider 내부에서 ref.watch() 사용 금지 (무한 재계산 유발)
final selectedGroupIdProvider = StateProvider<String?>((ref) {
  debugPrint('[selectedGroupIdProvider] 🔧 Created with initial value: null');
  return null;
});

/// 선택된 그룹 초기화 완료 여부
final selectedGroupInitializedProvider = StateProvider<bool>((ref) {
  debugPrint('[selectedGroupInitializedProvider] 🔧 Created with initial value: false');
  return false;
});

/// 앱 시작 시 로컬 저장소에서 마지막 선택 그룹 복원
/// 또는 첫 번째 그룹으로 자동 초기화
/// main.dart 또는 앱 초기화 시점에 한 번만 호출
Future<void> initializeSelectedGroup(WidgetRef ref) async {
  // 이미 초기화되었으면 스킵
  if (ref.read(selectedGroupInitializedProvider)) return;

  final memberships = ref.read(userMembershipsProvider).value ?? [];

  if (memberships.isEmpty) {
    debugPrint('[initializeSelectedGroup] ⚠️ No memberships yet');
    ref.read(selectedGroupInitializedProvider.notifier).state = true;
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final lastSelected = prefs.getString('last_selected_group_id');

  // 로컬 저장소에 저장된 그룹이 유효하면 사용
  if (lastSelected != null && memberships.any((m) => m.groupId == lastSelected)) {
    debugPrint('[initializeSelectedGroup] ✅ Restored last selected group: $lastSelected');
    ref.read(selectedGroupIdProvider.notifier).state = lastSelected;
  } else {
    // 첫 번째 그룹으로 초기화
    final firstGroupId = memberships.first.groupId;
    debugPrint('[initializeSelectedGroup] 🎯 Setting first group: $firstGroupId');
    ref.read(selectedGroupIdProvider.notifier).state = firstGroupId;
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

/// 중복 "나만의 공간" 필터링된 멤버십 목록 (UI 표시용)
/// 가장 오래된 "나만의 공간" 1개만 유지
final filteredUserMembershipsProvider = Provider<AsyncValue<List<Membership>>>((ref) {
  final membershipsAsync = ref.watch(userMembershipsProvider);

  return membershipsAsync.whenData((memberships) {
    // "나만의 공간" 그룹들 중 가장 오래된 것 찾기
    String? oldestMySpaceId;
    DateTime? oldestJoinedAt;

    for (final m in memberships) {
      if (m.groupName == '나만의 공간') {
        if (oldestJoinedAt == null || m.joinedAt.isBefore(oldestJoinedAt)) {
          oldestMySpaceId = m.groupId;
          oldestJoinedAt = m.joinedAt;
        }
      }
    }

    // 중복 "나만의 공간" 제외
    return memberships.where((m) {
      if (m.groupName != '나만의 공간') return true;
      return m.groupId == oldestMySpaceId;
    }).toList();
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
/// userId 기준 중복 제거 (레거시 ID + 결정적 ID 공존 시 결정적 ID 우선)
final groupMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('memberships')
      .where('groupId', isEqualTo: membership.groupId)
      .snapshots()
      .map((snapshot) {
        final all = snapshot.docs.map((doc) => Membership.fromFirestore(doc)).toList();
        // userId 기준 중복 제거: 결정적 ID({userId}_{groupId}) 문서 우선
        final byUserId = <String, Membership>{};
        for (final m in all) {
          final existing = byUserId[m.userId];
          if (existing == null) {
            byUserId[m.userId] = m;
          } else {
            // 결정적 ID 형식인 것을 우선
            final isDeterministic = m.id == '${m.userId}_${m.groupId}';
            if (isDeterministic) {
              byUserId[m.userId] = m;
            }
          }
        }
        return byUserId.values.toList();
      });
});

/// 온보딩 완료 여부 (한 번이라도 봤으면 true)
/// 초기값 false, completeOnboarding() 호출 시 true로 변경
/// 앱 시작 시 initOnboardingState()로 SharedPreferences에서 복원
final onboardingCompletedProvider = StateProvider<bool>((ref) => false);

/// 앱 시작 시 온보딩 상태 복원 (main.dart에서 호출)
Future<void> initOnboardingState(ProviderContainer container) async {
  final prefs = await SharedPreferences.getInstance();
  final isCompleted = prefs.getString('onboarding_status') == 'completed';
  container.read(onboardingCompletedProvider.notifier).state = isCompleted;
}

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

/// Membership의 프로필 업데이트 (닉네임, 색상)
Future<void> updateMembershipProfile(
  dynamic ref,
  String membershipId, {
  String? name,
  String? color,
  String? avatarType,
  String? avatarEmoji,
  String? statusMessage,
}) async {
  final firestore = ref.read(firestoreProvider);
  if (firestore == null) return;

  final updates = <String, dynamic>{};
  if (name != null) updates['name'] = name;
  if (color != null) updates['color'] = color;
  if (avatarType != null) updates['avatarType'] = avatarType;
  if (avatarEmoji != null) updates['avatarEmoji'] = avatarEmoji;
  if (statusMessage != null) {
    updates['statusMessage'] = statusMessage;
    updates['statusUpdatedAt'] = DateTime.now();
  }

  if (updates.isNotEmpty) {
    await firestore
        .collection('memberships')
        .doc(membershipId)
        .update(updates);
  }
}

/// 그룹 나가기 및 다음 그룹으로 전환
/// 반환값: {success: 성공 여부, wasGroupDeleted: 그룹 삭제 여부, hasRemainingGroups: 남은 그룹 유무}
Future<Map<String, dynamic>> leaveGroupAndSwitch(
  dynamic ref,
  String groupId,
) async {
  try {
    final authService = ref.read(authServiceProvider);
    final result = await authService.leaveGroup(groupId);

    final nextGroupId = result['nextGroupId'] as String?;
    final wasGroupDeleted = result['wasGroupDeleted'] as bool;

    if (nextGroupId != null) {
      // 남은 그룹으로 전환
      await switchGroup(ref, nextGroupId, withTransition: true);
    } else {
      // 그룹이 없으면 selectedGroupId를 null로 설정 (온보딩으로 리다이렉트)
      ref.read(selectedGroupIdProvider.notifier).state = null;

      // 로컬 저장소에서도 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_selected_group_id');
    }

    debugPrint('[GroupProvider] ✅ Left group and switched: nextGroupId=$nextGroupId');

    return {
      'success': true,
      'wasGroupDeleted': wasGroupDeleted,
      'hasRemainingGroups': nextGroupId != null,
    };
  } catch (e) {
    debugPrint('[GroupProvider] ❌ Leave group failed: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
