import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'calendar_group_provider.dart';

/// 캘린더에서 완료된 항목 표시 여부
final showCompletedInCalendarProvider = StateProvider<bool>((ref) => true);

/// 모든 캘린더 그룹 ID (computed provider)
/// selectedCalendarGroupsProvider의 기본값으로 사용
final allCalendarGroupIdsProvider = Provider<Set<String>>((ref) {
  final groups = ref.watch(calendarGroupsProvider).value ?? [];
  return groups.map((g) => g.id).toSet();
});

/// 선택된 캘린더 그룹 ID 목록
/// 빈 Set으로 초기화하고, 빈 경우 전체 선택으로 처리
final selectedCalendarGroupsProvider = StateProvider<Set<String>>((ref) {
  return <String>{};
});

/// 실제 선택된 그룹 ID (빈 경우 전체 반환)
final effectiveSelectedCalendarGroupsProvider = Provider<Set<String>>((ref) {
  final selected = ref.watch(selectedCalendarGroupsProvider);
  if (selected.isEmpty) {
    return ref.watch(allCalendarGroupIdsProvider);
  }
  return selected;
});
