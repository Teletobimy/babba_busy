"""
B2-1 단위 테스트: rule_registry

각 규칙별로 trigger / no-trigger 케이스 + build_rule_candidates 종합.

실행 (cloud-run/ 안에서):
    python -m pytest tests/test_suggestion_rule_registry.py -v
"""
from __future__ import annotations

import sys
import types
from datetime import datetime, timedelta
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

# services/__init__.py가 firestore/pydantic_settings 등을 import하므로
# 의존성 없는 환경(시스템 python)에서는 services를 namespace stub로 대체.
# 이미 정상 import된 환경(Cloud Run, venv)에서는 영향 없음.
if "services" not in sys.modules:
    _services_stub = types.ModuleType("services")
    _services_stub.__path__ = [str(ROOT_DIR / "services")]
    sys.modules["services"] = _services_stub

from services.suggestion_engine import (  # noqa: E402
    SuggestionContext,
    SuggestionEvent,
    SuggestionTodo,
    build_rule_candidates,
)
from services.suggestion_engine.rule_registry import (  # noqa: E402
    rule_low_completion_rate,
    rule_overdue_with_no_reminder,
    rule_upcoming_event_no_prep,
)


# ============ 공통 fixture ============


def _now() -> datetime:
    return datetime(2026, 5, 1, 9, 0, 0)


def _ctx(**overrides) -> SuggestionContext:
    base = SuggestionContext(user_id="user-1", now=_now())
    for k, v in overrides.items():
        setattr(base, k, v)
    return base


# ============ rule_overdue_with_no_reminder ============


def test_overdue_rule_triggers_when_due_within_24h_and_no_reminder():
    ctx = _ctx(
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="장보기",
                due_date=_now() + timedelta(hours=5),
                has_reminder=False,
            )
        ]
    )
    draft = rule_overdue_with_no_reminder(ctx)
    assert draft is not None
    assert draft.rule_id == "overdue_with_no_reminder"
    assert draft.action_type == "bulk_set_reminder"
    assert draft.action_payload == {
        "todo_ids": ["t1"],
        "default_minutes": 60,
    }
    assert draft.confidence == 0.85
    assert draft.fingerprint_extras == ["t1"]


def test_overdue_rule_skips_when_reminder_already_set():
    ctx = _ctx(
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="장보기",
                due_date=_now() + timedelta(hours=5),
                has_reminder=True,                # 이미 설정
            )
        ]
    )
    assert rule_overdue_with_no_reminder(ctx) is None


def test_overdue_rule_skips_when_due_more_than_24h_away():
    ctx = _ctx(
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="장보기",
                due_date=_now() + timedelta(hours=25),   # 24h 초과
                has_reminder=False,
            )
        ]
    )
    assert rule_overdue_with_no_reminder(ctx) is None


def test_overdue_rule_skips_completed_todos():
    ctx = _ctx(
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="장보기",
                due_date=_now() + timedelta(hours=5),
                has_reminder=False,
                is_completed=True,
            )
        ]
    )
    assert rule_overdue_with_no_reminder(ctx) is None


def test_overdue_rule_aggregates_multiple_targets():
    ctx = _ctx(
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="장보기",
                due_date=_now() + timedelta(hours=5),
                has_reminder=False,
            ),
            SuggestionTodo(
                id="t2",
                title="운동",
                due_date=_now() + timedelta(hours=10),
                has_reminder=False,
            ),
            SuggestionTodo(
                id="t3",
                title="청소",
                due_date=_now() + timedelta(hours=20),
                has_reminder=False,
            ),
        ]
    )
    draft = rule_overdue_with_no_reminder(ctx)
    assert draft is not None
    assert "외 2건" in draft.target_label
    assert sorted(draft.action_payload["todo_ids"]) == ["t1", "t2", "t3"]
    assert sorted(draft.fingerprint_extras) == ["t1", "t2", "t3"]


# ============ rule_low_completion_rate ============


