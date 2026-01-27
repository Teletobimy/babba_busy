import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'group_provider.dart';

/// 초기 로딩 상태 감지
/// 멤버십은 로드됐지만 그룹 초기화가 안 된 경우 -> 로딩 중
final isInitialLoadingProvider = Provider<bool>((ref) {
  final memberships = ref.watch(userMembershipsProvider);
  final isGroupInitialized = ref.watch(selectedGroupInitializedProvider);

  // 멤버십이 로딩 중이면 로딩 상태
  if (memberships.isLoading) {
    return true;
  }

  // 멤버십은 로드됐지만 그룹이 있고 초기화 안됨 -> 로딩 중
  if (memberships.hasValue &&
      memberships.value!.isNotEmpty &&
      !isGroupInitialized) {
    return true;
  }

  return false;
});
