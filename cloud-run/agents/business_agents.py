import asyncio
from typing import Optional
from .base_agent import BaseAgent


class MarketResearchAgent(BaseAgent):
    """시장 조사 에이전트"""

    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, idea: str, industry: Optional[str] = None) -> dict:
        prompt = f"""당신은 시장 조사 전문가입니다.
다음 사업 아이디어에 대한 시장 분석을 수행해주세요.

사업 아이디어: {idea}
{f'산업 분야: {industry}' if industry else ''}

다음 JSON 형식으로 응답해주세요:
{{
    "market_size": "예상 시장 규모 (금액 포함)",
    "growth_rate": "시장 성장률",
    "target_customers": ["타겟 고객 1", "타겟 고객 2", "타겟 고객 3"],
    "customer_pain_points": ["고객 불편점 1", "고객 불편점 2"],
    "trends": ["주요 트렌드 1", "주요 트렌드 2", "주요 트렌드 3"],
    "market_opportunity": "시장 기회 요약 (2-3문장)"
}}

한국 시장 기준으로 분석하고, 구체적인 수치를 포함해주세요."""

        return await self._generate_json(prompt)


class CompetitorAnalysisAgent(BaseAgent):
    """경쟁사 분석 에이전트"""

    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, idea: str, industry: Optional[str] = None) -> dict:
        prompt = f"""당신은 경쟁 분석 전문가입니다.
다음 사업 아이디어와 관련된 경쟁사 분석을 수행해주세요.

사업 아이디어: {idea}
{f'산업 분야: {industry}' if industry else ''}

다음 JSON 형식으로 응답해주세요:
{{
    "direct_competitors": [
        {{"name": "경쟁사명", "description": "서비스 설명", "strength": "강점", "weakness": "약점"}}
    ],
    "indirect_competitors": [
        {{"name": "간접 경쟁사명", "description": "서비스 설명"}}
    ],
    "differentiation_points": ["차별화 포인트 1", "차별화 포인트 2", "차별화 포인트 3"],
    "entry_barriers": ["진입 장벽 1", "진입 장벽 2"],
    "competitive_advantage": "경쟁 우위 확보 방안 (2-3문장)"
}}

실제 존재하는 한국 서비스/기업 위주로 분석해주세요."""

        return await self._generate_json(prompt)


class ProductPlanningAgent(BaseAgent):
    """상품 기획 에이전트"""

    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, idea: str, market_data: dict, competitor_data: dict) -> dict:
        prompt = f"""당신은 프로덕트 매니저입니다.
다음 정보를 바탕으로 MVP(최소 기능 제품) 기획을 해주세요.

사업 아이디어: {idea}

시장 분석 결과:
- 타겟 고객: {market_data.get('target_customers', [])}
- 고객 불편점: {market_data.get('customer_pain_points', [])}

경쟁사 분석 결과:
- 차별화 포인트: {competitor_data.get('differentiation_points', [])}

다음 JSON 형식으로 응답해주세요:
{{
    "mvp_definition": "MVP 한줄 정의",
    "core_features": [
        {{"feature": "핵심 기능 1", "priority": "P0", "description": "설명"}},
        {{"feature": "핵심 기능 2", "priority": "P0", "description": "설명"}},
        {{"feature": "부가 기능 1", "priority": "P1", "description": "설명"}}
    ],
    "user_journey": ["단계1: 사용자 행동", "단계2: 사용자 행동", "단계3: 사용자 행동"],
    "tech_stack_suggestion": ["추천 기술 1", "추천 기술 2"],
    "roadmap": [
        {{"phase": "Phase 1 (0-3개월)", "goals": ["목표1", "목표2"]}},
        {{"phase": "Phase 2 (3-6개월)", "goals": ["목표1", "목표2"]}},
        {{"phase": "Phase 3 (6-12개월)", "goals": ["목표1", "목표2"]}}
    ]
}}"""

        return await self._generate_json(prompt)


