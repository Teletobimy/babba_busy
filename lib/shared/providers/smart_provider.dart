import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_member.dart';
import '../models/family.dart';
import '../models/todo_item.dart';
import '../models/event.dart';
import '../models/memory.dart';
import '../models/transaction.dart';
import '../models/calendar_group.dart';
import '../models/chat_message.dart';
import '../models/memo.dart';
import '../models/memo_category.dart';
import '../../app/router.dart';
import 'auth_provider.dart';
import 'demo_provider.dart';
import 'todo_provider.dart';
import 'event_provider.dart';
import 'memory_provider.dart';
import 'budget_provider.dart';
import 'group_provider.dart';
import 'chat_provider.dart';
import 'calendar_group_provider.dart';
import 'memo_provider.dart';

/// ========================================
/// 스마트 Provider - 데모/실제 데이터 자동 선택
/// ========================================

/// 현재 사용자 (데모/실제)
final smartCurrentMemberProvider = Provider<FamilyMember?>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) {
    final members = ref.watch(demoMembersProvider);
    return members.isNotEmpty ? members.first : null;
  }
  
  final membership = ref.watch(currentMembershipProvider);
  final user = ref.watch(currentUserProvider); // Firebase Auth User
  final userData = ref.watch(currentUserDataProvider).value; // Firestore User Document
  
  if (membership == null) return null;
  
  // 이름 우선순위: 1. 멤버십 닉네임, 2. Firestore 사용자 이름, 3. Google/Firebase 이름, 4. 기본값
  String displayName = membership.name;
  if (displayName.isEmpty) {
    displayName = userData?.name ?? user?.displayName ?? '사용자';
  }
  
  return FamilyMember(
    id: membership.userId,
    familyId: membership.groupId,
    name: displayName,
    email: user?.email ?? userData?.email ?? '',
    color: membership.color,
    role: membership.role,
    createdAt: membership.joinedAt,
    avatarUrl: userData?.avatarUrl ?? user?.photoURL,
  );
});

/// 현재 가족 (데모/실제)
final smartCurrentFamilyProvider = Provider<FamilyGroup?>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoFamilyProvider);
  return ref.watch(currentGroupProvider).value;
});

/// 가족 구성원 목록 (데모/실제)
final smartMembersProvider = Provider<List<FamilyMember>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoMembersProvider);

  final memberships = ref.watch(groupMembershipsProvider).value ?? [];
  // 사용자 정보 가져오기 (이상적으로는 별도 Provider로 조인해야 함)
  // 여기서는 Membership 정보만으로 FamilyMember 구성
  return memberships.map((m) => FamilyMember(
    id: m.userId,
    familyId: m.groupId,
    name: m.name.isEmpty ? '구성원' : m.name,
    email: '', // email 정보는 Membership에 없음
    color: m.color,
    avatarUrl: m.avatarUrl, // Google 프로필 사진 등
    role: m.role,
    createdAt: m.joinedAt,
  )).toList();
});

/// 할일 목록 (데모/실제)
final smartTodosProvider = Provider<List<TodoItem>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoTodosProvider);
  return ref.watch(todosProvider).value ?? [];
});

/// 오늘의 할일
final smartTodayTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(smartTodosProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  return todos.where((todo) {
    if (todo.dueDate == null) return false;
    return todo.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
           todo.dueDate!.isBefore(tomorrow);
  }).toList();
});

/// 완료되지 않은 할일
final smartPendingTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(smartTodosProvider);
  return todos.where((todo) => !todo.isCompleted).toList();
});

/// 완료된 할일
final smartCompletedTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(smartTodosProvider);
  return todos.where((todo) => todo.isCompleted).toList()
    ..sort((a, b) {
      // completedAt이 있으면 그걸로 정렬, 없으면 createdAt으로
      final aTime = a.completedAt ?? a.createdAt;
      final bTime = b.completedAt ?? b.createdAt;
      return bTime.compareTo(aTime); // 최근 완료된 것이 위로
    });
});

