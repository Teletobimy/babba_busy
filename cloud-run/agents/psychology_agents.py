import asyncio
from typing import Optional, List
from enum import Enum
from .base_agent import BaseAgent


class TestType(str, Enum):
    BIG5 = "big5"
    ATTACHMENT = "attachment"
    MBTI = "mbti"
    LOVE_LANGUAGE = "love_language"
    STRESS = "stress"
    ANXIETY = "anxiety"
    DEPRESSION = "depression"


# ============ 검사 질문 데이터베이스 ============

PSYCHOLOGY_TESTS = {
    TestType.BIG5: {
        "name": "Big5 성격검사",
        "description": "성격의 5가지 주요 요인을 측정합니다",
        "duration": "약 10분",
        "dimensions": ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"],
        "questions": [
            # 개방성 (Openness) - 5문항
            {"id": "big5_o1", "dimension": "openness", "text": "나는 새로운 아이디어나 개념에 흥미를 느낀다", "reverse": False},
            {"id": "big5_o2", "dimension": "openness", "text": "나는 예술, 음악, 문학에 관심이 많다", "reverse": False},
            {"id": "big5_o3", "dimension": "openness", "text": "나는 상상력이 풍부한 편이다", "reverse": False},
            {"id": "big5_o4", "dimension": "openness", "text": "나는 새로운 경험을 시도하는 것을 즐긴다", "reverse": False},
            {"id": "big5_o5", "dimension": "openness", "text": "나는 전통적인 방식보다 새로운 방식을 선호한다", "reverse": False},
            # 성실성 (Conscientiousness) - 5문항
            {"id": "big5_c1", "dimension": "conscientiousness", "text": "나는 계획을 세우고 그것을 따르는 편이다", "reverse": False},
            {"id": "big5_c2", "dimension": "conscientiousness", "text": "나는 맡은 일을 끝까지 완수한다", "reverse": False},
            {"id": "big5_c3", "dimension": "conscientiousness", "text": "나는 정리정돈을 잘 하는 편이다", "reverse": False},
            {"id": "big5_c4", "dimension": "conscientiousness", "text": "나는 약속 시간을 잘 지킨다", "reverse": False},
            {"id": "big5_c5", "dimension": "conscientiousness", "text": "나는 목표 달성을 위해 꾸준히 노력한다", "reverse": False},
            # 외향성 (Extraversion) - 5문항
            {"id": "big5_e1", "dimension": "extraversion", "text": "나는 사람들과 어울리는 것을 좋아한다", "reverse": False},
            {"id": "big5_e2", "dimension": "extraversion", "text": "나는 파티나 모임에서 활발하게 대화한다", "reverse": False},
            {"id": "big5_e3", "dimension": "extraversion", "text": "나는 에너지가 넘치는 편이다", "reverse": False},
            {"id": "big5_e4", "dimension": "extraversion", "text": "나는 낯선 사람에게 먼저 말을 거는 편이다", "reverse": False},
            {"id": "big5_e5", "dimension": "extraversion", "text": "나는 혼자 있는 것보다 사람들과 함께 있는 것을 선호한다", "reverse": False},
            # 친화성 (Agreeableness) - 5문항
            {"id": "big5_a1", "dimension": "agreeableness", "text": "나는 다른 사람의 감정에 공감을 잘 한다", "reverse": False},
            {"id": "big5_a2", "dimension": "agreeableness", "text": "나는 다른 사람을 돕는 것을 좋아한다", "reverse": False},
            {"id": "big5_a3", "dimension": "agreeableness", "text": "나는 갈등 상황에서 타협점을 찾으려 한다", "reverse": False},
            {"id": "big5_a4", "dimension": "agreeableness", "text": "나는 다른 사람을 쉽게 신뢰한다", "reverse": False},
            {"id": "big5_a5", "dimension": "agreeableness", "text": "나는 다른 사람의 필요를 내 것보다 먼저 생각한다", "reverse": False},
            # 신경증 (Neuroticism) - 5문항
            {"id": "big5_n1", "dimension": "neuroticism", "text": "나는 쉽게 스트레스를 받는다", "reverse": False},
            {"id": "big5_n2", "dimension": "neuroticism", "text": "나는 걱정이 많은 편이다", "reverse": False},
            {"id": "big5_n3", "dimension": "neuroticism", "text": "나는 기분 변화가 심한 편이다", "reverse": False},
            {"id": "big5_n4", "dimension": "neuroticism", "text": "나는 쉽게 불안해진다", "reverse": False},
            {"id": "big5_n5", "dimension": "neuroticism", "text": "나는 작은 일에도 쉽게 짜증이 난다", "reverse": False},
        ],
        "options": ["전혀 그렇지 않다", "그렇지 않다", "보통이다", "그렇다", "매우 그렇다"],
    },

    TestType.ATTACHMENT: {
        "name": "애착유형 검사",
        "description": "대인관계에서의 애착 패턴을 파악합니다",
        "duration": "약 8분",
        "dimensions": ["secure", "anxious", "avoidant", "fearful"],
        "questions": [
            # 안정 (Secure) - 5문항
            {"id": "att_s1", "dimension": "secure", "text": "나는 가까운 사람에게 의지하는 것이 편안하다", "reverse": False},
            {"id": "att_s2", "dimension": "secure", "text": "나는 다른 사람이 나를 진정으로 좋아한다고 믿는다", "reverse": False},
            {"id": "att_s3", "dimension": "secure", "text": "나는 연인/친구와 친밀해지는 것이 쉽다", "reverse": False},
            {"id": "att_s4", "dimension": "secure", "text": "나는 혼자 있을 때도 안정감을 느낀다", "reverse": False},
            {"id": "att_s5", "dimension": "secure", "text": "나는 관계에서 적절한 거리를 유지할 수 있다", "reverse": False},
            # 불안 (Anxious) - 5문항
            {"id": "att_x1", "dimension": "anxious", "text": "나는 상대방이 나를 떠날까봐 걱정된다", "reverse": False},
            {"id": "att_x2", "dimension": "anxious", "text": "나는 상대방의 사랑을 자주 확인받고 싶다", "reverse": False},
            {"id": "att_x3", "dimension": "anxious", "text": "연락이 늦으면 불안해진다", "reverse": False},
            {"id": "att_x4", "dimension": "anxious", "text": "나는 거절당하는 것이 두렵다", "reverse": False},
            {"id": "att_x5", "dimension": "anxious", "text": "상대방이 나만큼 나를 사랑하지 않는 것 같다", "reverse": False},
            # 회피 (Avoidant) - 5문항
            {"id": "att_v1", "dimension": "avoidant", "text": "나는 너무 가까워지는 것이 불편하다", "reverse": False},
            {"id": "att_v2", "dimension": "avoidant", "text": "나는 독립적인 것이 중요하다", "reverse": False},
            {"id": "att_v3", "dimension": "avoidant", "text": "감정을 표현하는 것이 어렵다", "reverse": False},
            {"id": "att_v4", "dimension": "avoidant", "text": "나는 누군가에게 의지하는 것이 불편하다", "reverse": False},
            {"id": "att_v5", "dimension": "avoidant", "text": "친밀한 관계보다 자유가 더 중요하다", "reverse": False},
            # 혼란 (Fearful) - 5문항
            {"id": "att_f1", "dimension": "fearful", "text": "나는 친밀함을 원하지만 동시에 두렵다", "reverse": False},
            {"id": "att_f2", "dimension": "fearful", "text": "관계에서 상처받을까봐 거리를 둔다", "reverse": False},
            {"id": "att_f3", "dimension": "fearful", "text": "나는 사람들을 믿고 싶지만 믿기 어렵다", "reverse": False},
            {"id": "att_f4", "dimension": "fearful", "text": "가까워지면 결국 상처받게 될 것 같다", "reverse": False},
            {"id": "att_f5", "dimension": "fearful", "text": "관계에 대한 기대와 두려움이 공존한다", "reverse": False},
        ],
        "options": ["전혀 그렇지 않다", "그렇지 않다", "보통이다", "그렇다", "매우 그렇다"],
    },

    TestType.MBTI: {
        "name": "MBTI 성격유형 검사",
        "description": "16가지 성격 유형 중 나의 유형을 알아봅니다",
        "duration": "약 8분",
        "dimensions": ["EI", "SN", "TF", "JP"],
        "questions": [
            # E vs I - 5문항
            {"id": "mbti_ei1", "dimension": "EI", "text": "모임에서 나는 여러 사람과 대화하는 것을 선호한다", "pole": "E"},
            {"id": "mbti_ei2", "dimension": "EI", "text": "나는 혼자만의 시간이 꼭 필요하다", "pole": "I"},
            {"id": "mbti_ei3", "dimension": "EI", "text": "나는 말하면서 생각을 정리한다", "pole": "E"},
            {"id": "mbti_ei4", "dimension": "EI", "text": "나는 조용한 환경에서 더 잘 집중한다", "pole": "I"},
            {"id": "mbti_ei5", "dimension": "EI", "text": "새로운 사람을 만나면 에너지가 충전된다", "pole": "E"},
            # S vs N - 5문항
            {"id": "mbti_sn1", "dimension": "SN", "text": "나는 구체적이고 실용적인 정보를 선호한다", "pole": "S"},
            {"id": "mbti_sn2", "dimension": "SN", "text": "나는 미래의 가능성에 대해 생각하는 것을 좋아한다", "pole": "N"},
            {"id": "mbti_sn3", "dimension": "SN", "text": "나는 경험해본 것을 바탕으로 판단한다", "pole": "S"},
            {"id": "mbti_sn4", "dimension": "SN", "text": "나는 추상적인 개념이나 이론에 관심이 많다", "pole": "N"},
            {"id": "mbti_sn5", "dimension": "SN", "text": "나는 현실적인 해결책을 찾는 편이다", "pole": "S"},
            # T vs F - 5문항
            {"id": "mbti_tf1", "dimension": "TF", "text": "결정할 때 논리와 객관성을 중시한다", "pole": "T"},
            {"id": "mbti_tf2", "dimension": "TF", "text": "다른 사람의 감정을 먼저 고려한다", "pole": "F"},
            {"id": "mbti_tf3", "dimension": "TF", "text": "나는 공정함이 배려보다 중요하다고 생각한다", "pole": "T"},
            {"id": "mbti_tf4", "dimension": "TF", "text": "나는 조화로운 관계를 유지하는 것이 중요하다", "pole": "F"},
            {"id": "mbti_tf5", "dimension": "TF", "text": "비판할 때 솔직하게 말하는 편이다", "pole": "T"},
            # J vs P - 5문항
            {"id": "mbti_jp1", "dimension": "JP", "text": "나는 계획을 세우고 그대로 실행하는 것을 좋아한다", "pole": "J"},
            {"id": "mbti_jp2", "dimension": "JP", "text": "나는 상황에 따라 유연하게 대처한다", "pole": "P"},
            {"id": "mbti_jp3", "dimension": "JP", "text": "마감 기한 전에 일을 끝내야 마음이 편하다", "pole": "J"},
            {"id": "mbti_jp4", "dimension": "JP", "text": "나는 열린 선택지를 유지하는 것을 좋아한다", "pole": "P"},
            {"id": "mbti_jp5", "dimension": "JP", "text": "일정이 정해지면 안심이 된다", "pole": "J"},
        ],
        "options": ["전혀 그렇지 않다", "그렇지 않다", "보통이다", "그렇다", "매우 그렇다"],
    },

    TestType.LOVE_LANGUAGE: {
        "name": "사랑의 언어 검사",
        "description": "나의 사랑 표현/수용 방식을 알아봅니다",
        "duration": "약 6분",
        "dimensions": ["words", "service", "gifts", "time", "touch"],
        "questions": [
            # 인정의 말 (Words of Affirmation) - 3문항
            {"id": "love_w1", "dimension": "words", "text": "나는 칭찬이나 격려의 말을 들을 때 사랑받는다고 느낀다", "reverse": False},
            {"id": "love_w2", "dimension": "words", "text": "상대방이 나를 자랑스럽다고 말해줄 때 기쁘다", "reverse": False},
            {"id": "love_w3", "dimension": "words", "text": "문자나 메모로 애정 표현을 받으면 행복하다", "reverse": False},
            # 봉사 (Acts of Service) - 3문항
            {"id": "love_s1", "dimension": "service", "text": "상대방이 나를 위해 무언가를 해줄 때 사랑을 느낀다", "reverse": False},
            {"id": "love_s2", "dimension": "service", "text": "바쁠 때 도움을 받으면 큰 감동을 받는다", "reverse": False},
            {"id": "love_s3", "dimension": "service", "text": "상대방이 내 부담을 덜어주면 고맙다", "reverse": False},
            # 선물 (Receiving Gifts) - 3문항
            {"id": "love_g1", "dimension": "gifts", "text": "생각지 못한 선물을 받으면 매우 기쁘다", "reverse": False},
            {"id": "love_g2", "dimension": "gifts", "text": "선물의 크기보다 마음이 담긴 것이 중요하다", "reverse": False},
            {"id": "love_g3", "dimension": "gifts", "text": "기념일에 선물을 받으면 사랑받는다고 느낀다", "reverse": False},
            # 함께하는 시간 (Quality Time) - 3문항
            {"id": "love_t1", "dimension": "time", "text": "상대방과 단둘이 시간을 보낼 때 행복하다", "reverse": False},
            {"id": "love_t2", "dimension": "time", "text": "대화에 집중해주면 소중하게 여겨진다고 느낀다", "reverse": False},
            {"id": "love_t3", "dimension": "time", "text": "함께 활동하는 것이 사랑 표현이라고 생각한다", "reverse": False},
            # 스킨십 (Physical Touch) - 3문항
            {"id": "love_p1", "dimension": "touch", "text": "포옹이나 손잡기를 통해 사랑을 느낀다", "reverse": False},
            {"id": "love_p2", "dimension": "touch", "text": "스킨십이 없으면 거리감을 느낀다", "reverse": False},
            {"id": "love_p3", "dimension": "touch", "text": "신체적 접촉이 나에게 안정감을 준다", "reverse": False},
        ],
        "options": ["전혀 그렇지 않다", "그렇지 않다", "보통이다", "그렇다", "매우 그렇다"],
    },

    TestType.STRESS: {
        "name": "스트레스 지수 검사 (PSS-10)",
        "description": "최근 한 달간의 스트레스 수준을 측정합니다",
        "duration": "약 4분",
        "dimensions": ["stress"],
        "questions": [
            {"id": "pss_1", "dimension": "stress", "text": "예상치 못한 일이 생겨서 기분이 상한 적이 있다", "reverse": False},
            {"id": "pss_2", "dimension": "stress", "text": "중요한 일을 통제할 수 없다고 느꼈다", "reverse": False},
            {"id": "pss_3", "dimension": "stress", "text": "긴장하거나 스트레스를 받았다", "reverse": False},
            {"id": "pss_4", "dimension": "stress", "text": "일상의 짜증스러운 일을 처리할 수 없다고 느꼈다", "reverse": False},
            {"id": "pss_5", "dimension": "stress", "text": "일이 뜻대로 되어간다고 느꼈다", "reverse": True},
            {"id": "pss_6", "dimension": "stress", "text": "해야 할 일에 대처할 수 없다고 느꼈다", "reverse": False},
            {"id": "pss_7", "dimension": "stress", "text": "짜증나는 일을 잘 다스릴 수 있었다", "reverse": True},
            {"id": "pss_8", "dimension": "stress", "text": "모든 일이 잘 되어가고 있다고 느꼈다", "reverse": True},
            {"id": "pss_9", "dimension": "stress", "text": "통제할 수 없는 일 때문에 화가 났다", "reverse": False},
            {"id": "pss_10", "dimension": "stress", "text": "어려운 일이 쌓여서 극복할 수 없다고 느꼈다", "reverse": False},
        ],
        "options": ["전혀 없었다", "거의 없었다", "가끔 있었다", "자주 있었다", "매우 자주 있었다"],
        "time_frame": "최근 한 달간",
    },

    TestType.ANXIETY: {
        "name": "불안 선별검사 (GAD-7)",
        "description": "범불안장애 선별을 위한 표준화된 검사입니다",
        "duration": "약 3분",
        "dimensions": ["anxiety"],
        "questions": [
            {"id": "gad_1", "dimension": "anxiety", "text": "초조하거나 불안하거나 조마조마하게 느낀다", "reverse": False},
            {"id": "gad_2", "dimension": "anxiety", "text": "걱정하는 것을 멈추거나 조절할 수 없다", "reverse": False},
            {"id": "gad_3", "dimension": "anxiety", "text": "여러 가지 것들에 대해 걱정을 너무 많이 한다", "reverse": False},
            {"id": "gad_4", "dimension": "anxiety", "text": "편하게 있기가 어렵다", "reverse": False},
            {"id": "gad_5", "dimension": "anxiety", "text": "너무 안절부절 못해서 가만히 있기가 어렵다", "reverse": False},
            {"id": "gad_6", "dimension": "anxiety", "text": "쉽게 짜증이 나거나 쉽게 성을 내게 된다", "reverse": False},
            {"id": "gad_7", "dimension": "anxiety", "text": "마치 끔찍한 일이 일어날 것처럼 두렵게 느껴진다", "reverse": False},
        ],
        "options": ["전혀 없음", "며칠 동안", "1주일 이상", "거의 매일"],
        "time_frame": "지난 2주간",
    },

    TestType.DEPRESSION: {
        "name": "우울 선별검사 (PHQ-9)",
        "description": "우울증 선별을 위한 표준화된 검사입니다",
        "duration": "약 4분",
        "dimensions": ["depression"],
        "questions": [
            {"id": "phq_1", "dimension": "depression", "text": "일을 하는 것에 흥미나 재미가 거의 없다", "reverse": False},
            {"id": "phq_2", "dimension": "depression", "text": "기분이 가라앉거나 우울하거나 희망이 없다고 느낀다", "reverse": False},
            {"id": "phq_3", "dimension": "depression", "text": "잠들기 어렵거나 자주 깬다 / 또는 너무 많이 잔다", "reverse": False},
            {"id": "phq_4", "dimension": "depression", "text": "피곤하다고 느끼거나 기운이 거의 없다", "reverse": False},
            {"id": "phq_5", "dimension": "depression", "text": "식욕이 줄었다 / 또는 과식을 한다", "reverse": False},
            {"id": "phq_6", "dimension": "depression", "text": "내 자신이 실패자로 여겨지거나 자신과 가족을 실망시켰다고 느낀다", "reverse": False},
            {"id": "phq_7", "dimension": "depression", "text": "신문을 읽거나 TV를 보는 것과 같은 일에 집중하기 어렵다", "reverse": False},
            {"id": "phq_8", "dimension": "depression", "text": "다른 사람들이 알아챌 정도로 느리게 움직이거나 말한다 / 또는 반대로 평소보다 많이 움직인다", "reverse": False},
            {"id": "phq_9", "dimension": "depression", "text": "차라리 죽는 것이 낫겠다는 생각이 든다", "reverse": False},
        ],
        "options": ["전혀 없음", "며칠 동안", "1주일 이상", "거의 매일"],
        "time_frame": "지난 2주간",
        "warning": "이 검사는 선별 목적이며, 정확한 진단을 위해서는 전문가 상담이 필요합니다.",
    },
}


