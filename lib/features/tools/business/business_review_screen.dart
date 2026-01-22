import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/ai/ai_api_service.dart';
import '../../../services/ai/business_agent_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/business_review_provider.dart';
import '../../../shared/models/business_review.dart';

/// 사업 검토 화면
class BusinessReviewScreen extends ConsumerStatefulWidget {
  const BusinessReviewScreen({super.key});

  @override
  ConsumerState<BusinessReviewScreen> createState() => _BusinessReviewScreenState();
}

class _BusinessReviewScreenState extends ConsumerState<BusinessReviewScreen> {
  final _ideaController = TextEditingController();
  String? _selectedIndustry;
  String? _selectedBudget;

  bool _isAnalyzing = false;
  Map<String, String> _analysisProgress = {};
  BusinessAnalysisResult? _result;
  String? _error;
  String? _inputError; // P1: 입력 검증 에러

  final List<String> _industries = [
    '테크/IT',
    '이커머스',
    '푸드테크',
    '헬스케어',
    '교육',
    '금융/핀테크',
    '라이프스타일',
    '엔터테인먼트',
    '기타',
  ];

  final List<String> _budgets = [
    '500만원 이하',
    '500만원 ~ 2000만원',
    '2000만원 ~ 5000만원',
    '5000만원 ~ 1억원',
    '1억원 이상',
  ];

