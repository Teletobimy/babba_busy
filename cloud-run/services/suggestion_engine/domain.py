"""
SuggestionEngine 도메인 객체 (Pydantic-free, 순수 dataclass)

규칙 함수가 받는 입력(SuggestionContext)과 출력(SuggestionDraft)을 정의.
Firestore 의존성 없음 — 단위 테스트에서 fixture로 직접 채워 검증 가능.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Optional


@dataclass
class SuggestionTodo:
    """규칙 평가용 todo 슬림 뷰"""
    id: str
    title: str
    due_date: Optional[datetime] = None       # tz-naive UTC
    has_reminder: bool = False
    is_completed: bool = False
    completed_at: Optional[datetime] = None


@dataclass
class SuggestionEvent:
    """규칙 평가용 calendar event 슬림 뷰"""
    id: str
    title: str
    start_time: Optional[datetime] = None
    has_note: bool = False                    # 준비 메모 존재 여부
    location: Optional[str] = None


@dataclass
class SuggestionContext:
    """규칙 함수가 보는 사용자 상태 단일 스냅샷.

    `now`는 호출자가 주입 (테스트 가능성). cron job이 utcnow_naive()로 채움.
    """
    user_id: str
    now: datetime
    pending_todos: list[SuggestionTodo] = field(default_factory=list)
    upcoming_events: list[SuggestionEvent] = field(default_factory=list)
    completion_rate_7d: float = 0.0           # 0.0 ~ 1.0
    completed_today: int = 0
    active_family_id: Optional[str] = None    # 멀티그룹 중 현재 컨텍스트


@dataclass
class SuggestionDraft:
    """규칙 1회 평가 결과. 통과한 candidate 1건.

    각 stage의 timestamp는 engine이 stamping. 규칙은 본질만 채움.
    """
    rule_id: str                              # 예: "overdue_with_no_reminder"
    type: str                                 # 카테고리: "reminder_setup" | "encouragement" | "event_prep"
    title: str
    body: Optional[str] = None
    confidence: float = 0.5                   # 0.0 ~ 1.0
    action_type: Optional[str] = None         # 후속 action (e.g. "bulk_set_reminder")
    action_payload: dict[str, Any] = field(default_factory=dict)
    target_label: Optional[str] = None        # audit/UI용 짧은 대상 식별 (예: "장보기 외 2건")
    fingerprint_extras: list[str] = field(default_factory=list)
    # ↑ dedup fingerprint 계산 시 추가 키 (예: 대상 todo id들). 같은 날 동일 fingerprint는 dedup.

    source_stage: str = "rule"                # rule | keyword | llm
