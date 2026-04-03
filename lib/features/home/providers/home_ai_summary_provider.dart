import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/ai/babba_subagent_runtime_service.dart';
import '../../../shared/models/family_member.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/smart_provider.dart';
import 'home_filters.dart';

/// 홈 AI 요약 Provider
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
  final selectedMemberName = _findMemberName(members, selectedMemberId);
  final userName =
      currentMember?.name ??
      currentUser?.displayName ??
      selectedMemberName ??
      '사용자';

  return runtimeService.generateHomeSummary(
    userId: currentUser?.uid,
    userName: userName,
    selectedMemberId: selectedMemberId,
    selectedMemberName: selectedMemberName,
    pendingTodos: pendingTodos,
    completedToday: todayCompleted.length,
    upcomingEvents: upcomingTodos.length,
    fallbackTodos: todos,
  );
});

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
