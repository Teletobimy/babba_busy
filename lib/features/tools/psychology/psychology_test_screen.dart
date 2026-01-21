import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/ai/ai_api_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/psychology_result_provider.dart';
import '../../../app/router.dart';

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
  int? _selectedAnswerIndex; // P1: 선택된 답변 시각적 표시용

  // 결과 및 상태 추적
  final List<int> _answers = []; // 선택한 답변 인덱스 목록
  final List<String> _questionTexts = []; // 질문 텍스트 목록 (분석용)
  bool _isComplete = false;
  Map<String, dynamic>? _analysis;

  // 멀티 에이전트 분석 상태
  final Map<String, String> _agentProgress = {};
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _startTest();
  }

  Future<void> _startTest() async {
    try {
      final user = ref.read(currentUserProvider);
      final isDemo = ref.read(demoModeProvider);
      
      if (user == null && !isDemo) throw Exception('로그인이 필요합니다');
      
      final userId = user?.uid ?? 'demo_user';

      final aiService = ref.read(aiApiServiceProvider);
      final result = await aiService.startPsychologyTest(
        userId: userId,
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
        _error = "Cloud Run 연결 실패: $e"; // 더 구체적인 에러 메시지
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

    setState(() {
      _isSubmitting = true;
      _selectedAnswerIndex = answerIndex; // P1: 선택된 답변 표시
    });

    try {
      final user = ref.read(currentUserProvider);
      final isDemo = ref.read(demoModeProvider);
      
      if (user == null && !isDemo) throw Exception('로그인이 필요합니다');
      
      final userId = user?.uid ?? 'demo_user';

      final aiService = ref.read(aiApiServiceProvider);
      
      // 답변 리스트에 추가 (로컬 저장용)
      _answers.add(answerIndex);

      final result = await aiService.submitPsychologyAnswer(
        userId: userId,
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
          _selectedAnswerIndex = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = "답변 제출 실패: $e";
        _isSubmitting = false;
      });
    }
  }

  Future<void> _getResult() async {
    setState(() {
      _isAnalyzing = true;
      _isSubmitting = true; // 분석 중에는 다른 동작 방지
      _agentProgress.clear(); // 이전 진행 상태 초기화
    });

    try {
      final user = ref.read(currentUserProvider);
      final isDemo = ref.read(demoModeProvider);
      if (user == null && !isDemo) throw Exception('로그인이 필요합니다');
      final userId = user?.uid ?? 'demo_user';

      final aiService = ref.read(aiApiServiceProvider);
      final stream = aiService.analyzePsychologyStream(
        userId: userId,
        sessionId: _sessionId!,
      );

      await for (final progress in stream) {
        setState(() {
          _agentProgress[progress.agentName] = progress.status;
          if (progress.agentName == 'final_report' && progress.status == 'completed') {
            final result = progress.result;
            _isComplete = true;
            _isAnalyzing = false;
            _isSubmitting = false; // 분석 완료 후 제출 상태 해제
            _analysis = {
              'summary': result['summary'],
              'recommendations': List<String>.from(result['recommendations'] ?? []),
              ...result['result'] ?? {},
            };
          }
        });
      }

      // DB에 결과 저장
      if (user != null && _analysis != null) {
        final resultService = ref.read(psychologyResultServiceProvider);
        await resultService.saveResult(
          testType: widget.testType,
          answers: _answers, // 이 부분은 실제 답변 데이터를 저장하도록 수정 필요
          result: _analysis!,
        );
      }
    } catch (e) {
      setState(() {
        _error = "분석 실패: $e";
        _isSubmitting = false;
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 테스트 진행 중일 때는 _buildTestScreen()이 자체 Scaffold를 가짐 (PopScope 포함)
    if (!_isLoading && _error == null && !_isComplete && !_isAnalyzing) {
      return _buildTestScreen();
    }

    // 결과 화면도 자체 Scaffold를 가짐
    if (_isComplete) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        title: Text(_getTestName(widget.testType)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _error != null
              ? _buildErrorView()
              : _buildAnalysisProgress(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
          ),
          const SizedBox(height: 16),
          Text(
            '검사를 준비하고 있습니다...',
            style: TextStyle(color: AppColors.grayScale[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.coral[400]),
            const SizedBox(height: 16),
            Text(
              '검사를 불러오지 못했습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.grayScale[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayScale[600]),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Iconsax.arrow_left),
                  label: const Text('돌아가기'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isLoading = true;
                    });
                    _startTest();
                  },
                  icon: const Icon(Iconsax.refresh),
                  label: const Text('다시 시도'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral[500],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisProgress() {
    final agents = [
      {'id': 'personality_analyst', 'name': '성격 특성 분석가', 'icon': Icons.psychology},
      {'id': 'emotional_wellbeing', 'name': '정서 건강 전문가', 'icon': Icons.favorite},
      {'id': 'social_relational', 'name': '대인관계 심리 전문가', 'icon': Icons.people},
      {'id': 'final_report', 'name': '오케스트레이터 종합 판단', 'icon': Icons.auto_awesome},
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🔍 멀티 에이전트 분석 중',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '각 분야의 AI 전문가들이 답변을 분석하고 있습니다.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ...agents.map((agent) {
              final status = _agentProgress[agent['id']];
              final isStarted = status == 'started';
              final isCompleted = status == 'completed';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withOpacity(0.1)
                            : isStarted
                                ? AppColors.coral[500]!.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        agent['icon'] as IconData,
                        color: isCompleted
                            ? Colors.green
                            : isStarted
                                ? AppColors.coral[500]
                                : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent['name'] as String,
                            style: TextStyle(
                              fontWeight: isStarted || isCompleted
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCompleted ? Colors.green : null,
                            ),
                          ),
                          if (isStarted)
                            Text(
                              '분석 내용을 작성 중입니다...',
                              style: TextStyle(fontSize: 12, color: AppColors.coral[500]),
                            ),
                          if (isCompleted)
                            const Text(
                              '분석 완료',
                              style: TextStyle(fontSize: 12, color: Colors.green),
                            ),
                        ],
                      ),
                    ),
                    if (isStarted)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.coral[500]),
                        ),
                      ),
                    if (isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestScreen() {
    final progress = (_currentIndex + 1) / _totalQuestions;

    // P1: 시스템 뒤로가기 버튼 이탈 방지
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
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
                          color: Colors.black.withOpacity(0.05),
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
    ),  // PopScope 닫기
    );
  }

  Widget _buildOptionButton(int index, String option) {
    // P1: 선택된 상태 시각화
    final isSelected = _selectedAnswerIndex == index;
    final isSubmittingThis = _isSubmitting && isSelected;

    return Material(
      color: isSelected ? AppColors.coral[50] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isSubmitting ? null : () => _submitAnswer(index),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.coral[100],
        highlightColor: AppColors.coral[50],
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.coral[400]! : AppColors.grayScale[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.coral[400] : AppColors.grayScale[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
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
                    color: isSelected ? AppColors.coral[700] : AppColors.grayScale[700],
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSubmittingThis)
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
                  // P1: 미구현 버튼 비활성화
                  child: ElevatedButton.icon(
                    onPressed: null, // 준비 중
                    icon: const Icon(Iconsax.share),
                    label: const Text('준비 중'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral[500],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.grayScale[200],
                      disabledForegroundColor: AppColors.grayScale[500],
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
