"""
BABBA Suggestion Engine (Phase B2)

3단 비용 게이트 + 8-stage lifecycle trace로 proactive AI 제안을 생성.
참조: docs/ai/BABBA_3BRAIN_DESIGN_V1.md §6, §7, SUPERWORK PROACTIVE_AI_DESIGN.md

흐름:
    SuggestionContext (사용자 상태 스냅샷)
        ↓
    Stage 1: rule_registry  (AI 호출 0)
        ↓
    Stage 2: keyword_filter (AI 호출 0)
        ↓
    Stage 3: llm_judge      (Gemini Flash, relevance ≥ 0.7)
        ↓
    SuggestionDraft → 8-stage stamping → Firestore write
"""
from .domain import (
    SuggestionContext,
    SuggestionDraft,
    SuggestionTodo,
    SuggestionEvent,
)
from .rule_registry import build_rule_candidates, RULE_REGISTRY
from .keyword_filter import (
    KeywordEvaluation,
    evaluate_keywords,
    filter_candidates,
    NEGATIVE_CONTEXT_KEYWORDS,
    POSITIVE_INTENT_KEYWORDS,
)

__all__ = [
    "SuggestionContext",
    "SuggestionDraft",
    "SuggestionTodo",
    "SuggestionEvent",
    "build_rule_candidates",
    "RULE_REGISTRY",
    "KeywordEvaluation",
    "evaluate_keywords",
    "filter_candidates",
    "NEGATIVE_CONTEXT_KEYWORDS",
    "POSITIVE_INTENT_KEYWORDS",
]
