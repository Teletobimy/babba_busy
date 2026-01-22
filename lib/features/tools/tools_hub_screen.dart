import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/module_provider.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/memory_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/models/memory.dart';
import '../../shared/models/chat_message.dart';
import '../memory/memory_screen.dart';
import '../memory/widgets/add_memory_sheet.dart';
import '../budget/widgets/add_transaction_sheet.dart';
import '../people/people_screen.dart';
import '../memo/memo_screen.dart';
import 'package:go_router/go_router.dart';

/// 현재 선택된 도구 탭 인덱스
final selectedToolTabProvider = StateProvider<int>((ref) => 0);

class ToolsHubScreen extends ConsumerStatefulWidget {
  const ToolsHubScreen({super.key});

  @override
  ConsumerState<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends ConsumerState<ToolsHubScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final activeModules = ref.read(activeModulesProvider);
    _tabController = TabController(
      length: activeModules.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      ref.read(selectedToolTabProvider.notifier).state = _tabController.index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeModules = ref.watch(activeModulesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 활성화된 모듈이 변경되면 탭 컨트롤러 재생성
    if (_tabController.length != activeModules.length) {
      _tabController.removeListener(_handleTabChange);
      _tabController.dispose();
      _tabController = TabController(
        length: activeModules.length,
        vsync: this,
        initialIndex: 0,
      );
      _tabController.addListener(_handleTabChange);
    }

    // 활성화된 모듈이 없으면
    if (activeModules.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.box_1,
                  size: 64,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  '활성화된 도구가 없습니다',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  '설정에서 도구를 활성화해주세요',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 헤더 + 탭바
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingL,
                AppTheme.spacingL,
                AppTheme.spacingL,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '도구',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: AppTheme.spacingM),
                  // 탭바 (2줄 배치)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(activeModules.length, (index) {
                        final module = activeModules[index];
                        final isSelected = _tabController.index == index;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _tabController.animateTo(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _getModuleColor(module)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getModuleIcon(module),
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  module.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
                ],
              ),
            ),
            // 탭 콘텐츠
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: activeModules.map((module) {
                  return _buildModuleContent(module);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleContent(AppModule module) {
    switch (module) {
      case AppModule.memo:
        return const MemoContent();
      case AppModule.memory:
        return const _MemoryContent();
      case AppModule.budget:
        return const _BudgetContent();
      case AppModule.people:
        return const PeopleScreen();
      case AppModule.chat:
        return const _ChatContent();
      case AppModule.business:
        return const _BusinessContent();
      case AppModule.psychology:
        return const _PsychologyContent();
    }
  }

  IconData _getModuleIcon(AppModule module) {
    switch (module) {
      case AppModule.memo:
        return Iconsax.note_1;
      case AppModule.memory:
        return Iconsax.map_1;
      case AppModule.budget:
        return Iconsax.wallet_3;
      case AppModule.people:
        return Iconsax.people;
      case AppModule.chat:
        return Iconsax.message;
      case AppModule.business:
        return Iconsax.briefcase;
      case AppModule.psychology:
        return Iconsax.heart;
    }
  }

  Color _getModuleColor(AppModule? module) {
    if (module == null) return AppColors.primaryLight;
    switch (module) {
      case AppModule.memo:
        return AppColors.memoColor;
      case AppModule.memory:
        return AppColors.memoryColor;
      case AppModule.budget:
        return AppColors.budgetColor;
      case AppModule.people:
        return AppColors.peopleColor;
      case AppModule.chat:
        return AppColors.chatColor;
      case AppModule.business:
        return AppColors.coral[500]!;
      case AppModule.psychology:
        return AppColors.lavender[500]!;
    }
  }

}

/// 추억 콘텐츠 (MemoryScreen 내부 내용만)
class _MemoryContent extends ConsumerWidget {
  const _MemoryContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MemoryScreen의 body 내용을 그대로 사용하되, Scaffold 없이
    return const _MemoryScreenContent();
  }
}

/// MemoryScreen의 내용만 추출 (Scaffold 제외)
class _MemoryScreenContent extends ConsumerWidget {
  const _MemoryScreenContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapView = ref.watch(memoryViewModeProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final allMemories = ref.watch(smartMemoriesProvider);
    final memories = selectedCategory == null
        ? allMemories
        : allMemories.where((m) => m.category == selectedCategory).toList();

    return Stack(
      children: [
        Column(
          children: [
            // 상단 정보 + 필터
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingS,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${memories.length}개의 추억',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.memoryColor,
                        ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(memoryViewModeProvider.notifier).state = !isMapView;
                    },
                    icon: Icon(
                      isMapView ? Iconsax.grid_1 : Iconsax.map_1,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // 카테고리 필터
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                children: [
                  _MemoryCategoryChip(
                    label: '전체',
                    count: allMemories.length,
                    isSelected: selectedCategory == null,
                    onTap: () =>
                        ref.read(selectedCategoryProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  ...MemoryCategory.all.map((category) {
                    final count =
                        allMemories.where((m) => m.category == category).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _MemoryCategoryChip(
                        label: MemoryCategory.getLabel(category),
                        count: count,
                        isSelected: selectedCategory == category,
                        onTap: () => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = category,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            // 콘텐츠
            Expanded(
              child: isMapView
                  ? _buildMapView(context, memories)
                  : _buildTimelineView(context, ref, memories),
            ),
          ],
        ),
        // FAB
        Positioned(
          right: AppTheme.spacingL,
          bottom: AppTheme.spacingL,
          child: FloatingActionButton(
            heroTag: 'memory_fab',
            onPressed: () => _showAddMemorySheet(context),
            backgroundColor: AppColors.memoryColor,
            child: const Icon(Iconsax.add),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView(BuildContext context, List<Memory> memories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.map_1,
            size: 64,
            color: AppColors.memoryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            '지도 뷰',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '총 ${memories.length}개의 추억',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.memoryColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(BuildContext context, WidgetRef ref, List<Memory> memories) {
    if (memories.isEmpty) {
      return const Center(child: Text('추억을 추가해보세요'));
    }
    // 간단한 그리드 뷰
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.memoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconsax.gallery, color: AppColors.memoryColor),
              const Spacer(),
              Text(
                memory.title,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                memory.placeName,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMemorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddMemorySheet(),
    );
  }
}

class _MemoryCategoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemoryCategoryChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.memoryColor
              : AppColors.memoryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.memoryColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 가계부 콘텐츠 (BudgetScreen 내부 내용만)
class _BudgetContent extends ConsumerWidget {
  const _BudgetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _BudgetScreenContent();
  }
}

/// BudgetScreen 내용 추출
class _BudgetScreenContent extends ConsumerWidget {
  const _BudgetScreenContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(smartMonthSummaryProvider);
    final transactions = ref.watch(smartThisMonthTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numberFormat = NumberFormat('#,###', 'ko_KR');

    return Stack(
      children: [
        Column(
          children: [
            // 요약 카드
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow:
                      isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('수입',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            '${numberFormat.format(summary.totalIncome)}원',
                            style: TextStyle(
                              color: AppColors.successLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('지출',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            '${numberFormat.format(summary.totalExpense)}원',
                            style: TextStyle(
                              color: AppColors.errorLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('잔액',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            '${numberFormat.format(summary.balance)}원',
                            style: TextStyle(
                              color: AppColors.budgetColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 거래 내역
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(
                        '이번 달 거래 내역이 없습니다',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingL),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final t = transactions[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.getCategoryColor(t.category)
                                    .withValues(alpha: 0.2),
                            child: Icon(
                              t.isIncome ? Iconsax.arrow_down : Iconsax.arrow_up,
                              color: AppColors.getCategoryColor(t.category),
                              size: 20,
                            ),
                          ),
                          title: Text(t.memo ?? ''),
                          subtitle: Text(
                            DateFormat('M/d').format(t.date),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Text(
                            '${t.isIncome ? '+' : '-'}${numberFormat.format(t.amount)}원',
                            style: TextStyle(
                              color: t.isIncome
                                  ? AppColors.successLight
                                  : AppColors.errorLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        // FAB
        Positioned(
          right: AppTheme.spacingL,
          bottom: AppTheme.spacingL,
          child: FloatingActionButton(
            heroTag: 'budget_fab',
            onPressed: () => _showAddTransactionSheet(context),
            backgroundColor: AppColors.budgetColor,
            child: const Icon(Iconsax.add),
          ),
        ),
      ],
    );
  }

  void _showAddTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(),
    );
  }
}

/// 대화방 콘텐츠
class _ChatContent extends ConsumerStatefulWidget {
  const _ChatContent();

  @override
  ConsumerState<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends ConsumerState<_ChatContent> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Firebase에 메시지 저장
    ref.read(chatServiceProvider).sendMessage(content: text);

    _messageController.clear();

    // 스크롤을 맨 아래로
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const chatColor = Color(0xFF9B59B6);

    // Provider에서 메시지 목록 가져오기
    final messages = ref.watch(smartChatMessagesProvider);
    final currentUserId = ref.watch(smartCurrentUserIdProvider);
    final currentFamily = ref.watch(smartCurrentFamilyProvider);

    return Column(
      children: [
        // 그룹 정보 헤더
        if (currentFamily != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: chatColor.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: chatColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Iconsax.people, size: 16, color: chatColor),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  currentFamily.name,
                  style: TextStyle(
                    color: chatColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        // 메시지 목록
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.message,
                        size: 64,
                        color: chatColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Text(
                        '아직 메시지가 없습니다',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        '첫 메시지를 보내보세요!',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    return _ChatBubble(
                      message: message,
                      isMe: isMe,
                    );
                  },
                ),
        ),
        // 입력창
        Container(
          padding: EdgeInsets.only(
            left: AppTheme.spacingM,
            right: AppTheme.spacingM,
            top: AppTheme.spacingS,
            bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingS,
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
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              IconButton(
                onPressed: _sendMessage,
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: chatColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.send_1,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 채팅 버블 위젯 - ChatMessage 모델 사용
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const chatColor = Color(0xFF9B59B6);

    // 시스템 메시지
    if (message.type == MessageType.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: chatColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: chatColor,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacingS,
                  bottom: 2,
                ),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? chatColor
                    : (isDark ? AppColors.surfaceDark : Colors.grey[200]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isMe
                      ? Colors.white
                      : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 2,
                left: AppTheme.spacingS,
                right: AppTheme.spacingS,
              ),
              child: Text(
                message.formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사업검토 콘텐츠
class _BusinessContent extends StatelessWidget {
  const _BusinessContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.coral[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Iconsax.briefcase,
                size: 40,
                color: AppColors.coral[600],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'AI 사업 검토',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              '7개의 AI 전문가 에이전트가\n당신의 사업 아이디어를 분석합니다',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () => context.push('/tools/business'),
              icon: const Icon(Iconsax.play),
              label: const Text('시작하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral[500],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 심리검사 콘텐츠
class _PsychologyContent extends StatelessWidget {
  const _PsychologyContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lavender[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Iconsax.heart,
                size: 40,
                color: AppColors.lavender[600],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              '심리검사',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              '7종의 과학적인 심리검사로\n나를 더 잘 이해해보세요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () => context.push('/tools/psychology'),
              icon: const Icon(Iconsax.play),
              label: const Text('시작하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lavender[500],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