class FinancialAnalysisAgent(BaseAgent):
    """재무 분석 에이전트"""

    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, idea: str, budget: Optional[str] = None, market_data: dict = None) -> dict:
        prompt = f"""당신은 스타트업 재무 전문가입니다.
다음 사업 아이디어에 대한 재무 분석을 수행해주세요.

사업 아이디어: {idea}
{f'예산 규모: {budget}' if budget else '예산: 미정'}
시장 규모: {market_data.get('market_size', '분석 중') if market_data else '분석 중'}

다음 JSON 형식으로 응답해주세요:
{{
    "initial_costs": {{
        "development": "개발비 (예: 3000만원)",
        "marketing": "마케팅비 (예: 1000만원)",
        "operation": "운영비 (예: 500만원)",
        "total": "총 초기 비용"
    }},
    "monthly_costs": {{
        "fixed": "월 고정비",
        "variable": "월 변동비 (예상)",
        "total": "월 총 비용"
    }},
    "revenue_model": [
        {{"model": "수익 모델 1", "description": "설명", "potential": "예상 매출"}}
    ],
    "break_even_analysis": {{
        "monthly_target": "월 손익분기 매출",
        "customers_needed": "필요 고객 수",
        "timeline": "예상 달성 기간"
    }},
    "funding_suggestion": "자금 조달 제안 (2-3문장)",
    "financial_risks": ["재무 리스크 1", "재무 리스크 2"]
}}

한국 시장 기준, 현실적인 수치로 분석해주세요."""

        return await self._generate_json(prompt)


