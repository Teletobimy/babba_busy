import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../services/ai/ai_api_service.dart';
import '../../shared/models/analysis_job.dart';
import '../../shared/models/memo.dart';
import '../../shared/models/memo_category.dart';
import '../../shared/providers/analysis_job_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/memo_provider.dart';
import '../tools/business/widgets/request_accepted_screen.dart';
import 'memo_category_utils.dart';
import 'widgets/memo_card.dart';
import 'widgets/memo_category_chip.dart';
import 'widgets/add_memo_sheet.dart';
import 'widgets/create_memo_category_dialog.dart';
import 'memo_detail_screen.dart';

/// 메모 뷰 모드 (목록/그리드)
final memoViewModeProvider = StateProvider<bool>(
  (ref) => false,
); // false = 목록, true = 그리드

/// 메모 메인 화면
class MemoScreen extends ConsumerWidget {
  const MemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Text(
                '메모',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ).animate().fadeIn(duration: 300.ms),
            // 콘텐츠
            const Expanded(child: _MemoContent()),
          ],
        ),
      ),
    );
  }
}

/// 메모 콘텐츠 (ToolsHub에서도 사용)
class MemoContent extends ConsumerWidget {
  const MemoContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MemoContent();
  }
}

class _MemoContent extends ConsumerWidget {
  const _MemoContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGridView = ref.watch(memoViewModeProvider);
    ref.watch(memoCategoryBootstrapProvider);
    final selectedCategoryId = ref.watch(smartSelectedMemoCategoryIdProvider);
    final categories = ref.watch(smartMemoCategoriesProvider);
    final allMemos = ref.watch(smartMemosProvider);
    final pinnedMemos = ref.watch(smartPinnedMemosProvider);
    final unpinnedMemos = ref.watch(smartUnpinnedMemosProvider);
    final selectedMemoCount = selectedCategoryId == null
        ? allMemos.length
        : pinnedMemos.length + unpinnedMemos.length;
    final selectedCategory = findMemoCategoryById(
      categories,
      selectedCategoryId,
    );

