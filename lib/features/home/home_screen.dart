import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/group_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/todo_provider.dart';
import '../../shared/widgets/member_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../todo/widgets/add_todo_sheet.dart';
import 'widgets/ai_summary_card.dart';
import 'widgets/upcoming_events_card.dart';
import 'widgets/compact_todo_card.dart';
import '../../shared/widgets/group_selector.dart';

/// 선택된 구성원 필터
final selectedMemberFilterProvider = StateProvider<String?>((ref) => null);

/// 완료 섹션 펼침 상태
final completedSectionExpandedProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Smart Provider 사용 - 데모/실제 데이터 자동 선택
    final currentMember = ref.watch(smartCurrentMemberProvider);
    final members = ref.watch(smartMembersProvider);
    // Firebase Auth에서 직접 이름 가져오기 (빠른 fallback용)
    final firebaseUser = ref.watch(currentUserProvider);

    // Reset member filter and completed section when group changes
    ref.listen(currentMembershipProvider, (previous, next) {
      if (previous?.groupId != next?.groupId) {
        ref.read(selectedMemberFilterProvider.notifier).state = null;
        ref.read(completedSectionExpandedProvider.notifier).state = false;
      }
    });

    final selectedMemberId = ref.watch(selectedMemberFilterProvider);
    
    // 필터된 할일
    final allTodos = ref.watch(smartTodosProvider);
    final todos = selectedMemberId == null
        ? allTodos
        : allTodos.where((t) => t.isAssignedTo(selectedMemberId)).toList();
    
    final pendingTodos = todos.where((t) => !t.isCompleted).toList();
    final completedTodos = todos.where((t) => t.isCompleted).toList()
      ..sort((a, b) {
        final aTime = a.completedAt ?? a.createdAt;
        final bTime = b.completedAt ?? b.createdAt;
        return bTime.compareTo(aTime); // 최근 완료된 것이 위로
      });
    final isCompletedExpanded = ref.watch(completedSectionExpandedProvider);

    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    // Check loading state - use AsyncValue for better loading detection
    final todosAsync = ref.watch(todosProvider);
    final isLoading = todosAsync.isLoading && allTodos.isEmpty;

    // Show shimmer during initial load, but with error fallback
    if (isLoading) {
      // todosProvider에 에러가 있으면 로딩 대신 에러 상태 표시
      if (todosAsync.hasError) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.warning_2, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text('데이터를 불러오지 못했어요',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(todosProvider),
                    icon: const Icon(Iconsax.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(
        body: SafeArea(
          child: HomeScreenShimmer(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 프로필 아바타 + 그룹 선택기 (최상단)
                    Row(
                      children: [
                        if (currentMember != null)
                          MemberAvatar(
                            member: currentMember,
                            size: 48,
                          ).animate().fadeIn(duration: 300.ms),
                        const Spacer(),
                        // 그룹 선택기
                        const GroupSelector()
                            .animate()
                            .fadeIn(duration: 300.ms, delay: 100.ms),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    // 인사말 (별도 줄)
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 150.ms),
                    const SizedBox(height: 2),
                    // 사용자 이름 (강조) - 멤버십 이름 → Firebase 이름 → 기본값 순서
                    Text(
                      '${currentMember?.name ?? firebaseUser?.displayName ?? '사용자'}님',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(begin: -0.05),
                    const SizedBox(height: 4),
                    // 날짜
                    Text(
                      DateFormat('M월 d일 EEEE', 'ko_KR').format(now),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 250.ms),
                  ],
                ),
              ),
            ),

            // AI 요약 카드
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                child: const AiSummaryCard()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.1),
              ),
            ),

            // 구성원 필터
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingL),
                child: MemberAvatarList(
                  members: members,
                  selectedMemberId: selectedMemberId,
                  onMemberSelected: (id) {
                    ref.read(selectedMemberFilterProvider.notifier).state = id;
                  },
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
              ),
            ),

            // 할일 섹션 타이틀
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '할 일 (${pendingTodos.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (completedTodos.isNotEmpty)
                      Text(
                        '완료 ${completedTodos.length}개',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
              ),
            ),

            // 할일 목록 (컴팩트 카드 - 더 많이 표시)
            if (pendingTodos.isEmpty)
              SliverToBoxAdapter(
                child: TodoEmptyState(
                  onAdd: () => _showAddTodoSheet(context, isQuickMode: true),
                ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final todo = pendingTodos[index];
                    final member = _findMember(members, todo.assigneeId);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                      ),
                      child: CompactTodoCard(
                        todo: todo,
                        assignee: member,
                      ).animate().fadeIn(
                            duration: 200.ms,
                            delay: Duration(milliseconds: 50 * index),
                          ),
                    );
                  },
                  childCount: pendingTodos.length > 10 ? 10 : pendingTodos.length,
                ),
              ),

            // 더보기 버튼 (할일이 10개 초과시)
            if (pendingTodos.length > 10)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                  child: TextButton(
                    onPressed: () {
                      context.go('/todos');
                    },
                    child: Text('${pendingTodos.length - 10}개 더보기'),
                  ),
                ),
              ),

            // 완료된 할일 섹션 (접기/펼치기)
            if (completedTodos.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                  child: _CompletedSection(
                    completedTodos: completedTodos,
                    members: members,
                    isExpanded: isCompletedExpanded,
                    onToggle: () {
                      ref.read(completedSectionExpandedProvider.notifier).state =
                          !isCompletedExpanded;
                    },
                  ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
                ),
              ),

            // 다가오는 일정
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: const UpcomingEventsCard()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 700.ms)
                    .slideY(begin: 0.1),
              ),
            ),

            // 하단 여백
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () => _showAddTodoSheet(context, isQuickMode: false),
        child: FloatingActionButton(
          onPressed: () => _showAddTodoSheet(context, isQuickMode: true),
          tooltip: '탭: 빠른 추가 | 길게 누르기: 자세히',
          child: const Icon(Iconsax.add),
        ),
      ).animate().scale(delay: 800.ms, duration: 300.ms),
    );
  }

  dynamic _findMember(List members, String? memberId) {
    if (memberId == null || members.isEmpty) return null;
    try {
      return members.firstWhere((m) => m.id == memberId);
    } catch (e) {
      return null;
    }
  }

  String _getGreeting(int hour) {
    if (hour < 6) return '좋은 밤이에요';
    if (hour < 12) return '좋은 아침이에요';
    if (hour < 18) return '좋은 오후에요';
    return '좋은 저녁이에요';
  }

  void _showAddTodoSheet(BuildContext context, {bool isQuickMode = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTodoSheet(isQuickMode: isQuickMode),
    );
  }
}

/// 완료된 할일 섹션 위젯
class _CompletedSection extends StatelessWidget {
  final List completedTodos;
  final List members;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CompletedSection({
    required this.completedTodos,
    required this.members,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spacingM),
        // 섹션 헤더 (접기/펼치기)
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacingS,
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.tick_circle,
                  size: 18,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 8),
                Text(
                  '완료됨 (${completedTodos.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Iconsax.arrow_down_1,
                    size: 18,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 완료된 할일 목록 (펼쳐졌을 때만 표시)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: AppTheme.spacingXS),
              ...completedTodos.map((todo) {
                final member = _findMember(members, todo.assigneeId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
                  child: CompactTodoCard(
                    todo: todo,
                    assignee: member,
                  ),
                );
              }),
              if (completedTodos.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingXS),
                  child: Text(
                    '외 ${completedTodos.length - 5}개',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                  ),
                ),
            ],
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  dynamic _findMember(List members, String? memberId) {
    if (memberId == null || members.isEmpty) return null;
    try {
      return members.firstWhere((m) => m.id == memberId);
    } catch (e) {
      return null;
    }
  }
}