# ============ 개별 분석 에이전트들 ============

class Big5AnalysisAgent(BaseAgent):
    """Big5 분석 에이전트"""
    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, scores: dict) -> dict:
        prompt = f"""당신은 성격 심리학 전문가입니다.
Big5 성격검사 결과를 분석해주세요.

점수 (각 0-100):
- 개방성(Openness): {scores.get('openness', 0)}
- 성실성(Conscientiousness): {scores.get('conscientiousness', 0)}
- 외향성(Extraversion): {scores.get('extraversion', 0)}
- 친화성(Agreeableness): {scores.get('agreeableness', 0)}
- 신경증(Neuroticism): {scores.get('neuroticism', 0)}

다음 JSON 형식으로 분석해주세요:
{{
    "profile_type": "프로파일 유형명 (예: 창의적 탐험가)",
    "summary": "전체 성격 요약 (3-4문장)",
    "dimension_analysis": {{
        "openness": {{"level": "높음/보통/낮음", "description": "설명", "traits": ["특성1", "특성2"]}},
        "conscientiousness": {{"level": "높음/보통/낮음", "description": "설명", "traits": ["특성1", "특성2"]}},
        "extraversion": {{"level": "높음/보통/낮음", "description": "설명", "traits": ["특성1", "특성2"]}},
        "agreeableness": {{"level": "높음/보통/낮음", "description": "설명", "traits": ["특성1", "특성2"]}},
        "neuroticism": {{"level": "높음/보통/낮음", "description": "설명", "traits": ["특성1", "특성2"]}}
    }},
    "strengths": ["강점1", "강점2", "강점3"],
    "growth_areas": ["성장 영역1", "성장 영역2"],
    "career_suggestions": ["적합 직업/역할 1", "적합 직업/역할 2"],
    "relationship_style": "대인관계 스타일 설명 (2문장)"
}}

따뜻하고 긍정적인 톤으로 작성해주세요."""

        return await self._generate_json(prompt)


