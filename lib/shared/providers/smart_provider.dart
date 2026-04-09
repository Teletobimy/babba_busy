import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_member.dart';
import '../models/family.dart';
import '../models/todo_item.dart';
import '../models/album.dart';
import '../models/transaction.dart';
import '../models/calendar_group.dart';
import '../models/chat_message.dart';
import '../models/memo.dart';
import '../models/memo_category.dart';
import '../models/membership.dart';
import '../utils/date_utils.dart' as date_utils;
import 'auth_provider.dart';
import 'todo_provider.dart';
import 'album_provider.dart';
import 'budget_provider.dart';
import 'group_provider.dart';
import 'chat_provider.dart';
import 'calendar_group_provider.dart';
import 'memo_provider.dart';
import 'calendar_filter_provider.dart';
import 'stealth_provider.dart';

/// ========================================
/// 스마트 Provider - 실제 데이터 사용
/// ========================================

/// 현재 사용자
final smartCurrentMemberProvider = Provider<FamilyMember?>((ref) {
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

/// 현재 가족
final smartCurrentFamilyProvider = Provider<FamilyGroup?>((ref) {
  return ref.watch(currentGroupProvider).value;
});

/// 가족 구성원 목록
final smartMembersProvider = Provider<List<FamilyMember>>((ref) {
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

/// 할일 목록 (visibility + sharedEventTypes 필터 적용)
final smartTodosProvider = Provider<List<TodoItem>>((ref) {
  final todosAsync = ref.watch(todosProvider);
  if (todosAsync.hasError) {
    debugPrint('[smartTodosProvider] Error: ${todosAsync.error}');
  }
  var todos = todosAsync.value ?? [];

  // sharedEventTypes 필터: 작성자가 해당 타입을 공유하도록 설정했는지 확인
  final membershipByUserId = ref.watch(_membershipByUserIdProvider);
  todos = todos.where((todo) {
    if (todo.createdBy.isEmpty) return true;
    final creator = membershipByUserId[todo.createdBy];
    final sharedTypes = creator?.sharedEventTypes ?? ['todo', 'schedule', 'event'];
    return sharedTypes.contains(todo.eventType.value);
  }).toList();

  // visibility 필터: private 일정은 본인만 볼 수 있음
  final currentUserId = ref.watch(currentUserProvider)?.uid;
  todos = todos.where((todo) {
    if (todo.visibility == TodoVisibility.private) {
      return todo.ownerId == currentUserId || todo.createdBy == currentUserId;
    }
    return true;
  }).toList();

  // 스텔스 모드: 활성화 시 private 할일 숨기기
  final stealthMode = ref.watch(stealthModeProvider);
  if (stealthMode) {
    todos = todos.where((todo) => todo.visibility != TodoVisibility.private).toList();
  }

  return todos;
});

/// 오늘의 할일
final smartTodayTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(smartTodosProvider);
  final today = date_utils.normalizeDate(DateTime.now());

  return todos.where((todo) {
    if (todo.dueDate == null) return false;
    final normalizedDueDate = date_utils.normalizeDate(todo.dueDate!);
    return normalizedDueDate.isAtSameMomentAs(today);
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
  final today = date_utils.normalizeDate(DateTime.now());

  return todos.where((todo) {
    final completedDate = todo.completedAt ?? todo.createdAt;
    final todoDate = date_utils.normalizeDate(completedDate);
    return todoDate.isAtSameMomentAs(today);
  }).toList();
});

/// 특정 날짜의 시간 있는 할일 (Day View용)
final smartTimedTodosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  final todos = ref.watch(smartTodosProvider);
  final targetDate = date_utils.normalizeDate(date);

  return todos.where((todo) {
    if (!todo.hasTime || todo.startTime == null) return false;
    final todoDate = date_utils.normalizeDate(todo.startTime!);
    return todoDate.isAtSameMomentAs(targetDate);
  }).toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
});

/// 특정 날짜의 시간 미정 할일 (Day View용)
final smartUndecidedTodosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  final targetDate = date_utils.normalizeDate(date);

  var todos = (ref.watch(todosProvider).value ?? []).where((todo) {
    if (todo.hasTime || todo.startTime != null) return false;
    if (todo.dueDate == null) return false;

    final todoDate = date_utils.normalizeDate(todo.dueDate!);
    return todoDate.isAtSameMomentAs(targetDate);
  }).toList();

  // sharedEventTypes 필터: 작성자가 해당 타입을 공유하도록 설정했는지 확인
  final membershipByUserId = ref.watch(_membershipByUserIdProvider);
  todos = todos.where((todo) {
    if (todo.createdBy.isEmpty) return true;
    final creatorMembership = membershipByUserId[todo.createdBy];
    final sharedTypes = creatorMembership?.sharedEventTypes ?? ['todo', 'schedule', 'event'];
    return sharedTypes.contains(todo.eventType.value);
  }).toList();

  // visibility 필터: private 일정은 본인만 볼 수 있음
  final currentUserId = ref.watch(currentUserProvider)?.uid;
  todos = todos.where((todo) {
    if (todo.visibility == TodoVisibility.private) {
      return todo.ownerId == currentUserId || todo.createdBy == currentUserId;
    }
    return true;
  }).toList();

  // 스텔스 모드: 활성화 시 private 할일 숨기기
  final stealthMode = ref.watch(stealthModeProvider);
  if (stealthMode) {
    todos = todos.where((todo) => todo.visibility != TodoVisibility.private).toList();
  }

  // 완료 항목 필터 적용
  final showCompleted = ref.watch(showCompletedInCalendarProvider);
  if (!showCompleted) {
    todos = todos.where((t) => !t.isCompleted).toList();
  }

  return todos..sort((a, b) => a.createdAt.compareTo(b.createdAt));
});

