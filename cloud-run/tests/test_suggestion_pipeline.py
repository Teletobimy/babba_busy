"""B2-4 단위 테스트: pipeline (3단 게이트 + dedup + lifecycle stamping)"""
from __future__ import annotations

import sys
import types
from datetime import datetime, timedelta
from pathlib import Path

import pytest

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

if "services" not in sys.modules:
    _stub = types.ModuleType("services")
    _stub.__path__ = [str(ROOT_DIR / "services")]
    sys.modules["services"] = _stub

from services.suggestion_engine import (  # noqa: E402
    SuggestionContext,
    SuggestionEvent,
    SuggestionTodo,
    compute_fingerprint,
    run_pipeline,
)
from services.suggestion_engine.domain import SuggestionDraft  # noqa: E402


def _now() -> datetime:
    return datetime(2026, 5, 1, 9, 0, 0)


def _ctx_with_overdue_todo() -> SuggestionContext:
    return SuggestionContext(
        user_id="user-1",
        now=_now(),
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="장보기",
                due_date=_now() + timedelta(hours=5),
                has_reminder=False,
            )
        ],
        completion_rate_7d=0.7,                  # low_completion 트리거 안 되게 충분히 높게
    )


async def _yes_caller(prompt: str) -> str:
    """기본 LLM judge 모킹 — relevance 0.9 (통과)"""
    return '{"relevance": 0.9}'


# ============ fingerprint ============


def test_fingerprint_stable_for_same_inputs():
    d = SuggestionDraft(
        rule_id="r1", type="reminder_setup", title="t",
        fingerprint_extras=["a", "b"]
    )
    fp1 = compute_fingerprint(d, "u1", "20260501")
    fp2 = compute_fingerprint(d, "u1", "20260501")
    assert fp1 == fp2


def test_fingerprint_differs_for_different_day():
    d = SuggestionDraft(rule_id="r1", type="x", title="t")
    fp_today = compute_fingerprint(d, "u1", "20260501")
    fp_tomorrow = compute_fingerprint(d, "u1", "20260502")
    assert fp_today != fp_tomorrow


def test_fingerprint_order_independent():
    """extras 순서 달라도 동일 fingerprint (sorted)"""
    d1 = SuggestionDraft(rule_id="r1", type="x", title="t", fingerprint_extras=["a", "b"])
    d2 = SuggestionDraft(rule_id="r1", type="x", title="t", fingerprint_extras=["b", "a"])
    assert compute_fingerprint(d1, "u1", "20260501") == compute_fingerprint(d2, "u1", "20260501")


# ============ run_pipeline ============


@pytest.mark.asyncio
async def test_pipeline_no_judge_caller_drops_needs_judge():
    """judge_caller=None이면 needs_judge candidate 모두 drop.

    keyword_filter는 사용자 신호(ctx.todos.title 등)만 보므로 일반 cron 호출 시
    rule draft가 ctx에 명시 키워드 없으면 needs_judge로 분류됨. caller 없으면 drop.
    """
    ctx = _ctx_with_overdue_todo()
    ctx.upcoming_events = [
        SuggestionEvent(
            id="e1",
            title="회의",                        # positive 키워드 없음
            start_time=_now() + timedelta(hours=24),
            has_note=False,
        )
    ]

    result = await run_pipeline(ctx, judge_caller=None)
    # 둘 다 needs_judge로 가서 caller 없으니 drop
    assert result.records == []
    assert result.needs_judge == 2
    assert result.judge_passed == 0


@pytest.mark.asyncio
async def test_pipeline_fast_pass_when_user_signal_matches():
    """ctx.todos.title에 positive 키워드 있으면 LLM 없이도 fast_pass"""
    ctx = SuggestionContext(
        user_id="user-1",
        now=_now(),
        completion_rate_7d=0.7,
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="우유 사오기 까먹지 말 것",          # "까먹" → reminder_setup positive
                due_date=_now() + timedelta(hours=5),
                has_reminder=False,
            )
        ],
    )
    result = await run_pipeline(ctx, judge_caller=None)
    rule_ids = {r.rule_id for r in result.records}
    assert "overdue_with_no_reminder" in rule_ids
    assert result.fast_passed == 1


