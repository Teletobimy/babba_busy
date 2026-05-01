"""
User Brain Router (Phase B1)

3-Brain Architecture의 가장 활동적 tier — 개인 사용자의 KB, reflection, suggestion 조회.

참조: docs/ai/BABBA_3BRAIN_DESIGN_V1.md
"""

from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from dependencies import get_current_user
from models import (
    ErrorResponse,
    UserBrainCurrentState,
    UserBrainGroupContext,
    UserBrainKB,
    UserBrainKBResponse,
    UserBrainKnowledge,
    UserBrainPlatformContext,
    UserBrainReflectionEntry,
    UserBrainReflectionListResponse,
    UserBrainSuggestionEntry,
    UserBrainSuggestionLifecycleStages,
    UserBrainSuggestionListResponse,
)
from services import FirestoreCache
from time_utils import utcnow_naive as _utcnow

router = APIRouter(prefix="/api/agent/brain/user", tags=["UserBrain"])


def _empty_kb_doc(user_id: str, now: datetime) -> dict:
    """KB 시드 — 첫 호출 시 lazy 생성"""
    return {
        "user_id": user_id,
        "knowledge": {
            "personal_knowledge": "",
            "inferred_patterns": [],
            "rhythm_summary": None,
        },
        "current_state": {
            "active_todos": 0,
            "upcoming_events": 0,
            "completed_today": 0,
            "completion_rate_7d": 0.0,
            "last_active_at": None,
        },
        "platform_context": None,
        "group_contexts": [],
        "version": 1,
        "seeded_at": now,
        "last_reflection_at": None,
        "last_updated": now,
    }


def _coerce_kb(raw: dict, user_id: str) -> UserBrainKB:
    """Firestore raw → Pydantic. 누락 필드는 default."""
    knowledge_raw = raw.get("knowledge") or {}
    state_raw = raw.get("current_state") or {}
    platform_raw = raw.get("platform_context")
    group_raw = raw.get("group_contexts") or []

    return UserBrainKB(
        user_id=str(raw.get("user_id") or user_id),
        knowledge=UserBrainKnowledge(
            personal_knowledge=str(knowledge_raw.get("personal_knowledge") or ""),
            inferred_patterns=[str(x) for x in (knowledge_raw.get("inferred_patterns") or [])],
            rhythm_summary=knowledge_raw.get("rhythm_summary"),
        ),
        current_state=UserBrainCurrentState(
            active_todos=int(state_raw.get("active_todos") or 0),
            upcoming_events=int(state_raw.get("upcoming_events") or 0),
            completed_today=int(state_raw.get("completed_today") or 0),
            completion_rate_7d=float(state_raw.get("completion_rate_7d") or 0.0),
            last_active_at=state_raw.get("last_active_at"),
        ),
        platform_context=(
            UserBrainPlatformContext(
                injected_at=platform_raw.get("injected_at"),
                platform_kb_version=int(platform_raw.get("platform_kb_version") or 0),
                summary=str(platform_raw.get("summary") or ""),
                relevant_signals=[str(x) for x in (platform_raw.get("relevant_signals") or [])],
            )
            if isinstance(platform_raw, dict)
            else None
        ),
        group_contexts=[
            UserBrainGroupContext(
                family_id=str(g.get("family_id") or ""),
                family_name=g.get("family_name"),
                summary=str(g.get("summary") or ""),
                last_synced_at=g.get("last_synced_at"),
            )
            for g in group_raw
            if isinstance(g, dict) and (g.get("family_id") or "").strip()
        ],
        version=int(raw.get("version") or 1),
        seeded_at=raw.get("seeded_at"),
        last_reflection_at=raw.get("last_reflection_at"),
        last_updated=raw.get("last_updated"),
    )


@router.get(
    "/kb",
    response_model=UserBrainKBResponse,
    responses={500: {"model": ErrorResponse}},
)
async def get_user_brain_kb(current_user: dict = Depends(get_current_user)):
    """현재 사용자의 User Brain KB 조회 (없으면 lazy seed)"""
    try:
        uid = current_user["uid"]
        raw = await FirestoreCache.get_user_brain_kb(uid)
        if raw is None:
            seed = _empty_kb_doc(uid, _utcnow())
            await FirestoreCache.set_user_brain_kb(uid, seed)
            raw = seed
        kb = _coerce_kb(raw, uid)
        return UserBrainKBResponse(kb=kb, fetched_at=_utcnow())
    except Exception as exc:
        print(f"User brain kb error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="User Brain KB 조회 중 오류가 발생했습니다.",
        )


@router.get(
    "/reflections",
    response_model=UserBrainReflectionListResponse,
    responses={500: {"model": ErrorResponse}},
)
async def list_user_brain_reflections(
    limit: int = Query(default=10, ge=1, le=30),
    current_user: dict = Depends(get_current_user),
):
    """최근 reflection 목록 — created_at desc"""
    try:
        uid = current_user["uid"]
        items_raw = await FirestoreCache.list_user_brain_reflections(uid, limit)
        items = [
            UserBrainReflectionEntry(
                period=str(item.get("period") or ""),
                type=str(item.get("type") or "tick"),
                summary=str(item.get("summary") or ""),
                insights=[str(x) for x in (item.get("insights") or [])],
                state_hash=item.get("state_hash"),
                created_at=item.get("created_at") or _utcnow(),
            )
            for item in items_raw
            if (item.get("period") or "").strip()
        ]
        return UserBrainReflectionListResponse(
            user_id=uid,
            items=items,
            fetched_at=_utcnow(),
        )
    except Exception as exc:
        print(f"User brain reflections error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="User Brain reflection 조회 중 오류가 발생했습니다.",
        )


@router.get(
    "/suggestions",
    response_model=UserBrainSuggestionListResponse,
    responses={500: {"model": ErrorResponse}},
)
async def list_user_brain_suggestions(
    limit: int = Query(default=20, ge=1, le=50),
    current_user: dict = Depends(get_current_user),
):
    """최근 proactive suggestion 목록"""
    try:
        uid = current_user["uid"]
        items_raw = await FirestoreCache.list_user_brain_suggestions(uid, limit)
        items: list[UserBrainSuggestionEntry] = []
        for item in items_raw:
            stages_raw = item.get("stages") or {}
            signal_at = stages_raw.get("signal")
            if not signal_at:
                continue
            stages = UserBrainSuggestionLifecycleStages(
                signal=signal_at,
                dedup=stages_raw.get("dedup"),
                policy=stages_raw.get("policy"),
                agent=stages_raw.get("agent"),
                suggestion=stages_raw.get("suggestion"),
                shown=stages_raw.get("shown"),
                accepted=stages_raw.get("accepted"),
                completed=stages_raw.get("completed"),
            )
            items.append(
                UserBrainSuggestionEntry(
                    suggestion_id=str(item.get("suggestion_id") or item.get("id") or ""),
                    type=str(item.get("type") or "rule"),
                    title=str(item.get("title") or ""),
                    body=item.get("body"),
                    confidence=float(item.get("confidence") or 0.0),
                    source_stage=str(item.get("source_stage") or "rule"),
                    action_type=item.get("action_type"),
                    stages=stages,
                    accepted=item.get("accepted"),
                    created_at=item.get("created_at") or signal_at,
                )
            )
        return UserBrainSuggestionListResponse(
            user_id=uid,
            items=items,
            fetched_at=_utcnow(),
        )
    except Exception as exc:
        print(f"User brain suggestions error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="User Brain suggestion 조회 중 오류가 발생했습니다.",
        )