class AttachmentAnalysisAgent(BaseAgent):
    """애착유형 분석 에이전트"""
    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, scores: dict) -> dict:
        prompt = f"""당신은 애착이론 전문 심리상담사입니다.
애착유형 검사 결과를 분석해주세요.

점수 (각 0-100):
- 안정(Secure): {scores.get('secure', 0)}
- 불안(Anxious): {scores.get('anxious', 0)}
- 회피(Avoidant): {scores.get('avoidant', 0)}
- 혼란(Fearful): {scores.get('fearful', 0)}

다음 JSON 형식으로 분석해주세요:
{{
    "primary_type": "주 애착유형",
    "secondary_type": "부 애착유형 (있다면)",
    "summary": "애착 패턴 요약 (3-4문장)",
    "type_description": "해당 유형의 특징 설명",
    "relationship_patterns": ["관계 패턴1", "관계 패턴2", "관계 패턴3"],
    "triggers": ["불안/회피 유발 상황1", "유발 상황2"],
    "coping_strategies": ["대처 전략1", "대처 전략2", "대처 전략3"],
    "growth_suggestions": ["성장을 위한 제안1", "제안2", "제안3"],
    "partner_compatibility": "파트너 유형별 궁합 조언"
}}

비판단적이고 지지적인 톤으로 작성해주세요."""

        return await self._generate_json(prompt)