class BusinessPMAgent(BaseAgent):
    """사업 검토 PM 에이전트 (오케스트레이터)"""

    def __init__(self):
        super().__init__(model_type="pm")
        self.market_agent = MarketResearchAgent()
        self.competitor_agent = CompetitorAnalysisAgent()
        self.product_agent = ProductPlanningAgent()
        self.financial_agent = FinancialAnalysisAgent()

    async def run(
        self,
        idea: str,
        industry: Optional[str] = None,
        target_market: Optional[str] = None,
        budget: Optional[str] = None,
        on_progress: Optional[callable] = None,
    ) -> dict:
        """
        전체 사업 분석 실행
        on_progress: 진행 상황 콜백 (step_name, status)
        """
        results = {}
        errors = []

        # 1. 시장 조사 & 경쟁사 분석 (병렬)
        if on_progress:
            await on_progress("market_research", "started")
            await on_progress("competitor_analysis", "started")

        try:
            market_task = self.market_agent.run(idea, industry)
            competitor_task = self.competitor_agent.run(idea, industry)
            market_result, competitor_result = await asyncio.gather(
                market_task, competitor_task, return_exceptions=True
            )

            if isinstance(market_result, Exception):
                errors.append(f"시장 조사 오류: {market_result}")
                market_result = {}
            else:
                results["market_analysis"] = market_result
                if on_progress:
                    await on_progress("market_research", "completed")

            if isinstance(competitor_result, Exception):
                errors.append(f"경쟁사 분석 오류: {competitor_result}")
                competitor_result = {}
            else:
                results["competitor_analysis"] = competitor_result
                if on_progress:
                    await on_progress("competitor_analysis", "completed")

        except Exception as e:
            errors.append(f"1단계 오류: {e}")
            market_result, competitor_result = {}, {}

        # 2. 상품 기획 & 재무 분석 (병렬, 이전 결과 활용)
        if on_progress:
            await on_progress("product_planning", "started")
            await on_progress("financial_analysis", "started")

        try:
            product_task = self.product_agent.run(idea, market_result, competitor_result)
            financial_task = self.financial_agent.run(idea, budget, market_result)
            product_result, financial_result = await asyncio.gather(
                product_task, financial_task, return_exceptions=True
            )

            if isinstance(product_result, Exception):
                errors.append(f"상품 기획 오류: {product_result}")
                product_result = {}
            else:
                results["product_planning"] = product_result
                if on_progress:
                    await on_progress("product_planning", "completed")

            if isinstance(financial_result, Exception):
                errors.append(f"재무 분석 오류: {financial_result}")
                financial_result = {}
            else:
                results["financial_analysis"] = financial_result
                if on_progress:
                    await on_progress("financial_analysis", "completed")

        except Exception as e:
            errors.append(f"2단계 오류: {e}")
            product_result, financial_result = {}, {}

        # 3. PM 종합 리포트 생성
        if on_progress:
            await on_progress("final_report", "started")

        final_report = await self._generate_final_report(
            idea, results, industry, target_market, budget
        )

        if on_progress:
            await on_progress("final_report", "completed")

        return {
            "idea": idea,
            "industry": industry,
            "target_market": target_market,
            "budget": budget,
            "analysis": results,
            "report": final_report,
            "errors": errors if errors else None,
        }

    async def _generate_final_report(
        self,
        idea: str,
        results: dict,
        industry: Optional[str],
        target_market: Optional[str],
        budget: Optional[str],
    ) -> dict:
        """종합 리포트 생성"""
        prompt = f"""당신은 시니어 비즈니스 컨설턴트입니다.
다음 분석 결과들을 종합하여 최종 사업성 평가 리포트를 작성해주세요.

## 사업 아이디어
{idea}

## 분석 결과
시장 분석: {results.get('market_analysis', '분석 실패')}
경쟁사 분석: {results.get('competitor_analysis', '분석 실패')}
상품 기획: {results.get('product_planning', '분석 실패')}
재무 분석: {results.get('financial_analysis', '분석 실패')}

## 추가 정보
- 산업: {industry or '미지정'}
- 타겟 시장: {target_market or '미지정'}
- 예산: {budget or '미지정'}

다음 JSON 형식으로 종합 리포트를 작성해주세요:
{{
    "executive_summary": "핵심 요약 (3-4문장)",
    "overall_score": 75,
    "score_breakdown": {{
        "market_potential": 80,
        "competitive_position": 70,
        "product_feasibility": 75,
        "financial_viability": 72
    }},
    "swot": {{
        "strengths": ["강점 1", "강점 2", "강점 3"],
        "weaknesses": ["약점 1", "약점 2"],
        "opportunities": ["기회 1", "기회 2"],
        "threats": ["위협 1", "위협 2"]
    }},
    "key_success_factors": ["성공 요인 1", "성공 요인 2", "성공 요인 3"],
    "risk_factors": ["리스크 1", "리스크 2"],
    "recommendations": ["추천 사항 1", "추천 사항 2", "추천 사항 3"],
    "next_steps": [
        {{"step": 1, "action": "다음 단계 1", "timeline": "1-2주"}},
        {{"step": 2, "action": "다음 단계 2", "timeline": "2-4주"}},
        {{"step": 3, "action": "다음 단계 3", "timeline": "1-2개월"}}
    ],
    "go_no_go": "GO" 또는 "CONDITIONAL_GO" 또는 "NO_GO",
    "final_verdict": "최종 판단 한줄 (투자자에게 발표한다고 생각하고)"
}}

overall_score는 0-100점, 각 항목별 점수도 0-100점으로 평가해주세요.
현실적이고 건설적인 피드백을 제공해주세요."""

        return await self._generate_json(prompt)

    async def chat(self, history: list, user_message: str, context: Optional[dict] = None) -> str:
        """사업 검토 대화"""
        context_info = ""
        if context:
            context_info = f"""
## 이전 분석 결과 요약
- 사업 아이디어: {context.get('idea', '')}
- 사업성 점수: {context.get('score', 'N/A')}점
- 주요 강점: {context.get('strengths', [])}
- 주요 약점: {context.get('weaknesses', [])}
"""

        system_prompt = f"""당신은 시니어 스타트업 비즈니스 컨설턴트입니다.
사용자의 사업 아이디어에 대해 전문적이고 건설적인 피드백을 제공하세요.
{context_info}

대화 지침:
- 구체적인 질문을 통해 아이디어를 구체화하도록 도와주세요
- 실행 가능한 조언을 제공하세요
- 리스크도 솔직하게 언급하되, 해결책도 함께 제시하세요
- 한국어로 응답하세요"""

        # 대화 히스토리 구성
        messages = [{"role": "user", "parts": [system_prompt]}]
        for msg in history:
            messages.append({"role": msg["role"], "parts": [msg["content"]]})

        try:
            chat = self.model.start_chat(history=messages)
            response = await chat.send_message_async(user_message)
            return response.text.strip()
        except Exception as e:
            print(f"Business chat error: {e}")
            return "죄송합니다. 응답 생성 중 오류가 발생했습니다. 다시 시도해주세요."
