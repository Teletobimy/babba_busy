import hashlib
import json
from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException

from dependencies import get_current_user
from models import (
    AgentAuditLogEntry,
    AgentAuditLogListResponse,
    AgentCalendarCreateDecisionRequest,
    AgentCalendarCreateDecisionResponse,
    AgentCalendarCreatePreview,
    AgentCalendarCreatePreviewRequest,
    AgentCalendarCreatePreviewResponse,
    AgentCalendarCreateResult,
    AgentCalendarUpdateDecisionRequest,
    AgentCalendarUpdateDecisionResponse,
    AgentCalendarUpdatePreview,
    AgentCalendarUpdatePreviewRequest,
    AgentCalendarUpdatePreviewResponse,
    AgentCalendarUpdateResult,
    AgentFamilyChatSummaryRequest,
    AgentFamilyChatSummaryResponse,
    AgentHomeSummaryRequest,
    AgentHomeSummaryResponse,
    AgentMemoSummaryRequest,
    AgentMemoSummaryResponse,
    AgentNoteCreateDecisionRequest,
    AgentNoteCreateDecisionResponse,
    AgentNoteCreatePreview,
    AgentNoteCreatePreviewRequest,
    AgentNoteCreatePreviewResponse,
    AgentNoteCreateResult,
    AgentReminderCreateDecisionRequest,
    AgentReminderCreateDecisionResponse,
    AgentReminderCreatePreview,
    AgentReminderCreatePreviewRequest,
    AgentReminderCreatePreviewResponse,
    AgentReminderCreateResult,
    AgentNoteUpdateDecisionRequest,
    AgentNoteUpdateDecisionResponse,
    AgentNoteUpdatePreview,
    AgentNoteUpdatePreviewRequest,
    AgentNoteUpdatePreviewResponse,
    AgentNoteUpdateResult,
    AgentTodoCreateDecisionRequest,
    AgentTodoCreateDecisionResponse,
    AgentTodoCreatePreview,
    AgentTodoCreatePreviewRequest,
    AgentTodoCreatePreviewResponse,
    AgentTodoCreateResult,
    AgentTodoCompleteDecisionRequest,
    AgentTodoCompleteDecisionResponse,
    AgentTodoCompletePreview,
    AgentTodoCompletePreviewRequest,
    AgentTodoCompletePreviewResponse,
    AgentTodoCompleteResult,
    AgentToolConsent,
    ErrorResponse,
)
from services import FirestoreCache, gemini_service
from time_utils import normalize_utc_naive, utcnow_naive as _utcnow

router = APIRouter(prefix="/api/agent", tags=["Agent"])


def _resolve_subject_name(request: AgentHomeSummaryRequest) -> str:
    selected_name = (request.selected_member_name or "").strip()
    if selected_name:
        return selected_name

    user_name = request.user_name.strip()
    if user_name:
        return user_name

    return "사용자"


def _build_cache_key(today: str, selected_member_id: str | None) -> str:
    member_scope = (selected_member_id or "").strip()
    if member_scope:
        return f"{today}__agent_home_summary__member_{member_scope}"
    return f"{today}__agent_home_summary__all"


def _build_family_chat_cache_key(
    family_id: str,
    latest_message_id: str,
    limit_messages: int,
) -> str:
    return (
        f"agent_family_chat_summary__{family_id}"
        f"__{latest_message_id}__limit_{limit_messages}"
    )


def _build_memo_summary_cache_key(
    content: str,
    memo_title: str | None,
    category_name: str | None,
) -> str:
    cache_basis = "\n".join(
        [
            (memo_title or "").strip(),
            (category_name or "").strip(),
            content.strip(),
        ]
    )
    digest = hashlib.sha256(cache_basis.encode("utf-8")).hexdigest()[:20]
    return f"agent_memo_summary__{digest}"


def _normalize_priority(value: object) -> int:
    try:
        priority = int(value)
    except (TypeError, ValueError):
        priority = 1
    return min(max(priority, 0), 2)


def _priority_label(priority: int) -> str:
    if priority >= 2:
        return "높음"
    if priority <= 0:
        return "낮음"
    return "보통"


def _format_due_date_label(due_date: datetime | None) -> str | None:
    if due_date is None:
        return None

    if due_date.hour == 0 and due_date.minute == 0:
        return due_date.strftime("%m월 %d일")
    return due_date.strftime("%m월 %d일 %H:%M")


def _format_reminder_label(minutes: int) -> str:
    if minutes == 0:
        return "정시"
    if minutes < 60:
        return f"{minutes}분 전"
    if minutes < 1440:
        hours = minutes // 60
        remainder = minutes % 60
        if remainder == 0:
            return f"{hours}시간 전"
        return f"{hours}시간 {remainder}분 전"

    days = minutes // 1440
    remainder_hours = (minutes % 1440) // 60
    if remainder_hours == 0:
        return f"{days}일 전"
    return f"{days}일 {remainder_hours}시간 전"


def _build_todo_preview_params_hash(preview: dict) -> str:
    payload = {
        "title": preview["title"],
        "note": preview.get("note"),
        "due_date": preview["due_date"].isoformat() if preview.get("due_date") else None,
        "priority": preview["priority"],
        "reminder_minutes": preview["reminder_minutes"],
        "visibility": preview["visibility"],
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:24]


def _build_todo_complete_params_hash(preview: dict) -> str:
    payload = {
        "todo_id": preview["todo_id"],
        "title": preview["title"],
        "due_date": preview["due_date"].isoformat() if preview.get("due_date") else None,
        "visibility": preview["visibility"],
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:24]


def _calendar_event_type_label(event_type: str) -> str:
    return "이벤트" if event_type == "event" else "일정"


def _format_time_range(
    start_time: datetime | None,
    end_time: datetime | None,
) -> str | None:
    if start_time is None:
        return None

    start_label = start_time.strftime("%H:%M")
    if end_time is None:
        return start_label
    return f"{start_label} - {end_time.strftime('%H:%M')}"


