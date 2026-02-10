import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/business_review.dart';
import '../../../shared/models/analysis_job.dart';
import '../../../shared/providers/business_review_provider.dart';
import '../../../shared/providers/analysis_job_provider.dart';

class BusinessHistoryScreen extends ConsumerWidget {
  const BusinessHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(businessReviewsProvider);
    final pendingJobsAsync = ref.watch(pendingAnalysisJobsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/tools/business');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.grayScale[50],
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left),
            onPressed: () => context.go('/tools/business'),
          ),
          title: const Text('검토 이력'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: reviewsAsync.when(
          data: (reviews) {
            // 진행 중인 작업 필터링 (사업 검토만)
            final pendingJobs =
                pendingJobsAsync.valueOrNull
                    ?.where(
                      (job) => job.jobType == AnalysisJobType.businessReview,
                    )
                    .toList() ??
                [];

            if (reviews.isEmpty && pendingJobs.isEmpty) {
              return _buildEmptyState(context);
            }

            return _buildContent(context, ref, reviews, pendingJobs);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.warning_2, size: 48, color: AppColors.coral[400]),
                const SizedBox(height: 16),
                Text(
                  '이력을 불러올 수 없습니다',
                  style: TextStyle(color: AppColors.grayScale[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<BusinessReview> reviews,
    List<AnalysisJob> pendingJobs,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 진행 중인 작업 섹션
        if (pendingJobs.isNotEmpty) ...[
          _buildSectionHeader(context, '진행 중', AppColors.coral[500]!),
          const SizedBox(height: 12),
          ...pendingJobs.map((job) => _buildPendingJobCard(context, ref, job)),
          const SizedBox(height: 24),
        ],

        // 완료된 검토 목록
        if (reviews.isNotEmpty) ...[
          if (pendingJobs.isNotEmpty)
            _buildSectionHeader(context, '완료됨', AppColors.sage[500]!),
          if (pendingJobs.isNotEmpty) const SizedBox(height: 12),
          _buildReviewsList(context, ref, reviews),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.grayScale[700],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingJobCard(
    BuildContext context,
    WidgetRef ref,
    AnalysisJob job,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coral[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 펄스 애니메이션 인디케이터
                Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.coral[500],
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(duration: 600.ms)
                    .fadeOut(duration: 600.ms),
                const SizedBox(width: 8),
                Text(
                  job.status == AnalysisJobStatus.pending ? '대기 중' : '분석 중',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.coral[600],
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // 취소 버튼
                TextButton(
                  onPressed: () => _showCancelDialog(context, ref, job),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      color: AppColors.grayScale[500],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 아이디어 미리보기
            Text(
              job.businessInput.businessIdea,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // 진행률 바
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progressPercent / 100,
                backgroundColor: AppColors.grayScale[200],
                valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),

            // 진행률 텍스트
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  job.progress.currentStepName ?? '준비 중',
                  style: TextStyle(
                    color: AppColors.grayScale[500],
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${job.progressPercent.toInt()}%',
                  style: TextStyle(
                    color: AppColors.coral[500],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, AnalysisJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('분석 취소'),
        content: const Text('진행 중인 분석을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final service = ref.read(analysisJobServiceProvider);
              final success = await service.cancelJob(job.id);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('취소에 실패했습니다')));
              }
            },
            child: Text('예', style: TextStyle(color: AppColors.coral[500])),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.document, size: 64, color: AppColors.grayScale[300]),
          const SizedBox(height: 16),
          Text(
            '아직 검토 이력이 없습니다',
            style: TextStyle(color: AppColors.grayScale[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '사업 아이디어를 분석하면\n이곳에 기록됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayScale[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(
    BuildContext context,
    WidgetRef ref,
    List<BusinessReview> reviews,
  ) {
    // 날짜별 그룹화
    final groupedReviews = <String, List<BusinessReview>>{};
    for (final review in reviews) {
      final dateKey = DateFormat('yyyy년 M월').format(review.createdAt);
      groupedReviews.putIfAbsent(dateKey, () => []).add(review);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedReviews.entries.map((entry) {
        final dateKey = entry.key;
        final monthReviews = entry.value;
        final index = groupedReviews.keys.toList().indexOf(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: index > 0 ? 16 : 0),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grayScale[600],
                ),
              ),
            ),
            ...monthReviews.map(
              (review) => _buildReviewCard(context, ref, review),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    WidgetRef ref,
    BusinessReview review,
  ) {
    Color scoreColor;
    if (review.score >= 75) {
      scoreColor = AppColors.sage[500]!;
    } else if (review.score >= 50) {
      scoreColor = AppColors.coral[500]!;
    } else {
      scoreColor = Colors.red[400]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          _showReviewDetailSheet(context, review);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 점수 표시
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    '${review.score}',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.businessIdea,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (review.industry != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.coral[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              review.industry!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.coral[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          DateFormat('M월 d일').format(review.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grayScale[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: AppColors.grayScale[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDetailSheet(BuildContext context, BusinessReview review) {
    Color scoreColor;
    String scoreLabel;
    if (review.score >= 75) {
      scoreColor = AppColors.sage[500]!;
      scoreLabel = 'GO';
    } else if (review.score >= 50) {
      scoreColor = AppColors.coral[500]!;
      scoreLabel = '조건부 GO';
    } else {
      scoreColor = Colors.red[400]!;
      scoreLabel = '재검토 필요';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.grayScale[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.grayScale[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: scoreColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${review.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scoreLabel,
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('yyyy년 M월 d일').format(review.createdAt),
                            style: TextStyle(
                              color: AppColors.grayScale[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 공유 버튼
                    IconButton(
                      onPressed: () => _shareReview(review, scoreLabel),
                      icon: Icon(
                        Iconsax.share,
                        color: AppColors.grayScale[600],
                      ),
                      tooltip: '공유하기',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 내용
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // 아이디어
                    _buildDetailSection(
                      '💡 아이디어',
                      review.businessIdea,
                      AppColors.coral[50]!,
                    ),
                    const SizedBox(height: 16),
                    // 요약
                    _buildDetailSection(
                      '📝 요약',
                      review.summary,
                      Colors.blue[50]!,
                    ),
                    const SizedBox(height: 16),
                    // SWOT
                    _buildSwotSection(context, review),
                    const SizedBox(height: 16),
                    // 시장 조사
                    if (review.marketResearch != null &&
                        !review.marketResearch!.isEmpty)
                      _buildMarketResearchSection(review),
                    if (review.marketResearch != null &&
                        !review.marketResearch!.isEmpty)
                      const SizedBox(height: 16),
                    // 다음 단계
                    _buildNextStepsSection(review),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          SelectableText(
            content,
            style: TextStyle(color: AppColors.grayScale[700], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSwotSection(BuildContext context, BusinessReview review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📊 SWOT 분석',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Text(
                '탭하여 상세보기',
                style: TextStyle(fontSize: 11, color: AppColors.grayScale[400]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSwotItem(
            context,
            'strengths',
            '💪 강점',
            'Strengths',
            review.strengths,
            AppColors.sage[50]!,
            AppColors.sage[500]!,
          ),
          const SizedBox(height: 12),
          _buildSwotItem(
            context,
            'weaknesses',
            '⚠️ 약점',
            'Weaknesses',
            review.weaknesses,
            Colors.orange[50]!,
            Colors.orange[500]!,
          ),
          const SizedBox(height: 12),
          _buildSwotItem(
            context,
            'opportunities',
            '🚀 기회',
            'Opportunities',
            review.opportunities,
            Colors.blue[50]!,
            Colors.blue[500]!,
          ),
          const SizedBox(height: 12),
          _buildSwotItem(
            context,
            'threats',
            '🛡️ 위협',
            'Threats',
            review.threats,
            Colors.red[50]!,
            Colors.red[500]!,
          ),
        ],
      ),
    );
  }

  Widget _buildSwotItem(
    BuildContext context,
    String type,
    String title,
    String englishTitle,
    List<String> items,
    Color bgColor,
    Color accentColor,
  ) {
    return InkWell(
      onTap: () => _showSwotDetailSheet(
        context,
        type,
        title,
        englishTitle,
        items,
        bgColor,
        accentColor,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}개',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Iconsax.arrow_right_3, size: 14, color: accentColor),
              ],
            ),
            const SizedBox(height: 8),
            ...items
                .take(2)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $item',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.grayScale[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            if (items.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '외 ${items.length - 2}개 더보기',
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSwotDetailSheet(
    BuildContext context,
    String type,
    String title,
    String englishTitle,
    List<String> items,
    Color bgColor,
    Color accentColor,
  ) {
    final descriptions = _getSwotDescriptions(type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.grayScale[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${items.length}개',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descriptions['description']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.grayScale[600],
                    ),
                  ),
                ],
              ),
            ),
            // 아이템 목록
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SelectableText(
                            items[index],
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.grayScale[800],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 하단 안내
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.grayScale[50],
                border: Border(
                  top: BorderSide(color: AppColors.grayScale[200]!),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.info_circle,
                    size: 16,
                    color: AppColors.grayScale[500],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      descriptions['tip']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grayScale[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _getSwotDescriptions(String type) {
    switch (type) {
      case 'strengths':
        return {
          'description': '경쟁 우위를 확보하는 내부 강점 요소',
          'tip': '강점을 최대한 활용하여 기회를 잡으세요',
        };
      case 'weaknesses':
        return {
          'description': '개선이 필요한 내부 약점 요소',
          'tip': '약점을 보완하거나 아웃소싱을 고려하세요',
        };
      case 'opportunities':
        return {
          'description': '성장과 확장을 위한 외부 기회 요소',
          'tip': '시장 트렌드와 기회를 선점하세요',
        };
      case 'threats':
        return {
          'description': '비즈니스에 위협이 되는 외부 요인',
          'tip': '위협에 대한 대응 전략을 미리 준비하세요',
        };
      default:
        return {'description': '', 'tip': ''};
    }
  }

  Widget _buildMarketResearchSection(BusinessReview review) {
    final market = review.marketResearch!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🔍 시장 조사',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.coral[700],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.coral[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Market Research',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.coral[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 시장 규모
          if (market.marketSize != null) ...[
            _buildMarketInfoRow(
              icon: Iconsax.chart_21,
              label: '시장 규모',
              value: market.marketSize!,
              color: AppColors.sage[500]!,
            ),
            const SizedBox(height: 12),
          ],

          // 타겟 고객
          if (market.customerSegment != null &&
              market.customerSegment!.isNotEmpty) ...[
            _buildMarketInfoRow(
              icon: Iconsax.people,
              label: '타겟 고객',
              value: market.customerSegment!,
              color: Colors.blue[500]!,
            ),
            const SizedBox(height: 12),
          ],

          // 진입 장벽
          if (market.entryBarrier != null &&
              market.entryBarrier!.isNotEmpty) ...[
            _buildMarketInfoRow(
              icon: Iconsax.shield_tick,
              label: '진입 장벽',
              value: market.entryBarrier!,
              color: Colors.orange[500]!,
            ),
            const SizedBox(height: 12),
          ],

          // 경쟁사
          if (market.competitors.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Iconsax.building_4, size: 16, color: Colors.purple[500]),
                const SizedBox(width: 8),
                Text(
                  '주요 경쟁사',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grayScale[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: market.competitors
                  .map(
                    (comp) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple[100]!),
                      ),
                      child: Text(
                        comp,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[700],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // 트렌드
          if (market.trends.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Iconsax.trend_up, size: 16, color: AppColors.coral[500]),
                const SizedBox(width: 8),
                Text(
                  '시장 트렌드',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grayScale[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...market.trends.map(
              (trend) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.coral[400],
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        trend,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.grayScale[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 시장 기회
          if (market.targetMarket != null &&
              market.targetMarket!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.coral[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.coral[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Iconsax.lamp_on,
                        size: 14,
                        color: AppColors.coral[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '시장 기회',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.coral[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    market.targetMarket!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.grayScale[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.grayScale[500]),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.grayScale[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextStepsSection(BusinessReview review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 다음 단계',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.lavender[700],
            ),
          ),
          const SizedBox(height: 12),
          ...review.nextSteps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.lavender[100],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: AppColors.lavender[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      step,
                      style: TextStyle(
                        color: AppColors.grayScale[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _shareReview(BusinessReview review, String scoreLabel) {
    final buffer = StringBuffer();

    // 헤더
    buffer.writeln('📊 사업 아이디어 검토 결과');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();

    // 점수 및 판정
    buffer.writeln('🎯 점수: ${review.score}점 ($scoreLabel)');
    buffer.writeln();

    // 아이디어
    buffer.writeln('💡 아이디어');
    buffer.writeln(review.businessIdea);
    buffer.writeln();

    // 요약
    buffer.writeln('📝 요약');
    buffer.writeln(review.summary);
    buffer.writeln();

    // SWOT
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📊 SWOT 분석');
    buffer.writeln();

    buffer.writeln('💪 강점');
    for (final item in review.strengths) {
      buffer.writeln('  • $item');
    }
    buffer.writeln();

    buffer.writeln('⚠️ 약점');
    for (final item in review.weaknesses) {
      buffer.writeln('  • $item');
    }
    buffer.writeln();

    buffer.writeln('🚀 기회');
    for (final item in review.opportunities) {
      buffer.writeln('  • $item');
    }
    buffer.writeln();

    buffer.writeln('🛡️ 위협');
    for (final item in review.threats) {
      buffer.writeln('  • $item');
    }
    buffer.writeln();

    // 시장 조사
    if (review.marketResearch != null && !review.marketResearch!.isEmpty) {
      final market = review.marketResearch!;
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🔍 시장 조사');
      buffer.writeln();

      if (market.marketSize != null) {
        buffer.writeln('📊 시장 규모: ${market.marketSize}');
      }
      if (market.customerSegment != null &&
          market.customerSegment!.isNotEmpty) {
        buffer.writeln('👥 타겟 고객: ${market.customerSegment}');
      }
      if (market.competitors.isNotEmpty) {
        buffer.writeln('🏢 경쟁사: ${market.competitors.join(", ")}');
      }
      if (market.trends.isNotEmpty) {
        buffer.writeln('📈 트렌드:');
        for (final trend in market.trends) {
          buffer.writeln('  • $trend');
        }
      }
      buffer.writeln();
    }

    // 다음 단계
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🎯 다음 단계');
    for (int i = 0; i < review.nextSteps.length; i++) {
      buffer.writeln('${i + 1}. ${review.nextSteps[i]}');
    }
    buffer.writeln();

    // 푸터
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('BABBA 앱에서 분석됨');

    Share.share(buffer.toString());
  }
}
