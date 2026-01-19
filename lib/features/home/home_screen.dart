import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/widgets/member_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../todo/widgets/add_todo_sheet.dart';
import 'widgets/ai_summary_card.dart';
import 'widgets/upcoming_events_card.dart';
import 'widgets/compact_todo_card.dart';
import '../../shared/widgets/group_selector.dart';

/// 선택된 구성원 필터
final selectedMemberFilterProvider = StateProvider<String?>((ref) => null);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Smart Provider 사용 - 데모/실제 데이터 자동 선택
    final currentMember = ref.watch(smartCurrentMemberProvider);
    final currentFamily = ref.watch(smartCurrentFamilyProvider);
    final members = ref.watch(smartMembersProvider);
    
    final selectedMemberId = ref.watch(selectedMemberFilterProvider);
    
    // 필터된 할일
    final allTodos = ref.watch(smartTodosProvider);
    final todos = selectedMemberId == null 
        ? allTodos 
        : allTodos.where((t) => t.assigneeId == selectedMemberId).toList();
    
    final pendingTodos = todos.where((t) => !t.isCompleted).toList();
    final completedTodos = todos.where((t) => t.isCompleted).toList();

    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

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
                    // 인사말 + 날짜
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting, ${currentMember?.name ?? '사용자'}님',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('M월 d일 EEEE', 'ko_KR').format(now),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
                            ],
                          ),
                        ),
                        // 그룹 선택기
                        const GroupSelector()
                            .animate()
                            .fadeIn(duration: 300.ms, delay: 200.ms),
                      ],
                    ),
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
                  onAdd: () => _showAddTodoSheet(context),
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
                      // TODO: 할일 전체보기 화면으로 이동
                    },
                    child: Text('${pendingTodos.length - 10}개 더보기'),
                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoSheet(context),
        child: const Icon(Iconsax.add),
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

  void _showAddTodoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTodoSheet(),
    );
  }
}