def _build_calendar_create_params_hash(preview: dict) -> str:
    payload = {
        "title": preview["title"],
        "event_type": preview["event_type"],
        "due_date": preview["due_date"].isoformat() if preview.get("due_date") else None,
        "start_time": preview["start_time"].isoformat() if preview.get("start_time") else None,
        "end_time": preview["end_time"].isoformat() if preview.get("end_time") else None,
        "location": preview.get("location"),
        "visibility": preview["visibility"],
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:24]


def _build_calendar_update_params_hash(preview: dict) -> str:
    payload = {
        "event_id": preview["event_id"],
        "title": preview["title"],
        "event_type": preview["event_type"],
        "due_date": preview["due_date"].isoformat() if preview.get("due_date") else None,
        "start_time": preview["start_time"].isoformat() if preview.get("start_time") else None,
        "end_time": preview["end_time"].isoformat() if preview.get("end_time") else None,
        "location": preview.get("location"),
        "visibility": preview["visibility"],
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:24]


def _build_note_create_params_hash(preview: dict) -> str:
    payload = {
        "title": preview["title"],
        "content": preview.get("content"),
        "category_name": preview.get("category_name"),
        "tags": preview.get("tags") or [],
        "is_pinned": bool(preview.get("is_pinned")),
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:24]


def _build_note_update_params_hash(preview: dict) -> str:
    payload = {
        "memo_id": preview["memo_id"],
        "title": preview["title"],
        "content": preview.get("content"),
        "category_name": preview.get("category_name"),
        "tags": preview.get("tags") or [],
        "is_pinned": bool(preview.get("is_pinned")),
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:24]


def _normalize_recurrence(value: object) -> str | None:
    normalized = str(value or "").strip().lower()
    if normalized in {"daily", "weekly", "monthly"}:
        return normalized
    return None


def _recurrence_label(recurrence: str | None) -> str | None:
    if recurrence == "daily":
        return "매일"
    if recurrence == "weekly":
        return "매주"
    if recurrence == "monthly":
        return "매월"
    return None


def _format_remind_at_label(remind_at: datetime | None) -> str | None:
    if remind_at is None:
        return None
    return remind_at.strftime("%m월 %d일 %H:%M")


def _build_reminder_create_params_hash(preview: dict) -> str:
    payload = {
        "message": preview["message"],
        "remind_at": preview["remind_at"].isoformat(),
        "recurrence": preview.get("recurrence"),
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:24]


def _normalize_scope_prompt(prompt: str) -> str:
    return " ".join(str(prompt or "").strip().lower().split())


def _is_explicit_shared_scope_request(prompt: str, domain: str) -> bool:
    normalized = _normalize_scope_prompt(prompt)
    if not normalized:
        return False

    domain_phrases = {
        "todo": [
            "공유 할 일",
            "공유 할일",
            "가족 할 일",
            "가족 할일",
            "그룹 할 일",
            "그룹 할일",
            "우리 할 일",
            "우리 할일",
            "shared todo",
            "family todo",
            "group todo",
        ],
        "calendar": [
            "공유 일정",
            "공유 캘린더",
            "가족 캘린더",
            "그룹 캘린더",
            "우리 캘린더",
            "shared calendar",
            "family calendar",
            "group calendar",
        ],
        "notes": [
            "공유 메모",
            "가족 메모",
            "그룹 메모",
            "우리 메모",
            "공동 메모",
            "shared note",
            "shared memo",
        ],
        "reminder": [
            "공유 알림",
            "공유 리마인더",
            "가족 알림",
            "가족 리마인더",
            "모두에게 알림",
            "전원에게 알림",
            "단톡방에 알림",
            "shared reminder",
            "group reminder",
        ],
    }

    for phrase in domain_phrases.get(domain, []):
        if phrase in normalized:
            return True

    return False


def _personal_scope_denial_message(domain_label: str) -> str:
    return (
        f"{domain_label} AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. "
        "개인 범위 요청으로 다시 입력해주세요."
    )


