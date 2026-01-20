from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime

from models import (
    DailySummaryRequest,
    DailySummaryResponse,
    WeeklySummaryRequest,
    WeeklySummaryResponse,
    ErrorResponse,
)
from services import FirestoreCache, gemini_service
from dependencies import get_current_user

router = APIRouter(prefix="/api/summary", tags=["Summary"])


@router.post(
    "/daily",
    response_model=DailySummaryResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def generate_daily_summary(
    request: DailySummaryRequest,
    current_user: dict = Depends(get_current_user),
):
    """일일 요약 생성"""
    try:
        # 권한 확인: 본인만 조회 가능
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        today = datetime.utcnow().strftime("%Y-%m-%d")

        # 캐시 확인
        cached = await FirestoreCache.get_daily_summary(request.user_id, today)
        if cached:
            return DailySummaryResponse(
                summary=cached["content"],
                cached=True,
                generated_at=cached["created_at"],
            )

        # AI 요약 생성
        summary = await gemini_service.generate_daily_summary(
            user_name=request.user_name,
            pending_todos=request.pending_todos,
            completed_today=request.completed_today,
            upcoming_events=request.upcoming_events,
            monthly_expense=request.monthly_expense,
            monthly_income=request.monthly_income,
        )

        # 캐시 저장
        await FirestoreCache.set_daily_summary(request.user_id, today, summary)

        return DailySummaryResponse(
            summary=summary,
            cached=False,
            generated_at=datetime.utcnow(),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Daily summary error: {e}")
        raise HTTPException(status_code=500, detail="요약 생성 중 오류가 발생했습니다.")


@router.post(
    "/weekly",
    response_model=WeeklySummaryResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def generate_weekly_summary(
    request: WeeklySummaryRequest,
    current_user: dict = Depends(get_current_user),
):
    """주간 요약 생성"""
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 주간 키 생성 (ISO week)
        now = datetime.utcnow()
        week_key = f"{now.year}-W{now.isocalendar()[1]:02d}"

        # 캐시 확인
        cached = await FirestoreCache.get_weekly_summary(request.user_id, week_key)
        if cached:
            return WeeklySummaryResponse(
                summary=cached["content"],
                completion_rate=cached.get("completion_rate", 0.0),
                cached=True,
                generated_at=cached["created_at"],
            )

        # 완료율 계산
        completion_rate = (
            (request.completed_todos / request.total_todos * 100)
            if request.total_todos > 0
            else 0.0
        )

        # AI 요약 생성
        summary = await gemini_service.generate_weekly_summary(
            user_name=request.user_name,
            completed_todos=request.completed_todos,
            total_todos=request.total_todos,
            events_attended=request.events_attended,
            weekly_expense=request.weekly_expense,
        )

        # 캐시 저장
        await FirestoreCache.set_weekly_summary(
            request.user_id, week_key, summary, completion_rate
        )

        return WeeklySummaryResponse(
            summary=summary,
            completion_rate=completion_rate,
            cached=False,
            generated_at=datetime.utcnow(),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Weekly summary error: {e}")
        raise HTTPException(status_code=500, detail="요약 생성 중 오류가 발생했습니다.")
