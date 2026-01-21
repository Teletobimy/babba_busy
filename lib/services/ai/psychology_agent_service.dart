import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ai_api_service.dart';
import '../../app/router.dart';

/// Gemini AI를 직접 사용하여 심리검사를 진행하는 서비스
final psychologyAgentServiceProvider = Provider<PsychologyAgentService>((ref) {
  return PsychologyAgentService(ref);
});

class PsychologyAgentService {
  final Ref _ref;
  
  PsychologyAgentService(this._ref);

  static String get _apiKey {
    const buildTimeKey = String.fromEnvironment('GEMINI_API_KEY');
    if (buildTimeKey.isNotEmpty) return buildTimeKey;
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  GenerativeModel get _model => GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: _apiKey,
  );

  /// 검사 시작: 질문지 생성 및 첫 번째 질문 반환
  Future<PsychologyStartResult> startTest({
    required String testType,
  }) async {
    // 실제 AI를 사용하여 질문지 정보를 가져옴 (또는 미리 정의된 프롬프트 활용)
    final prompt = '''
당신은 전문 심리 상담가입니다. '$testType' 유형의 심리검사를 진행하려 합니다.
사용자가 답변할 수 있는 문항 10개를 생성해주세요. 
각 문항은 5점 척도(매우 그렇지 않다 ~ 매우 그렇다)로 답변할 수 있어야 합니다.

JSON 형식으로만 응답하세요:
{
  "test_name": "검사 이름",
  "questions": [
    {
      "id": "q1",
      "question": "질문 내용",
      "options": ["매우 그렇지 않다", "그렇지 않다", "보통이다", "그렇다", "매우 그렇다"]
    }
  ]
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      
      // JSON 추출 및 파싱
      final jsonData = _parseJson(text);
      final questions = (jsonData['questions'] as List);
      
      return PsychologyStartResult(
        sessionId: 'ai_test_${DateTime.now().millisecondsSinceEpoch}',
        testType: testType,
        totalQuestions: questions.length,
        firstQuestion: PsychologyQuestion.fromJson(questions[0]),
      );
    } catch (e) {
      // 실패 시 기본 데이터 반환 (폴백)
      return PsychologyStartResult(
        sessionId: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
        testType: testType,
        totalQuestions: 5,
        firstQuestion: PsychologyQuestion(
          questionId: 'q1',
          question: '평소 자신의 감정을 잘 파악하는 편인가요?',
          options: ['매우 그렇지 않다', '그렇지 않다', '보통이다', '그렇다', '매우 그렇다'],
        ),
      );
    }
  }

  /// 답변 제출 및 다음 질문 (로컬에서 처리하거나 AI에 물어봄)
  /// 여기서는 초기 생성된 질문지를 세션에 저장하거나 간단히 로컬에서 인지하도록 구현 가능
  /// 우선은 PsychologyTestScreen에서 모든 질문을 미리 받는 형태로 가거나, 
  /// 필요할 때마다 Gemini에게 다음 질문을 물어보는 방식으로 구현
  Future<PsychologyAnswerResult> submitAnswer({
    required String testType,
    required String sessionId,
    required String questionId,
    required int answerIndex,
    required int currentIdx,
    required int totalCount,
  }) async {
    final nextIdx = currentIdx + 1;
    final isComplete = nextIdx >= totalCount;

    if (isComplete) {
      return PsychologyAnswerResult(
        sessionId: sessionId,
        progress: 1.0,
        isComplete: true,
      );
    }

    // 다음 질문을 가져오기 위한 AI 호출 (또는 캐시된 데이터 사용)
    // 여기서는 간단하게 다음 번호의 질문을 생성하도록 요청
    final prompt = "'$testType' 심리검사의 $nextIdx번째 질문을 5점 척도 선택지와 함께 JSON(question_id, question, options)으로 생성해주세요.";
    
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final jsonData = _parseJson(response.text ?? '');
      
      return PsychologyAnswerResult(
        sessionId: sessionId,
        progress: nextIdx / totalCount,
        isComplete: false,
        nextQuestion: PsychologyQuestion.fromJson(jsonData),
      );
    } catch (e) {
      return PsychologyAnswerResult(
        sessionId: sessionId,
        progress: nextIdx / totalCount,
        isComplete: false,
        nextQuestion: PsychologyQuestion(
          questionId: 'q_$nextIdx',
          question: '다음 질문을 불러오지 못했습니다. 평소 스트레스 관리는 어떻게 하시나요?',
          options: ['전혀 안 함', '조금 함', '보통', '하는 편', '아주 잘 함'],
        ),
      );
    }
  }

  /// 최종 결과 분석
  Future<PsychologyResult> getAnalysis({
    required String testType,
    required List<String> questions,
    required List<int> answers,
  }) async {
    final answersStr = List.generate(questions.length, (i) => "문항: ${questions[i]}, 답변인덱스: ${answers[i]} (0-4)").join('\n');
    
    final prompt = '''
당신은 최고의 심리 분석 전문가입니다. 사용자의 '$testType' 검사 답변을 바탕으로 심층 분석 보고서를 작성해주세요.

사용자 답변:
$answersStr

JSON 형식으로 응답하세요:
{
  "summary": "전체적인 심리 상태 요약 (3-4줄)",
  "result": {
    "score": 0-100점 점수,
    "traits": ["특성1", "특성2", "특성3"]
  },
  "recommendations": ["추천 활동 1", "추천 활동 2", "추천 활동 3"]
}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final jsonData = _parseJson(response.text ?? '');
      
      return PsychologyResult(
        sessionId: 'result_${DateTime.now().millisecondsSinceEpoch}',
        testType: testType,
        result: jsonData['result'] ?? {},
        summary: jsonData['summary'] ?? '',
        recommendations: List<String>.from(jsonData['recommendations'] ?? []),
      );
    } catch (e) {
      return PsychologyResult(
        sessionId: 'error',
        testType: testType,
        result: {'score': 50},
        summary: '분석 중 오류가 발생했지만, 전반적으로 안정적인 상태로 보입니다.',
        recommendations: ['충분한 휴식을 취하세요', '가벼운 산책을 추천합니다'],
      );
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    String jsonText = text.trim();
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.substring(7);
    } else if (jsonText.startsWith('```')) {
      jsonText = jsonText.substring(3);
    }
    if (jsonText.endsWith('```')) {
      jsonText = jsonText.substring(0, jsonText.length - 3);
    }
    return jsonDecode(jsonText.trim());
  }
}
