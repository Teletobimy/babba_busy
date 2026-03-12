import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'smart_provider.dart';

/// 활동 유형
enum ActivityType { completed, created }

/// 활동 아이템 모델
class ActivityItem {
  final ActivityType type;
  final String todoTitle;
  final String memberName;
  final DateTime timestamp;

  const ActivityItem({
    required this.type,
    required this.todoTitle,
    required this.memberName,
    required this.timestamp,
  });
}

/// 최근 24시간 활동 피드
final recentActivityProvider = Provider<List<ActivityItem>>((ref) {
  final todos = ref.watch(smartCompletedTodosProvider);
  final members = ref.watch(smartMembersProvider);
  final activities = <ActivityItem>[];

  final cutoff = DateTime.now().subtract(const Duration(hours: 24));

  for (final todo in todos) {
    // 최근 24시간 내 완료된 할일
    if (todo.completedAt != null && todo.completedAt!.isAfter(cutoff)) {
      final memberName = _findMemberName(members, todo.ownerId ?? todo.createdBy);
      activities.add(ActivityItem(
        type: ActivityType.completed,
        todoTitle: todo.title,
        memberName: memberName,
        timestamp: todo.completedAt!,
      ));
    }
  }

  activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return activities.take(10).toList();
});

String _findMemberName(List members, String? userId) {
  if (userId == null) return '구성원';
  try {
    final member = members.firstWhere((m) => m.id == userId);
    return member.name;
  } catch (_) {
    return '구성원';
  }
}
