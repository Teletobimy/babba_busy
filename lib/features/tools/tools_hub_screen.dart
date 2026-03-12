import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/module_provider.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/album_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/models/album.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/transaction.dart';
import '../../shared/utils/chat_attachment_policy.dart';
import '../album/widgets/add_album_sheet.dart';
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
    final savedIndex = ref.read(selectedToolTabProvider);
    final length = activeModules.isEmpty ? 1 : activeModules.length;
    final initialIndex = activeModules.isEmpty
        ? 0
        : savedIndex.clamp(0, activeModules.length - 1).toInt();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: initialIndex,
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
    // indexIsChanging 조건 제거 - 스와이프/탭 클릭 모두 동기화
    ref.read(selectedToolTabProvider.notifier).state = _tabController.index;
  }

  @override
  Widget build(BuildContext context) {
    final activeModules = ref.watch(activeModulesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    // 활성화된 모듈이 변경되면 탭 컨트롤러 재생성
    if (_tabController.length != activeModules.length) {
      final savedIndex = ref.read(selectedToolTabProvider);
      _tabController.removeListener(_handleTabChange);
      _tabController.dispose();
      final initialIndex = savedIndex
          .clamp(0, activeModules.length - 1)
          .toInt();
      _tabController = TabController(
        length: activeModules.length,
        vsync: this,
        initialIndex: initialIndex,
      );
      _tabController.addListener(_handleTabChange);
      ref.read(selectedToolTabProvider.notifier).state = initialIndex;
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
                  const SizedBox(height: AppTheme.spacingS),
                  // 빠른 바로가기
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickLinkChip(
                          icon: Iconsax.chart_1,
                          label: '리포트',
                          onTap: () => context.push('/reports'),
                        ),
                        const SizedBox(width: 8),
                        _QuickLinkChip(
                          icon: Iconsax.people,
                          label: '함께하는 시간',
                          onTap: () => context.push('/together-time'),
                        ),
                        const SizedBox(width: 8),
                        _QuickLinkChip(
                          icon: Iconsax.refresh,
                          label: '집안일 로테이션',
                          onTap: () => context.push('/chore-rotation'),
                        ),
                        const SizedBox(width: 8),
                        _QuickLinkChip(
                          icon: Iconsax.calendar_1,
                          label: '시간표',
                          onTap: () => context.push('/timetable'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  // 탭바 (2줄 배치)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(activeModules.length, (index) {
                        final module = activeModules[index];
                        final isSelected = _tabController.index == index;
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _tabController.animateTo(index);
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _getModuleColor(module)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
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
                                                  : AppColors
                                                        .textSecondaryLight),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
      case AppModule.album:
        return const _AlbumContent();
      case AppModule.budget:
        return const _BudgetContent();
      case AppModule.people:
        return const PeopleScreen();
      case AppModule.chat:
        return const _ChatContent();
      case AppModule.community:
        return const _CommunityContent();
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
      case AppModule.album:
        return Iconsax.gallery;
      case AppModule.budget:
        return Iconsax.wallet_3;
      case AppModule.people:
        return Iconsax.people;
      case AppModule.chat:
        return Iconsax.message;
      case AppModule.community:
        return Iconsax.hashtag;
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
      case AppModule.album:
        return AppColors.memoryColor;
      case AppModule.budget:
        return AppColors.budgetColor;
      case AppModule.people:
        return AppColors.peopleColor;
      case AppModule.chat:
        return AppColors.chatColor;
      case AppModule.community:
        return AppColors.communityColor;
      case AppModule.business:
        return AppColors.coral[500]!;
      case AppModule.psychology:
        return AppColors.lavender[500]!;
    }
  }
}

/// 앨범 콘텐츠 (AlbumScreen 내부 내용만)
class _AlbumContent extends ConsumerWidget {
  const _AlbumContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AlbumScreenContent();
  }
}

/// AlbumScreen의 내용만 추출 (Scaffold 제외)
class _AlbumScreenContent extends ConsumerWidget {
  const _AlbumScreenContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(albumViewModeProvider);
    final selectedType = ref.watch(selectedAlbumTypeProvider);
    final albums = ref.watch(filteredAlbumsProvider);
    final allAlbums = ref.watch(combinedAlbumsProvider);

