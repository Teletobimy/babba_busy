import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ai_api_service.dart';

/// 7개 전문 에이전트를 병렬 실행하는 서비스
class BusinessAgentService {
  final String? apiKey;

  BusinessAgentService([this.apiKey]);

  /// API 키 가져오기
  static String get _apiKey {
    const buildTimeKey = String.fromEnvironment('GEMINI_API_KEY');
    if (buildTimeKey.isNotEmpty) return buildTimeKey;
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  /// 7개 에이전트 병렬 실행 (Stream 진행 상태 전달)
  Stream<AgentProgress> analyzeWithAgents({
    required String businessIdea,
    String? industry,
    String? budget,
  }) async* {
    final effectiveApiKey = apiKey ?? _apiKey;
    if (effectiveApiKey.isEmpty) {
      throw Exception('Gemini API 키가 설정되지 않았습니다');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: effectiveApiKey,
    );

    // Phase 1: 5개 에이전트 병렬 실행
    final agentNames = [
      '시장조사 전문가',
      '경쟁사 분석가',
      '재무 분석가',
      '법률/규제 전문가',
      '마케팅 전략가',
    ];

    for (final name in agentNames) {
      yield AgentProgress(name, 'started', null);
    }

    final futures = [
      _runMarketResearchAgent(model, businessIdea, industry, budget),
      _runCompetitorAgent(model, businessIdea, industry),
      _runFinancialAgent(model, businessIdea, budget),
      _runLegalAgent(model, businessIdea, industry),
      _runMarketingAgent(model, businessIdea, industry, budget),
    ];

    final results = await Future.wait(futures);

    for (int i = 0; i < agentNames.length; i++) {
      yield AgentProgress(agentNames[i], 'completed', results[i]);
    }

    // Phase 2: 제품 기획자 (Phase 1 결과 활용)
    yield AgentProgress('제품 기획자', 'started', null);
    final productResult = await _runProductAgent(model, businessIdea, results);
    yield AgentProgress('제품 기획자', 'completed', productResult);

    // Phase 3: 종합 전략 컨설턴트 (모든 결과 종합)
    yield AgentProgress('종합 전략 컨설턴트', 'started', null);
    final finalResult = await _runStrategistAgent(
      model,
      businessIdea,
      [...results, productResult],
    );
    yield AgentProgress('종합 전략 컨설턴트', 'completed', finalResult);
  }

  /// 시장조사 전문가
  Future<String> _runMarketResearchAgent(
    GenerativeModel model,
    String idea,
    String? industry,
    String? budget,
  ) async {
    final prompt = '''
당신은 시장조사 전문가입니다. 다음 사업 아이디어를 분석하세요:

아이디어: $idea
${industry != null ? '산업: $industry' : ''}
${budget != null ? '예산: $budget' : ''}

다음을 포함해서 분석하세요:
1. TAM/SAM/SOM (시장 규모)
2. 시장 트렌드
3. 고객 니즈
4. 성장 잠재력

간결하게 5-7줄로 요약하세요.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '분석 실패';
    } catch (e) {
      return '분석 실패: $e';
    }
  }

  /// 경쟁사 분석가
  Future<String> _runCompetitorAgent(
    GenerativeModel model,
    String idea,
    String? industry,
  ) async {
    final prompt = '''
당신은 경쟁사 분석 전문가입니다. 다음 사업 아이디어를 분석하세요:

아이디어: $idea
${industry != null ? '산업: $industry' : ''}

다음을 포함해서 분석하세요:
1. 주요 직접 경쟁사
2. 간접 경쟁사
3. 경쟁 우위 요소
4. 차별화 포인트

간결하게 5-7줄로 요약하세요.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '분석 실패';
    } catch (e) {
      return '분석 실패: $e';
    }
  }

