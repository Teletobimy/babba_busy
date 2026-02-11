import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/ai/ai_api_service.dart';
import '../../../../shared/models/analysis_job.dart';
import '../../../../shared/providers/analysis_job_provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/psychology_result_provider.dart';

/// 분석 요청 접수 확인 화면
class RequestAcceptedScreen extends ConsumerStatefulWidget {
  final String jobId;
  final int estimatedTimeSeconds;
  final VoidCallback? onWaitHere;
  final AnalysisJobType? initialJobType;

  const RequestAcceptedScreen({
    super.key,
    required this.jobId,
    this.estimatedTimeSeconds = 120,
    this.onWaitHere,
    this.initialJobType,
  });

  @override
  ConsumerState<RequestAcceptedScreen> createState() =>
      _RequestAcceptedScreenState();
}

class _RequestAcceptedScreenState extends ConsumerState<RequestAcceptedScreen> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    // 작업 상태 실시간 감시
    final jobAsync = ref.watch(analysisJobProvider(widget.jobId));

    // 완료 시 자동 네비게이션
    ref.listen<AsyncValue<AnalysisJob?>>(analysisJobProvider(widget.jobId), (
      previous,
      next,
    ) {
      if (_hasNavigated) return;

      next.whenData((job) {
        if (job != null && job.status == AnalysisJobStatus.completed) {
          _hasNavigated = true;
          unawaited(_handleCompletedJob(job));
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // 체크 아이콘
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.sage[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.tick_circle5,
                  size: 60,
                  color: AppColors.sage[600],
                ),
              ).animate().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                duration: 400.ms,
                curve: Curves.elasticOut,
              ),
              const SizedBox(height: 32),

              // 메인 텍스트
              Text(
                '분석 요청이 접수되었어요',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),

              // 서브 텍스트
              Text(
                '완료되면 알림으로 알려드릴게요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grayScale[600],
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 8),

              // 예상 시간
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coral[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.clock, size: 16, color: AppColors.coral[600]),
                    const SizedBox(width: 6),
                    Text(
                      '예상 소요 시간: 약 ${_formatTime(widget.estimatedTimeSeconds)}',
                      style: TextStyle(
                        color: AppColors.coral[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 24),

              // 진행 상태 카드
              jobAsync
                  .when(
                    data: (job) {
                      if (job == null) return const SizedBox.shrink();
                      return _buildProgressCard(context, job);
                    },
                    loading: () => _buildProgressCard(
                      context,
                      AnalysisJob(
                        id: widget.jobId,
                        userId: '',
                        jobType:
                            widget.initialJobType ??
                            AnalysisJobType.businessReview,
                        status: AnalysisJobStatus.pending,
                        input: {},
                        progress: AnalysisJobProgress(
                          currentStep: 0,
                          totalSteps: 5,
                          percentage: 0.0,
                        ),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  )
                  .animate()
                  .fadeIn(delay: 500.ms),

              const Spacer(),

              // 버튼들
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral[500],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.home, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '홈으로 돌아가기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
              const SizedBox(height: 12),

              // 여기서 기다리기 옵션
              if (widget.onWaitHere != null)
                TextButton(
                  onPressed: widget.onWaitHere,
                  child: Text(
                    '여기서 결과 기다리기',
                    style: TextStyle(
                      color: AppColors.grayScale[600],
                      fontSize: 14,
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCompletedJob(AnalysisJob job) async {
    if (job.jobType == AnalysisJobType.psychologyTest) {
      await _syncPsychologyResult(job);
    }

    if (!mounted) return;
    final route = switch (job.jobType) {
      AnalysisJobType.psychologyTest => '/tools/psychology/history',
      AnalysisJobType.businessReview => '/tools/business/history',
      AnalysisJobType.memoCategoryAnalysis => '/home',
    };
    context.go(route);
  }

  Future<void> _syncPsychologyResult(AnalysisJob job) async {
    final sessionId = job.resultId;
    final user = ref.read(currentUserProvider);
    if (sessionId == null || sessionId.isEmpty || user == null) {
      return;
    }

    try {
      final aiApiService = ref.read(aiApiServiceProvider);
      final resultService = ref.read(psychologyResultServiceProvider);
      final apiResult = await aiApiService.getPsychologyResult(
        userId: user.uid,
        sessionId: sessionId,
      );

      final testType = apiResult.testType.isNotEmpty
          ? apiResult.testType
          : (job.input['testType']?.toString() ??
                job.input['test_type']?.toString() ??
                '');
      if (testType.isEmpty) return;

      final resultPayload = <String, dynamic>{
        ...apiResult.result,
        if (apiResult.summary.isNotEmpty) 'summary': apiResult.summary,
        if (apiResult.recommendations.isNotEmpty)
          'recommendations': apiResult.recommendations,
        'jobId': job.id,
        'sessionId': sessionId,
      };

      await resultService.saveResultFromSession(
        sessionId: sessionId,
        testType: testType,
        result: resultPayload,
      );
    } catch (_) {
      // 저장 실패 시에도 화면 이동은 유지
    }
  }

  Widget _buildProgressCard(BuildContext context, AnalysisJob job) {
    final steps = job.jobType == AnalysisJobType.psychologyTest
        ? [
            ('점수 계산', Icons.calculate),
            ('패턴 분석', Icons.insights),
            ('강점 분석', Icons.psychology_alt),
            ('성장 제안', Icons.trending_up),
            ('최종 리포트', Iconsax.document_text),
          ]
        : job.jobType == AnalysisJobType.memoCategoryAnalysis
        ? [
            ('분석 축 설계', Icons.alt_route),
            ('문맥 압축', Icons.compress),
            ('통합 분석', Icons.hub),
            ('품질 검증', Icons.verified),
            ('최종 정리', Iconsax.document_text),
          ]
        : [
            ('시장 조사', Iconsax.chart),
            ('경쟁사 분석', Iconsax.people),
            ('제품 기획', Iconsax.box),
            ('재무 분석', Iconsax.money),
            ('최종 리포트', Iconsax.document_text),
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (job.status == AnalysisJobStatus.processing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
                  ),
                )
              else
                Icon(Iconsax.clock, size: 16, color: AppColors.grayScale[500]),
              const SizedBox(width: 8),
              Text(
                job.status == AnalysisJobStatus.pending
                    ? '대기 중...'
                    : job.status == AnalysisJobStatus.processing
                    ? '분석 중...'
                    : job.status.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grayScale[700],
                ),
              ),
              const Spacer(),
              Text(
                '${job.progress.percentage.toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.coral[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: job.progress.percentage / 100,
              backgroundColor: AppColors.grayScale[200],
              valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // 단계 표시
          ...List.generate(steps.length, (index) {
            final isCompleted = index < job.progress.currentStep;
            final isCurrent =
                index == job.progress.currentStep - 1 ||
                (job.progress.currentStep == 0 &&
                    index == 0 &&
                    job.status == AnalysisJobStatus.processing);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _buildStepIcon(isCompleted, isCurrent),
                  const SizedBox(width: 10),
                  Icon(
                    steps[index].$2,
                    size: 16,
                    color: isCompleted || isCurrent
                        ? AppColors.grayScale[700]
                        : AppColors.grayScale[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    steps[index].$1,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted || isCurrent
                          ? AppColors.grayScale[700]
                          : AppColors.grayScale[400],
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

  Widget _buildStepIcon(bool isCompleted, bool isCurrent) {
    if (isCompleted) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.sage[500],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }

    if (isCurrent) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
        ),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grayScale[300]!),
        shape: BoxShape.circle,
      ),
    );
  }

  String _formatTime(int seconds) {
    if (seconds < 60) {
      return '$seconds초';
    } else {
      final minutes = seconds ~/ 60;
      return '$minutes분';
    }
  }
}