    return Stack(
      children: [
        Column(
          children: [
            // 상단 정보 + 뷰 모드 토글
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingS,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$selectedMemoCount개의 메모',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.memoColor),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '카테고리 분석 이력',
                        onPressed: () => _openCategoryAnalysisHistory(context),
                        icon: const Icon(Iconsax.document_text, size: 20),
                      ),
                      IconButton(
                        tooltip: selectedCategoryId == null
                            ? '전체 메모 분석 요청'
                            : '"${selectedCategory?.name ?? '카테고리'}" 분석 요청',
                        onPressed: () => _submitCategoryAnalysis(
                          context: context,
                          ref: ref,
                          categoryId: selectedCategoryId,
                          categoryName: selectedCategory?.name,
                          memoCount: selectedMemoCount,
                        ),
                        icon: Icon(
                          Iconsax.magic_star,
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ref.read(memoViewModeProvider.notifier).state =
                              !isGridView;
                        },
                        icon: Icon(
                          isGridView ? Iconsax.row_vertical : Iconsax.grid_1,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 카테고리 필터
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
              ),
              child: Row(
                children: [
                  MemoCategoryChip(
                    label: '전체',
                    count: allMemos.length,
                    isSelected: selectedCategoryId == null,
                    color: AppColors.memoColor,
                    onTap: () =>
                        ref
                                .read(
                                  smartSelectedMemoCategoryIdProvider.notifier,
                                )
                                .state =
                            null,
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((category) {
                    final count = allMemos
                        .where((m) => m.categoryId == category.id)
                        .length;
                    final color = parseMemoCategoryColor(category.color);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MemoCategoryChip(
                        label: category.name,
                        count: count,
                        isSelected: selectedCategoryId == category.id,
                        color: color,
                        icon: category.icon,
                        onTap: () =>
                            ref
                                .read(
                                  smartSelectedMemoCategoryIdProvider.notifier,
                                )
                                .state = category
                                .id,
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _createCategory(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.memoColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          border: Border.all(
                            color: AppColors.memoColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.add_circle,
                              size: 14,
                              color: AppColors.memoColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '카테고리+',
                              style: TextStyle(
                                color: AppColors.memoColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            // 콘텐츠
            Expanded(
              child: isGridView
                  ? _buildGridView(
                      context,
                      ref,
                      pinnedMemos,
                      unpinnedMemos,
                      categories,
                    )
                  : _buildListView(context, ref, pinnedMemos, unpinnedMemos),
            ),
          ],
        ),
        // FAB
        Positioned(
          right: AppTheme.spacingL,
          bottom: AppTheme.spacingL,
          child: FloatingActionButton(
            heroTag: 'memo_fab',
            onPressed: () => _showAddMemoSheet(context),
            backgroundColor: AppColors.memoColor,
            child: const Icon(Iconsax.add),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    List<Memo> pinnedMemos,
    List<Memo> unpinnedMemos,
  ) {
    if (pinnedMemos.isEmpty && unpinnedMemos.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      children: [
        // 고정된 메모
        if (pinnedMemos.isNotEmpty) ...[
          _buildSectionHeader(context, '고정됨', Iconsax.attach_circle5),
          const SizedBox(height: AppTheme.spacingS),
          ...pinnedMemos.map(
            (memo) => MemoCard(
              memo: memo,
              onTap: () => _openMemoDetail(context, memo),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
        ],
        // 일반 메모
        if (unpinnedMemos.isNotEmpty) ...[
          if (pinnedMemos.isNotEmpty)
            _buildSectionHeader(context, '메모', Iconsax.note),
          if (pinnedMemos.isNotEmpty) const SizedBox(height: AppTheme.spacingS),
          ...unpinnedMemos.map(
            (memo) => MemoCard(
              memo: memo,
              onTap: () => _openMemoDetail(context, memo),
            ),
          ),
        ],
        // 하단 여백 (FAB 공간)
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildGridView(
    BuildContext context,
    WidgetRef ref,
    List<Memo> pinnedMemos,
    List<Memo> unpinnedMemos,
    List<MemoCategory> categories,
  ) {
    if (pinnedMemos.isEmpty && unpinnedMemos.isEmpty) {
      return _buildEmptyState(context);
    }

    final allMemos = [...pinnedMemos, ...unpinnedMemos];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: allMemos.length + 1, // +1 for FAB space
      itemBuilder: (context, index) {
        if (index == allMemos.length) {
          return const SizedBox(height: 80);
        }

        final memo = allMemos[index];
        final matchedCategory = findMemoCategoryById(
          categories,
          memo.categoryId,
        );
        final categoryColor = parseMemoCategoryColor(matchedCategory?.color);
        final categoryName = matchedCategory?.name ?? memo.categoryName;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () => _openMemoDetail(context, memo),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: memo.isPinned
                  ? Border.all(
                      color: categoryColor.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
              boxShadow: isDark
                  ? AppTheme.softShadowDark
                  : AppTheme.softShadowLight,
            ),
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 카테고리 + 고정
                Row(
                  children: [
                    if (categoryName != null && categoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (memo.isPinned)
                      Icon(
                        Iconsax.attach_circle5,
                        size: 14,
                        color: categoryColor,
                      ),
                  ],
                ),
                const Spacer(),
                // 제목
                Text(
                  memo.displayTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (memo.previewText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    memo.previewText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                // AI 표시
                if (memo.aiAnalysis != null && memo.aiAnalysis!.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Iconsax.magic_star,
                        size: 12,
                        color: AppColors.primaryLight,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.note_1,
            size: 64,
            color: AppColors.memoColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            '메모가 없습니다',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text('새 메모를 추가해보세요', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton.icon(
            onPressed: () => _showAddMemoSheet(context),
            icon: const Icon(Iconsax.add),
            label: const Text('메모 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.memoColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.memoColor),
        const SizedBox(width: AppTheme.spacingS),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.memoColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _createCategory(BuildContext context, WidgetRef ref) async {
    final created = await showCreateMemoCategoryDialog(
      context: context,
      ref: ref,
    );
    if (!context.mounted || created == null) return;

    ref.read(smartSelectedMemoCategoryIdProvider.notifier).state = created.id;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('"${created.name}" 카테고리를 추가했습니다')));
  }

  void _openCategoryAnalysisHistory(BuildContext context) {
    context.push('/memo/category-analysis/history');
  }

  Future<void> _submitCategoryAnalysis({
    required BuildContext context,
    required WidgetRef ref,
    required String? categoryId,
    required String? categoryName,
    required int memoCount,
  }) async {
    if (memoCount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('분석할 메모가 없습니다.')));
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    final pendingJobsAsync = ref.read(pendingAnalysisJobsProvider);
    final hasPendingMemoCategoryJob =
        pendingJobsAsync.valueOrNull?.any(
          (job) => job.jobType == AnalysisJobType.memoCategoryAnalysis,
        ) ??
        false;
    if (hasPendingMemoCategoryJob) {
      _showPendingCategoryAnalysisDialog(context);
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    SubmitJobResult? submitResult;
    var shouldShowPendingCategoryDialog = false;
    try {
      submitResult = await ref
          .read(aiApiServiceProvider)
          .submitMemoCategoryAnalysis(
            userId: user.uid,
            categoryId: categoryId,
            categoryName: categoryName,
            maxMemos: memoCount.clamp(10, 300).toInt(),
          );
    } on AiApiException catch (e) {
      if (context.mounted) {
        final lowerMessage = e.message.toLowerCase();
        final isDuplicatePending =
            e.statusCode == 409 ||
            lowerMessage.contains('already') ||
            lowerMessage.contains('pending') ||
            e.message.contains('진행 중');
        if (isDuplicatePending) {
          shouldShowPendingCategoryDialog = true;
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('분석 요청 실패: ${e.message}')));
          return;
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('분석 요청 실패: $e')));
      }
      return;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }

    if (!context.mounted) return;
    if (shouldShowPendingCategoryDialog) {
      _showPendingCategoryAnalysisDialog(context);
      return;
    }

    final accepted = submitResult;
    if (accepted == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('분석 요청 응답이 올바르지 않습니다.')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestAcceptedScreen(
          jobId: accepted.jobId,
          estimatedTimeSeconds: accepted.estimatedTimeSeconds,
          initialJobType: AnalysisJobType.memoCategoryAnalysis,
        ),
      ),
    );
  }

  void _showPendingCategoryAnalysisDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('진행 중인 분석'),
        content: const Text('이미 메모 카테고리 분석이 진행 중입니다.\n분석 이력에서 상태를 확인해 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openCategoryAnalysisHistory(context);
            },
            child: Text('이력 보기', style: TextStyle(color: AppColors.memoColor)),
          ),
        ],
      ),
    );
  }

  void _showAddMemoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddMemoSheet(),
    );
  }

  void _openMemoDetail(BuildContext context, Memo memo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MemoDetailScreen(memo: memo)),
    );
  }
}