class MBTIAnalysisAgent(BaseAgent):
    """MBTI 분석 에이전트"""
    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, type_code: str, dimension_scores: dict) -> dict:
        prompt = f"""당신은 MBTI 전문가입니다.
MBTI 검사 결과를 분석해주세요.

결과 유형: {type_code}
차원별 점수:
- E/I: E {dimension_scores.get('E', 0)}% / I {dimension_scores.get('I', 0)}%
- S/N: S {dimension_scores.get('S', 0)}% / N {dimension_scores.get('N', 0)}%
- T/F: T {dimension_scores.get('T', 0)}% / F {dimension_scores.get('F', 0)}%
- J/P: J {dimension_scores.get('J', 0)}% / P {dimension_scores.get('P', 0)}%

다음 JSON 형식으로 분석해주세요:
{{
    "type": "{type_code}",
    "nickname": "유형 별명 (예: 논리적인 사색가)",
    "summary": "유형 요약 (3-4문장)",
    "core_traits": ["핵심 특성1", "핵심 특성2", "핵심 특성3", "핵심 특성4"],
    "cognitive_functions": {{
        "dominant": "주기능 설명",
        "auxiliary": "부기능 설명"
    }},
    "strengths": ["강점1", "강점2", "강점3"],
    "weaknesses": ["약점1", "약점2"],
    "career_matches": ["적합 직업1", "적합 직업2", "적합 직업3"],
    "relationship_style": "연애/친구 관계 스타일",
    "compatible_types": ["궁합 유형1", "궁합 유형2"],
    "growth_advice": "성장을 위한 조언 (2-3문장)"
}}

재미있고 공감되는 톤으로 작성해주세요."""

        return await self._generate_json(prompt)


