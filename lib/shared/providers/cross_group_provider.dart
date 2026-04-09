import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo_item.dart';
import 'group_provider.dart';
import 'todo_provider.dart';

/// 크로스 그룹 뷰 토글
final crossGroupViewEnabledProvider = StateProvider<bool>((ref) => false);

/// 크로스 그룹 모드일 때 사용할 기본 todos 소스.
/// - 비활성: 현재 그룹 todos (todosProvider) 반환
/// - 활성: 사용자의 모든 그룹 todos (userTodosProvider) 반환
///
/// 이 provider는 todosProvider와 동일한 AsyncValue 시그니처를
/// 유지하여 하위 provider들이 동일하게 소비할 수 있도록 합니다.
final crossGroupAwareTodosProvider =
    Provider<AsyncValue<List<TodoItem>>>((ref) {
  final enabled = ref.watch(crossGroupViewEnabledProvider);

  if (!enabled) {
    // 기존 동작: 현재 그룹의 todos만 반환
    return ref.watch(todosProvider);
  }

  // 크로스 그룹 모드: 사용자의 모든 todos 반환 (그룹 무관)
  return ref.watch(userTodosProvider);
});

/// 그룹별 색상 매핑 (크로스 그룹 뷰에서 그룹 구분에 사용)
final groupColorMapProvider = Provider<Map<String, int>>((ref) {
  final memberships = ref.watch(userMembershipsProvider).value ?? [];
  final colorMap = <String, int>{};
  final colors = [
    0xFF6C63FF,
    0xFFFF6B6B,
    0xFF4ECDC4,
    0xFFFFE66D,
    0xFFA8E6CF,
  ];

  for (var i = 0; i < memberships.length; i++) {
    colorMap[memberships[i].groupId] = colors[i % colors.length];
  }

  return colorMap;
});

/// 그룹 ID to 그룹 이름 매핑 (크로스 그룹 뷰에서 표시용)
final groupNameMapProvider = Provider<Map<String, String>>((ref) {
  final memberships = ref.watch(userMembershipsProvider).value ?? [];
  return {
    for (final m in memberships) m.groupId: m.groupName,
  };
});
