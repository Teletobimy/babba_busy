import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_member.dart';
import '../models/todo_item.dart';
import 'smart_provider.dart';
import 'todo_provider.dart';

/// 활동 유형
enum ActivityType { completed, created }

/// 활동 아이템 모델
class ActivityItem {
  final ActivityType type;
  final String todoTitle;
  final String memberName;
  final String? memberColor;
  final DateTime timestamp;

  const ActivityItem({
    required this.type,
    required this.todoTitle,
    required this.memberName,
    this.memberColor,
    required this.timestamp,
  });
}

/// 최근 24시간 활동 피드
final recentActivityProvider = Provider<List<ActivityItem>>((ref) {
  final todosAsync = ref.watch(todosProvider);
  final todos = todosAsync.value ?? [];
  final members = ref.watch(smartMembersProvider);
  final activities = <ActivityItem>[];

  final cutoff = DateTime.now().subtract(const Duration(hours: 24));

  for (final todo in todos) {
    // Recent completions
    if (todo.completedAt != null && todo.completedAt!.isAfter(cutoff)) {
      final member = _findMember(members, todo);
      activities.add(ActivityItem(
        type: ActivityType.completed,
        todoTitle: todo.title,
        memberName: member?.name ?? '멤버',
        memberColor: member?.color,
        timestamp: todo.completedAt!,
      ));
    }
    // Recent creations (only uncompleted items to avoid duplication)
    if (todo.createdAt.isAfter(cutoff) && !todo.isCompleted) {
      final member = _findMember(members, todo);
      activities.add(ActivityItem(
        type: ActivityType.created,
        todoTitle: todo.title,
        memberName: member?.name ?? '멤버',
        memberColor: member?.color,
        timestamp: todo.createdAt,
      ));
    }
  }

  activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return activities.take(10).toList();
});

FamilyMember? _findMember(List<FamilyMember> members, TodoItem todo) {
  if (members.isEmpty) return null;
  // Try ownerId first, then createdBy, then assigneeId
  for (final userId in [todo.ownerId, todo.createdBy, todo.assigneeId]) {
    if (userId == null || userId.isEmpty) continue;
    try {
      return members.firstWhere((m) => m.id == userId);
    } catch (_) {
      // Not found, try next
    }
  }
  return null;
}