/// 특정 구성원의 할일
final smartMemberTodosProvider = Provider.family<List<TodoItem>, String?>((ref, memberId) {
  final todos = ref.watch(smartTodosProvider);
  if (memberId == null) return todos;
  return todos.where((todo) => todo.isAssignedTo(memberId)).toList();
});

/// 캘린더 그룹 목록
final smartCalendarGroupsProvider = Provider<List<CalendarGroup>>((ref) {
  return ref.watch(calendarGroupsProvider).value ?? [];
});

/// 필터링된 Todo (선택된 캘린더 그룹 기반)
/// effectiveSelectedCalendarGroupsProvider 사용으로 빈 Set 처리 통일
final filteredTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(smartTodosProvider);
  final selectedGroups = ref.watch(effectiveSelectedCalendarGroupsProvider);

  return todos.where((todo) {
    // calendarGroupId가 없는 todo는 가족 그룹으로 간주
    final groupId = todo.calendarGroupId ?? 'cal_family';
    return selectedGroups.contains(groupId);
  }).toList();
});

/// 멤버십 맵 캐싱 (userId -> Membership)
/// groupMembershipsProvider를 매번 맵으로 변환하지 않도록 캐싱
final _membershipByUserIdProvider = Provider<Map<String, Membership>>((ref) {
  final groupMemberships = ref.watch(groupMembershipsProvider).value ?? [];
  return {for (final m in groupMemberships) m.userId: m};
});

/// 특정 날짜의 할일 (필터 적용, 반복 확장 포함)
/// 최적화: 날짜 정규화 + 멤버십 맵 캐싱
final smartTodosForDateProvider = Provider.family<List<TodoItem>, DateTime>((ref, date) {
  // 날짜 정규화 (시간 제거) - 캐시 히트율 향상
  final normalizedDate = date_utils.normalizeDate(date);

  // 실제 모드: 반복 확장된 todos 사용
  List<TodoItem> todos = ref.watch(todosForDateProvider(normalizedDate));

  // 캐싱된 멤버십 맵 사용
  final membershipByUserId = ref.watch(_membershipByUserIdProvider);

  todos = todos.where((todo) {
    // createdBy가 비어있으면 기본적으로 표시
    if (todo.createdBy.isEmpty) return true;

    // 작성자의 membership 조회
    final creatorMembership = membershipByUserId[todo.createdBy];

    // membership을 찾을 수 없으면 기본값으로 모든 타입 공유
    final sharedTypes = creatorMembership?.sharedEventTypes ?? ['todo', 'schedule', 'event'];

    // 작성자가 해당 타입을 공유하도록 설정했는지 확인
    return sharedTypes.contains(todo.eventType.value);
  }).toList();

  // Apply visibility filter: private 일정은 본인만 볼 수 있음
  final currentUserId = ref.watch(currentUserProvider)?.uid;
  todos = todos.where((todo) {
    if (todo.visibility == TodoVisibility.private) {
      return todo.ownerId == currentUserId || todo.createdBy == currentUserId;
    }
    return true;
  }).toList();

  // Apply calendar group filter
  final selectedGroups = ref.watch(effectiveSelectedCalendarGroupsProvider);
  todos = todos.where((todo) {
    final groupId = todo.calendarGroupId ?? 'cal_family';
    return selectedGroups.contains(groupId);
  }).toList();

  // 정렬
  todos.sort((a, b) {
    final aTime = a.startTime ?? a.dueDate ?? a.createdAt;
    final bTime = b.startTime ?? b.dueDate ?? b.createdAt;
    return aTime.compareTo(bTime);
  });

  // 완료 항목 필터 적용
  final showCompleted = ref.watch(showCompletedInCalendarProvider);
  if (!showCompleted) {
    todos = todos.where((t) => !t.isCompleted).toList();
  }

  return todos;
});

