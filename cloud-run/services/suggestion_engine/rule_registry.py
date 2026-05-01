"""
Stage 1 (AI 호출 0): rule_registry

규칙 함수 시그니처:
    fn(ctx: SuggestionContext) -> Optional[SuggestionDraft]

각 규칙은 빠르고 결정적이고 explainable. LLM 없음.

추가 규칙은 `RULE_REGISTRY` 끝에 append하면 자동 평가.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Callable, Optional

from .domain import SuggestionContext, SuggestionDraft

RuleFn = Callable[[SuggestionContext], Optional[SuggestionDraft]]


# ============ 개별 규칙 ============


def rule_overdue_with_no_reminder(ctx: SuggestionContext) -> Optional[SuggestionDraft]:
    """24시간 이내 마감인데 reminder 미설정인 todo가 있으면 일괄 알림 설정 제안.

    confidence 높음 (0.85) — 마감 임박은 명백히 가치 있음.
    """
    cutoff = ctx.now + timedelta(hours=24)
    targets = [
        t for t in ctx.pending_todos
        if t.due_date is not None
        and t.due_date <= cutoff
        and t.due_date >= ctx.now
        and not t.has_reminder
        and not t.is_completed
    ]
    if not targets:
        return None

    target_ids = sorted(t.id for t in targets)
    title_preview = targets[0].title.strip()[:18]
    if len(targets) > 1:
        target_label = f"{title_preview} 외 {len(targets) - 1}건"
    else:
        target_label = title_preview

    return SuggestionDraft(
        rule_id="overdue_with_no_reminder",
        type="reminder_setup",
        title=f"24시간 안에 마감되는 할 일 {len(targets)}개에 알림을 설정할까요?",
        body=(
            "마감 임박인데 알림이 없어서 놓칠 수 있어요. "
            "기본 1시간 전 알림으로 일괄 설정 가능합니다."
        ),
        confidence=0.85,
        action_type="bulk_set_reminder",
        action_payload={"todo_ids": target_ids, "default_minutes": 60},
        target_label=target_label,
        fingerprint_extras=target_ids,
    )


def rule_low_completion_rate(ctx: SuggestionContext) -> Optional[SuggestionDraft]:
    """최근 7일 완료율 < 40% — 격려 + pending top 1 추천.

    confidence 중간 (0.5) — 완료율 낮음이 항상 문제는 아님 (계획 변경 등).
    LLM 호출 0인 템플릿 메시지.
    """
    if ctx.completion_rate_7d >= 0.4:
        return None
    if not ctx.pending_todos:
        return None

    rate_pct = int(round(ctx.completion_rate_7d * 100))
    top = ctx.pending_todos[0]

    return SuggestionDraft(
        rule_id="low_completion_rate",
        type="encouragement",
        title=f"이번 주 완료율 {rate_pct}% — 가장 가까운 한 가지부터 시작해볼까요?",
        body=(
            f"'{top.title.strip()[:30]}' 같은 작은 항목 1개로 흐름을 만들면 "
            "나머지가 따라옵니다."
        ),
        confidence=0.5,
        action_type="open_todo",
        action_payload={"todo_id": top.id},
        target_label=top.title.strip()[:24],
        # 일별 1회만 보냄 — fingerprint에 날짜만 포함 (rule_id + date로 자동 dedup)
        fingerprint_extras=[],
    )


def rule_upcoming_event_no_prep(ctx: SuggestionContext) -> Optional[SuggestionDraft]:
    """48시간 이내 시작하는 event인데 준비 메모 없음 → 메모 작성 제안.

    LLM-judge 통과 시에만 보냄 (confidence 낮음 0.45 — 항상 메모가 필요한 건 아님).
    """
    cutoff = ctx.now + timedelta(hours=48)
    targets = [
        e for e in ctx.upcoming_events
        if e.start_time is not None
        and e.start_time <= cutoff
        and e.start_time >= ctx.now
        and not e.has_note
    ]
    if not targets:
        return None

    target = targets[0]                       # 가장 임박한 1개만
    label_title = target.title.strip()[:20]

    return SuggestionDraft(
        rule_id="upcoming_event_no_prep",
        type="event_prep",
        title=f"'{label_title}' 일정 전에 준비 메모를 만들까요?",
        body="장소·소지품·체크리스트를 미리 적어두면 당일에 헤매지 않아요.",
        confidence=0.45,                      # LLM judge로 다시 한번 거름
        action_type="create_memo",
        action_payload={
            "event_id": target.id,
            "event_title": target.title,
            "memo_template": "prep_checklist",
        },
        target_label=label_title,
        fingerprint_extras=[target.id],
    )


# ============ 레지스트리 + 평가 함수 ============


RULE_REGISTRY: list[RuleFn] = [
    rule_overdue_with_no_reminder,
    rule_low_completion_rate,
    rule_upcoming_event_no_prep,
]


def build_rule_candidates(ctx: SuggestionContext) -> list[SuggestionDraft]:
    """등록된 모든 규칙을 평가해서 통과한 candidate 목록 반환.

    예외 발생한 규칙은 무시 (1개 규칙 버그가 전체 tick을 멈추지 않도록).
    """
    candidates: list[SuggestionDraft] = []
    for rule in RULE_REGISTRY:
        try:
            draft = rule(ctx)
        except Exception as exc:
            # 운영 환경에서는 logger.exception 권장
            print(f"[rule_registry] {rule.__name__} raised: {exc}")
            continue
        if draft is None:
            continue
        candidates.append(draft)
    return candidates
