"""
SuggestionEngine 통합 파이프라인 + 8-stage lifecycle stamping.

흐름:
    SuggestionContext
      → build_rule_candidates  (Stage 1: rule)
      → filter_candidates      (Stage 2: keyword) → fast_pass / needs_judge
      → judge_drafts           (Stage 3: LLM, needs_judge에만)
      → 최종 통과 drafts
      → dedup (fingerprint)
      → 8-stage lifecycle stamping
      → SuggestionRecord (Firestore-ready dict)

본 파이프라인은 Firestore 쓰기는 하지 않음. 호출자(reflection cron 등)가
SuggestionRecord를 받아서 set_user_brain_suggestion으로 저장.

설계 분리 이유:
- 단위 테스트 가능 (Firestore stub 불필요)
- 같은 파이프라인을 future Group Brain에도 재사용
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Optional

from .domain import SuggestionContext, SuggestionDraft
from .keyword_filter import filter_candidates
from .llm_judge import JudgeCaller, JudgeVerdict, judge_drafts
from .rule_registry import build_rule_candidates


# 8-stage lifecycle stage 이름 — domain.py와 일치 (UserBrainSuggestionLifecycleStages)
STAGE_NAMES = (
    "signal", "dedup", "policy", "agent",
    "suggestion", "shown", "accepted", "completed",
)


@dataclass
class SuggestionRecord:
    """Firestore에 쓰기 직전 형태. set/merge로 그대로 저장 가능한 dict로 to_payload."""
    suggestion_id: str
    user_id: str
    rule_id: str
    type: str
    title: str
    body: Optional[str]
    confidence: float
    source_stage: str                         # rule | keyword | llm
    action_type: Optional[str]
    action_payload: dict[str, Any]
    target_label: Optional[str]
    fingerprint: str
    stages: dict[str, datetime]
    created_at: datetime
    judge_verdict: Optional[JudgeVerdict] = None  # 있으면 audit/디버깅용

    def to_payload(self) -> dict[str, Any]:
        """firestore.set/merge에 그대로 넣을 dict.

        UserBrainSuggestionEntry 스키마와 호환 (user_brain.py의 _coerce 패턴).
        """
        return {
            "user_id": self.user_id,
            "rule_id": self.rule_id,
            "type": self.type,
            "title": self.title,
            "body": self.body,
            "confidence": self.confidence,
            "source_stage": self.source_stage,
            "action_type": self.action_type,
            "action_payload": self.action_payload,
            "target_label": self.target_label,
            "fingerprint": self.fingerprint,
            "stages": dict(self.stages),
            "created_at": self.created_at,
            "judge_relevance": (
                self.judge_verdict.relevance if self.judge_verdict else None
            ),
            "judge_reason": (
                self.judge_verdict.reason if self.judge_verdict else None
            ),
        }


@dataclass
class PipelineResult:
    """1회 실행 결과 + 메트릭"""
    records: list[SuggestionRecord]
    rule_candidate_count: int
    fast_passed: int
    needs_judge: int
    judge_passed: int
    blocked_by_keyword: int
    deduped: int


# ============ Fingerprint (dedup) ============


def compute_fingerprint(draft: SuggestionDraft, user_id: str, day: str) -> str:
    """같은 사용자 / 같은 날 / 같은 rule + extras → 동일 fingerprint.

    day는 호출자가 'YYYYMMDD' 형식으로 주입.
    """
    extras = "|".join(sorted(draft.fingerprint_extras))
    raw = f"{user_id}|{day}|{draft.rule_id}|{extras}"
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:20]


# ============ Lifecycle stamping ============


def stamp_lifecycle(
    *,
    signal_at: datetime,
    dedup_at: datetime,
    policy_at: datetime,
    agent_at: datetime,
    suggestion_at: datetime,
) -> dict[str, datetime]:
    """signal~suggestion까지 5개 stage timestamp 기록 (shown/accepted/completed는
    클라이언트 인터랙션 시 추후 stamp)"""
    return {
        "signal": signal_at,
        "dedup": dedup_at,
        "policy": policy_at,
        "agent": agent_at,
        "suggestion": suggestion_at,
    }


# ============ 통합 파이프라인 ============


async def run_pipeline(
    ctx: SuggestionContext,
    *,
    judge_caller: Optional[JudgeCaller] = None,
    extra_text_signals: Optional[str] = None,
    existing_fingerprints: Optional[set[str]] = None,
    day: Optional[str] = None,
    suggestion_id_prefix: str = "sg",
    judge_timeout_seconds: float = 8.0,
) -> PipelineResult:
    """3단 게이트 + dedup + lifecycle stamping을 모두 실행.

    Args:
        judge_caller: None이면 LLM 호출 안 함 (needs_judge 모두 drop). 통합 테스트나
                      kill-switch 발동 시 사용.
        existing_fingerprints: 같은 날 이미 생성된 fingerprint 집합. 중복 차단용.
        day: dedup key 일자 (default = ctx.now.strftime('%Y%m%d')).
    """
    metrics_blocked = 0
    metrics_deduped = 0
    metrics_judge_passed = 0

    signal_at = ctx.now

    # Stage 1: rule
    rule_drafts = build_rule_candidates(ctx)
    rule_count = len(rule_drafts)

    # Stage 2: keyword
    fast_passed_drafts, needs_judge_drafts = filter_candidates(
        rule_drafts, ctx, extra_text_signals=extra_text_signals
    )
    metrics_blocked = rule_count - len(fast_passed_drafts) - len(needs_judge_drafts)
    keyword_at = ctx.now

    # Stage 3: LLM judge (caller 없으면 needs_judge drop)
    judged_pairs: list[tuple[SuggestionDraft, JudgeVerdict]] = []
    if needs_judge_drafts and judge_caller is not None:
        judged_pairs = await judge_drafts(
            needs_judge_drafts,
            ctx,
            judge_caller,
            timeout_seconds=judge_timeout_seconds,
        )
    judged_at = ctx.now

    # 최종 통과 후보 모으기
    final_pairs: list[tuple[SuggestionDraft, Optional[JudgeVerdict]]] = []
    for d in fast_passed_drafts:
        final_pairs.append((d, None))
    for d, v in judged_pairs:
        if v.passed:
            metrics_judge_passed += 1
            final_pairs.append((d, v))

    # Dedup + record build
    day_key = day or ctx.now.strftime("%Y%m%d")
    seen = set(existing_fingerprints or set())
    records: list[SuggestionRecord] = []
    suggestion_at = ctx.now

    for idx, (draft, verdict) in enumerate(final_pairs):
        fp = compute_fingerprint(draft, ctx.user_id, day_key)
        if fp in seen:
            metrics_deduped += 1
            continue
        seen.add(fp)
        record = SuggestionRecord(
            suggestion_id=f"{suggestion_id_prefix}_{day_key}_{fp[:10]}_{idx}",
            user_id=ctx.user_id,
            rule_id=draft.rule_id,
            type=draft.type,
            title=draft.title,
            body=draft.body,
            confidence=draft.confidence,
            source_stage=draft.source_stage,
            action_type=draft.action_type,
            action_payload=dict(draft.action_payload),
            target_label=draft.target_label,
            fingerprint=fp,
            stages=stamp_lifecycle(
                signal_at=signal_at,
                dedup_at=keyword_at,                  # dedup은 keyword 직전이지만 timestamp 동등
                policy_at=keyword_at,
                agent_at=judged_at,
                suggestion_at=suggestion_at,
            ),
            created_at=suggestion_at,
            judge_verdict=verdict,
        )
        records.append(record)

    return PipelineResult(
        records=records,
        rule_candidate_count=rule_count,
        fast_passed=len(fast_passed_drafts),
        needs_judge=len(needs_judge_drafts),
        judge_passed=metrics_judge_passed,
        blocked_by_keyword=metrics_blocked,
        deduped=metrics_deduped,
    )
