import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'business_agent_service.dart';

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
    defaultValue: 'https://babba-ai-api-cykf2jfgmq-du.a.run.app',
  );

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

  /// 사업 아이디어 분석 (동기)
  Future<BusinessAnalysisResult> analyzeBusinessIdea({
    required String userId,
    required String idea,
    String? industry,
    String? targetMarket,
    String? budget,
  }) async {
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

  /// 사업 아이디어 분석 비동기 요청 (백그라운드 처리)
  Future<SubmitJobResult> submitBusinessAnalysis({
    required String userId,
    required String idea,
    String? industry,
    String? targetMarket,
    String? budget,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/jobs/business/submit'),
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
        return SubmitJobResult(
          jobId: data['job_id'],
          status: data['status'] ?? 'pending',
          estimatedTimeSeconds: data['estimated_time_seconds'] ?? 120,
        );
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw AiApiException(data['detail'] ?? '요청 실패');
      } else {
        throw AiApiException('요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 분석 작업 상태 조회
  Future<JobStatusResult> getJobStatus(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/jobs/$jobId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return JobStatusResult.fromJson(data);
      } else if (response.statusCode == 404) {
        throw AiApiException('작업을 찾을 수 없습니다');
      } else {
        throw AiApiException('조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 분석 작업 취소
  Future<bool> cancelJob(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/jobs/$jobId/cancel'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw AiApiException(data['detail'] ?? '취소 실패');
      } else {
        throw AiApiException('취소 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 사용자의 진행 중인 작업 목록 조회
  Future<List<JobStatusResult>> getPendingJobs() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/jobs/user/pending'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => JobStatusResult.fromJson(item)).toList();
      } else {
        throw AiApiException('조회 실패: ${response.statusCode}');
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
        throw AiApiException('심리검사 시작 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 심리검사 답변 제출
  Future<PsychologyAnswerResult> submitPsychologyAnswer({
    required String userId,
    required String sessionId,
    required String questionId,
    required int answerIndex,
  }) async {
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

  /// 메모 분석
  Future<MemoAnalysisResult> analyzeMemo({
    required String userId,
    required String content,
    String? categoryName,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/memo/analyze'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'content': content,
          if (categoryName != null) 'category_name': categoryName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MemoAnalysisResult(
          analysis: data['analysis'] ?? '',
          cached: data['cached'] ?? false,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw AiApiException(errorData['detail'] ?? '분석 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('네트워크 오류: $e');
    }
  }

  /// 사업 아이디어 분석 스트리밍 (7개 에이전트 진행 상황)
  Stream<AgentProgress> analyzeBusinessStream({
    required String userId,
    required String idea,
    String? industry,
    String? targetMarket,
    String? budget,
  }) async* {
    final token = await _getAuthToken();
    final url = '$_baseUrl/api/business/analyze/stream';

    final client = http.Client();
    final request = http.Request('POST', Uri.parse(url));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({
      'user_id': userId,
      'idea': idea,
      if (industry != null) 'industry': industry,
      if (targetMarket != null) 'target_market': targetMarket,
      if (budget != null) 'budget': budget,
    });

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
            print('JSON parse error in business stream: $dataStr, error: $e');
          }
        }
      }
    } catch (e) {
      if (e is AiApiException) rethrow;
      throw AiApiException('분석 중 오류 발생: $e');
    } finally {
      client.close();
    }
  }

  /// 심리검사 분석 스트리밍 (멀티 에이전트 진행 상황)
  Stream<AgentProgress> analyzePsychologyStream({
    required String userId,
    required String sessionId,
  }) async* {
    final token = await _getAuthToken();
    final url = '$_baseUrl/api/psychology/analyze/stream';

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(url));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';

      // 쿼리 파라미터 대신 request body 사용
      request.body = jsonEncode({
        'user_id': userId,
        'session_id': sessionId,
      });

      final response = await client.send(request).timeout(
        const Duration(minutes: 6),
        onTimeout: () {
          throw AiApiException('분석 요청 시간이 초과되었습니다');
        },
      );

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
}

/// AI API 예외
class AiApiException implements Exception {
  final String message;
  AiApiException(this.message);

  @override
  String toString() => message;
}

/// 메모 분석 결과
class MemoAnalysisResult {
  final String analysis;
  final bool cached;

  MemoAnalysisResult({
    required this.analysis,
    this.cached = false,
  });
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

/// 비동기 작업 제출 결과
class SubmitJobResult {
  final String jobId;
  final String status;
  final int estimatedTimeSeconds;

  SubmitJobResult({
    required this.jobId,
    required this.status,
    required this.estimatedTimeSeconds,
  });
}

/// 작업 진행 상황
class JobProgress {
  final int currentStep;
  final int totalSteps;
  final double percentage;
  final String? currentStepName;

  JobProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.percentage,
    this.currentStepName,
  });

  factory JobProgress.fromJson(Map<String, dynamic> json) {
    return JobProgress(
      currentStep: json['current_step'] ?? 0,
      totalSteps: json['total_steps'] ?? 5,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      currentStepName: json['current_step_name'],
    );
  }
}

/// 작업 상태 결과
class JobStatusResult {
  final String jobId;
  final String userId;
  final String jobType;
  final String status;
  final JobProgress progress;
  final String? resultId;
  final Map<String, dynamic>? error;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  JobStatusResult({
    required this.jobId,
    required this.userId,
    required this.jobType,
    required this.status,
    required this.progress,
    this.resultId,
    this.error,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory JobStatusResult.fromJson(Map<String, dynamic> json) {
    return JobStatusResult(
      jobId: json['job_id'] ?? '',
      userId: json['user_id'] ?? '',
      jobType: json['job_type'] ?? 'business_review',
      status: json['status'] ?? 'pending',
      progress: JobProgress.fromJson(json['progress'] ?? {}),
      resultId: json['result_id'],
      error: json['error'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  bool get isInProgress => status == 'pending' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}
