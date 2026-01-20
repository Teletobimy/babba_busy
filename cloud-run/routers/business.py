from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
import uuid

from models import (
    BusinessAnalyzeRequest,
    BusinessAnalyzeResponse,
    BusinessChatRequest,
    BusinessChatResponse,
    ErrorResponse,
)
from services import FirestoreCache, gemini_service
from dependencies import get_current_user

router = APIRouter(prefix="/api/business", tags=["Business"])


@router.post(
    "/analyze",
    response_model=BusinessAnalyzeResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def analyze_business_idea(
    request: BusinessAnalyzeRequest,
    current_user: dict = Depends(get_current_user),
):
    """사업 아이디어 분석"""
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # AI 분석
        analysis = await gemini_service.analyze_business_idea(
            idea=request.idea,
            industry=request.industry,
            target_market=request.target_market,
            budget=request.budget,
        )

        return BusinessAnalyzeResponse(
            analysis=analysis,
            summary=analysis.get("recommendation", ""),
            score=analysis.get("score", 0),
            generated_at=datetime.utcnow(),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Business analyze error: {e}")
        raise HTTPException(status_code=500, detail="분석 중 오류가 발생했습니다.")


@router.post(
    "/chat",
    response_model=BusinessChatResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def chat_business(
    request: BusinessChatRequest,
    current_user: dict = Depends(get_current_user),
):
    """사업 검토 대화"""
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 세션 조회 또는 생성
        session = await FirestoreCache.get_business_session(
            request.user_id, request.session_id
        )

        if not session:
            session = {
                "id": request.session_id,
                "history": [],
                "turn": 0,
                "created_at": datetime.utcnow(),
            }

        # 대화 히스토리
        history = session.get("history", [])

        # AI 응답 생성
        reply = await gemini_service.chat_business(history, request.message)

        # 히스토리 업데이트
        history.append({"role": "user", "content": request.message})
        history.append({"role": "model", "content": reply})

        # 세션 저장
        session["history"] = history
        session["turn"] = len(history) // 2

        await FirestoreCache.set_business_session(
            request.user_id, request.session_id, session
        )

        return BusinessChatResponse(
            reply=reply,
            session_id=request.session_id,
            turn=session["turn"],
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Business chat error: {e}")
        raise HTTPException(status_code=500, detail="대화 중 오류가 발생했습니다.")


@router.post("/session/new")
async def create_business_session(
    current_user: dict = Depends(get_current_user),
):
    """새 사업 검토 세션 생성"""
    session_id = str(uuid.uuid4())
    return {"session_id": session_id}
