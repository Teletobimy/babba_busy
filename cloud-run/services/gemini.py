import google.generativeai as genai
from typing import Optional, List
from config import get_settings

settings = get_settings()

# Gemini API 설정
genai.configure(api_key=settings.gemini_api_key)


class GeminiService:
    """Gemini AI 서비스 (일반 요약용 - Lite 모델)"""

    def __init__(self):
        self.model = genai.GenerativeModel(settings.gemini_lite_model)

    async def generate_daily_summary(
        self,
        user_name: str,
        pending_todos: int,
        completed_today: int,
        upcoming_events: int,
        monthly_expense: Optional[int] = None,
        monthly_income: Optional[int] = None,
    ) -> str:
        """일일 요약 생성"""

        expense_info = ""
        if monthly_expense is not None:
            expense_info = f"\n- 이번 달 지출: {monthly_expense:,}원"
            if monthly_income is not None:
                balance = monthly_income - monthly_expense
                expense_info += f"\n- 이번 달 수입: {monthly_income:,}원 (잔액: {balance:,}원)"

        prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 친근한 AI 비서입니다.
{user_name}님에게 오늘의 요약을 2-3문장으로 작성해주세요.

현재 상황:
- 남은 할일: {pending_todos}개
- 오늘 완료한 할일: {completed_today}개
- 다가오는 일정: {upcoming_events}개{expense_info}

