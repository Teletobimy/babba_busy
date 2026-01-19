import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_item.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 현재 그룹의 Todo 목록
final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('todos')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList());
});

/// 오늘의 할일 목록
final todayTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(todosProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  return todos.where((todo) {
    if (todo.dueDate == null) return false;
    return todo.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
           todo.dueDate!.isBefore(tomorrow);
  }).toList();
});

/// 완료되지 않은 할일 목록
final pendingTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(todosProvider).value ?? [];
  return todos.where((todo) => !todo.isCompleted).toList();
});

/// 특정 구성원의 할일 목록
final memberTodosProvider = Provider.family<List<TodoItem>, String?>((ref, memberId) {
  final todos = ref.watch(todosProvider).value ?? [];
  if (memberId == null) return todos;
  return todos.where((todo) => todo.assigneeId == memberId).toList();
});

/// 할일 서비스
final todoServiceProvider = Provider<TodoService>((ref) {
  return TodoService(ref);
});

class TodoService {
  final Ref _ref;

  TodoService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String? get _groupId => _ref.read(currentMembershipProvider)?.groupId;
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  CollectionReference? get _todosCollection {
    if (_groupId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_groupId).collection('todos');
  }

  /// 할일 추가
  Future<void> addTodo({
    required String title,
    String? note,
    String? assigneeId,
    DateTime? dueDate,
    String? repeatType,
    int priority = 1,
  }) async {
    final todosRef = _todosCollection;
    if (todosRef == null || _userId == null) return;

    await todosRef.add({
      'familyId': _groupId,
      'title': title,
      'note': note,
      'assigneeId': assigneeId,
      'isCompleted': false,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'repeatType': repeatType,
      'priority': priority,
      'createdBy': _userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 할일 완료 상태 토글
  Future<void> toggleTodo(String todoId, bool isCompleted) async {
    final todosRef = _todosCollection;
    if (todosRef == null) return;
    await todosRef.doc(todoId).update({'isCompleted': isCompleted});
  }

  /// 할일 수정
  Future<void> updateTodo(String todoId, {
    String? title,
    String? note,
    String? assigneeId,
    DateTime? dueDate,
    String? repeatType,
    int? priority,
  }) async {
    final todosRef = _todosCollection;
    if (todosRef == null) return;
    
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (note != null) updates['note'] = note;
    if (assigneeId != null) updates['assigneeId'] = assigneeId;
    if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);
    if (repeatType != null) updates['repeatType'] = repeatType;
    if (priority != null) updates['priority'] = priority;

    if (updates.isNotEmpty) {
      await todosRef.doc(todoId).update(updates);
    }
  }

  /// 할일 삭제
  Future<void> deleteTodo(String todoId) async {
    final todosRef = _todosCollection;
    if (todosRef == null) return;
    await todosRef.doc(todoId).delete();
  }
}
