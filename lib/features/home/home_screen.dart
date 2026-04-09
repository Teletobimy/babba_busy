import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/ai_feature_flag_provider.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/group_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/todo_provider.dart';
import '../../shared/services/ai_telemetry_service.dart';
import '../../shared/widgets/member_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../todo/widgets/add_todo_sheet.dart';
import 'providers/home_filters.dart';
import 'widgets/ai_home_action_entry_sheet.dart';
import 'widgets/ai_reminder_create_sheet.dart';
import 'widgets/ai_summary_card.dart';
import 'widgets/ai_todo_action_sheet.dart';
import 'widgets/ai_todo_complete_sheet.dart';
import 'widgets/upcoming_events_card.dart';
import 'widgets/compact_todo_card.dart';
import 'widgets/activity_feed_card.dart';
import 'widgets/couple_card.dart';
import 'widgets/dday_card.dart';
import '../../shared/widgets/group_selector.dart';
import '../../shared/providers/streak_provider.dart';

/// 완료 섹션 펼침 상태
final completedSectionExpandedProvider = StateProvider<bool>((ref) => false);

/// 할일 더보기 상태
final showAllTodosProvider = StateProvider<bool>((ref) => false);

/// 홈 shimmer 타임아웃 (5초 후 강제 해제)
final _shimmerTimeoutProvider = FutureProvider<bool>((ref) async {
  await Future.delayed(const Duration(seconds: 5));
  return true;
});

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
        ref.read(showAllTodosProvider.notifier).state = false;
      }
    });

    final selectedMemberId = ref.watch(selectedMemberFilterProvider);

    // 필터된 할일
    final allTodos = ref.watch(smartTodosProvider);
    final todos = selectedMemberId == null
        ? allTodos
        : allTodos.where((t) => t.isAssignedTo(selectedMemberId)).toList();

    final pendingTodos = todos.where((t) => !t.isCompleted).toList()
      ..sort((a, b) {
        final aDate = a.dueDate ?? a.startTime;
        final bDate = b.dueDate ?? b.startTime;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1; // 날짜 없는 것 뒤로
        if (bDate == null) return -1;
        return aDate.compareTo(bDate); // 급한 것 먼저
      });
    final completedTodos = todos.where((t) => t.isCompleted).toList()
      ..sort((a, b) {
        final aTime = a.completedAt ?? a.createdAt;
        final bTime = b.completedAt ?? b.createdAt;
        return bTime.compareTo(aTime); // 최근 완료된 것이 위로
      });
    final isCompletedExpanded = ref.watch(completedSectionExpandedProvider);
    final showAllTodos = ref.watch(showAllTodosProvider);

    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final streak = ref.watch(streakProvider);

    // Check loading state - use AsyncValue for better loading detection
    final todosAsync = ref.watch(todosProvider);
    final shimmerTimedOut = ref.watch(_shimmerTimeoutProvider).value ?? false;
    final isLoading =
        todosAsync.isLoading && allTodos.isEmpty && !shimmerTimedOut;

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
                  Text(
                    '데이터를 불러오지 못했어요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
      return const Scaffold(body: SafeArea(child: HomeScreenShimmer()));
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
                        const GroupSelector().animate().fadeIn(
                          duration: 300.ms,
                          delay: 100.ms,
                        ),
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
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        )
                        .animate()
                        .fadeIn(duration: 300.ms, delay: 200.ms)
                        .slideX(begin: -0.05),
                    const SizedBox(height: 4),
                    // 날짜 + 스트릭
                    Row(
                      children: [
                        Text(
                          DateFormat('M월 d일 EEEE', 'ko_KR').format(now),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                        ),
                        if (streak > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Iconsax.flash_1,
                                  size: 12,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$streak일 연속',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ).animate().fadeIn(duration: 300.ms, delay: 250.ms),
                  ],
                ),
              ),
            ),

            // AI 요약 카드
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                ),
                child: const AiSummaryCard()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.1),
              ),
            ),

            // 커플 카드 (2인 그룹일 때만)
            if (members.length == 2)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.spacingL,
                    right: AppTheme.spacingL,
                    top: AppTheme.spacingM,
                  ),
                  child: const CoupleCard()
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 350.ms)
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
                    final member = _findAssignedMember(members, todo);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                      ),
                      child: CompactTodoCard(todo: todo, assignee: member)
                          .animate()
                          .fadeIn(
                            duration: 200.ms,
                            delay: Duration(
                              milliseconds: 50 * (index < 10 ? index : 10),
                            ),
                          ),
                    );
                  },
                  childCount: showAllTodos
                      ? pendingTodos.length
                      : (pendingTodos.length > 10 ? 10 : pendingTodos.length),
                ),
              ),

            // 더보기/접기 버튼 (할일이 10개 초과시)
            if (pendingTodos.length > 10)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                  ),
                  child: TextButton(
                    onPressed: () {
                      ref.read(showAllTodosProvider.notifier).state =
                          !showAllTodos;
                    },
                    child: Text(
                      showAllTodos ? '접기' : '${pendingTodos.length - 10}개 더보기',
                    ),
                  ),
                ),
              ),

            // 다가오는 일정
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: const UpcomingEventsCard()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 600.ms)
                    .slideY(begin: 0.1),
              ),
            ),

            // 최근 활동
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                ),
                child: const ActivityFeedCard().animate().fadeIn(
                  duration: 400.ms,
                  delay: 650.ms,
                ),
              ),
            ),

            // 완료된 할일 섹션 (접기/펼치기)
            if (completedTodos.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                  ),
                  child: _CompletedSection(
                    completedTodos: completedTodos,
                    members: members,
                    isExpanded: isCompletedExpanded,
                    onToggle: () {
                      ref
                              .read(completedSectionExpandedProvider.notifier)
                              .state =
                          !isCompletedExpanded;
                    },
                  ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
                ),
              ),

            // D-day 카운터
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                ),
                child: const DdayCard().animate().fadeIn(
                  duration: 400.ms,
                  delay: 750.ms,
                ),
              ),
            ),

            // 하단 여백
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: const _QuickAddBar().animate().slideY(
        begin: 1,
        duration: 300.ms,
        delay: 800.ms,
      ),
    );
  }

  dynamic _findAssignedMember(List members, dynamic todo) {
    if (members.isEmpty) return null;
    // assigneeId 확인
    if (todo.assigneeId != null) {
      try {
        return members.firstWhere((m) => m.id == todo.assigneeId);
      } catch (_) {}
    }
    // participants 확인
    for (final pid in todo.participants) {
      try {
        return members.firstWhere((m) => m.id == pid);
      } catch (_) {}
    }
    return null;
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

/// 하단 빠른 추가 바 (인라인 텍스트 입력)
class _QuickAddBar extends ConsumerStatefulWidget {
  const _QuickAddBar();

  @override
  ConsumerState<_QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<_QuickAddBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitQuickAdd() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    await ref.read(todoServiceProvider).addTodo(title: title);
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _isEditing = false);
  }

  Future<void> _openAiActionSheet() async {
    final aiFlags = ref.read(babbaAiFeatureFlagsProvider);
    final telemetry = ref.read(aiTelemetryServiceProvider);
    telemetry.logEntryTapped(
      toolName: BabbaAiTools.homeQuickActions,
      source: 'home_quick_add_ai',
      enabled: aiFlags.hasAnyHomeQuickActionAvailable,
      extra: {
        'todo_actions_enabled': aiFlags.todoActionsAvailable,
        'reminder_actions_enabled': aiFlags.reminderActionsAvailable,
      },
    );
    if (!aiFlags.hasAnyHomeQuickActionAvailable) {
      telemetry.logPreviewBlocked(
        toolName: BabbaAiTools.homeQuickActions,
        source: 'home_quick_add_ai',
        reason: aiFlags.homeQuickActionDisabledReason,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aiFlags.homeQuickActionDisabledReason)),
      );
      return;
    }

    final mode = await showAiHomeActionEntrySheet(
      context: context,
      initialPrompt: _controller.text.trim(),
      todoActionsEnabled: aiFlags.todoActionsAvailable,
      todoActionsDisabledReason: aiFlags.disabledReasonFor(
        BabbaAiCapability.todoActions,
      ),
      reminderActionsEnabled: aiFlags.reminderActionsAvailable,
      reminderActionsDisabledReason: aiFlags.disabledReasonFor(
        BabbaAiCapability.reminderActions,
      ),
    );
    if (!mounted || mode == null) return;

    if (mode == AiHomeActionEntryMode.todoCreate) {
      final result = await showAiTodoActionSheet(
        context: context,
        initialPrompt: _controller.text.trim(),
      );
      if (!mounted || result == null) return;

      if (result.created) {
        _controller.clear();
        _focusNode.unfocus();
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI가 "${result.title}" 개인 할 일을 추가했어요.')),
        );
      }
      return;
    }

    if (mode == AiHomeActionEntryMode.todoComplete) {
      final completeResult = await showAiTodoCompleteSheet(
        context: context,
        initialPrompt: _controller.text.trim(),
      );
      if (!mounted || completeResult == null) return;

      if (completeResult.completed) {
        _controller.clear();
        _focusNode.unfocus();
        setState(() => _isEditing = false);
        final message = completeResult.alreadyCompleted
            ? 'AI가 "${completeResult.title}" 할 일이 이미 완료된 상태라고 확인했어요.'
            : 'AI가 "${completeResult.title}" 개인 할 일을 완료 처리했어요.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    final reminderResult = await showAiReminderCreateSheet(
      context: context,
      initialPrompt: _controller.text.trim(),
    );
    if (!mounted || reminderResult == null) return;

    if (reminderResult.created) {
      _controller.clear();
      _focusNode.unfocus();
      setState(() => _isEditing = false);
      final whenLabel =
          (reminderResult.formattedRemindAt ?? '').trim().isNotEmpty
          ? ' ${reminderResult.formattedRemindAt!.trim()}에'
          : '';
      final recurrenceLabel =
          (reminderResult.recurrenceLabel ?? '').trim().isNotEmpty
          ? ' (${reminderResult.recurrenceLabel!.trim()})'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI가 "${reminderResult.message}" 리마인더를$whenLabel 등록했어요$recurrenceLabel.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiFlags = ref.watch(babbaAiFeatureFlagsProvider);
    final homeAiActionsEnabled = aiFlags.hasAnyHomeQuickActionAvailable;
    final aiButtonColor = homeAiActionsEnabled
        ? AppColors.primaryLight
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacingM,
        right: AppTheme.spacingM,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingS,
        top: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitQuickAdd(),
                    decoration: InputDecoration(
                      hintText: '할 일을 입력하세요',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _focusNode.unfocus();
                          setState(() => _isEditing = false);
                        },
                      ),
                    ),
                  )
                : Semantics(
                    label: '할 일 추가',
                    button: true,
                    child: GestureDetector(
                    onTap: () => setState(() => _isEditing = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        border: Border.all(
                          color:
                              (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight)
                                  .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.add_circle,
                            size: 20,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '할 일 추가...',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'AI 빠른 작업',
            button: true,
            child: IconButton(
            onPressed: _openAiActionSheet,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: aiButtonColor.withValues(
                  alpha: homeAiActionsEnabled ? 0.12 : 0.08,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(Iconsax.magic_star, color: aiButtonColor, size: 20),
            ),
          ),
          ),
          const SizedBox(width: 4),
          if (_isEditing)
            Semantics(
              label: '할 일 전송',
              button: true,
              child: IconButton(
                onPressed: _submitQuickAdd,
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Iconsax.send_1,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            )
          else
            Semantics(
              label: '새 할일 추가',
              button: true,
              child: IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddTodoSheet(isQuickMode: false),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(Iconsax.add, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 완료된 할일 섹션 위젯
class _CompletedSection extends StatefulWidget {
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
  State<_CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends State<_CompletedSection> {
  bool _showAll = false;

  dynamic _findAssignedMember(List members, dynamic todo) {
    if (members.isEmpty) return null;
    if (todo.assigneeId != null) {
      try {
        return members.firstWhere((m) => m.id == todo.assigneeId);
      } catch (_) {}
    }
    for (final pid in todo.participants) {
      try {
        return members.firstWhere((m) => m.id == pid);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visibleTodos = _showAll
        ? widget.completedTodos
        : widget.completedTodos.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spacingM),
        // 섹션 헤더 (접기/펼치기)
        GestureDetector(
          onTap: widget.onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
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
                  '완료됨 (${widget.completedTodos.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: widget.isExpanded ? 0.5 : 0,
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
              ...visibleTodos.map((todo) {
                final member = _findAssignedMember(widget.members, todo);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
                  child: CompactTodoCard(todo: todo, assignee: member),
                );
              }),
              if (!_showAll && widget.completedTodos.length > 5)
                TextButton(
                  onPressed: () => setState(() => _showAll = true),
                  child: Text('${widget.completedTodos.length - 5}개 더보기'),
                ),
            ],
          ),
          crossFadeState: widget.isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