    return Stack(
      children: [
        Column(
          children: [
            // 상단 정보 + 뷰 모드 전환
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingS,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${albums.length}개의 앨범',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.memoryColor,
                    ),
                  ),
                  PopupMenuButton<AlbumViewMode>(
                    icon: Icon(_getViewModeIcon(viewMode), size: 20),
                    onSelected: (mode) {
                      ref.read(albumViewModeProvider.notifier).state = mode;
                    },
                    itemBuilder: (context) => AlbumViewMode.values
                        .map(
                          (mode) => PopupMenuItem(
                            value: mode,
                            child: Row(
                              children: [
                                Icon(
                                  _getViewModeIcon(mode),
                                  size: 20,
                                  color: viewMode == mode
                                      ? AppColors.memoryColor
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  mode.label,
                                  style: TextStyle(
                                    color: viewMode == mode
                                        ? AppColors.memoryColor
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            // 타입 필터
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
              ),
              child: Row(
                children: [
                  _AlbumTypeChip(
                    label: '전체',
                    count: allAlbums.length,
                    isSelected: selectedType == null,
                    onTap: () =>
                        ref.read(selectedAlbumTypeProvider.notifier).state =
                            null,
                  ),
                  const SizedBox(width: 8),
                  ...AlbumType.values.map((type) {
                    final count = allAlbums
                        .where((a) => a.albumType == type)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AlbumTypeChip(
                        label: type.label,
                        count: count,
                        isSelected: selectedType == type,
                        onTap: () =>
                            ref.read(selectedAlbumTypeProvider.notifier).state =
                                type,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            // 콘텐츠
            Expanded(child: _buildAlbumContent(context, ref, viewMode, albums)),
          ],
        ),
        // FAB
        Positioned(
          right: AppTheme.spacingL,
          bottom: AppTheme.spacingL,
          child: FloatingActionButton(
            heroTag: 'album_fab',
            onPressed: () => _showAddAlbumSheet(context),
            backgroundColor: AppColors.memoryColor,
            child: const Icon(Iconsax.add),
          ),
        ),
      ],
    );
  }

  IconData _getViewModeIcon(AlbumViewMode mode) {
    switch (mode) {
      case AlbumViewMode.timeline:
        return Iconsax.calendar_1;
      case AlbumViewMode.person:
        return Iconsax.people;
      case AlbumViewMode.location:
        return Iconsax.location;
    }
  }

  Widget _buildAlbumContent(
    BuildContext context,
    WidgetRef ref,
    AlbumViewMode viewMode,
    List<Album> albums,
  ) {
    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.gallery,
              size: 64,
              color: AppColors.memoryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text('앨범을 추가해보세요', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    // 시간순 뷰 (기본)
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.memoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Iconsax.gallery, color: AppColors.memoryColor),
                  const Spacer(),
                  if (album.sharedGroups.isNotEmpty)
                    Icon(Iconsax.share, size: 14, color: AppColors.memoryColor),
                ],
              ),
              const Spacer(),
              Text(
                album.title,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                album.albumType.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.memoryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddAlbumSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddAlbumSheet(),
    );
  }
}

class _AlbumTypeChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlbumTypeChip({
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
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: isDark
                      ? AppTheme.softShadowDark
                      : AppTheme.softShadowLight,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '수입',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                          Text(
                            '지출',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                          Text(
                            '잔액',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                        horizontal: AppTheme.spacingL,
                      ),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final t = transactions[index];
                        return ListTile(
                          onTap: () => _showEditTransactionSheet(context, t),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.getCategoryColor(
                              t.category,
                            ).withValues(alpha: 0.2),
                            child: Icon(
                              t.isIncome
                                  ? Iconsax.arrow_down
                                  : Iconsax.arrow_up,
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

  void _showEditTransactionSheet(
    BuildContext context,
    BudgetTransaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(transaction: transaction),
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
  bool _isUploadingAttachment = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    // 초기 로드 시 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ChatContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 메시지가 추가되면 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendMessage() async {
    if (_isUploadingAttachment) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Firebase에 메시지 저장
      await ref.read(chatServiceProvider).sendMessage(content: text);
      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      _showSnackBar('메시지 전송 실패: $e');
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_isUploadingAttachment) return;

    final allowedExtensions = ChatAttachmentPolicy.allowedExtensions.toList()
      ..sort();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnackBar('파일을 읽을 수 없습니다. 다시 시도해주세요.');
      return;
    }

    if (ChatAttachmentPolicy.isBlocked(file.name)) {
      _showSnackBar('보안상 허용되지 않는 파일 형식입니다.');
      return;
    }

    if (!ChatAttachmentPolicy.isAllowed(file.name)) {
      _showSnackBar('지원하지 않는 파일 형식입니다.');
      return;
    }

    if (!ChatAttachmentPolicy.isWithinSizeLimit(bytes.length)) {
      _showSnackBar(
        '파일 용량은 ${ChatAttachmentPolicy.formatBytes(ChatAttachmentPolicy.maxAttachmentBytes)} 이하만 업로드할 수 있습니다.',
      );
      return;
    }

    setState(() {
      _isUploadingAttachment = true;
      _uploadProgress = 0;
    });

    try {
      final initialText = _messageController.text;
      final caption = initialText.trim();
      await ref
          .read(chatServiceProvider)
          .sendAttachmentMessage(
            bytes: bytes,
            fileName: file.name,
            caption: caption.isEmpty ? null : caption,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _uploadProgress = progress.clamp(0, 1);
              });
            },
          );

      if (_messageController.text == initialText) {
        _messageController.clear();
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      _showSnackBar('첨부 업로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
          _uploadProgress = 0;
        });
      }
    }
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
                bottom: BorderSide(color: chatColor.withValues(alpha: 0.2)),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                    return _ChatBubble(message: message, isMe: isMe);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isUploadingAttachment)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        child: LinearProgressIndicator(
                          value: _uploadProgress <= 0 ? null : _uploadProgress,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight,
                          color: chatColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _uploadProgress > 0
                            ? '업로드 중... ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                            : '업로드 준비 중...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    onPressed: _isUploadingAttachment
                        ? null
                        : _pickAndSendAttachment,
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: chatColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.attach_file,
                        color: chatColor,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
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
                    onPressed: _isUploadingAttachment ? null : _sendMessage,
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

  Future<void> _openAttachment(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파일을 열 수 없습니다.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파일 열기에 실패했습니다.')));
      }
    }
  }

  Color _messageTextColor(bool isDark) {
    if (isMe) return Colors.white;
    return isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  }

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
              style: TextStyle(color: chatColor, fontSize: 12),
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
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
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
              child: _ChatMessageBody(
                message: message,
                isMe: isMe,
                isDark: isDark,
                textColor: _messageTextColor(isDark),
                onOpenAttachment: (url) => _openAttachment(context, url),
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

class _ChatMessageBody extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;
  final Color textColor;
  final void Function(String url) onOpenAttachment;

  const _ChatMessageBody({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.textColor,
    required this.onOpenAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final attachmentUrl = message.attachmentUrl ?? message.imageUrl;
    final trimmedContent = message.content.trim();
    final hasImagePlaceholder = trimmedContent == '사진';
    final hasFileNameOnly =
        message.attachmentName != null &&
        trimmedContent == message.attachmentName;
    final hasCaption =
        trimmedContent.isNotEmpty && !hasImagePlaceholder && !hasFileNameOnly;

    if (message.type == MessageType.image &&
        attachmentUrl != null &&
        attachmentUrl.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onOpenAttachment(attachmentUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                attachmentUrl,
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 220,
                  height: 220,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: isMe ? Colors.white70 : Colors.black45,
                  ),
                ),
              ),
            ),
          ),
          if (hasCaption) ...[
            const SizedBox(height: 8),
            Text(message.content, style: TextStyle(color: textColor)),
          ],
        ],
      );
    }