/// 오늘 완료된 할일
final smartTodayCompletedTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(smartCompletedTodosProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return todos.where((todo) {
    final completedDate = todo.completedAt ?? todo.createdAt;
    final todoDate = DateTime(completedDate.year, completedDate.month, completedDate.day);
    return todoDate.isAtSameMomentAs(today);
  }).toList();
});

/// 특정 날짜의 시간 있는 할일 (Day View용)
final smartTimedTodosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  final todos = ref.watch(smartTodosProvider);
  final targetDate = DateTime(date.year, date.month, date.day);

  return todos.where((todo) {
    if (!todo.hasTime || todo.startTime == null) return false;
    final todoDate = DateTime(
      todo.startTime!.year,
      todo.startTime!.month,
      todo.startTime!.day,
    );
    return todoDate.isAtSameMomentAs(targetDate);
  }).toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
});

/// 특정 구성원의 할일
final smartMemberTodosProvider = Provider.family<List<TodoItem>, String?>((ref, memberId) {
  final todos = ref.watch(smartTodosProvider);
  if (memberId == null) return todos;
  return todos.where((todo) => todo.assigneeId == memberId).toList();
});

/// 이벤트 목록 (데모/실제)
final smartEventsProvider = Provider<List<Event>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoEventsProvider);
  return ref.watch(eventsProvider).value ?? [];
});

/// 캘린더 그룹 목록 (데모/실제)
final smartCalendarGroupsProvider = Provider<List<CalendarGroup>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoCalendarGroupsProvider);
  return ref.watch(calendarGroupsProvider).value ?? [];
});

/// 선택된 캘린더 그룹 ID 목록
final selectedCalendarGroupsProvider = StateProvider<Set<String>>((ref) {
  // 기본값: 모든 캘린더 그룹 선택
  final groups = ref.watch(smartCalendarGroupsProvider);
  return groups.map((g) => g.id).toSet();
});

/// 필터링된 이벤트 (선택된 캘린더 그룹 기반)
final filteredEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(smartEventsProvider);
  final selectedGroups = ref.watch(selectedCalendarGroupsProvider);
  
  // 모든 그룹이 선택되었거나 선택이 비어있으면 전체 반환
  if (selectedGroups.isEmpty) return events;
  
  return events.where((event) {
    // calendarGroupId가 없는 이벤트는 가족 그룹으로 간주
    final groupId = event.calendarGroupId ?? 'cal_family';
    return selectedGroups.contains(groupId);
  }).toList();
});

/// 특정 날짜의 이벤트 (필터 적용)
final smartEventsForDateProvider = Provider.family<List<Event>, DateTime>((ref, date) {
  final events = ref.watch(filteredEventsProvider);
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return events.where((event) {
    return event.startAt.isBefore(endOfDay) && event.endAt.isAfter(startOfDay);
  }).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
});

/// 다가오는 이벤트 (7일 이내, 필터 적용)
final smartUpcomingEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(filteredEventsProvider);
  final now = DateTime.now();
  final weekLater = now.add(const Duration(days: 7));

  return events.where((event) {
    return event.startAt.isAfter(now) && event.startAt.isBefore(weekLater);
  }).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
});

/// 이번 주 이벤트 (필터 적용)
final smartThisWeekEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(filteredEventsProvider);
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  return events.where((event) {
    return event.startAt.isBefore(endOfWeek) && event.endAt.isAfter(startOfWeek);
  }).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
});

/// 추억 목록 (데모/실제)
final smartMemoriesProvider = Provider<List<Memory>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoMemoriesProvider);
  return ref.watch(memoriesProvider).value ?? [];
});

/// 카테고리별 추억
final smartMemoriesByCategoryProvider = Provider.family<List<Memory>, String?>((ref, category) {
  final memories = ref.watch(smartMemoriesProvider);
  if (category == null || category.isEmpty) return memories;
  return memories.where((m) => m.category == category).toList();
});

/// 거래 목록 (데모/실제)
final smartTransactionsProvider = Provider<List<BudgetTransaction>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoTransactionsProvider);
  return ref.watch(transactionsProvider).value ?? [];
});

