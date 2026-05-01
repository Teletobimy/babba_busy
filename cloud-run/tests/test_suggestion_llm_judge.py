"""B2-3 단위 테스트: llm_judge"""
from __future__ import annotations

import asyncio
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
    SuggestionDraft,
    SuggestionTodo,
    build_judge_prompt,
    judge_drafts,
    parse_judge_response,
)


def _now() -> datetime:
    return datetime(2026, 5, 1, 9, 0, 0)


def _ctx() -> SuggestionContext:
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
    )


def _draft(**overrides) -> SuggestionDraft:
    base = SuggestionDraft(
        rule_id="r1",
        type="reminder_setup",
        title="알림 설정할까요",
        body="놓치지 않게",
        confidence=0.5,
    )
    for k, v in overrides.items():
        setattr(base, k, v)
    return base


# ============ build_judge_prompt ============


def test_judge_prompt_contains_required_fields():
    p = build_judge_prompt(_draft(), _ctx())
    assert "BABBA" in p
    assert "relevance" in p
    assert "reminder_setup" in p
    assert "장보기" in p
    assert "JSON" in p


# ============ parse_judge_response — 정상 ============


def test_parse_clean_json_passes():
    raw = '{"relevance": 0.85, "reason": "마감 임박이라 도움됨"}'
    v = parse_judge_response(raw)
    assert v.passed is True
    assert v.relevance == 0.85
    assert v.reason == "마감 임박이라 도움됨"


def test_parse_threshold_exact_07_passes():
    v = parse_judge_response('{"relevance": 0.7}')
    assert v.passed is True
    assert v.relevance == 0.7


def test_parse_below_threshold_fails():
    v = parse_judge_response('{"relevance": 0.69}')
    assert v.passed is False


def test_parse_clamps_to_0_1():
    v_high = parse_judge_response('{"relevance": 1.5}')
    assert v_high.relevance == 1.0
    v_low = parse_judge_response('{"relevance": -0.3}')
    assert v_low.relevance == 0.0


# ============ parse_judge_response — 변형 입력 ============


def test_parse_strips_code_block():
    raw = '```json\n{"relevance": 0.8}\n```'
    v = parse_judge_response(raw)
    assert v.passed is True
    assert v.relevance == 0.8


def test_parse_extracts_first_json_block_from_noisy_text():
    raw = '여기 결과입니다: {"relevance": 0.75, "reason": "적절"} 끝.'
    v = parse_judge_response(raw)
    assert v.passed is True
    assert v.relevance == 0.75


# ============ parse_judge_response — 실패/안전 ============


def test_parse_no_json_returns_failed():
    v = parse_judge_response("그냥 텍스트")
    assert v.passed is False
    assert v.reason == "no_json"


def test_parse_invalid_relevance_value():
    v = parse_judge_response('{"relevance": "high"}')
    assert v.passed is False
    assert v.reason == "invalid_relevance"


def test_parse_empty_string():
    v = parse_judge_response("")
    assert v.passed is False
    assert v.relevance == 0.0


# ============ judge_drafts 통합 ============


@pytest.mark.asyncio
async def test_judge_drafts_passes_high_relevance():
    async def mock_caller(prompt: str) -> str:
        return '{"relevance": 0.9, "reason": "very good"}'

    results = await judge_drafts([_draft()], _ctx(), mock_caller)
    assert len(results) == 1
    draft, verdict = results[0]
    assert verdict.passed is True
    assert verdict.relevance == 0.9
    assert draft.source_stage == "llm"
    # rule confidence 0.5 + LLM 0.9 → 평균 0.7
    assert draft.confidence == 0.7


@pytest.mark.asyncio
async def test_judge_drafts_fails_low_relevance():
    async def mock_caller(prompt: str) -> str:
        return '{"relevance": 0.3}'

    results = await judge_drafts([_draft()], _ctx(), mock_caller)
    draft, verdict = results[0]
    assert verdict.passed is False
    # source_stage / confidence는 변경 안 됨
    assert draft.source_stage == "rule"
    assert draft.confidence == 0.5


@pytest.mark.asyncio
async def test_judge_drafts_isolates_caller_exception():
    """1개 호출 실패해도 다른 draft 평가는 진행"""
    call_count = {"n": 0}

    async def flaky(prompt: str) -> str:
        call_count["n"] += 1
        if call_count["n"] == 1:
            raise RuntimeError("boom")
        return '{"relevance": 0.85}'

    results = await judge_drafts(
        [_draft(), _draft(rule_id="r2")],
        _ctx(),
        flaky,
    )
    assert len(results) == 2
    # 둘 중 하나는 실패, 하나는 성공 (gather 순서는 호출 순)
    statuses = sorted([r[1].passed for r in results])
    assert statuses == [False, True]
    fail_reasons = [r[1].reason for r in results if not r[1].passed]
    assert any("llm_error" in (r or "") for r in fail_reasons)


@pytest.mark.asyncio
async def test_judge_drafts_handles_timeout():
    async def slow(prompt: str) -> str:
        await asyncio.sleep(2.0)
        return '{"relevance": 0.9}'

    results = await judge_drafts([_draft()], _ctx(), slow, timeout_seconds=0.05)
    draft, verdict = results[0]
    assert verdict.passed is False
    assert verdict.reason == "timeout"


@pytest.mark.asyncio
async def test_judge_drafts_empty_input_returns_empty():
    async def never_called(prompt: str) -> str:
        raise AssertionError("should not be called")

    results = await judge_drafts([], _ctx(), never_called)
    assert results == []
