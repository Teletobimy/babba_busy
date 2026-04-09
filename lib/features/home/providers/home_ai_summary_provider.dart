import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/ai/babba_subagent_runtime_service.dart';
import '../../../shared/models/family_member.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/utils/date_utils.dart' as date_utils;
import 'home_filters.dart';

/// 캐시 키: 날짜 + 주요 수치가 같으면 API를 다시 호출하지 않는다.
@immutable
class _SummaryCacheKey {
  final DateTime date;
  final int pending;
  final int completed;
  final int upcoming;
  final String? selectedMemberId;

  const _SummaryCacheKey({
    required this.date,
    required this.pending,
    required this.completed,
    required this.upcoming,
    required this.selectedMemberId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SummaryCacheKey &&
          date == other.date &&
          pending == other.pending &&
          completed == other.completed &&
          upcoming == other.upcoming &&
          selectedMemberId == other.selectedMemberId;

  @override
  int get hashCode => Object.hash(date, pending, completed, upcoming, selectedMemberId);
}

/// 인메모리 캐시 — 앱 라이프사이클 동안 유지된다.
_SummaryCacheKey? _lastCacheKey;
String? _lastCachedSummary;

/// 홈 AI 요약 Provider
///
/// 날짜 + 핵심 수치(남은 할일, 완료, 다가오는 일정)가 동일하면
/// Gemini API를 다시 호출하지 않고 캐시된 결과를 반환한다.
final aiSummaryProvider = FutureProvider<String>((ref) async {
  final runtimeService = ref.read(babbaSubagentRuntimeServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  final currentMember = ref.watch(smartCurrentMemberProvider);
  final selectedMemberId = ref.watch(selectedMemberFilterProvider);
  final members = ref.watch(smartMembersProvider);

  final todos = _filterTodosForMember(
    ref.watch(smartTodosProvider),
    selectedMemberId,
  );
  final upcomingTodos = _filterTodosForMember(
    ref.watch(smartUpcomingTodosProvider),
    selectedMemberId,
  );
  final todayCompleted = _filterTodosForMember(
    ref.watch(smartTodayCompletedTodosProvider),
    selectedMemberId,
  );

  final pendingTodos = todos.where((todo) => !todo.isCompleted).length;
  final completedCount = todayCompleted.length;
  final upcomingCount = upcomingTodos.length;

  // --- 캐시 확인 ---
  final today = date_utils.normalizeDate(DateTime.now());
  final cacheKey = _SummaryCacheKey(
    date: today,
    pending: pendingTodos,
    completed: completedCount,
    upcoming: upcomingCount,
    selectedMemberId: selectedMemberId,
  );

  if (cacheKey == _lastCacheKey && _lastCachedSummary != null) {
    return _lastCachedSummary!;
  }

  // --- 캐시 미스: API 호출 ---
  final selectedMemberName = _findMemberName(members, selectedMemberId);
  final userName =
      currentMember?.name ??
      currentUser?.displayName ??
      selectedMemberName ??
      '사용자';

  final summary = await runtimeService.generateHomeSummary(
    userId: currentUser?.uid,
    userName: userName,
    selectedMemberId: selectedMemberId,
    selectedMemberName: selectedMemberName,
    pendingTodos: pendingTodos,
    completedToday: completedCount,
    upcomingEvents: upcomingCount,
    fallbackTodos: todos,
  );

  // 캐시 저장
  _lastCacheKey = cacheKey;
  _lastCachedSummary = summary;

  return summary;
});

/// 캐시를 강제로 무효화한다 (예: 사용자가 수동 새로고침 시).
void invalidateAiSummaryCache() {
  _lastCacheKey = null;
  _lastCachedSummary = null;
}

List<TodoItem> _filterTodosForMember(List<TodoItem> todos, String? memberId) {
  if (memberId == null) {
    return todos;
  }
  return todos.where((todo) => todo.isAssignedTo(memberId)).toList();
}

String? _findMemberName(List<FamilyMember> members, String? memberId) {
  if (memberId == null) {
    return null;
  }

  for (final member in members) {
    if (member.id == memberId) {
      return member.name;
    }
  }

  return null;
}