/// 이번 달 거래
final smartThisMonthTransactionsProvider = Provider<List<BudgetTransaction>>((ref) {
  final transactions = ref.watch(smartTransactionsProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  return transactions.where((t) {
    return t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
           t.date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
  }).toList();
});

/// 이번 달 요약 (스마트)
final smartMonthSummaryProvider = Provider<MonthSummary>((ref) {
  final transactions = ref.watch(smartThisMonthTransactionsProvider);

  int totalIncome = 0;
  int totalExpense = 0;
  Map<String, int> categoryExpenses = {};

  for (final t in transactions) {
    if (t.isIncome) {
      totalIncome += t.amount;
    } else {
      totalExpense += t.amount;
      categoryExpenses[t.category] = 
          (categoryExpenses[t.category] ?? 0) + t.amount;
    }
  }

  return MonthSummary(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    balance: totalIncome - totalExpense,
    categoryExpenses: categoryExpenses,
  );
});

/// 고정 지출 목록 (스마트)
final smartRecurringTransactionsProvider = Provider<List<BudgetTransaction>>((ref) {
  final transactions = ref.watch(smartTransactionsProvider);
  return transactions.where((t) => t.isRecurring).toList();
});

/// ========================================
/// 채팅 관련 스마트 Provider
/// ========================================

/// 채팅 메시지 목록 (데모/실제)
final smartChatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoChatMessagesProvider);
  return ref.watch(chatMessagesProvider).value ?? [];
});

/// 현재 사용자 ID (데모/실제)
final smartCurrentUserIdProvider = Provider<String>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return 'member1'; // 데모 모드에서는 '엄마'로 고정
  return ref.watch(currentUserProvider)?.uid ?? '';
});

/// 읽지 않은 메시지 수 (스마트)
final smartUnreadMessagesCountProvider = Provider<int>((ref) {
  final messages = ref.watch(smartChatMessagesProvider);
  final userId = ref.watch(smartCurrentUserIdProvider);
  if (userId.isEmpty) return 0;
  return messages.where((msg) => !msg.isReadBy(userId)).length;
});

/// 마지막 채팅 메시지 (스마트)
final smartLastChatMessageProvider = Provider<ChatMessage?>((ref) {
  final messages = ref.watch(smartChatMessagesProvider);
  if (messages.isEmpty) return null;
  return messages.last;
});

/// ========================================
/// 메모 관련 스마트 Provider
/// ========================================

/// 메모 목록 (데모/실제)
final smartMemosProvider = Provider<List<Memo>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoMemosProvider);
  return ref.watch(memosProvider).value ?? [];
});

/// 메모 카테고리 목록 (데모/실제)
final smartMemoCategoriesProvider = Provider<List<MemoCategory>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoMemoCategoriesProvider);
  return ref.watch(memoCategoriesProvider).value ?? [];
});

/// 선택된 카테고리 ID (스마트)
final smartSelectedMemoCategoryIdProvider = StateProvider<String?>((ref) => null);

/// 필터링된 메모 목록 (스마트)
final smartFilteredMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(smartMemosProvider);
  final categoryId = ref.watch(smartSelectedMemoCategoryIdProvider);

  if (categoryId == null) return memos;
  return memos.where((m) => m.categoryId == categoryId).toList();
});

/// 고정된 메모 목록 (스마트)
final smartPinnedMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(smartFilteredMemosProvider);
  return memos.where((m) => m.isPinned).toList();
});

/// 고정되지 않은 메모 목록 (스마트)
final smartUnpinnedMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(smartFilteredMemosProvider);
  return memos.where((m) => !m.isPinned).toList();
});

/// 메모 검색 쿼리 (스마트)
final smartMemoSearchQueryProvider = StateProvider<String>((ref) => '');

/// 검색된 메모 목록 (스마트)
final smartSearchedMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(smartFilteredMemosProvider);
  final query = ref.watch(smartMemoSearchQueryProvider).toLowerCase();

  if (query.isEmpty) return memos;

  return memos.where((m) {
    return m.title.toLowerCase().contains(query) ||
           m.content.toLowerCase().contains(query) ||
           m.tags.any((t) => t.toLowerCase().contains(query));
  }).toList();
});