작성 지침:
- 따뜻하고 격려하는 톤으로
- 이모지를 적절히 사용
- 구체적인 숫자를 언급
- 한국어로 작성"""

        try:
            response = await self.model.generate_content_async(prompt)
            return response.text.strip()
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_daily_summary(user_name, pending_todos, completed_today)

    async def generate_weekly_summary(
        self,
        user_name: str,
        completed_todos: int,
        total_todos: int,
        events_attended: int,
        weekly_expense: Optional[int] = None,
    ) -> str:
        """주간 요약 생성"""

        completion_rate = (completed_todos / total_todos * 100) if total_todos > 0 else 0

        expense_info = ""
        if weekly_expense is not None:
            expense_info = f"\n- 이번 주 지출: {weekly_expense:,}원"

        prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 친근한 AI 비서입니다.
{user_name}님의 이번 주 활동을 2-3문장으로 요약해주세요.

이번 주 현황:
- 완료한 할일: {completed_todos}개 / {total_todos}개 (완료율: {completion_rate:.0f}%)
- 참여한 일정: {events_attended}개{expense_info}

작성 지침:
- 성과를 칭찬하는 톤
- 다음 주를 위한 간단한 격려
- 이모지 적절히 사용
- 한국어로 작성"""

        try:
            response = await self.model.generate_content_async(prompt)
            return response.text.strip()
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_weekly_summary(user_name, completion_rate)

    async def analyze_business_idea(
        self,
        idea: str,
        industry: Optional[str] = None,
        target_market: Optional[str] = None,
        budget: Optional[str] = None,
    ) -> dict:
        """사업 아이디어 분석"""

        context = ""
        if industry:
            context += f"\n- 산업: {industry}"
        if target_market:
            context += f"\n- 타겟 시장: {target_market}"
        if budget:
            context += f"\n- 예산: {budget}"

        prompt = f"""당신은 스타트업 비즈니스 컨설턴트입니다.
다음 사업 아이디어를 분석해주세요.

사업 아이디어:
{idea}
{context}

다음 JSON 형식으로 응답해주세요:
{{
    "strengths": ["강점1", "강점2", "강점3"],
    "weaknesses": ["약점1", "약점2"],
    "opportunities": ["기회1", "기회2"],
    "threats": ["위협1", "위협2"],
    "market_size": "예상 시장 규모 설명",
    "competitors": ["경쟁사1", "경쟁사2"],
    "recommendation": "종합 추천 의견 (2-3문장)",
    "next_steps": ["다음 단계1", "다음 단계2", "다음 단계3"],
    "score": 75
}}

score는 0-100 사이의 정수로, 사업성 점수입니다."""

        try:
            response = await self.model.generate_content_async(prompt)
            # JSON 파싱 시도
            import json
            text = response.text.strip()
            # ```json ... ``` 형식 처리
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            return json.loads(text)
        except Exception as e:
            print(f"Gemini API error: {e}")
            return {
                "strengths": ["분석 중 오류가 발생했습니다"],
                "weaknesses": [],
                "opportunities": [],
                "threats": [],
                "market_size": "분석 불가",
                "competitors": [],
                "recommendation": "다시 시도해주세요.",
                "next_steps": [],
                "score": 0,
            }

    async def chat_business(self, history: List[dict], user_message: str) -> str:
        """사업 검토 대화"""

        system_prompt = """당신은 스타트업 비즈니스 컨설턴트입니다.
사용자의 사업 아이디어에 대해 건설적인 피드백을 제공하세요.
질문을 통해 아이디어를 구체화하도록 도와주세요.
한국어로 응답하세요."""

        # 대화 히스토리 구성
        messages = [{"role": "user", "parts": [system_prompt]}]
        for msg in history:
            messages.append({"role": msg["role"], "parts": [msg["content"]]})
        messages.append({"role": "user", "parts": [user_message]})

        try:
            chat = self.model.start_chat(history=messages[:-1])
            response = await chat.send_message_async(user_message)
            return response.text.strip()
        except Exception as e:
            print(f"Gemini API error: {e}")
            return "죄송합니다. 응답을 생성하는 중 오류가 발생했습니다. 다시 시도해주세요."

    async def generate_psychology_result(
        self,
        test_type: str,
        answers: List[dict],
        scores: dict,
    ) -> dict:
        """심리검사 결과 분석"""

        prompt = f"""당신은 심리상담 전문가입니다.
다음 심리검사 결과를 분석해주세요.

검사 유형: {test_type}
점수: {scores}

다음 JSON 형식으로 응답해주세요:
{{
    "summary": "전체 결과 요약 (2-3문장)",
    "detailed_analysis": "상세 분석 (3-4문장)",
    "recommendations": ["추천1", "추천2", "추천3"],
    "positive_aspects": ["긍정적 측면1", "긍정적 측면2"],
    "areas_for_growth": ["성장 영역1", "성장 영역2"]
}}

따뜻하고 지지적인 톤으로 작성하세요. 한국어로 응답하세요."""

        try:
            response = await self.model.generate_content_async(prompt)
            import json
            text = response.text.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            return json.loads(text)
        except Exception as e:
            print(f"Gemini API error: {e}")
            return {
                "summary": "검사 결과 분석 중 오류가 발생했습니다.",
                "detailed_analysis": "",
                "recommendations": ["전문 상담사와 상담을 권장합니다."],
                "positive_aspects": [],
                "areas_for_growth": [],
            }

    def _fallback_daily_summary(self, user_name: str, pending: int, completed: int) -> str:
        """일일 요약 폴백"""
        if pending == 0 and completed == 0:
            return f"안녕하세요 {user_name}님! 오늘의 할일을 추가해보세요 ✨"
        elif pending == 0:
            return f"대단해요 {user_name}님! 할일을 모두 완료했어요 🎉"
        elif pending <= 3:
            return f"{user_name}님, 오늘 할일 {pending}개만 남았어요. 조금만 더 힘내세요! 💪"
        else:
            return f"{user_name}님, 오늘 할일이 {pending}개 있어요. 하나씩 해결해봐요! 📝"

    def _fallback_weekly_summary(self, user_name: str, rate: float) -> str:
        """주간 요약 폴백"""
        if rate >= 80:
            return f"{user_name}님, 이번 주 완료율 {rate:.0f}%! 정말 잘하셨어요! 🎉"
        elif rate >= 50:
            return f"{user_name}님, 이번 주 완료율 {rate:.0f}%예요. 다음 주도 화이팅! 💪"
        else:
            return f"{user_name}님, 이번 주 완료율 {rate:.0f}%네요. 다음 주는 더 잘할 수 있어요! ✨"


# 싱글톤 인스턴스
gemini_service = GeminiService()
