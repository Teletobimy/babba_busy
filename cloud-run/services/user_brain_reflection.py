"""
User Brain Reflection — 1 사용자에 대해 1회 reflection 실행.

흐름:
  1. ctx 빌드 (Firestore에서 todos/events + KB current_state)
  2. SuggestionEngine pipeline 실행 (3단 게이트)
  3. PipelineResult → Firestore write:
       - users/{uid}/ai_brain_suggestions/{sg_id}
       - users/{uid}/ai_brain_reflections/{period}  (메트릭/요약)
       - users/{uid}/ai_brain_kb/main.last_reflection_at 갱신

cron(B2-5)이 활성 사용자 목록 받아 이 함수를 user별로 호출.
"""
from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional

from firebase_admin import firestore as fa_firestore

from services.firestore import FirestoreCache, db
from services.gemini import gemini_service
from services.suggestion_engine import (
    SuggestionContext,
    SuggestionEvent,
    SuggestionTodo,
    PipelineResult,
    run_pipeline,
)
from time_utils import sortable_datetime_or, utcnow_naive


@dataclass
class ReflectionOutcome:
    user_id: str
    pipeline: PipelineResult
    written_suggestions: int = 0
    reflection_period: Optional[str] = None
    error: Optional[str] = None


# ============ 컨텍스트 빌더 ============


async def build_user_context(
    user_id: str,
    *,
    now: Optional[datetime] = None,
) -> SuggestionContext:
    """현재 사용자에 대해 Firestore에서 정보 모아 SuggestionContext 빌드."""
    now = now or utcnow_naive()

    pending_raw = await FirestoreCache.get_recent_private_pending_todos(user_id, limit=20)
    upcoming_raw = await FirestoreCache.get_recent_private_calendar_items(user_id, limit=20)

    pending_todos = [
        SuggestionTodo(
            id=str(item.get("id") or ""),
            title=str(item.get("title") or "")[:120],
            due_date=item.get("due_date"),
            has_reminder=bool(item.get("reminder_minutes")),
            is_completed=False,
        )
        for item in pending_raw
        if (item.get("id") or "").strip()
    ]

    upcoming_events = [
        SuggestionEvent(
            id=str(item.get("id") or ""),
            title=str(item.get("title") or "")[:120],
            start_time=item.get("start_time") or item.get("due_date"),
            has_note=bool((item.get("note") or "").strip()),
            location=item.get("location"),
        )
        for item in upcoming_raw
        if (item.get("id") or "").strip()
    ]

    completion_rate, completed_today = await _compute_completion_signals(user_id, now)

    return SuggestionContext(
        user_id=user_id,
        now=now,
        pending_todos=pending_todos,
        upcoming_events=upcoming_events,
        completion_rate_7d=completion_rate,
        completed_today=completed_today,
    )


async def _compute_completion_signals(user_id: str, now: datetime) -> tuple[float, int]:
    """최근 7일 완료율 + 오늘 완료 개수 계산. 가벼운 query (limit 200)."""
    seven_days_ago = now - timedelta(days=7)
    today_start = datetime(now.year, now.month, now.day)

    def _query():
        # 완료된 todo (최근 7일 사이 completedAt)
        ref = (
            db.collection("users").document(user_id)
            .collection("todos")
            .where("isCompleted", "==", True)
            .order_by("completedAt", direction=fa_firestore.Query.DESCENDING)
            .limit(200)
        )
        return [doc.to_dict() | {"id": doc.id} for doc in ref.stream()]

    try:
        recent_completed = await asyncio.to_thread(_query)
    except Exception as exc:
        print(f"[user_brain_reflection] completion query failed for {user_id}: {exc}")
        return 0.0, 0

    # 7일 안에 완료된 것
    completed_in_week = []
    completed_today_count = 0
    for item in recent_completed:
        completed_at = sortable_datetime_or(item.get("completedAt"), datetime.min)
        if completed_at >= seven_days_ago:
            completed_in_week.append(item)
        if completed_at >= today_start:
            completed_today_count += 1

    # 분모 = 같은 기간 동안 due_date 또는 createdAt이 7일 안인 todo (간이)
    # 정밀도보단 게이트 신호용으로 충분. completed/(completed+pending_within_7d) 근사.
    pending_recent = [
        t for t in (await FirestoreCache.get_recent_private_pending_todos(user_id, limit=200))
        if t.get("due_date") and t["due_date"] >= seven_days_ago
    ]
    denom = len(completed_in_week) + len(pending_recent)
    if denom == 0:
        return 0.0, completed_today_count
    return round(len(completed_in_week) / denom, 3), completed_today_count


# ============ Firestore writer ============