@pytest.mark.asyncio
async def test_pipeline_with_judge_caller_includes_passed():
    """judge_caller 있으면 needs_judge 평가 후 passed만 포함"""
    ctx = _ctx_with_overdue_todo()
    ctx.upcoming_events = [
        SuggestionEvent(
            id="e1",
            title="회의",
            start_time=_now() + timedelta(hours=24),
            has_note=False,
        )
    ]

    result = await run_pipeline(ctx, judge_caller=_yes_caller)
    rule_ids = {r.rule_id for r in result.records}
    assert "overdue_with_no_reminder" in rule_ids
    assert "upcoming_event_no_prep" in rule_ids
    assert result.judge_passed == 2


@pytest.mark.asyncio
async def test_pipeline_dedup_by_existing_fingerprint():
    """existing_fingerprints에 같은 fp 있으면 record 안 만듬"""
    ctx = _ctx_with_overdue_todo()

    first = await run_pipeline(ctx, judge_caller=_yes_caller)
    assert len(first.records) == 1
    existing = {first.records[0].fingerprint}

    second = await run_pipeline(
        ctx, judge_caller=_yes_caller, existing_fingerprints=existing
    )
    assert second.records == []
    assert second.deduped == 1


@pytest.mark.asyncio
async def test_pipeline_records_have_lifecycle_stages():
    """records[].stages에 5개 stage timestamp 모두 있음"""
    ctx = _ctx_with_overdue_todo()
    result = await run_pipeline(ctx, judge_caller=_yes_caller)
    assert len(result.records) >= 1
    record = result.records[0]
    expected = {"signal", "dedup", "policy", "agent", "suggestion"}
    assert set(record.stages.keys()) == expected
    for stage_name, ts in record.stages.items():
        assert isinstance(ts, datetime), f"{stage_name} must be datetime"


@pytest.mark.asyncio
async def test_pipeline_to_payload_is_firestore_ready():
    """SuggestionRecord.to_payload()는 Firestore set에 그대로 넣을 수 있는 dict"""
    ctx = _ctx_with_overdue_todo()
    result = await run_pipeline(ctx, judge_caller=_yes_caller)
    payload = result.records[0].to_payload()

    expected_keys = {
        "user_id", "rule_id", "type", "title", "body", "confidence",
        "source_stage", "action_type", "action_payload", "target_label",
        "fingerprint", "stages", "created_at",
        "judge_relevance", "judge_reason",
    }
    assert set(payload.keys()) == expected_keys
    assert isinstance(payload["created_at"], datetime)
    assert isinstance(payload["stages"], dict)


@pytest.mark.asyncio
async def test_pipeline_metrics_track_pipeline_state():
    ctx = _ctx_with_overdue_todo()

    # 추가로 negative 차단 케이스
    ctx.pending_todos.append(
        SuggestionTodo(
            id="t2",
            title="휴가 가기",                  # negative keyword '휴가'
            due_date=_now() + timedelta(hours=10),
            has_reminder=False,
        )
    )

    result = await run_pipeline(ctx)
    # rule은 1개 candidate (overdue, t1+t2 묶임)
    assert result.rule_candidate_count == 1
    # 키워드 '휴가' 때문에 blocked
    assert result.blocked_by_keyword == 1
    assert result.fast_passed == 0
    assert result.records == []


@pytest.mark.asyncio
async def test_pipeline_empty_context_returns_empty():
    ctx = SuggestionContext(user_id="u", now=_now())
    result = await run_pipeline(ctx)
    assert result.records == []
    assert result.rule_candidate_count == 0
    assert result.fast_passed == 0
    assert result.needs_judge == 0
    assert result.judge_passed == 0
