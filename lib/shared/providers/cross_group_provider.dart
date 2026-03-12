import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo_item.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 크로스 그룹 뷰 토글
final crossGroupViewEnabledProvider = StateProvider<bool>((ref) => false);

/// 사용자의 모든 그룹에서 할일 가져오기
final crossGroupTodosProvider = FutureProvider<List<TodoItem>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);
  if (firestore == null || user == null) return [];

  // 사용자 레벨 todos 조회 (이미 모든 그룹의 데이터 포함)
  final snapshot = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('todos')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .get();

  return snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList();
});

/// 그룹별 색상 매핑
final groupColorMapProvider = Provider<Map<String, int>>((ref) {
  final memberships = ref.watch(userMembershipsProvider).value ?? [];
  final colorMap = <String, int>{};
  final colors = [0xFF6C63FF, 0xFFFF6B6B, 0xFF4ECDC4, 0xFFFFE66D, 0xFFA8E6CF];

  for (var i = 0; i < memberships.length; i++) {
    colorMap[memberships[i].groupId] = colors[i % colors.length];
  }

  return colorMap;
});
