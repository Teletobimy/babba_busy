import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 초기 로딩 상태 감지
/// 앱 시작 시 로딩 화면을 보여주고, 초기화 완료 후 숨김
final isInitialLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final memberships = ref.watch(userMembershipsProvider);
  final isGroupInitialized = ref.watch(selectedGroupInitializedProvider);

  // 인증 상태 로딩 중 -> 로딩 상태
  if (authState.isLoading) {
    return true;
  }

  // 로그인 안됨 -> 로딩 끝 (로그인 화면으로)
  if (authState.valueOrNull == null) {
    return false;
  }

  // 로그인됨, 멤버십 로딩 중 -> 로딩 상태
  if (memberships.isLoading) {
    return true;
  }

  // 멤버십은 로드됐지만 그룹이 있고 초기화 안됨 -> 로딩 중
  if (memberships.hasValue &&
      (memberships.value?.isNotEmpty ?? false) &&
      !isGroupInitialized) {
    return true;
  }

  return false;
});
