"""
Stage 3 (Gemini Flash): llm_judge

1+2단 게이트 통과한 candidate 중 keyword fast_pass 안 된 것들에 대해
"진짜 사용자에게 도움 되는가?" Gemini로 판정. relevance ≥ 0.7만 통과.

설계 원칙:
  - 외부 LLM 호출은 명시적으로 inject (테스트 가능성)
  - 실패/타임아웃은 isolation: 1개 실패가 batch 전체를 멈추지 않음
  - JSON-only 응답 강제, 파싱 실패 시 fallback (drop)
"""
from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass
from typing import Awaitable, Callable, Optional

from .domain import SuggestionContext, SuggestionDraft

# JSON 응답 형식 강제 — Gemini가 코드 블럭 감싸도 정규식으로 추출
_JSON_BLOCK_RE = re.compile(r"\{[^{}]*\}", re.DOTALL)


# 외부 호출 콜러블 — judge_drafts 호출 측에서 inject.
# 시그니처: async fn(prompt: str) -> str (Gemini 응답 텍스트)
JudgeCaller = Callable[[str], Awaitable[str]]


@dataclass
class JudgeVerdict:
    """draft 1건에 대한 LLM 판정 결과"""
    passed: bool
    relevance: float                          # 0.0 ~ 1.0
    reason: Optional[str] = None
    raw_response: Optional[str] = None        # 디버깅용


# ============ 프롬프트 ============


def build_judge_prompt(draft: SuggestionDraft, ctx: SuggestionContext) -> str:
    """LLM에게 1건씩 판정 시키는 프롬프트.

    응답은 strict JSON: {"relevance": 0.0~1.0, "reason": "..."}
    """
    # ctx 정보를 너무 많이 안 넘김 — 토큰 절약 + 개인정보 최소화
    todo_titles = [t.title for t in ctx.pending_todos[:3]]
    event_titles = [e.title for e in ctx.upcoming_events[:3]]

    return f"""당신은 BABBA 가족 일정 앱의 AI 안전성 심사관입니다.
사용자에게 보낼 proactive 제안 1건을 검토하고 0.0~1.0의 relevance 점수를 매기세요.

검토 기준:
- 1.0: 사용자에게 명백히 도움이 되고 시기적절함
- 0.7~0.9: 도움 될 가능성 높음 (제안 실행 권장)
- 0.4~0.6: 애매함 (보내지 않는 것이 더 나을 수 있음)
- 0.0~0.3: 부적절하거나 사용자를 귀찮게 함

제안:
- 종류: {draft.type}
- 제목: {draft.title}
- 본문: {draft.body or "(없음)"}
- 대상: {draft.target_label or "(없음)"}

사용자 컨텍스트 (최근):
- 진행 중 할 일: {todo_titles or "(없음)"}
- 다가오는 일정: {event_titles or "(없음)"}
- 최근 7일 완료율: {int(ctx.completion_rate_7d * 100)}%
- 오늘 완료: {ctx.completed_today}개

응답은 반드시 다음 JSON 형식만:
{{"relevance": 0.0~1.0 사이 숫자, "reason": "한 줄 이유"}}
"""


# ============ 응답 파싱 ============


def parse_judge_response(raw: str) -> JudgeVerdict:
    """LLM 응답 텍스트에서 JSON 추출 → JudgeVerdict.

    파싱 실패 시 passed=False, relevance=0 fallback (안전 측).
    """
    try:
        text = (raw or "").strip()
        # 코드블럭 제거
        if text.startswith("```"):
            text = re.sub(r"^```[a-zA-Z]*\s*", "", text)
            text = re.sub(r"\s*```$", "", text)
        # 첫 JSON 블럭 추출
        match = _JSON_BLOCK_RE.search(text)
        if not match:
            return JudgeVerdict(passed=False, relevance=0.0, reason="no_json", raw_response=raw)
        data = json.loads(match.group(0))
        relevance_raw = data.get("relevance")
        try:
            relevance = float(relevance_raw)
        except (TypeError, ValueError):
            return JudgeVerdict(passed=False, relevance=0.0, reason="invalid_relevance", raw_response=raw)
        relevance = max(0.0, min(1.0, relevance))
        reason = str(data.get("reason") or "").strip() or None
        return JudgeVerdict(
            passed=relevance >= 0.7,
            relevance=relevance,
            reason=reason,
            raw_response=raw,
        )
    except Exception as exc:
        return JudgeVerdict(passed=False, relevance=0.0, reason=f"parse_error:{exc}", raw_response=raw)


# ============ 평가 함수 ============


async def judge_drafts(
    drafts: list[SuggestionDraft],
    ctx: SuggestionContext,
    caller: JudgeCaller,
    timeout_seconds: float = 8.0,
) -> list[tuple[SuggestionDraft, JudgeVerdict]]:
    """drafts 각각을 LLM으로 판정. 결과는 (draft, verdict) 튜플 리스트.

    - 호출자가 통과한 것만 골라 사용
    - 동시에 N개 병렬 호출 (asyncio.gather, return_exceptions=True)
    - 개별 호출 실패는 verdict.passed=False로 격리
    """
    if not drafts:
        return []

    async def _judge_one(draft: SuggestionDraft) -> tuple[SuggestionDraft, JudgeVerdict]:
        prompt = build_judge_prompt(draft, ctx)
        try:
            raw = await asyncio.wait_for(caller(prompt), timeout=timeout_seconds)
        except asyncio.TimeoutError:
            return draft, JudgeVerdict(passed=False, relevance=0.0, reason="timeout")
        except Exception as exc:
            return draft, JudgeVerdict(passed=False, relevance=0.0, reason=f"llm_error:{exc}")
        verdict = parse_judge_response(raw)
        return draft, verdict

    results = await asyncio.gather(
        *(_judge_one(d) for d in drafts),
        return_exceptions=False,                 # _judge_one 자체가 예외 catch 처리
    )

    # passed 된 draft에 source_stage 표시 + confidence 갱신
    finalized: list[tuple[SuggestionDraft, JudgeVerdict]] = []
    for draft, verdict in results:
        if verdict.passed:
            draft.source_stage = "llm"
            # LLM relevance를 confidence에 직접 반영 (rule confidence와 평균)
            draft.confidence = round((draft.confidence + verdict.relevance) / 2, 3)
        finalized.append((draft, verdict))
    return finalized