class LoveLanguageAnalysisAgent(BaseAgent):
    """사랑의 언어 분석 에이전트"""
    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, scores: dict) -> dict:
        prompt = f"""당신은 관계 코칭 전문가입니다.
사랑의 언어 검사 결과를 분석해주세요.

점수 (각 0-100):
- 인정의 말(Words): {scores.get('words', 0)}
- 봉사(Service): {scores.get('service', 0)}
- 선물(Gifts): {scores.get('gifts', 0)}
- 함께하는 시간(Time): {scores.get('time', 0)}
- 스킨십(Touch): {scores.get('touch', 0)}

다음 JSON 형식으로 분석해주세요:
{{
    "primary_language": "1순위 사랑의 언어",
    "secondary_language": "2순위 사랑의 언어",
    "summary": "사랑 표현 방식 요약 (3문장)",
    "language_details": {{
        "words": {{"rank": 1-5, "description": "이 언어가 당신에게 어떤 의미인지"}},
        "service": {{"rank": 1-5, "description": "설명"}},
        "gifts": {{"rank": 1-5, "description": "설명"}},
        "time": {{"rank": 1-5, "description": "설명"}},
        "touch": {{"rank": 1-5, "description": "설명"}}
    }},
    "how_to_feel_loved": ["사랑받는다고 느끼는 방법1", "방법2", "방법3"],
    "how_you_show_love": ["사랑을 표현하는 방법1", "방법2"],
    "partner_tips": "파트너에게 전하는 팁 (상대방이 알면 좋을 것)",
    "self_care_suggestions": ["자기 돌봄 방법1", "방법2"]
}}

따뜻하고 로맨틱한 톤으로 작성해주세요."""

        return await self._generate_json(prompt)