/// 다가오는 할일 (7일 이내, 필터 적용)
final smartUpcomingTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(filteredTodosProvider);
  final now = DateTime.now();
  final today = date_utils.normalizeDate(now);
  final weekLater = today.add(const Duration(days: 7));

  return todos.where((todo) {
    if (todo.isCompleted) return false; // 완료 항목 제외
    if (todo.dueDate == null && todo.startTime == null) return false;
    final todoDate = todo.startTime ?? todo.dueDate!;
    return todoDate.isAfter(now) && todoDate.isBefore(weekLater);
  }).toList()
    ..sort((a, b) {
      final aTime = a.startTime ?? a.dueDate ?? a.createdAt;
      final bTime = b.startTime ?? b.dueDate ?? b.createdAt;
      return aTime.compareTo(bTime);
    });
});

/// 다가오는 할일 (7일 이내, 반복 확장 포함, 필터 적용)
/// effectiveSelectedCalendarGroupsProvider 사용으로 빈 Set 처리 통일
final smartUpcomingExpandedTodosProvider = Provider<List<TodoItem>>((ref) {
  final now = DateTime.now();
  final today = date_utils.normalizeDate(now);
  final weekLater = today.add(const Duration(days: 7));

  // Get expanded todos for current month and next month
  // (월말 경계에서 다음 달 일정이 누락되는 문제 방지)
  final currentMonthTodos = ref.watch(expandedTodosForMonthProvider((
    year: now.year,
    month: now.month,
  )));
  final nextMonth = now.month == 12 ? 1 : now.month + 1;
  final nextYear = now.month == 12 ? now.year + 1 : now.year;
  final nextMonthTodos = ref.watch(expandedTodosForMonthProvider((
    year: nextYear,
    month: nextMonth,
  )));
  final expandedTodos = [...currentMonthTodos, ...nextMonthTodos];

  // Apply calendar group filter (effectiveSelectedCalendarGroupsProvider 사용)
  final selectedGroups = ref.watch(effectiveSelectedCalendarGroupsProvider);
  final todos = expandedTodos.where((todo) {
    final groupId = todo.calendarGroupId ?? 'cal_family';
    return selectedGroups.contains(groupId);
  }).toList();

  // Filter to upcoming only
  return todos.where((todo) {
    if (todo.isCompleted) return false;
    if (todo.dueDate == null && todo.startTime == null) return false;
    final todoDate = todo.startTime ?? todo.dueDate!;
    return todoDate.isAfter(now) && todoDate.isBefore(weekLater);
  }).toList()
    ..sort((a, b) {
      final aTime = a.startTime ?? a.dueDate ?? a.createdAt;
      final bTime = b.startTime ?? b.dueDate ?? b.createdAt;
      return aTime.compareTo(bTime);
    });
});

/// 이번 주 할일 (필터 적용)
final smartThisWeekTodosProvider = Provider<List<TodoItem>>((ref) {
  final todos = ref.watch(filteredTodosProvider);
  final now = DateTime.now();
  final startOfWeek = date_utils.normalizeDate(now).subtract(Duration(days: now.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  return todos.where((todo) {
    if (todo.dueDate == null && todo.startTime == null) return false;
    final todoStart = todo.startTime ?? todo.dueDate!;
    final todoEnd = todo.endTime ?? todoStart;
    return todoStart.isBefore(endOfWeek) && todoEnd.isAfter(startOfWeek);
  }).toList()
    ..sort((a, b) {
      final aTime = a.startTime ?? a.dueDate ?? a.createdAt;
      final bTime = b.startTime ?? b.dueDate ?? b.createdAt;
      return aTime.compareTo(bTime);
    });
});

/// 앨범 목록 (Memory 대체)
final smartAlbumsListProvider = Provider<List<Album>>((ref) {
  return ref.watch(smartAlbumsProvider);
});

/// 타입별 앨범
final smartAlbumsByTypeProvider = Provider.family<List<Album>, AlbumType?>((ref, type) {
  final albums = ref.watch(smartAlbumsListProvider);
  if (type == null) return albums;
  return albums.where((a) => a.albumType == type).toList();
});

/// 거래 목록
final smartTransactionsProvider = Provider<List<BudgetTransaction>>((ref) {
  final txAsync = ref.watch(transactionsProvider);
  if (txAsync.hasError) {
    debugPrint('[smartTransactionsProvider] Error: ${txAsync.error}');
  }
  return txAsync.value ?? [];
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

/// 채팅 메시지 목록
final smartChatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  final chatAsync = ref.watch(chatMessagesProvider);
  if (chatAsync.hasError) {
    debugPrint('[smartChatMessagesProvider] Error: ${chatAsync.error}');
  }
  return chatAsync.value ?? [];
});

/// 현재 사용자 ID
final smartCurrentUserIdProvider = Provider<String>((ref) {
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

/// 메모 목록
final smartMemosProvider = Provider<List<Memo>>((ref) {
  final memosAsync = ref.watch(memosProvider);
  if (memosAsync.hasError) {
    debugPrint('[smartMemosProvider] Error: ${memosAsync.error}');
  }
  return memosAsync.value ?? [];
});

/// 메모 카테고리 목록
final smartMemoCategoriesProvider = Provider<List<MemoCategory>>((ref) {
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
