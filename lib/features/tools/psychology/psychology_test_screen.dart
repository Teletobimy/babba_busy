import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/ai/ai_api_service.dart';
import '../../../shared/providers/auth_provider.dart';

/// 심리검사 진행 화면
class PsychologyTestScreen extends ConsumerStatefulWidget {
  final String testType;

  const PsychologyTestScreen({
    super.key,
    required this.testType,
  });

  @override
  ConsumerState<PsychologyTestScreen> createState() => _PsychologyTestScreenState();
}

class _PsychologyTestScreenState extends ConsumerState<PsychologyTestScreen> {
  String? _sessionId;
  String? _testName;
  int _totalQuestions = 0;
  int _currentIndex = 0;
  PsychologyQuestion? _currentQuestion;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // 결과
  bool _isComplete = false;
  Map<String, dynamic>? _analysis;

  @override
  void initState() {
    super.initState();
    _startTest();
  }

  Future<void> _startTest() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다');

      final aiService = ref.read(aiApiServiceProvider);
      final result = await aiService.startPsychologyTest(
        userId: user.uid,
        testType: widget.testType,
      );

      setState(() {
        _sessionId = result.sessionId;
        _testName = _getTestName(widget.testType);
        _totalQuestions = result.totalQuestions;
        _currentIndex = 0;
        _currentQuestion = result.firstQuestion;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getTestName(String testType) {
    switch (testType) {
      case 'big5':
        return 'Big5 성격검사';
      case 'mbti':
        return 'MBTI 성격유형';
      case 'attachment':
        return '애착유형 검사';
      case 'love_language':
        return '사랑의 언어';
      case 'stress':
        return '스트레스 지수';
      case 'anxiety':
        return '불안 선별검사';
      case 'depression':
        return '우울 선별검사';
      default:
        return '심리검사';
    }
  }

  Future<void> _submitAnswer(int answerIndex) async {
    if (_isSubmitting || _currentQuestion == null || _sessionId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다');

      final aiService = ref.read(aiApiServiceProvider);
      final result = await aiService.submitPsychologyAnswer(
        userId: user.uid,
        sessionId: _sessionId!,
        questionId: _currentQuestion!.questionId,
        answerIndex: answerIndex,
      );

      if (result.isComplete) {
        // 검사 완료 - 결과 가져오기
        await _getResult();
      } else {
        setState(() {
          _currentIndex++;
          _currentQuestion = result.nextQuestion;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  Future<void> _getResult() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다');

      final aiService = ref.read(aiApiServiceProvider);
      final result = await aiService.getPsychologyResult(
        userId: user.uid,
        sessionId: _sessionId!,
      );

      setState(() {
        _isComplete = true;
        _analysis = {
          'summary': result.summary,
          'recommendations': result.recommendations,
          ...result.result,
        };
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.grayScale[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.grayScale[50],
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isComplete) {
      return _buildResultScreen();
    }

    return _buildTestScreen();
  }

  Widget _buildTestScreen() {
    final progress = (_currentIndex + 1) / _totalQuestions;

    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        title: Text(_testName ?? '심리검사'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => _showExitDialog(),
        ),
      ),
      body: Column(
        children: [
          // 진행률
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_currentIndex + 1} / $_totalQuestions',
                      style: TextStyle(
                        color: AppColors.grayScale[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        color: AppColors.coral[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.grayScale[200],
                    valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 질문
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentQuestion?.question ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate(key: ValueKey(_currentIndex)).fadeIn().slideY(begin: -0.1),
                  const SizedBox(height: 32),

                  // 선택지
                  ..._currentQuestion?.options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildOptionButton(index, option),
                        ).animate(key: ValueKey('${_currentIndex}_$index'))
                            .fadeIn(delay: (50 * index).ms)
                            .slideX(begin: 0.1);
                      }).toList() ??
                      [],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index, String option) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isSubmitting ? null : () => _submitAnswer(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grayScale[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.grayScale[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: AppColors.grayScale[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    color: AppColors.grayScale[700],
                    fontSize: 15,
                  ),
                ),
              ),
              if (_isSubmitting)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검사 종료'),
        content: const Text('검사를 종료하시겠습니까?\n진행 상황은 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('종료'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        title: const Text('검사 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 완료 표시
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.sage[500],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ).animate().scale(delay: 200.ms),
            const SizedBox(height: 16),
            Text(
              '$_testName 완료!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),

            // 결과 요약
            if (_analysis != null) ...[
              Container(
                width: double.infinity,
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
                        Icon(Iconsax.chart_2, color: AppColors.coral[500]),
                        const SizedBox(width: 8),
                        const Text(
                          'AI 분석 결과',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _analysis!['summary'] ?? '분석 결과를 불러오는 중...',
                      style: TextStyle(
                        color: AppColors.grayScale[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
              const SizedBox(height: 16),

              // 추천사항
              if (_analysis!['recommendations'] != null)
                Container(
                  width: double.infinity,
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
                          Icon(Iconsax.lamp_on, color: AppColors.lavender[500]),
                          const SizedBox(width: 8),
                          const Text(
                            '추천사항',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...(_analysis!['recommendations'] as List).map((rec) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '•',
                                style: TextStyle(
                                  color: AppColors.lavender[500],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rec,
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
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
            ],
            const SizedBox(height: 32),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Iconsax.arrow_left),
                    label: const Text('돌아가기'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: 공유 기능
                    },
                    icon: const Icon(Iconsax.share),
                    label: const Text('결과 공유'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral[500],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