    if (message.type == MessageType.file &&
        attachmentUrl != null &&
        attachmentUrl.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AttachmentFileCard(
            fileName: message.attachmentName ?? '첨부파일',
            mimeType: message.attachmentMimeType,
            fileSizeBytes: message.attachmentSizeBytes,
            isMe: isMe,
            isDark: isDark,
            onTap: () => onOpenAttachment(attachmentUrl),
          ),
          if (hasCaption) ...[
            const SizedBox(height: 8),
            Text(message.content, style: TextStyle(color: textColor)),
          ],
        ],
      );
    }

    return Text(message.content, style: TextStyle(color: textColor));
  }
}

class _AttachmentFileCard extends StatelessWidget {
  final String fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final bool isMe;
  final bool isDark;
  final VoidCallback onTap;

  const _AttachmentFileCard({
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.isMe,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extension = ChatAttachmentPolicy.extractExtension(
      fileName,
    ).toUpperCase();
    final typeLabel = extension.isEmpty
        ? (mimeType?.split('/').last.toUpperCase() ?? 'FILE')
        : extension;
    final sizeLabel = fileSizeBytes != null
        ? ChatAttachmentPolicy.formatBytes(fileSizeBytes!)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.16)
                : (isDark ? AppColors.backgroundDark : Colors.white),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.35)
                  : (isDark ? Colors.white24 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 20,
                color: isMe
                    ? Colors.white
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      sizeLabel == null ? typeLabel : '$typeLabel • $sizeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white70
                            : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: isMe
                    ? Colors.white70
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 커뮤니티 콘텐츠
class _CommunityContent extends StatelessWidget {
  const _CommunityContent();

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
                color: AppColors.communityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Iconsax.hashtag,
                size: 40,
                color: AppColors.communityColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              '커뮤니티',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              '테마별로 여러 게시판을 만들고\n글/댓글로 소통해보세요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () => context.push('/tools/community'),
              icon: const Icon(Iconsax.play),
              label: const Text('커뮤니티 열기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.communityColor,
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
class _QuickLinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
      side: BorderSide(
        color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
            .withValues(alpha: 0.2),
      ),
    );
  }
}

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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