  @override
  void dispose() {
    _ideaController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    // P1: 입력 검증 시각적 피드백
    final text = _ideaController.text.trim();
    if (text.isEmpty) {
      setState(() => _inputError = '아이디어를 입력해주세요');
      return;
    }
    if (text.length < 10) {
      setState(() => _inputError = '10자 이상 입력해주세요 (현재 ${text.length}자)');
      return;
    }
    setState(() => _inputError = null);

    setState(() {
      _isAnalyzing = true;
      _analysisProgress = {
        '시장조사 전문가': 'pending',
        '경쟁사 분석가': 'pending',
        '재무 분석가': 'pending',
        '법률/규제 전문가': 'pending',
        '마케팅 전략가': 'pending',
        '제품 기획자': 'pending',
        '종합 전략 컨설턴트': 'pending',
      };
      _result = null;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider);

      if (user == null) throw Exception('로그인이 필요합니다');

      final userId = user.uid;

      final agentService = BusinessAgentService();
      BusinessAnalysisResult? finalResult;

      await for (final progress in agentService.analyzeWithAgents(
        businessIdea: _ideaController.text.trim(),
        industry: _selectedIndustry,
        budget: _selectedBudget,
      )) {
        // 에러 상태 처리
        if (progress.status == 'error') {
          setState(() {
            _error = progress.result?.toString() ?? '분석 중 오류가 발생했습니다';
            _isAnalyzing = false;
          });
          return;
        }

        setState(() {
          _analysisProgress[progress.agentName] = progress.status;
        });

        if (progress.agentName == '종합 전략 컨설턴트' &&
            progress.status == 'completed') {
          finalResult = progress.result as BusinessAnalysisResult;
        }
      }

      if (finalResult != null) {
        setState(() {
          _result = finalResult;
          _isAnalyzing = false;
        });

        // 자동 저장
        final reviewService = ref.read(businessReviewServiceProvider);
        final review = BusinessReview.fromAnalysisResult(
          userId: userId,
          businessIdea: _ideaController.text.trim(),
          industry: _selectedIndustry,
          budget: _selectedBudget,
          result: {
            'score': finalResult.score,
            'summary': finalResult.summary,
            'strengths': finalResult.strengths,
            'weaknesses': finalResult.weaknesses,
            'opportunities': finalResult.opportunities,
            'threats': finalResult.threats,
            'nextSteps': finalResult.nextSteps,
          },
        );
        await reviewService.saveReview(review);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  // P1: 분석 중 이탈 방지 다이얼로그
  Future<bool> _showExitConfirmDialog() async {
    if (!_isAnalyzing) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('분석 중단'),
        content: const Text('분석을 중단하시겠습니까?\n진행 상황은 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('중단', style: TextStyle(color: AppColors.coral[500])),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // P1: 분석 중 이탈 방지
    return PopScope(
      canPop: !_isAnalyzing,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _isAnalyzing) {
          final shouldPop = await _showExitConfirmDialog();
          if (shouldPop && context.mounted) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.grayScale[50],
        appBar: AppBar(
          title: const Text('사업 검토'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _isAnalyzing
              ? IconButton(
                  icon: const Icon(Iconsax.arrow_left),
                  onPressed: () async {
                    final shouldPop = await _showExitConfirmDialog();
                    if (shouldPop && context.mounted) {
                      context.pop();
                    }
                  },
                )
              : null,
          actions: [
            if (!_isAnalyzing)
              IconButton(
                icon: const Icon(Iconsax.document_text),
                onPressed: () => context.push('/tools/business/history'),
              ),
          ],
        ),
        body: _result != null ? _buildResultView() : _buildInputView(),
      ),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Text(
            '💡 사업 아이디어를 입력하세요',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI가 시장조사, 경쟁사 분석, 상품 기획, 재무 분석을 수행합니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grayScale[600],
                ),
          ),
          const SizedBox(height: 24),

          // 아이디어 입력
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: _inputError != null
                  ? Border.all(color: AppColors.coral[400]!, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _ideaController,
              maxLines: 6,
              maxLength: 2000,
              onChanged: (value) {
                // P1: 입력 중 에러 해제
                if (_inputError != null && value.trim().length >= 10) {
                  setState(() => _inputError = null);
                }
              },
              decoration: InputDecoration(
                hintText: '예: 반려동물 산책 매칭 서비스를 만들고 싶어요.\n'
                    '견주들이 시간이 없을 때 근처 산책 도우미를 찾을 수 있고,\n'
                    '산책 도우미는 부수입을 얻을 수 있는 플랫폼입니다.',
                hintStyle: TextStyle(color: AppColors.grayScale[400]),
                errorText: _inputError, // P1: 에러 메시지 표시
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 산업 분야 선택
          Text(
            '산업 분야 (선택)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _industries.map((industry) {
              final isSelected = _selectedIndustry == industry;
              return ChoiceChip(
                label: Text(industry),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedIndustry = selected ? industry : null;
                  });
                },
                selectedColor: AppColors.coral[100],
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.coral[700] : AppColors.grayScale[700],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 예산 선택
          Text(
            '예상 예산 (선택)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _budgets.map((budget) {
              final isSelected = _selectedBudget == budget;
              return ChoiceChip(
                label: Text(budget),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedBudget = selected ? budget : null;
                  });
                },
                selectedColor: AppColors.sage[100],
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.sage[700] : AppColors.grayScale[700],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // 분석 버튼 또는 진행 상황
          if (_isAnalyzing) _buildProgressView() else _buildAnalyzeButton(),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[700]),
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

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _startAnalysis,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral[500],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.chart_2),
            SizedBox(width: 8),
            Text(
              '분석 시작',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressView() {
    final steps = [
      ('시장조사 전문가', '시장 조사', Iconsax.chart),
      ('경쟁사 분석가', '경쟁사 분석', Iconsax.people),
      ('재무 분석가', '재무 분석', Iconsax.money),
      ('법률/규제 전문가', '법률/규제', Iconsax.shield_tick),
      ('마케팅 전략가', '마케팅 전략', Iconsax.trend_up),
      ('제품 기획자', '제품 기획', Iconsax.box),
      ('종합 전략 컨설턴트', '최종 리포트', Iconsax.document_text),
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
        children: [
          const Text(
            '🔍 7개 전문 에이전트가 분석 중입니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...steps.map((step) {
            final status = _analysisProgress[step.$1] ?? 'pending';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _buildStatusIcon(status),
                  const SizedBox(width: 12),
                  Icon(step.$3, size: 20, color: AppColors.grayScale[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.$2,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: status == 'completed'
                          ? AppColors.sage[600]
                          : AppColors.grayScale[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ).animate(target: status != 'pending' ? 1 : 0).fadeIn();
          }),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.sage[500],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case 'started':
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
          ),
        );
      default:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grayScale[300]!),
            shape: BoxShape.circle,
          ),
        );
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return '완료';
      case 'started':
        return '진행 중...';
      default:
        return '대기';
    }
  }

  Widget _buildResultView() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 점수 헤더
          _buildScoreHeader(result),
          const SizedBox(height: 20),

          // 요약
          _buildSummaryCard(result),
          const SizedBox(height: 16),

          // SWOT 분석
          _buildSwotCard(result),
          const SizedBox(height: 16),

          // 다음 단계
          _buildNextStepsCard(result),
          const SizedBox(height: 24),

          // 액션 버튼들
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _result = null;
                    });
                  },
                  icon: const Icon(Iconsax.refresh),
                  label: const Text('새로 분석'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // P1: 미구현 버튼 비활성화
                child: ElevatedButton.icon(
                  onPressed: null, // 준비 중
                  icon: const Icon(Iconsax.message),
                  label: const Text('준비 중'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral[500],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.grayScale[200],
                    disabledForegroundColor: AppColors.grayScale[500],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreHeader(BusinessAnalysisResult result) {
    Color scoreColor;
    String scoreLabel;
    if (result.score >= 75) {
      scoreColor = AppColors.sage[500]!;
      scoreLabel = 'GO';
    } else if (result.score >= 50) {
      scoreColor = AppColors.coral[500]!;
      scoreLabel = '조건부 GO';
    } else {
      scoreColor = Colors.red[400]!;
      scoreLabel = '재검토 필요';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withValues(alpha: 0.1), scoreColor.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scoreColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${result.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사업성 점수',
                  style: TextStyle(
                    color: AppColors.grayScale[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreLabel,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildSummaryCard(BusinessAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Iconsax.lamp_on, color: AppColors.coral[500]),
              const SizedBox(width: 8),
              const Text(
                '핵심 요약',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.summary,
            style: TextStyle(
              color: AppColors.grayScale[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildSwotCard(BusinessAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Row(
            children: [
              Icon(Iconsax.chart_square, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'SWOT 분석',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSwotItem('💪', '강점', result.strengths, AppColors.sage[100]!),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSwotItem('⚠️', '약점', result.weaknesses, Colors.orange[50]!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSwotItem('🚀', '기회', result.opportunities, Colors.blue[50]!),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSwotItem('🛡️', '위협', result.threats, Colors.red[50]!),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildSwotItem(String emoji, String title, List<String> items, Color bgColor) {
    final hasMore = items.length > 3 || items.any((item) => item.length > 50);

    return GestureDetector(
      onTap: () => _showSwotDetailSheet(context, emoji, title, items, bgColor),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$emoji $title',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (hasMore)
                  Icon(Iconsax.arrow_right_3, size: 14, color: AppColors.grayScale[400]),
              ],
            ),
            const SizedBox(height: 8),
            ...items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $item',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grayScale[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${items.length - 3}개 더보기',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.grayScale[500],
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
    String emoji,
    String title,
    List<String> items,
    Color bgColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // 전체 아이템 리스트
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: bgColor,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            items[index],
                            style: const TextStyle(height: 1.5),
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
      ),
    );
  }

  Widget _buildNextStepsCard(BusinessAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Iconsax.flag, color: AppColors.lavender[500]),
              const SizedBox(width: 8),
              const Text(
                '다음 단계',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...result.nextSteps.asMap().entries.map((entry) {
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
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }
}