  /// 재무 분석가
  Future<String> _runFinancialAgent(
    GenerativeModel model,
    String idea,
    String? budget,
  ) async {
    final prompt = '''
당신은 재무 분석 전문가입니다. 다음 사업 아이디어를 분석하세요:

아이디어: $idea
${budget != null ? '초기 예산: $budget' : ''}

다음을 포함해서 분석하세요:
1. 비용 구조 (고정비/변동비)
2. 수익 모델
3. BEP (손익분기점)
4. 자금 조달 방안

간결하게 5-7줄로 요약하세요.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '분석 실패';
    } catch (e) {
      return '분석 실패: $e';
    }
  }

  /// 법률/규제 전문가
  Future<String> _runLegalAgent(
    GenerativeModel model,
    String idea,
    String? industry,
  ) async {
    final prompt = '''
당신은 법률/규제 전문가입니다. 다음 사업 아이디어를 분석하세요:

아이디어: $idea
${industry != null ? '산업: $industry' : ''}

다음을 포함해서 분석하세요:
1. 필요한 인허가
2. 규제 리스크
3. 법적 고려사항
4. 컴플라이언스

간결하게 5-7줄로 요약하세요.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '분석 실패';
    } catch (e) {
      return '분석 실패: $e';
    }
  }

  /// 마케팅 전략가
  Future<String> _runMarketingAgent(
    GenerativeModel model,
    String idea,
    String? industry,
    String? budget,
  ) async {
    final prompt = '''
당신은 마케팅 전략 전문가입니다. 다음 사업 아이디어를 분석하세요:

아이디어: $idea
${industry != null ? '산업: $industry' : ''}
${budget != null ? '예산: $budget' : ''}

다음을 포함해서 분석하세요:
1. GTM (Go-to-Market) 전략
2. 마케팅 채널
3. 가격 전략
4. 고객 획득 비용

간결하게 5-7줄로 요약하세요.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '분석 실패';
    } catch (e) {
      return '분석 실패: $e';
    }
  }

  /// 제품 기획자
  Future<String> _runProductAgent(
    GenerativeModel model,
    String idea,
    List<String> phase1Results,
  ) async {
    final prompt = '''
당신은 제품 기획 전문가입니다. 다음 사업 아이디어와 분석 결과를 바탕으로 제품을 기획하세요:

아이디어: $idea

시장조사 결과: ${phase1Results[0]}
경쟁사 분석: ${phase1Results[1]}

다음을 포함해서 기획하세요:
1. MVP 핵심 기능
2. 제품 로드맵
3. 우선순위
4. 기술 스택

간결하게 5-7줄로 요약하세요.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '분석 실패';
    } catch (e) {
      return '분석 실패: $e';
    }
  }

  /// 종합 전략 컨설턴트
  Future<BusinessAnalysisResult> _runStrategistAgent(
    GenerativeModel model,
    String idea,
    List<String> allResults,
  ) async {
    final prompt = '''
당신은 종합 전략 컨설턴트입니다. 다음 사업 아이디어와 전문가 분석 결과를 종합하여 최종 보고서를 작성하세요:

아이디어: $idea

시장조사: ${allResults[0]}
경쟁사 분석: ${allResults[1]}
재무 분석: ${allResults[2]}
법률/규제: ${allResults[3]}
마케팅 전략: ${allResults[4]}
제품 기획: ${allResults[5]}

다음 형식으로 JSON 응답하세요 (JSON 외에 다른 텍스트는 포함하지 마세요):
{
  "score": 0-100점 사이 정수,
  "summary": "한 문장 요약",
  "strengths": ["강점1", "강점2", "강점3"],
  "weaknesses": ["약점1", "약점2", "약점3"],
  "opportunities": ["기회1", "기회2", "기회3"],
  "threats": ["위협1", "위협2", "위협3"],
  "nextSteps": ["다음 단계1", "다음 단계2", "다음 단계3"]
}
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';

      // JSON 추출 (마크다운 코드 블록 제거)
      String jsonText = text.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      // JSON 파싱
      final jsonData = jsonDecode(jsonText) as Map<String, dynamic>;

      return BusinessAnalysisResult.fromJson({
        'score': jsonData['score'] ?? 50,
        'summary': jsonData['summary'] ?? '분석 완료',
        'strengths': jsonData['strengths'] ?? [],
        'weaknesses': jsonData['weaknesses'] ?? [],
        'opportunities': jsonData['opportunities'] ?? [],
        'threats': jsonData['threats'] ?? [],
        'nextSteps': jsonData['nextSteps'] ?? [],
        'analysis': {}, // 빈 맵
      });
    } catch (e) {
      // 파싱 실패 시 기본값 반환
      return BusinessAnalysisResult(
        score: 50,
        summary: '분석은 완료되었으나 결과 파싱에 실패했습니다',
        strengths: ['분석 데이터 확인 필요'],
        weaknesses: ['결과 형식 오류'],
        opportunities: [],
        threats: [],
        nextSteps: ['재분석 권장'],
        analysis: {},
      );
    }
  }
}

/// 에이전트 진행 상태
class AgentProgress {
  final String agentName;
  final String status; // 'started', 'completed', 'failed'
  final dynamic result;

  AgentProgress(this.agentName, this.status, this.result);
}