async def _write_suggestions(user_id: str, pipeline: PipelineResult) -> int:
    """pipeline.records를 users/{uid}/ai_brain_suggestions에 batch write."""
    if not pipeline.records:
        return 0

    def _batch():
        batch = db.batch()
        col = (
            db.collection("users").document(user_id)
            .collection("ai_brain_suggestions")
        )
        for record in pipeline.records:
            doc_ref = col.document(record.suggestion_id)
            batch.set(doc_ref, record.to_payload(), merge=True)
        batch.commit()

    await asyncio.to_thread(_batch)
    return len(pipeline.records)


async def _write_reflection(
    user_id: str,
    pipeline: PipelineResult,
    now: datetime,
) -> str:
    """reflection 1건을 users/{uid}/ai_brain_reflections에 기록. period ID 반환."""
    period = f"tick_{now.strftime('%Y%m%dT%H%M')}"

    insights = []
    insights.append(f"rule_candidate={pipeline.rule_candidate_count}")
    insights.append(f"fast_pass={pipeline.fast_passed}")
    insights.append(f"needs_judge={pipeline.needs_judge}")
    insights.append(f"judge_passed={pipeline.judge_passed}")
    insights.append(f"blocked_by_keyword={pipeline.blocked_by_keyword}")
    insights.append(f"deduped={pipeline.deduped}")
    if pipeline.records:
        rule_ids = sorted({r.rule_id for r in pipeline.records})
        insights.append(f"emitted_rules={','.join(rule_ids)}")

    payload = {
        "period": period,
        "type": "tick",
        "summary": (
            f"규칙 후보 {pipeline.rule_candidate_count}건 → "
            f"제안 {len(pipeline.records)}건 생성"
        ),
        "insights": insights,
        "created_at": now,
    }

    def _set():
        (
            db.collection("users").document(user_id)
            .collection("ai_brain_reflections")
            .document(period)
            .set(payload, merge=True)
        )

    await asyncio.to_thread(_set)
    return period


async def _touch_kb_last_reflection(user_id: str, now: datetime) -> None:
    """KB의 last_reflection_at + last_updated만 갱신. KB 누락 시 lazy seed는 라우터가 처리."""
    def _set():
        (
            db.collection("users").document(user_id)
            .collection("ai_brain_kb")
            .document("main")
            .set(
                {"last_reflection_at": now, "last_updated": now, "user_id": user_id},
                merge=True,
            )
        )

    await asyncio.to_thread(_set)


# ============ judge caller — gemini_service wrapping ============


async def _gemini_judge_call(prompt: str) -> str:
    """gemini_service.model.generate_content_async 사용. 의존성 격리."""
    response = await gemini_service.model.generate_content_async(prompt)
    return getattr(response, "text", "") or ""


# ============ entry point (cron이 호출) ============


async def run_reflection_for_user(
    user_id: str,
    *,
    now: Optional[datetime] = None,
    judge_enabled: bool = True,
) -> ReflectionOutcome:
    """단일 사용자에 대해 reflection 1회 실행.

    Args:
        judge_enabled: False면 LLM-judge 비활성화 (kill switch).
    """
    now = now or utcnow_naive()
    try:
        ctx = await build_user_context(user_id, now=now)
        existing_fp = await _load_existing_fingerprints(user_id, now)

        result = await run_pipeline(
            ctx,
            judge_caller=_gemini_judge_call if judge_enabled else None,
            existing_fingerprints=existing_fp,
        )

        written = await _write_suggestions(user_id, result)
        period = await _write_reflection(user_id, result, now)
        await _touch_kb_last_reflection(user_id, now)

        return ReflectionOutcome(
            user_id=user_id,
            pipeline=result,
            written_suggestions=written,
            reflection_period=period,
        )
    except Exception as exc:
        print(f"[user_brain_reflection] {user_id} failed: {exc}")
        empty = PipelineResult(
            records=[], rule_candidate_count=0, fast_passed=0,
            needs_judge=0, judge_passed=0, blocked_by_keyword=0, deduped=0,
        )
        return ReflectionOutcome(user_id=user_id, pipeline=empty, error=str(exc))


async def _load_existing_fingerprints(user_id: str, now: datetime) -> set[str]:
    """오늘 이미 생성된 suggestion fingerprint 집합."""
    today_start = datetime(now.year, now.month, now.day)

    def _q():
        return list(
            db.collection("users").document(user_id)
            .collection("ai_brain_suggestions")
            .where("created_at", ">=", today_start)
            .stream()
        )

    try:
        docs = await asyncio.to_thread(_q)
    except Exception as exc:
        print(f"[user_brain_reflection] fp load failed for {user_id}: {exc}")
        return set()

    fingerprints: set[str] = set()
    for doc in docs:
        data = doc.to_dict() or {}
        fp = (data.get("fingerprint") or "").strip()
        if fp:
            fingerprints.add(fp)
    return fingerprints
