"""B2-2 단위 테스트: keyword_filter"""
from __future__ import annotations

import sys
import types
from datetime import datetime, timedelta
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

if "services" not in sys.modules:
    _stub = types.ModuleType("services")
    _stub.__path__ = [str(ROOT_DIR / "services")]
    sys.modules["services"] = _stub

from services.suggestion_engine import (  # noqa: E402
    SuggestionContext,
    SuggestionDraft,
    SuggestionEvent,
    SuggestionTodo,
    evaluate_keywords,
    filter_candidates,
)


def _now() -> datetime:
    return datetime(2026, 5, 1, 9, 0, 0)


def _ctx(**overrides) -> SuggestionContext:
    base = SuggestionContext(user_id="user-1", now=_now())
    for k, v in overrides.items():
        setattr(base, k, v)
    return base


def _draft(type_: str = "reminder_setup", **overrides) -> SuggestionDraft:
    base = SuggestionDraft(
        rule_id="r1",
        type=type_,
        title="할 일 알림 설정할까요?",
        body="놓치지 않게 도와드려요",
        confidence=0.5,
    )
    for k, v in overrides.items():
        setattr(base, k, v)
    return base


# ============ blocked (negative) ============


def test_negative_keyword_in_todo_blocks_draft():
    """todo 제목에 '휴가' 들어있으면 차단"""
    ctx = _ctx(
        pending_todos=[SuggestionTodo(id="t1", title="휴가 가기")]
    )
    draft = _draft()
    result = evaluate_keywords(draft, ctx)
    assert result.blocked is True
    assert "휴가" in result.matched_negatives


def test_negative_keyword_in_extra_text_blocks_draft():
    """extra_text_signals에 '병원' 있으면 차단"""
    ctx = _ctx()
    draft = _draft()
    result = evaluate_keywords(draft, ctx, extra_text_signals="오늘 병원 가야 해서 다른 건 못함")
    assert result.blocked is True
    assert "병원" in result.matched_negatives


def test_filter_candidates_drops_blocked():
    ctx = _ctx(
        pending_todos=[SuggestionTodo(id="t1", title="휴가 준비")]
    )
    drafts = [_draft(type_="reminder_setup"), _draft(type_="encouragement")]
    fast_pass, needs_judge = filter_candidates(drafts, ctx)
    assert fast_pass == []
    assert needs_judge == []


# ============ fast_pass (positive) ============


def test_positive_keyword_in_todo_marks_fast_pass():
    ctx = _ctx(
        pending_todos=[SuggestionTodo(id="t1", title="우유 사오기 까먹지 말 것")]
    )
    draft = _draft(type_="reminder_setup")
    result = evaluate_keywords(draft, ctx)
    assert result.blocked is False
    assert result.fast_pass is True
    assert "까먹" in result.matched_positives


def test_positive_keyword_for_encouragement_type():
    ctx = _ctx(
        pending_todos=[SuggestionTodo(id="t1", title="요즘 너무 힘들다")]
    )
    draft = _draft(type_="encouragement")
    result = evaluate_keywords(draft, ctx)
    assert result.fast_pass is True


def test_filter_candidates_fast_passes_with_confidence_bump():
    ctx = _ctx(
        upcoming_events=[
            SuggestionEvent(
                id="e1",
                title="가족 모임 — 음료수 챙겨갈 것",
                start_time=_now() + timedelta(hours=24),
            )
        ]
    )
    drafts = [_draft(type_="event_prep", confidence=0.45)]
    fast_pass, needs_judge = filter_candidates(drafts, ctx)
    assert len(fast_pass) == 1
    assert needs_judge == []
    assert fast_pass[0].source_stage == "keyword"
    # 0.45 + 0.1 boost
    assert abs(fast_pass[0].confidence - 0.55) < 1e-6


# ============ needs_judge (no positive, no negative) ============


def test_no_keyword_match_routes_to_llm_judge():
    ctx = _ctx(
        pending_todos=[SuggestionTodo(id="t1", title="장보기")],
    )
    draft = _draft(type_="reminder_setup", title="알림", body="설정할까요")
    # title/body에는 positive 키워드("알림")가 있어 fast_pass.
    # negative 회피 + 다른 type으로 테스트
    result = evaluate_keywords(_draft(type_="event_prep", title="제안 1", body="검토해보세요"), ctx)
    assert result.blocked is False
    assert result.fast_pass is False
    assert result.matched_positives == []


def test_filter_candidates_partitions_correctly():
    ctx = _ctx(
        pending_todos=[
            SuggestionTodo(id="t1", title="우유 까먹지 말 것"),  # positive
        ]
    )
    drafts = [
        _draft(type_="reminder_setup"),                    # 매칭됨 (까먹) → fast_pass
        _draft(type_="event_prep", title="prep1", body="b"),  # 매칭 안 됨 → needs_judge
    ]
    fast_pass, needs_judge = filter_candidates(drafts, ctx)
    assert len(fast_pass) == 1
    assert len(needs_judge) == 1
    assert fast_pass[0].type == "reminder_setup"
    assert needs_judge[0].type == "event_prep"


# ============ confidence cap (1.0 초과 안 함) ============


def test_confidence_capped_at_one():
    ctx = _ctx(
        pending_todos=[SuggestionTodo(id="t1", title="까먹지 마")]
    )
    drafts = [_draft(type_="reminder_setup", confidence=0.95)]
    fast_pass, _ = filter_candidates(drafts, ctx)
    assert fast_pass[0].confidence == 1.0
