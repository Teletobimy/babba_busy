"""
Stage 2 (AI 호출 0): keyword_filter

규칙이 통과시킨 candidate가 실제로 사용자에게 의미있는 신호인지
한국어 도메인 키워드로 한 번 더 거름.

용도:
  - 사용자 메모/메시지/제목에서 트리거 키워드 검출 (긍정 키워드)
  - 또는 제외 키워드 검출 (부정/비활성 키워드 — 휴가/병원 등 의도적으로 안 할 수 있는 맥락)

본질적으로 작은 사전 매칭. SUPERWORK PROACTIVE_AI_DESIGN §7.1 패턴.
"""
from __future__ import annotations

from dataclasses import dataclass

from .domain import SuggestionDraft, SuggestionContext


# ============ 한국어 도메인 키워드 사전 ============

# 긍정 트리거 — 이런 단어가 prompt/메모에 있으면 LLM-judge 스킵하고 바로 통과
POSITIVE_INTENT_KEYWORDS: dict[str, set[str]] = {
    "reminder_setup": {
        "알림", "리마인더", "까먹", "잊어", "잊지", "기억", "체크",
    },
    "encouragement": {
        "힘들", "지치", "포기", "싫어", "안 돼", "안 되",
    },
    "event_prep": {
        "준비", "체크리스트", "챙겨", "필요", "뭐 사", "뭐사", "뭐 가져",
    },
}

# 부정 — 이런 맥락이면 그냥 차단 (사용자가 명시적으로 회피 의사 표현)
NEGATIVE_CONTEXT_KEYWORDS: set[str] = {
    "휴가", "휴식", "쉬어", "쉬고", "병원", "아파", "아픔", "아플",
    "장례", "조의", "안 보낼", "안보낼", "조용", "방해 금지", "방해금지",
}


# ============ 평가 결과 ============


@dataclass
class KeywordEvaluation:
    """draft 1건에 대한 키워드 필터 결과"""
    blocked: bool                             # True면 즉시 차단 (negative match)
    fast_pass: bool                           # True면 LLM-judge 생략 (positive match)
    matched_negatives: list[str]
    matched_positives: list[str]


def _normalize(text: str | None) -> str:
    return (text or "").strip().lower()


def _scan(text: str, keywords: set[str]) -> list[str]:
    found = []
    for kw in keywords:
        if kw in text:
            found.append(kw)
    return found


def evaluate_keywords(
    draft: SuggestionDraft,
    ctx: SuggestionContext,
    extra_text_signals: str | None = None,
) -> KeywordEvaluation:
    """draft + ctx의 텍스트 신호를 보고 키워드 매칭.

    text 합성 대상:
      - draft.title, draft.body, draft.target_label
      - extra_text_signals (호출자가 추가로 넘김 — 최근 메모 합치기 등)
      - ctx의 todo 제목들 (최대 5개)
      - ctx의 event 제목들 (최대 5개)
    """
    parts: list[str] = []
    parts.append(_normalize(draft.title))
    parts.append(_normalize(draft.body))
    parts.append(_normalize(draft.target_label))
    if extra_text_signals:
        parts.append(_normalize(extra_text_signals))

    for t in ctx.pending_todos[:5]:
        parts.append(_normalize(t.title))
    for e in ctx.upcoming_events[:5]:
        parts.append(_normalize(e.title))

    haystack = "\n".join(p for p in parts if p)

    matched_negatives = _scan(haystack, NEGATIVE_CONTEXT_KEYWORDS)
    if matched_negatives:
        return KeywordEvaluation(
            blocked=True,
            fast_pass=False,
            matched_negatives=matched_negatives,
            matched_positives=[],
        )

    positives_for_type = POSITIVE_INTENT_KEYWORDS.get(draft.type, set())
    matched_positives = _scan(haystack, positives_for_type)

    return KeywordEvaluation(
        blocked=False,
        fast_pass=bool(matched_positives),
        matched_negatives=[],
        matched_positives=matched_positives,
    )


def filter_candidates(
    drafts: list[SuggestionDraft],
    ctx: SuggestionContext,
    extra_text_signals: str | None = None,
) -> tuple[list[SuggestionDraft], list[SuggestionDraft]]:
    """drafts 목록을 fast_pass / needs_llm_judge 둘로 분류.

    blocked는 둘 다에서 제외 (drop).

    반환: (fast_pass_drafts, needs_judge_drafts)
    """
    fast_pass: list[SuggestionDraft] = []
    needs_judge: list[SuggestionDraft] = []
    for draft in drafts:
        ev = evaluate_keywords(draft, ctx, extra_text_signals=extra_text_signals)
        if ev.blocked:
            continue
        if ev.fast_pass:
            # 키워드 매칭 강력 → confidence 약간 올리고 source_stage 표시
            draft.source_stage = "keyword"
            draft.confidence = min(1.0, draft.confidence + 0.1)
            fast_pass.append(draft)
        else:
            needs_judge.append(draft)
    return fast_pass, needs_judge
