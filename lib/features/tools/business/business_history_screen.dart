import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/business_review.dart';
import '../../../shared/providers/business_review_provider.dart';

class BusinessHistoryScreen extends ConsumerWidget {
  const BusinessHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(businessReviewsProvider);

    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        title: const Text('검토 이력'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: reviewsAsync.when(
        data: (reviews) => reviews.isEmpty
            ? _buildEmptyState(context)
            : _buildReviewsList(context, ref, reviews),
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
            style: TextStyle(
              color: AppColors.grayScale[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '사업 아이디어를 분석하면\n이곳에 기록됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.grayScale[500],
              fontSize: 14,
            ),
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

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: groupedReviews.length,
      itemBuilder: (context, index) {
        final dateKey = groupedReviews.keys.elementAt(index);
        final monthReviews = groupedReviews[dateKey]!;

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
            ...monthReviews.map((review) => _buildReviewCard(context, ref, review)),
          ],
        );
      },
    );
  }

  Widget _buildReviewCard(BuildContext context, WidgetRef ref, BusinessReview review) {
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
              Icon(Iconsax.arrow_right_3, size: 16, color: AppColors.grayScale[400]),
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
                    _buildSwotSection(review),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: AppColors.grayScale[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwotSection(BusinessReview review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 SWOT 분석',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          _buildSwotItem('💪 강점', review.strengths, AppColors.sage[50]!),
          const SizedBox(height: 12),
          _buildSwotItem('⚠️ 약점', review.weaknesses, Colors.orange[50]!),
          const SizedBox(height: 12),
          _buildSwotItem('🚀 기회', review.opportunities, Colors.blue[50]!),
          const SizedBox(height: 12),
          _buildSwotItem('🛡️ 위협', review.threats, Colors.red[50]!),
        ],
      ),
    );
  }

  Widget _buildSwotItem(String title, List<String> items, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $item',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grayScale[700],
                  ),
                ),
              )),
        ],
      ),
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
                    child: Text(
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
}
