import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_member.dart';
import '../models/family.dart';
import '../models/todo_item.dart';
import '../models/event.dart';
import '../models/memory.dart';
import '../models/transaction.dart';
import '../models/calendar_group.dart';
import '../../app/router.dart';
import 'auth_provider.dart';
import 'demo_provider.dart';
import 'todo_provider.dart';
import 'event_provider.dart';
import 'memory_provider.dart';
import 'budget_provider.dart';

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
  return ref.watch(currentMemberProvider).value;
});

/// 현재 가족 (데모/실제)
final smartCurrentFamilyProvider = Provider<FamilyGroup?>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoFamilyProvider);
  return ref.watch(currentFamilyProvider).value;
});

/// 가족 구성원 목록 (데모/실제)
final smartMembersProvider = Provider<List<FamilyMember>>((ref) {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ref.watch(demoMembersProvider);
  return ref.watch(familyMembersProvider).value ?? [];
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
  return todos.where((todo) => todo.isCompleted).toList();
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
  // TODO: 실제 Firebase에서 캘린더 그룹 가져오기
  return [];
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