class ClinicalAnalysisAgent(BaseAgent):
    """임상 척도 분석 에이전트 (스트레스/불안/우울)"""
    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, test_type: str, score: int, max_score: int) -> dict:
        test_info = {
            "stress": {"name": "스트레스", "scale": "PSS-10", "ranges": [(0, 13, "낮음"), (14, 26, "보통"), (27, 40, "높음")]},
            "anxiety": {"name": "불안", "scale": "GAD-7", "ranges": [(0, 4, "정상"), (5, 9, "경미"), (10, 14, "중등도"), (15, 21, "심함")]},
            "depression": {"name": "우울", "scale": "PHQ-9", "ranges": [(0, 4, "정상"), (5, 9, "경미"), (10, 14, "중등도"), (15, 19, "중등도-심함"), (20, 27, "심함")]},
        }

        info = test_info.get(test_type, test_info["stress"])
        level = "보통"
        for min_s, max_s, lv in info["ranges"]:
            if min_s <= score <= max_s:
                level = lv
                break

        prompt = f"""당신은 임상심리 전문가입니다.
{info['name']} 검사({info['scale']}) 결과를 분석해주세요.

점수: {score} / {max_score}
수준: {level}

다음 JSON 형식으로 분석해주세요:
{{
    "score": {score},
    "max_score": {max_score},
    "level": "{level}",
    "percentage": {round(score/max_score*100)},
    "interpretation": "점수 해석 (2-3문장)",
    "possible_causes": ["가능한 원인1", "원인2"],
    "physical_symptoms": ["관련 신체 증상1", "증상2"],
    "coping_strategies": ["대처 방법1", "대처 방법2", "대처 방법3"],
    "lifestyle_suggestions": ["생활 습관 제안1", "제안2"],
    "professional_help": "전문가 도움 필요 여부 및 조언",
    "resources": ["도움 받을 수 있는 곳1", "곳2"],
    "encouragement": "격려의 말 (2문장)"
}}

따뜻하고 지지적인 톤으로 작성해주세요.
주의: 이 검사는 선별 목적이며, 진단이 아님을 명시해주세요."""

        return await self._generate_json(prompt)


