import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'business_agent_service.dart';
import '../../app/router.dart';

/// Cloud Run AI API 서비스 Provider
final aiApiServiceProvider = Provider<AiApiService>((ref) {
  return AiApiService(ref);
});

/// Cloud Run AI API 서비스
class AiApiService {
  final Ref _ref;
  AiApiService(this._ref);

  // Cloud Run API URL
  static const String _baseUrl = String.fromEnvironment(
    'AI_API_URL',
    defaultValue: 'https://***REMOVED_CLOUD_RUN_URL***',
  );

  /// 데모 모드 여부 확인
  bool get _isDemoMode => _ref.read(demoModeProvider);

  /// Firebase Auth 토큰 가져오기
  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// HTTP 헤더 생성
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 일일 요약 생성
  Future<AiSummaryResult> generateDailySummary({
    required String userId,
    required String userName,
    required int pendingTodos,
    required int completedToday,
    required int upcomingEvents,
    int? monthlyExpense,
    int? monthlyIncome,
  }) async {
    if (_isDemoMode) {
      await Future.delayed(const Duration(seconds: 1));
      return AiSummaryResult(
        summary: '$userName님, 오늘 완료해야 할 일이 $pendingTodos개 있네요. 화이팅하세요!',
        cached: false,
      );
    }

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/summary/daily'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'user_name': userName,
          'pending_todos': pendingTodos,
          'completed_today': completedToday,
          'upcoming_events': upcomingEvents,
          if (monthlyExpense != null) 'monthly_expense': monthlyExpense,
          if (monthlyIncome != null) 'monthly_income': monthlyIncome,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiSummaryResult(
          summary: data['summary'],
          cached: data['cached'] ?? false,
        );
      } else {
        throw AiApiException('요약 생성 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 주간 요약 생성
  Future<AiSummaryResult> generateWeeklySummary({
    required String userId,
    required String userName,
    required int completedTodos,
    required int totalTodos,
    required int eventsAttended,
    int? weeklyExpense,
  }) async {
    if (_isDemoMode) {
      await Future.delayed(const Duration(seconds: 1));
      final rate = totalTodos > 0 ? (completedTodos / totalTodos * 100).toInt() : 0;
      return AiSummaryResult(
        summary: '이번 주 $totalTodos개의 할 일 중 $completedTodos개를 완료하셨네요 ($rate%). 아주 훌륭한 한 주였습니다!',
        cached: false,
        completionRate: rate.toDouble(),
      );
    }

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/summary/weekly'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'user_name': userName,
          'completed_todos': completedTodos,
          'total_todos': totalTodos,
          'events_attended': eventsAttended,
          if (weeklyExpense != null) 'weekly_expense': weeklyExpense,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiSummaryResult(
          summary: data['summary'],
          cached: data['cached'] ?? false,
          completionRate: data['completion_rate']?.toDouble(),
        );
      } else {
        throw AiApiException('요약 생성 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 사업 아이디어 분석
  Future<BusinessAnalysisResult> analyzeBusinessIdea({
    required String userId,
    required String idea,
    String? industry,
    String? targetMarket,
    String? budget,
  }) async {
    if (_isDemoMode) {
      await Future.delayed(const Duration(seconds: 2));
      return BusinessAnalysisResult(
        score: 85,
        summary: '제시하신 아이디어는 시장 잠재력이 매우 높습니다. 차별화된 전략이 돋보이네요.',
        strengths: ['시장 트렌드 부합', '명확한 타겟 설정', '수익 모델 확장성'],
        weaknesses: ['초기 마케팅 비용 부담', '경쟁사 진입 장벽'],
        opportunities: ['글로벌 시장 진출 가능성', '제휴 파트너십'],
        threats: ['유사 서비스의 빠른 복제', '규제 환경 변화'],
        nextSteps: ['MVP 개발 착수', '사용자 설문 조사', '시드 투자 유치 준비'],
        analysis: {},
      );
    }

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/business/analyze'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'idea': idea,
          if (industry != null) 'industry': industry,
          if (targetMarket != null) 'target_market': targetMarket,
          if (budget != null) 'budget': budget,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BusinessAnalysisResult.fromJson(data);
      } else {
        throw AiApiException('분석 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 사업 검토 대화
  Future<BusinessChatResult> chatBusiness({
    required String userId,
    required String sessionId,
    required String message,
  }) async {
    if (_isDemoMode) {
      await Future.delayed(const Duration(seconds: 1));
      return BusinessChatResult(
        reply: '좋은 질문입니다. 해당 부분에 대해 더 자세히 분석해 보니, 다음과 같은 전략적 접근이 가능해 보입니다. 우선 기술적인 검토가 선행되어야 할 것 같네요.',
        sessionId: sessionId,
        turn: 1,
      );
    }

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/business/chat'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'session_id': sessionId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BusinessChatResult(
          reply: data['reply'],
          sessionId: data['session_id'],
          turn: data['turn'],
        );
      } else {
        throw AiApiException('대화 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 새 사업 검토 세션 생성
  Future<String> createBusinessSession() async {
    if (_isDemoMode) return 'demo_session_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/business/session/new'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['session_id'];
      } else {
        throw AiApiException('세션 생성 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 심리검사 시작
  Future<PsychologyStartResult> startPsychologyTest({
    required String userId,
    required String testType,
  }) async {
    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 800));
      return PsychologyStartResult(
        sessionId: 'demo_test_${DateTime.now().millisecondsSinceEpoch}',
        testType: testType,
        totalQuestions: 5, // 데모용은 5문항
        firstQuestion: _getDemoQuestion(testType, 0),
      );
    }

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/psychology/start'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'test_type': testType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PsychologyStartResult.fromJson(data);
      } else {
        // 백엔드 실패 시 데모 데이터로 폴백하여 앱이 멈추지 않게 함
        return _demoPsychologyStart(testType);
      }
    } catch (e) {
      // 네트워크 오류 시에도 데모 데이터로 폴백
      return _demoPsychologyStart(testType);
    }
  }

  /// 심리검사 답변 제출
  Future<PsychologyAnswerResult> submitPsychologyAnswer({
    required String userId,
    required String sessionId,
    required String questionId,
    required int answerIndex,
  }) async {
    if (sessionId.startsWith('demo_')) {
      await Future.delayed(const Duration(milliseconds: 300));
      final currentIdx = int.parse(questionId.split('_').last);
      final nextIdx = currentIdx + 1;
      final isComplete = nextIdx >= 5;

      return PsychologyAnswerResult(
        sessionId: sessionId,
        progress: nextIdx / 5,
        isComplete: isComplete,
        nextQuestion: isComplete ? null : _getDemoQuestion('', nextIdx),
      );
    }

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/psychology/answer'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'session_id': sessionId,
          'question_id': questionId,
          'answer_index': answerIndex,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PsychologyAnswerResult.fromJson(data);
      } else {
        throw AiApiException('답변 제출 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 심리검사 결과 조회
  Future<PsychologyResult> getPsychologyResult({
    required String userId,
    required String sessionId,
  }) async {
    if (sessionId.startsWith('demo_')) {
      await Future.delayed(const Duration(seconds: 1));
      return PsychologyResult(
        sessionId: sessionId,
        testType: 'demo',
        result: {'score': 80},
        summary: '당신은 아주 균형 잡힌 심리 상태를 가지고 있습니다. 주변 사람들과의 관계도 원만하며 자신감이 넘치는 시기네요.',
        recommendations: [
          '충분한 휴식을 취하세요',
          '좋아하는 취미 활동에 시간을 더 투자해 보세요',
          '주변 사람들에게 고마움을 표현해 보세요'
        ],
      );
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/psychology/result/$sessionId?user_id=$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PsychologyResult.fromJson(data);
      } else {
        throw AiApiException('결과 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 심리검사 분석 스트리밍 (멀티 에이전트 진행 상황)
  Stream<AgentProgress> analyzePsychologyStream({
    required String userId,
    required String sessionId,
  }) async* {
    if (_isDemoMode) {
      final agents = [
        'personality_analyst',
        'emotional_wellbeing',
        'social_relational',
        'final_report'
      ];
      for (final agentId in agents) {
        yield AgentProgress(agentId, 'started', null);
        await Future.delayed(const Duration(milliseconds: 1200));
        yield AgentProgress(
            agentId,
            'completed',
            agentId == 'final_report'
                ? {
                    'summary': '당신은 조화로운 마음을 가진 분이시군요.',
                    'recommendations': ['충분한 휴식을 취하세요'],
                    'result': {'core_personality': '친절함'}
                  }
                : '분석 완료');
      }
      return;
    }

    final token = await _getAuthToken();
    final url =
        '$_baseUrl/api/psychology/analyze/stream?user_id=$userId&session_id=$sessionId';

    final client = http.Client();
    final request = http.Request('POST', Uri.parse(url));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'text/event-stream';

    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw AiApiException('분석 스트리밍 시작 실패: ${response.statusCode}');
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr == '[DONE]') break;

          try {
            final data = jsonDecode(dataStr);
            if (data['type'] == 'result') {
              yield AgentProgress('final_report', 'completed', data['data']);
            } else if (data['type'] == 'error') {
              throw AiApiException(data['message']);
            } else if (data['step'] != null) {
              yield AgentProgress(data['step'], data['status'], null);
            }
          } catch (e) {
            print('JSON parse error in psychology stream: $dataStr, error: $e');
          }
        }
      }
    } catch (e) {
      throw AiApiException('분석 중 오류 발생: $e');
    } finally {
      client.close();
    }
  }

  // --- 데모 보조 메서드 ---

  Future<PsychologyStartResult> _demoPsychologyStart(String testType) async {
    return PsychologyStartResult(
      sessionId: 'demo_test_${DateTime.now().millisecondsSinceEpoch}',
      testType: testType,
      totalQuestions: 5,
      firstQuestion: _getDemoQuestion(testType, 0),
    );
  }

  PsychologyQuestion _getDemoQuestion(String testType, int index) {
    final questions = [
      '새로운 사람들을 만나는 것을 즐깁니까?',
      '어려운 상황에서도 침착함을 유지하는 편인가요?',
      '미래에 대한 계획을 세우는 것을 좋아하나요?',
      '다른 사람의 감정에 공감을 잘 하는 편인가요?',
      '혼자만의 시간을 가지는 것이 중요한가요?'
    ];
    
    return PsychologyQuestion(
      questionId: 'q_$index',
      question: questions[index % questions.length],
      options: ['매우 그렇다', '그렇다', '보통이다', '그렇지 않다', '매우 그렇지 않다'],
    );
  }
}

/// AI API 예외
class AiApiException implements Exception {
  final String message;
  AiApiException(this.message);

  @override
  String toString() => message;
}

/// AI 요약 결과
class AiSummaryResult {
  final String summary;
  final bool cached;
  final double? completionRate;

  AiSummaryResult({
    required this.summary,
    this.cached = false,
    this.completionRate,
  });
}

/// 사업 분석 결과
class BusinessAnalysisResult {
  final Map<String, dynamic> analysis;
  final String summary;
  final int score;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> opportunities;
  final List<String> threats;
  final List<String> nextSteps;

  BusinessAnalysisResult({
    required this.analysis,
    required this.summary,
    required this.score,
    required this.strengths,
    required this.weaknesses,
    required this.opportunities,
    required this.threats,
    required this.nextSteps,
  });

  factory BusinessAnalysisResult.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>? ?? {};
    return BusinessAnalysisResult(
      analysis: analysis,
      summary: json['summary'] ?? analysis['recommendation'] ?? '',
      score: json['score'] ?? analysis['score'] ?? 0,
      strengths: List<String>.from(analysis['strengths'] ?? []),
      weaknesses: List<String>.from(analysis['weaknesses'] ?? []),
      opportunities: List<String>.from(analysis['opportunities'] ?? []),
      threats: List<String>.from(analysis['threats'] ?? []),
      nextSteps: List<String>.from(analysis['next_steps'] ?? []),
    );
  }
}

/// 사업 대화 결과
class BusinessChatResult {
  final String reply;
  final String sessionId;
  final int turn;

  BusinessChatResult({
    required this.reply,
    required this.sessionId,
    required this.turn,
  });
}

/// 심리검사 시작 결과
class PsychologyStartResult {
  final String sessionId;
  final String testType;
  final int totalQuestions;
  final PsychologyQuestion firstQuestion;

  PsychologyStartResult({
    required this.sessionId,
    required this.testType,
    required this.totalQuestions,
    required this.firstQuestion,
  });

  factory PsychologyStartResult.fromJson(Map<String, dynamic> json) {
    return PsychologyStartResult(
      sessionId: json['session_id'],
      testType: json['test_type'],
      totalQuestions: json['total_questions'],
      firstQuestion: PsychologyQuestion.fromJson(json['first_question']),
    );
  }
}

/// 심리검사 질문
class PsychologyQuestion {
  final String questionId;
  final String question;
  final List<String> options;

  PsychologyQuestion({
    required this.questionId,
    required this.question,
    required this.options,
  });

  factory PsychologyQuestion.fromJson(Map<String, dynamic> json) {
    return PsychologyQuestion(
      questionId: json['question_id'],
      question: json['question'],
      options: List<String>.from(json['options']),
    );
  }
}

/// 심리검사 답변 결과
class PsychologyAnswerResult {
  final String sessionId;
  final double progress;
  final PsychologyQuestion? nextQuestion;
  final bool isComplete;

  PsychologyAnswerResult({
    required this.sessionId,
    required this.progress,
    this.nextQuestion,
    required this.isComplete,
  });

  factory PsychologyAnswerResult.fromJson(Map<String, dynamic> json) {
    return PsychologyAnswerResult(
      sessionId: json['session_id'],
      progress: (json['progress'] as num).toDouble(),
      nextQuestion: json['next_question'] != null
          ? PsychologyQuestion.fromJson(json['next_question'])
          : null,
      isComplete: json['is_complete'] ?? false,
    );
  }
}

/// 심리검사 최종 결과
class PsychologyResult {
  final String sessionId;
  final String testType;
  final Map<String, dynamic> result;
  final String summary;
  final List<String> recommendations;

  PsychologyResult({
    required this.sessionId,
    required this.testType,
    required this.result,
    required this.summary,
    required this.recommendations,
  });

  factory PsychologyResult.fromJson(Map<String, dynamic> json) {
    return PsychologyResult(
      sessionId: json['session_id'],
      testType: json['test_type'],
      result: json['result'] ?? {},
      summary: json['summary'] ?? '',
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }
}