@router.post(
    "/summary/home",
    response_model=AgentHomeSummaryResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def generate_home_summary(
    request: AgentHomeSummaryRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 read-only 홈 요약"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        today = _utcnow().strftime("%Y-%m-%d")
        cache_key = _build_cache_key(today, request.selected_member_id)
        subject_name = _resolve_subject_name(request)

        cached = await FirestoreCache.get_daily_summary(request.user_id, cache_key)
        if cached:
            return AgentHomeSummaryResponse(
                subject_name=subject_name,
                summary=cached["content"],
                cached=True,
                trace_id=f"cached-{cache_key}",
                generated_at=cached["created_at"],
            )

        summary = await gemini_service.generate_daily_summary(
            user_name=subject_name,
            pending_todos=request.pending_todos,
            completed_today=request.completed_today,
            upcoming_events=request.upcoming_events,
        )

        await FirestoreCache.set_daily_summary(request.user_id, cache_key, summary)

        return AgentHomeSummaryResponse(
            subject_name=subject_name,
            summary=summary,
            cached=False,
            trace_id=f"home-summary-{uuid4().hex[:12]}",
            generated_at=_utcnow(),
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent home summary error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="에이전트 홈 요약 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/summary/family-chat",
    response_model=AgentFamilyChatSummaryResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def generate_family_chat_summary(
    request: AgentFamilyChatSummaryRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 read-only 가족 채팅 요약"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        is_family_member = await FirestoreCache.is_family_member(
            request.user_id,
            request.family_id,
        )
        if not is_family_member:
            raise HTTPException(status_code=403, detail="가족 채팅 접근 권한이 없습니다.")

        messages = await FirestoreCache.get_recent_family_chat_messages(
            request.family_id,
            request.limit_messages,
        )
        if not messages:
            family_name = (request.family_name or "가족 채팅").strip() or "가족 채팅"
            return AgentFamilyChatSummaryResponse(
                family_id=request.family_id,
                family_name=family_name,
                summary="아직 요약할 대화가 없어요.",
                highlights=[],
                message_count=0,
                participant_count=0,
                latest_message_at=None,
                cached=False,
                trace_id=f"family-chat-empty-{request.family_id}",
                generated_at=_utcnow(),
            )

        latest_message = messages[-1]
        latest_message_id = (latest_message.get("id") or "latest").strip() or "latest"
        cache_key = _build_family_chat_cache_key(
            request.family_id,
            latest_message_id,
            request.limit_messages,
        )
        family_name = (request.family_name or "가족 채팅").strip() or "가족 채팅"
        participant_count = len(
            {
                (message.get("sender_id") or "").strip()
                for message in messages
                if (message.get("sender_id") or "").strip()
                and (message.get("sender_id") or "").strip() != "system"
            }
        )

        cached = await FirestoreCache.get_daily_summary(request.user_id, cache_key)
        if cached:
            return AgentFamilyChatSummaryResponse(
                family_id=request.family_id,
                family_name=str(cached.get("family_name") or family_name),
                summary=cached["content"],
                highlights=list(cached.get("highlights") or []),
                message_count=int(cached.get("message_count") or len(messages)),
                participant_count=int(cached.get("participant_count") or participant_count),
                latest_message_at=cached.get("latest_message_at"),
                cached=True,
                trace_id=f"cached-{cache_key}",
                generated_at=cached["created_at"],
            )

        summary_result = await gemini_service.generate_family_chat_summary(
            family_name=family_name,
            messages=messages,
        )

        latest_message_at = latest_message.get("created_at")
        await FirestoreCache.set_daily_summary(
            request.user_id,
            cache_key,
            summary_result["summary"],
            ttl_seconds=600,
            metadata={
                "family_name": family_name,
                "highlights": summary_result.get("highlights") or [],
                "message_count": len(messages),
                "participant_count": participant_count,
                "latest_message_at": latest_message_at,
            },
        )

        return AgentFamilyChatSummaryResponse(
            family_id=request.family_id,
            family_name=family_name,
            summary=summary_result["summary"],
            highlights=summary_result.get("highlights") or [],
            message_count=len(messages),
            participant_count=participant_count,
            latest_message_at=latest_message_at,
            cached=False,
            trace_id=f"family-chat-summary-{uuid4().hex[:12]}",
            generated_at=_utcnow(),
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent family chat summary error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="에이전트 가족 채팅 요약 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/summary/memo",
    response_model=AgentMemoSummaryResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def generate_memo_summary(
    request: AgentMemoSummaryRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 read-only 메모 요약"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        normalized_content = request.content.strip()
        if len(normalized_content) < 20:
            raise HTTPException(
                status_code=400,
                detail="내용이 너무 짧습니다 (최소 20자)",
            )

        cache_key = _build_memo_summary_cache_key(
            normalized_content,
            request.memo_title,
            request.category_name,
        )
        cached = await FirestoreCache.get_daily_summary(request.user_id, cache_key)
        if cached:
            return AgentMemoSummaryResponse(
                summary=cached["content"],
                analysis=str(cached.get("analysis") or ""),
                validation_points=list(cached.get("validation_points") or []),
                suggested_category=cached.get("suggested_category"),
                suggested_tags=list(cached.get("suggested_tags") or []),
                cached=True,
                trace_id=f"cached-{cache_key}",
                generated_at=cached["created_at"],
            )

        summary_result = await gemini_service.generate_memo_summary(
            content=normalized_content,
            category_name=request.category_name,
            memo_title=request.memo_title,
        )

        await FirestoreCache.set_daily_summary(
            request.user_id,
            cache_key,
            summary_result["summary"],
            ttl_seconds=3600,
            metadata={
                "analysis": summary_result.get("analysis") or "",
                "validation_points": summary_result.get("validation_points") or [],
                "suggested_category": summary_result.get("suggested_category"),
                "suggested_tags": summary_result.get("suggested_tags") or [],
            },
        )

        return AgentMemoSummaryResponse(
            summary=summary_result["summary"],
            analysis=summary_result.get("analysis") or "",
            validation_points=summary_result.get("validation_points") or [],
            suggested_category=summary_result.get("suggested_category"),
            suggested_tags=summary_result.get("suggested_tags") or [],
            cached=False,
            trace_id=f"memo-summary-{uuid4().hex[:12]}",
            generated_at=_utcnow(),
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent memo summary error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="에이전트 메모 요약 생성 중 오류가 발생했습니다.",
        )


@router.get(
    "/audit/recent",
    response_model=AgentAuditLogListResponse,
    responses={500: {"model": ErrorResponse}},
)
async def get_recent_agent_audit_logs(
    limit: int = 12,
    current_user: dict = Depends(get_current_user),
):
    """현재 사용자 기준 최근 AI tool audit 로그 조회"""
    try:
        safe_limit = min(max(limit, 1), 30)
        items = await FirestoreCache.list_recent_tool_audit_logs(
            current_user["uid"],
            safe_limit,
        )
        return AgentAuditLogListResponse(
            user_id=current_user["uid"],
            limit=safe_limit,
            total_count=len(items),
            items=[AgentAuditLogEntry(**item) for item in items],
            fetched_at=_utcnow(),
        )
    except Exception as exc:
        print(f"Agent audit read error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="에이전트 audit 로그 조회 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/notes/create/preview",
    response_model=AgentNoteCreatePreviewResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def preview_personal_note_create(
    request: AgentNoteCreatePreviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 메모 생성 preview"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        prompt = request.prompt.strip()
        if len(prompt) < 2:
            raise HTTPException(status_code=400, detail="요청 내용을 더 구체적으로 입력해주세요.")
        if _is_explicit_shared_scope_request(prompt, "notes"):
            raise HTTPException(
                status_code=403,
                detail=_personal_scope_denial_message("개인 메모"),
            )

        planned = await gemini_service.plan_personal_note_create(
            prompt=prompt,
            current_time_iso=_utcnow().isoformat(timespec="seconds"),
        )

        title = str(planned.get("title") or "").strip()
        content = str(planned.get("content") or "").strip()
        if not title and not content:
            raise HTTPException(status_code=400, detail="메모 초안을 생성할 수 없습니다.")
        if not title:
            title = (content[:40] or "새 메모").strip()

        preview_payload = {
            "title": title,
            "content": content,
            "category_name": str(planned.get("category_name") or "").strip() or None,
            "tags": FirestoreCache._normalize_note_tags(planned.get("tags")),
            "is_pinned": bool(planned.get("is_pinned")),
        }
        params_hash = _build_note_create_params_hash(preview_payload)
        request_id = f"note_create_{uuid4().hex[:16]}"
        summary = (
            str(planned.get("summary") or "").strip()
            or f"개인 메모 '{title}' 초안을 만들었어요."
        )
        generated_at = _utcnow()

        await FirestoreCache.set_ai_action_request(
            request.user_id,
            request_id,
            {
                "tool": "manage_notes",
                "action": "create",
                "scope": "personal",
                "status": "pending",
                "prompt": prompt,
                "source": (request.source or "").strip() or "memo_ai_fab",
                "params_hash": params_hash,
                "summary": summary,
                "preview": preview_payload,
                "consent": {
                    "required": True,
                    "approved": None,
                },
                "created_at": generated_at,
                "updated_at": generated_at,
            },
            merge=True,
        )

        return AgentNoteCreatePreviewResponse(
            request_id=request_id,
            params_hash=params_hash,
            summary=summary,
            preview=AgentNoteCreatePreview(**preview_payload),
            consent=AgentToolConsent(required=True, approved=None),
            generated_at=generated_at,
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent note create preview error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 메모 초안 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/notes/create/decision",
    response_model=AgentNoteCreateDecisionResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def decide_personal_note_create(
    request: AgentNoteCreateDecisionRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 메모 생성 consent 처리"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        stored_request = await FirestoreCache.get_ai_action_request(
            request.user_id,
            request.request_id,
        )
        if stored_request is None:
            raise HTTPException(status_code=404, detail="처리할 요청을 찾을 수 없습니다.")

        decision_result = await FirestoreCache.finalize_personal_note_create_action(
            request.user_id,
            request.request_id,
            request.approved,
        )
        result_payload = decision_result.get("result") or {}

        return AgentNoteCreateDecisionResponse(
            request_id=request.request_id,
            audit_id=str(decision_result.get("audit_id") or f"audit_{request.request_id}"),
            consent=AgentToolConsent(
                required=True,
                approved=bool(decision_result.get("approved")),
            ),
            result=AgentNoteCreateResult(**result_payload),
            executed_at=decision_result.get("executed_at") or _utcnow(),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        print(f"Agent note create decision error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 메모 생성 처리 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/notes/update/preview",
    response_model=AgentNoteUpdatePreviewResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def preview_personal_note_update(
    request: AgentNoteUpdatePreviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 메모 수정 preview"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        prompt = request.prompt.strip()
        if len(prompt) < 2:
            raise HTTPException(status_code=400, detail="요청 내용을 더 구체적으로 입력해주세요.")
        if _is_explicit_shared_scope_request(prompt, "notes"):
            raise HTTPException(
                status_code=403,
                detail=_personal_scope_denial_message("개인 메모"),
            )

        memos = await FirestoreCache.get_recent_memos(request.user_id, limit=30)
        if not memos:
            raise HTTPException(status_code=400, detail="수정할 개인 메모가 없습니다.")

        planned = await gemini_service.plan_personal_note_update(
            prompt=prompt,
            memos=memos,
            current_time_iso=_utcnow().isoformat(timespec="seconds"),
        )
        if not planned:
            raise HTTPException(status_code=400, detail="수정할 개인 메모를 찾을 수 없습니다.")

        memo_id = str(planned.get("memo_id") or "").strip()
        title = str(planned.get("title") or "").strip()
        if not memo_id or not title:
            raise HTTPException(status_code=400, detail="메모 수정 초안을 생성할 수 없습니다.")

        candidate = next(
            (
                item
                for item in memos
                if str(item.get("id") or "").strip() == memo_id
            ),
            None,
        )
        if candidate is None:
            raise HTTPException(status_code=400, detail="수정할 개인 메모를 찾을 수 없습니다.")

        preview_payload = {
            "memo_id": memo_id,
            "original_title": str(candidate.get("title") or "").strip(),
            "original_category_name": str(candidate.get("category_name") or "").strip()
            or None,
            "title": title,
            "content": str(planned.get("content") or "").strip(),
            "category_name": str(planned.get("category_name") or "").strip() or None,
            "tags": FirestoreCache._normalize_note_tags(planned.get("tags")),
            "is_pinned": bool(planned.get("is_pinned")),
            "match_reason": str(planned.get("reason") or "").strip() or None,
        }
        params_hash = _build_note_update_params_hash(preview_payload)
        request_id = f"note_update_{uuid4().hex[:16]}"
        summary = (
            str(planned.get("summary") or "").strip()
            or f"개인 메모 '{title}' 수정 초안을 만들었어요."
        )
        generated_at = _utcnow()

        await FirestoreCache.set_ai_action_request(
            request.user_id,
            request_id,
            {
                "tool": "manage_notes",
                "action": "update",
                "scope": "personal",
                "status": "pending",
                "prompt": prompt,
                "source": (request.source or "").strip() or "memo_ai_fab",
                "params_hash": params_hash,
                "summary": summary,
                "preview": preview_payload,
                "consent": {
                    "required": True,
                    "approved": None,
                },
                "created_at": generated_at,
                "updated_at": generated_at,
            },
            merge=True,
        )

        return AgentNoteUpdatePreviewResponse(
            request_id=request_id,
            params_hash=params_hash,
            summary=summary,
            preview=AgentNoteUpdatePreview(**preview_payload),
            consent=AgentToolConsent(required=True, approved=None),
            generated_at=generated_at,
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent note update preview error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 메모 수정 초안 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/notes/update/decision",
    response_model=AgentNoteUpdateDecisionResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def decide_personal_note_update(
    request: AgentNoteUpdateDecisionRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 메모 수정 consent 처리"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        stored_request = await FirestoreCache.get_ai_action_request(
            request.user_id,
            request.request_id,
        )
        if stored_request is None:
            raise HTTPException(status_code=404, detail="처리할 요청을 찾을 수 없습니다.")

        decision_result = await FirestoreCache.finalize_personal_note_update_action(
            request.user_id,
            request.request_id,
            request.approved,
        )
        result_payload = decision_result.get("result") or {}

        return AgentNoteUpdateDecisionResponse(
            request_id=request.request_id,
            audit_id=str(decision_result.get("audit_id") or f"audit_{request.request_id}"),
            consent=AgentToolConsent(
                required=True,
                approved=bool(decision_result.get("approved")),
            ),
            result=AgentNoteUpdateResult(**result_payload),
            executed_at=decision_result.get("executed_at") or _utcnow(),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        print(f"Agent note update decision error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 메모 수정 처리 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/reminders/create/preview",
    response_model=AgentReminderCreatePreviewResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def preview_personal_reminder_create(
    request: AgentReminderCreatePreviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 리마인더 생성 preview"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        prompt = request.prompt.strip()
        if len(prompt) < 2:
            raise HTTPException(status_code=400, detail="요청 내용을 더 구체적으로 입력해주세요.")
        if _is_explicit_shared_scope_request(prompt, "reminder"):
            raise HTTPException(
                status_code=403,
                detail=_personal_scope_denial_message("개인 리마인더"),
            )

        planned = await gemini_service.plan_personal_reminder_create(
            prompt=prompt,
            current_time_iso=_utcnow().isoformat(timespec="seconds"),
        )

        message = str(planned.get("message") or "").strip()
        remind_at = planned.get("remind_at")
        if remind_at is not None and isinstance(remind_at, datetime):
            remind_at = normalize_utc_naive(remind_at)

        if not message or not isinstance(remind_at, datetime):
            raise HTTPException(status_code=400, detail="리마인더 초안을 생성할 수 없습니다.")
        if remind_at <= _utcnow():
            raise HTTPException(
                status_code=400,
                detail="리마인더 시각이 현재보다 미래여야 합니다. 시간을 더 구체적으로 적어주세요.",
            )

        recurrence = _normalize_recurrence(planned.get("recurrence"))
        preview_payload = {
            "message": message,
            "remind_at": remind_at,
            "formatted_remind_at": _format_remind_at_label(remind_at),
            "recurrence": recurrence,
            "recurrence_label": _recurrence_label(recurrence),
        }
        params_hash = _build_reminder_create_params_hash(preview_payload)
        request_id = f"reminder_create_{uuid4().hex[:16]}"
        summary = (
            f"개인 리마인더 '{message}'를 "
            f"{preview_payload['formatted_remind_at']}에 만들어요."
        )
        if preview_payload["recurrence_label"]:
            summary = (
                f"개인 리마인더 '{message}'를 "
                f"{preview_payload['formatted_remind_at']}부터 "
                f"{preview_payload['recurrence_label']} 반복으로 만들어요."
            )
        generated_at = _utcnow()

        await FirestoreCache.set_ai_action_request(
            request.user_id,
            request_id,
            {
                "tool": "create_reminder",
                "action": "create",
                "scope": "personal",
                "status": "pending",
                "prompt": prompt,
                "source": (request.source or "").strip() or "home_quick_add_ai_reminder",
                "params_hash": params_hash,
                "summary": summary,
                "preview": preview_payload,
                "consent": {
                    "required": True,
                    "approved": None,
                },
                "created_at": generated_at,
                "updated_at": generated_at,
            },
            merge=True,
        )

        return AgentReminderCreatePreviewResponse(
            request_id=request_id,
            params_hash=params_hash,
            summary=summary,
            preview=AgentReminderCreatePreview(**preview_payload),
            consent=AgentToolConsent(required=True, approved=None),
            generated_at=generated_at,
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent reminder create preview error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 리마인더 초안 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/reminders/create/decision",
    response_model=AgentReminderCreateDecisionResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def decide_personal_reminder_create(
    request: AgentReminderCreateDecisionRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 리마인더 생성 consent 처리"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        stored_request = await FirestoreCache.get_ai_action_request(
            request.user_id,
            request.request_id,
        )
        if stored_request is None:
            raise HTTPException(status_code=404, detail="처리할 요청을 찾을 수 없습니다.")

        decision_result = await FirestoreCache.finalize_personal_reminder_create_action(
            request.user_id,
            request.request_id,
            request.approved,
        )
        result_payload = decision_result.get("result") or {}

        return AgentReminderCreateDecisionResponse(
            request_id=request.request_id,
            audit_id=str(decision_result.get("audit_id") or f"audit_{request.request_id}"),
            consent=AgentToolConsent(
                required=True,
                approved=bool(decision_result.get("approved")),
            ),
            result=AgentReminderCreateResult(**result_payload),
            executed_at=decision_result.get("executed_at") or _utcnow(),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        print(f"Agent reminder create decision error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 리마인더 생성 처리 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/todo/preview",
    response_model=AgentTodoCreatePreviewResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def preview_personal_todo_create(
    request: AgentTodoCreatePreviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 todo 생성 preview"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        prompt = request.prompt.strip()
        if len(prompt) < 2:
            raise HTTPException(status_code=400, detail="요청 내용을 더 구체적으로 입력해주세요.")
        if _is_explicit_shared_scope_request(prompt, "todo"):
            raise HTTPException(
                status_code=403,
                detail=_personal_scope_denial_message("개인 할 일"),
            )

        current_group_id = (request.current_group_id or "").strip()
        if current_group_id:
            is_family_member = await FirestoreCache.is_family_member(
                request.user_id,
                current_group_id,
            )
            if not is_family_member:
                raise HTTPException(
                    status_code=403,
                    detail="현재 가족 컨텍스트가 유효하지 않습니다. 그룹을 다시 선택해주세요.",
                )

        planned = await gemini_service.plan_personal_todo_create(
            prompt=prompt,
            current_time_iso=_utcnow().isoformat(timespec="seconds"),
        )

        title = str(planned.get("title") or "").strip()
        if not title:
            raise HTTPException(status_code=400, detail="할 일 초안을 생성할 수 없습니다.")

        due_date = planned.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None

        priority = _normalize_priority(planned.get("priority"))
        reminder_minutes = FirestoreCache._normalize_reminder_minutes(
            planned.get("reminder_minutes")
        )
        formatted_due_date = _format_due_date_label(due_date)

        preview_payload = {
            "title": title,
            "note": str(planned.get("note") or "").strip() or None,
            "due_date": due_date,
            "formatted_due_date": formatted_due_date,
            "priority": priority,
            "priority_label": _priority_label(priority),
            "reminder_minutes": reminder_minutes,
            "reminder_labels": [_format_reminder_label(item) for item in reminder_minutes],
            "visibility": "private",
        }
        params_hash = _build_todo_preview_params_hash(preview_payload)
        request_id = f"todo_create_{uuid4().hex[:16]}"
        summary = str(planned.get("summary") or "").strip() or f"개인 할 일 '{title}'을 만들어요."
        generated_at = _utcnow()

        await FirestoreCache.set_ai_action_request(
            request.user_id,
            request_id,
            {
                "tool": "manage_todos",
                "action": "create",
                "scope": "personal",
                "status": "pending",
                "prompt": prompt,
                "source": (request.source or "").strip() or "home_quick_add_ai",
                "current_group_id": (request.current_group_id or "").strip(),
                "params_hash": params_hash,
                "summary": summary,
                "preview": preview_payload,
                "consent": {
                    "required": True,
                    "approved": None,
                },
                "created_at": generated_at,
                "updated_at": generated_at,
            },
            merge=True,
        )

        return AgentTodoCreatePreviewResponse(
            request_id=request_id,
            params_hash=params_hash,
            summary=summary,
            preview=AgentTodoCreatePreview(**preview_payload),
            consent=AgentToolConsent(required=True, approved=None),
            generated_at=generated_at,
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent todo preview error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 할 일 초안 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/todo/decision",
    response_model=AgentTodoCreateDecisionResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def decide_personal_todo_create(
    request: AgentTodoCreateDecisionRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 todo 생성 consent 처리"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        stored_request = await FirestoreCache.get_ai_action_request(
            request.user_id,
            request.request_id,
        )
        if stored_request is None:
            raise HTTPException(status_code=404, detail="처리할 요청을 찾을 수 없습니다.")

        decision_result = await FirestoreCache.finalize_personal_todo_action(
            request.user_id,
            request.request_id,
            request.approved,
        )
        result_payload = decision_result.get("result") or {}

        return AgentTodoCreateDecisionResponse(
            request_id=request.request_id,
            audit_id=str(decision_result.get("audit_id") or f"audit_{request.request_id}"),
            consent=AgentToolConsent(
                required=True,
                approved=bool(decision_result.get("approved")),
            ),
            result=AgentTodoCreateResult(**result_payload),
            executed_at=decision_result.get("executed_at") or _utcnow(),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        print(f"Agent todo decision error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 할 일 생성 처리 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/todo/complete/preview",
    response_model=AgentTodoCompletePreviewResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def preview_personal_todo_complete(
    request: AgentTodoCompletePreviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 todo 완료 preview"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        prompt = request.prompt.strip()
        if len(prompt) < 2:
            raise HTTPException(status_code=400, detail="요청 내용을 더 구체적으로 입력해주세요.")
        if _is_explicit_shared_scope_request(prompt, "todo"):
            raise HTTPException(
                status_code=403,
                detail=_personal_scope_denial_message("개인 할 일"),
            )

        pending_todos = await FirestoreCache.get_recent_private_pending_todos(
            request.user_id,
            limit=20,
        )
        if not pending_todos:
            raise HTTPException(
                status_code=404,
                detail="완료할 수 있는 개인 할 일이 없어요.",
            )

        planned = await gemini_service.plan_personal_todo_complete(
            prompt=prompt,
            pending_todos=pending_todos,
            current_time_iso=_utcnow().isoformat(timespec="seconds"),
        )
        if not planned or not str(planned.get("todo_id") or "").strip():
            raise HTTPException(
                status_code=404,
                detail="완료할 개인 할 일을 찾지 못했어요. 제목이나 특징을 더 구체적으로 적어주세요.",
            )

        due_date = planned.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None

        preview_payload = {
            "todo_id": str(planned.get("todo_id") or "").strip(),
            "title": str(planned.get("title") or "").strip(),
            "note": str(planned.get("note") or "").strip() or None,
            "due_date": due_date,
            "formatted_due_date": _format_due_date_label(due_date),
            "visibility": "private",
            "match_reason": str(planned.get("reason") or "").strip() or None,
        }
        if not preview_payload["todo_id"] or not preview_payload["title"]:
            raise HTTPException(
                status_code=404,
                detail="완료할 개인 할 일을 찾지 못했어요.",
            )

        params_hash = _build_todo_complete_params_hash(preview_payload)
        request_id = f"todo_complete_{uuid4().hex[:16]}"
        summary = (
            str(planned.get("summary") or "").strip()
            or f"개인 할 일 '{preview_payload['title']}'을 완료 처리해요."
        )
        generated_at = _utcnow()

        await FirestoreCache.set_ai_action_request(
            request.user_id,
            request_id,
            {
                "tool": "manage_todos",
                "action": "complete",
                "scope": "personal",
                "status": "pending",
                "prompt": prompt,
                "source": (request.source or "").strip() or "home_quick_add_ai",
                "params_hash": params_hash,
                "summary": summary,
                "preview": preview_payload,
                "consent": {
                    "required": True,
                    "approved": None,
                },
                "created_at": generated_at,
                "updated_at": generated_at,
            },
            merge=True,
        )

        return AgentTodoCompletePreviewResponse(
            request_id=request_id,
            params_hash=params_hash,
            summary=summary,
            preview=AgentTodoCompletePreview(**preview_payload),
            consent=AgentToolConsent(required=True, approved=None),
            generated_at=generated_at,
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent todo complete preview error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 할 일 완료 초안 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/todo/complete/decision",
    response_model=AgentTodoCompleteDecisionResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def decide_personal_todo_complete(
    request: AgentTodoCompleteDecisionRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 todo 완료 consent 처리"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        stored_request = await FirestoreCache.get_ai_action_request(
            request.user_id,
            request.request_id,
        )
        if stored_request is None:
            raise HTTPException(status_code=404, detail="처리할 요청을 찾을 수 없습니다.")

        decision_result = await FirestoreCache.finalize_personal_todo_complete_action(
            request.user_id,
            request.request_id,
            request.approved,
        )
        result_payload = decision_result.get("result") or {}

        return AgentTodoCompleteDecisionResponse(
            request_id=request.request_id,
            audit_id=str(decision_result.get("audit_id") or f"audit_{request.request_id}"),
            consent=AgentToolConsent(
                required=True,
                approved=bool(decision_result.get("approved")),
            ),
            result=AgentTodoCompleteResult(**result_payload),
            executed_at=decision_result.get("executed_at") or _utcnow(),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        print(f"Agent todo complete decision error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 할 일 완료 처리 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/calendar/create/preview",
    response_model=AgentCalendarCreatePreviewResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def preview_personal_calendar_create(
    request: AgentCalendarCreatePreviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 일정 생성 preview"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        prompt = request.prompt.strip()
        if len(prompt) < 2:
            raise HTTPException(status_code=400, detail="요청 내용을 더 구체적으로 입력해주세요.")
        if _is_explicit_shared_scope_request(prompt, "calendar"):
            raise HTTPException(
                status_code=403,
                detail=_personal_scope_denial_message("개인 일정"),
            )

        current_group_id = (request.current_group_id or "").strip()
        if current_group_id:
            is_family_member = await FirestoreCache.is_family_member(
                request.user_id,
                current_group_id,
            )
            if not is_family_member:
                raise HTTPException(
                    status_code=403,
                    detail="현재 가족 컨텍스트가 유효하지 않습니다. 그룹을 다시 선택해주세요.",
                )

        planned = await gemini_service.plan_personal_calendar_create(
            prompt=prompt,
            current_time_iso=_utcnow().isoformat(timespec="seconds"),
            selected_date_iso=request.selected_date.isoformat()
            if request.selected_date is not None
            else None,
        )

        title = str(planned.get("title") or "").strip()
        if not title:
            raise HTTPException(status_code=400, detail="일정 초안을 생성할 수 없습니다.")

        due_date = planned.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None
        start_time = planned.get("start_time")
        if start_time is not None and not isinstance(start_time, datetime):
            start_time = None
        end_time = planned.get("end_time")
        if end_time is not None and not isinstance(end_time, datetime):
            end_time = None

        event_type = str(planned.get("event_type") or "schedule").strip().lower()
        if event_type not in {"schedule", "event"}:
            event_type = "schedule"

        has_time = bool(planned.get("has_time")) and start_time is not None
        reminder_minutes = FirestoreCache._normalize_reminder_minutes(
            planned.get("reminder_minutes")
        )

        preview_payload = {
            "title": title,
            "note": str(planned.get("note") or "").strip() or None,
            "event_type": event_type,
            "event_type_label": _calendar_event_type_label(event_type),
            "due_date": due_date,
            "formatted_due_date": _format_due_date_label(due_date),
            "start_time": start_time if has_time else None,
            "end_time": end_time if has_time else None,
            "formatted_time_range": _format_time_range(
                start_time if has_time else None,
                end_time if has_time else None,
            ),
            "has_time": has_time,
            "location": str(planned.get("location") or "").strip() or None,
            "reminder_minutes": reminder_minutes,
            "reminder_labels": [_format_reminder_label(item) for item in reminder_minutes],
            "visibility": "private",
        }
        params_hash = _build_calendar_create_params_hash(preview_payload)
        request_id = f"calendar_create_{uuid4().hex[:16]}"
        summary = (
            str(planned.get("summary") or "").strip()
            or f"개인 일정 '{title}'을 만들어요."
        )
        generated_at = _utcnow()

        await FirestoreCache.set_ai_action_request(
            request.user_id,
            request_id,
            {
                "tool": "manage_calendar",
                "action": "create",
                "scope": "personal",
                "status": "pending",
                "prompt": prompt,
                "source": (request.source or "").strip() or "calendar_ai_fab",
                "current_group_id": (request.current_group_id or "").strip(),
                "selected_date": request.selected_date,
                "params_hash": params_hash,
                "summary": summary,
                "preview": preview_payload,
                "consent": {
                    "required": True,
                    "approved": None,
                },
                "created_at": generated_at,
                "updated_at": generated_at,
            },
            merge=True,
        )

        return AgentCalendarCreatePreviewResponse(
            request_id=request_id,
            params_hash=params_hash,
            summary=summary,
            preview=AgentCalendarCreatePreview(**preview_payload),
            consent=AgentToolConsent(required=True, approved=None),
            generated_at=generated_at,
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent calendar create preview error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 일정 초안 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/calendar/create/decision",
    response_model=AgentCalendarCreateDecisionResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def decide_personal_calendar_create(
    request: AgentCalendarCreateDecisionRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 일정 생성 consent 처리"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        stored_request = await FirestoreCache.get_ai_action_request(
            request.user_id,
            request.request_id,
        )
        if stored_request is None:
            raise HTTPException(status_code=404, detail="처리할 요청을 찾을 수 없습니다.")

        decision_result = await FirestoreCache.finalize_personal_calendar_create_action(
            request.user_id,
            request.request_id,
            request.approved,
        )
        result_payload = decision_result.get("result") or {}

        return AgentCalendarCreateDecisionResponse(
            request_id=request.request_id,
            audit_id=str(decision_result.get("audit_id") or f"audit_{request.request_id}"),
            consent=AgentToolConsent(
                required=True,
                approved=bool(decision_result.get("approved")),
            ),
            result=AgentCalendarCreateResult(**result_payload),
            executed_at=decision_result.get("executed_at") or _utcnow(),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        print(f"Agent calendar create decision error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 일정 생성 처리 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/calendar/update/preview",
    response_model=AgentCalendarUpdatePreviewResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def preview_personal_calendar_update(
    request: AgentCalendarUpdatePreviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 일정 수정 preview"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        prompt = request.prompt.strip()
        if len(prompt) < 2:
            raise HTTPException(status_code=400, detail="요청 내용을 더 구체적으로 입력해주세요.")
        if _is_explicit_shared_scope_request(prompt, "calendar"):
            raise HTTPException(
                status_code=403,
                detail=_personal_scope_denial_message("개인 일정"),
            )

        calendar_items = await FirestoreCache.get_recent_private_calendar_items(
            request.user_id,
            limit=30,
        )
        if not calendar_items:
            raise HTTPException(
                status_code=400,
                detail="수정할 개인 일정 후보가 없습니다.",
            )

        planned = await gemini_service.plan_personal_calendar_update(
            prompt=prompt,
            calendar_items=calendar_items,
            current_time_iso=_utcnow().isoformat(timespec="seconds"),
            selected_date_iso=request.selected_date.isoformat()
            if request.selected_date is not None
            else None,
        )
        if not planned:
            raise HTTPException(
                status_code=400,
                detail="수정할 개인 일정을 찾을 수 없습니다.",
            )

        event_id = str(planned.get("event_id") or "").strip()
        title = str(planned.get("title") or "").strip()
        if not event_id or not title:
            raise HTTPException(
                status_code=400,
                detail="수정할 개인 일정 초안을 생성할 수 없습니다.",
            )

        candidate = next(
            (
                item
                for item in calendar_items
                if str(item.get("id") or "").strip() == event_id
            ),
            None,
        )
        if candidate is None:
            raise HTTPException(
                status_code=400,
                detail="수정할 개인 일정을 찾을 수 없습니다.",
            )

        due_date = planned.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None
        start_time = planned.get("start_time")
        if start_time is not None and not isinstance(start_time, datetime):
            start_time = None
        end_time = planned.get("end_time")
        if end_time is not None and not isinstance(end_time, datetime):
            end_time = None

        event_type = str(
            planned.get("event_type") or candidate.get("event_type") or "schedule"
        ).strip().lower()
        if event_type not in {"schedule", "event"}:
            event_type = "schedule"

        has_time = bool(planned.get("has_time")) and start_time is not None
        reminder_minutes = FirestoreCache._normalize_reminder_minutes(
            planned.get("reminder_minutes")
        )

        original_due_date = candidate.get("due_date")
        if original_due_date is not None and not isinstance(original_due_date, datetime):
            original_due_date = None
        original_start_time = candidate.get("start_time")
        if original_start_time is not None and not isinstance(original_start_time, datetime):
            original_start_time = None
        original_end_time = candidate.get("end_time")
        if original_end_time is not None and not isinstance(original_end_time, datetime):
            original_end_time = None

        preview_payload = {
            "event_id": event_id,
            "original_title": str(candidate.get("title") or "").strip(),
            "original_formatted_due_date": _format_due_date_label(original_due_date),
            "original_formatted_time_range": _format_time_range(
                original_start_time if bool(candidate.get("has_time")) else None,
                original_end_time if bool(candidate.get("has_time")) else None,
            ),
            "title": title,
            "note": str(planned.get("note") or "").strip() or None,
            "event_type": event_type,
            "event_type_label": _calendar_event_type_label(event_type),
            "due_date": due_date,
            "formatted_due_date": _format_due_date_label(due_date),
            "start_time": start_time if has_time else None,
            "end_time": end_time if has_time else None,
            "formatted_time_range": _format_time_range(
                start_time if has_time else None,
                end_time if has_time else None,
            ),
            "has_time": has_time,
            "location": str(planned.get("location") or "").strip() or None,
            "reminder_minutes": reminder_minutes,
            "reminder_labels": [_format_reminder_label(item) for item in reminder_minutes],
            "visibility": "private",
            "match_reason": str(planned.get("reason") or "").strip() or None,
        }

        params_hash = _build_calendar_update_params_hash(preview_payload)
        request_id = f"calendar_update_{uuid4().hex[:16]}"
        summary = (
            str(planned.get("summary") or "").strip()
            or f"개인 일정 '{title}' 수정 초안을 만들었어요."
        )
        generated_at = _utcnow()

        await FirestoreCache.set_ai_action_request(
            request.user_id,
            request_id,
            {
                "tool": "manage_calendar",
                "action": "update",
                "scope": "personal",
                "status": "pending",
                "prompt": prompt,
                "source": (request.source or "").strip() or "calendar_ai_fab",
                "selected_date": request.selected_date,
                "params_hash": params_hash,
                "summary": summary,
                "preview": preview_payload,
                "consent": {
                    "required": True,
                    "approved": None,
                },
                "created_at": generated_at,
                "updated_at": generated_at,
            },
            merge=True,
        )

        return AgentCalendarUpdatePreviewResponse(
            request_id=request_id,
            params_hash=params_hash,
            summary=summary,
            preview=AgentCalendarUpdatePreview(**preview_payload),
            consent=AgentToolConsent(required=True, approved=None),
            generated_at=generated_at,
        )
    except HTTPException:
        raise
    except Exception as exc:
        print(f"Agent calendar update preview error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 일정 수정 초안 생성 중 오류가 발생했습니다.",
        )


@router.post(
    "/actions/calendar/update/decision",
    response_model=AgentCalendarUpdateDecisionResponse,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def decide_personal_calendar_update(
    request: AgentCalendarUpdateDecisionRequest,
    current_user: dict = Depends(get_current_user),
):
    """BABBA 호스트 전용 개인 일정 수정 consent 처리"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        stored_request = await FirestoreCache.get_ai_action_request(
            request.user_id,
            request.request_id,
        )
        if stored_request is None:
            raise HTTPException(status_code=404, detail="처리할 요청을 찾을 수 없습니다.")

        decision_result = await FirestoreCache.finalize_personal_calendar_update_action(
            request.user_id,
            request.request_id,
            request.approved,
        )
        result_payload = decision_result.get("result") or {}

        return AgentCalendarUpdateDecisionResponse(
            request_id=request.request_id,
            audit_id=str(decision_result.get("audit_id") or f"audit_{request.request_id}"),
            consent=AgentToolConsent(
                required=True,
                approved=bool(decision_result.get("approved")),
            ),
            result=AgentCalendarUpdateResult(**result_payload),
            executed_at=decision_result.get("executed_at") or _utcnow(),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        print(f"Agent calendar update decision error: {exc}")
        raise HTTPException(
            status_code=500,
            detail="개인 일정 수정 처리 중 오류가 발생했습니다.",
        )