def test_low_completion_rule_triggers_when_rate_below_40_pct():
    ctx = _ctx(
        completion_rate_7d=0.25,
        pending_todos=[SuggestionTodo(id="t1", title="장보기")],
    )
    draft = rule_low_completion_rate(ctx)
    assert draft is not None
    assert draft.rule_id == "low_completion_rate"
    assert draft.action_payload == {"todo_id": "t1"}
    assert "25%" in draft.title


def test_low_completion_rule_skips_when_rate_at_threshold():
    ctx = _ctx(
        completion_rate_7d=0.4,
        pending_todos=[SuggestionTodo(id="t1", title="장보기")],
    )
    assert rule_low_completion_rate(ctx) is None


def test_low_completion_rule_skips_when_no_pending_todos():
    ctx = _ctx(completion_rate_7d=0.1, pending_todos=[])
    assert rule_low_completion_rate(ctx) is None


# ============ rule_upcoming_event_no_prep ============


def test_event_prep_rule_triggers_when_within_48h_and_no_note():
    ctx = _ctx(
        upcoming_events=[
            SuggestionEvent(
                id="e1",
                title="가족 모임",
                start_time=_now() + timedelta(hours=24),
                has_note=False,
            )
        ]
    )
    draft = rule_upcoming_event_no_prep(ctx)
    assert draft is not None
    assert draft.rule_id == "upcoming_event_no_prep"
    assert draft.action_type == "create_memo"
    assert draft.action_payload["event_id"] == "e1"


def test_event_prep_rule_skips_when_note_already_exists():
    ctx = _ctx(
        upcoming_events=[
            SuggestionEvent(
                id="e1",
                title="가족 모임",
                start_time=_now() + timedelta(hours=24),
                has_note=True,
            )
        ]
    )
    assert rule_upcoming_event_no_prep(ctx) is None


def test_event_prep_rule_skips_when_more_than_48h_away():
    ctx = _ctx(
        upcoming_events=[
            SuggestionEvent(
                id="e1",
                title="가족 모임",
                start_time=_now() + timedelta(hours=49),
                has_note=False,
            )
        ]
    )
    assert rule_upcoming_event_no_prep(ctx) is None


# ============ build_rule_candidates 종합 ============


def test_build_rule_candidates_returns_all_passing_rules():
    ctx = _ctx(
        pending_todos=[
            SuggestionTodo(
                id="t1",
                title="장보기",
                due_date=_now() + timedelta(hours=5),
                has_reminder=False,
            )
        ],
        upcoming_events=[
            SuggestionEvent(
                id="e1",
                title="가족 모임",
                start_time=_now() + timedelta(hours=24),
                has_note=False,
            )
        ],
        completion_rate_7d=0.2,
    )
    drafts = build_rule_candidates(ctx)
    rule_ids = {d.rule_id for d in drafts}
    assert rule_ids == {
        "overdue_with_no_reminder",
        "low_completion_rate",
        "upcoming_event_no_prep",
    }


def test_build_rule_candidates_returns_empty_when_no_rules_match():
    ctx = _ctx(completion_rate_7d=0.9)
    assert build_rule_candidates(ctx) == []


def test_build_rule_candidates_isolates_rule_exceptions():
    """1개 규칙이 raise해도 나머지는 정상 동작 — registry 직접 조작."""
    from services.suggestion_engine import rule_registry as rr

    def boom(_ctx):
        raise ValueError("intentional")

    original = rr.RULE_REGISTRY[:]
    rr.RULE_REGISTRY.insert(0, boom)
    try:
        ctx = _ctx(
            pending_todos=[
                SuggestionTodo(
                    id="t1",
                    title="장보기",
                    due_date=_now() + timedelta(hours=5),
                    has_reminder=False,
                )
            ]
        )
        drafts = build_rule_candidates(ctx)
        rule_ids = {d.rule_id for d in drafts}
        # boom은 빠지고 나머지 통과
        assert "overdue_with_no_reminder" in rule_ids
    finally:
        rr.RULE_REGISTRY[:] = original