# ============ PM 에이전트 ============

class PsychologyPMAgent(BaseAgent):
    """심리검사 PM 에이전트 (오케스트레이터)"""

    def __init__(self):
        super().__init__(model_type="pm")
        self.big5_agent = Big5AnalysisAgent()
        self.attachment_agent = AttachmentAnalysisAgent()
        self.mbti_agent = MBTIAnalysisAgent()
        self.love_agent = LoveLanguageAnalysisAgent()
        self.clinical_agent = ClinicalAnalysisAgent()

    def get_test_info(self, test_type: TestType) -> dict:
        """검사 정보 반환"""
        test = PSYCHOLOGY_TESTS.get(test_type)
        if not test:
            return None
        return {
            "type": test_type.value,
            "name": test["name"],
            "description": test["description"],
            "duration": test["duration"],
            "question_count": len(test["questions"]),
        }

    def get_all_tests(self) -> list:
        """모든 검사 목록 반환"""
        return [self.get_test_info(t) for t in TestType]

    def get_questions(self, test_type: TestType) -> list:
        """검사 질문 목록 반환"""
        test = PSYCHOLOGY_TESTS.get(test_type)
        if not test:
            return []
        return [
            {
                "id": q["id"],
                "text": q["text"],
                "options": test["options"],
            }
            for q in test["questions"]
        ]

    def calculate_scores(self, test_type: TestType, answers: List[dict]) -> dict:
        """답변으로부터 점수 계산"""
        test = PSYCHOLOGY_TESTS.get(test_type)
        if not test:
            return {}

        # 차원별 점수 집계
        dimension_scores = {}
        dimension_counts = {}

        for answer in answers:
            q_id = answer["question_id"]
            q_data = next((q for q in test["questions"] if q["id"] == q_id), None)
            if not q_data:
                continue

            dimension = q_data["dimension"]
            score = answer["answer_index"]

            # 역채점 처리
            if q_data.get("reverse"):
                max_idx = len(test["options"]) - 1
                score = max_idx - score

            if dimension not in dimension_scores:
                dimension_scores[dimension] = 0
                dimension_counts[dimension] = 0

            dimension_scores[dimension] += score
            dimension_counts[dimension] += 1

        # 백분율로 변환
        max_score_per_item = len(test["options"]) - 1
        result = {}
        for dim, total in dimension_scores.items():
            count = dimension_counts[dim]
            max_total = count * max_score_per_item
            result[dim] = round((total / max_total) * 100) if max_total > 0 else 0

        # MBTI 특수 처리
        if test_type == TestType.MBTI:
            result = self._calculate_mbti_type(test, answers)

        return result

    def _calculate_mbti_type(self, test: dict, answers: List[dict]) -> dict:
        """MBTI 유형 계산"""
        poles = {"E": 0, "I": 0, "S": 0, "N": 0, "T": 0, "F": 0, "J": 0, "P": 0}

        for answer in answers:
            q_id = answer["question_id"]
            q_data = next((q for q in test["questions"] if q["id"] == q_id), None)
            if not q_data:
                continue

            pole = q_data.get("pole")
            score = answer["answer_index"]  # 0-4

            if pole:
                # 높은 점수 = 해당 극에 동의
                poles[pole] += score

        # 각 차원별 백분율 계산
        result = {
            "E": round(poles["E"] / (poles["E"] + poles["I"] + 0.001) * 100),
            "I": round(poles["I"] / (poles["E"] + poles["I"] + 0.001) * 100),
            "S": round(poles["S"] / (poles["S"] + poles["N"] + 0.001) * 100),
            "N": round(poles["N"] / (poles["S"] + poles["N"] + 0.001) * 100),
            "T": round(poles["T"] / (poles["T"] + poles["F"] + 0.001) * 100),
            "F": round(poles["F"] / (poles["T"] + poles["F"] + 0.001) * 100),
            "J": round(poles["J"] / (poles["J"] + poles["P"] + 0.001) * 100),
            "P": round(poles["P"] / (poles["J"] + poles["P"] + 0.001) * 100),
        }

        # 유형 코드 결정
        type_code = ""
        type_code += "E" if result["E"] >= result["I"] else "I"
        type_code += "S" if result["S"] >= result["N"] else "N"
        type_code += "T" if result["T"] >= result["F"] else "F"
        type_code += "J" if result["J"] >= result["P"] else "P"

        result["type_code"] = type_code
        return result

    async def analyze(self, test_type: TestType, scores: dict) -> dict:
        """검사 결과 분석"""
        try:
            if test_type == TestType.BIG5:
                return await self.big5_agent.run(scores)
            elif test_type == TestType.ATTACHMENT:
                return await self.attachment_agent.run(scores)
            elif test_type == TestType.MBTI:
                type_code = scores.get("type_code", "INFP")
                return await self.mbti_agent.run(type_code, scores)
            elif test_type == TestType.LOVE_LANGUAGE:
                return await self.love_agent.run(scores)
            elif test_type in [TestType.STRESS, TestType.ANXIETY, TestType.DEPRESSION]:
                # 임상 척도는 단일 점수
                test = PSYCHOLOGY_TESTS[test_type]
                total_score = sum(scores.values())
                max_score = len(test["questions"]) * (len(test["options"]) - 1)
                return await self.clinical_agent.run(test_type.value, total_score, max_score)
            else:
                return {"error": "지원하지 않는 검사 유형입니다."}
        except Exception as e:
            print(f"Psychology analysis error: {e}")
            return {"error": str(e)}

    async def generate_comprehensive_report(self, results: List[dict]) -> dict:
        """여러 검사 결과 종합 리포트"""
        prompt = f"""당신은 통합 심리분석 전문가입니다.
다음 심리검사 결과들을 종합하여 통합 심리 프로파일을 작성해주세요.

검사 결과:
{results}

다음 JSON 형식으로 종합 리포트를 작성해주세요:
{{
    "overall_profile": "종합 심리 프로파일 요약 (4-5문장)",
    "key_insights": ["핵심 인사이트1", "인사이트2", "인사이트3"],
    "personality_summary": "성격 종합",
    "relationship_summary": "관계 패턴 종합",
    "emotional_wellbeing": "정서적 웰빙 상태",
    "integrated_recommendations": ["통합 추천1", "추천2", "추천3"],
    "self_care_plan": {{
        "daily": ["일상 실천 사항1", "사항2"],
        "weekly": ["주간 실천 사항1", "사항2"],
        "monthly": ["월간 점검 사항1"]
    }},
    "growth_journey": "성장을 위한 여정 제안 (3-4문장)"
}}

따뜻하고 통찰력 있는 톤으로 작성해주세요."""

        return await self._generate_json(prompt)
