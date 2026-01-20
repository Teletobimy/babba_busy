from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from fastapi.responses import StreamingResponse
from datetime import datetime
import uuid
import json
import asyncio

from models import (
    BusinessAnalyzeRequest,
    BusinessAnalyzeResponse,
    BusinessChatRequest,
    BusinessChatResponse,
    ErrorResponse,
)
from services import FirestoreCache
from agents import BusinessPMAgent
from dependencies import get_current_user

router = APIRouter(prefix="/api/business", tags=["Business"])

# PM 에이전트 싱글톤
business_pm = BusinessPMAgent()


@router.post(
    "/analyze",
    response_model=BusinessAnalyzeResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def analyze_business_idea(
    request: BusinessAnalyzeRequest,
    current_user: dict = Depends(get_current_user),
):
    """사업 아이디어 종합 분석 (멀티 에이전트)"""
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # PM 에이전트 실행
        result = await business_pm.run(
            idea=request.idea,
            industry=request.industry,
            target_market=request.target_market,
            budget=request.budget,
        )

        report = result.get("report", {})

        return BusinessAnalyzeResponse(
            analysis=result.get("analysis", {}),
            summary=report.get("executive_summary", ""),
            score=report.get("overall_score", 0),
            generated_at=datetime.utcnow(),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Business analyze error: {e}")
        raise HTTPException(status_code=500, detail="분석 중 오류가 발생했습니다.")


@router.post("/analyze/stream")
async def analyze_business_idea_stream(
    request: BusinessAnalyzeRequest,
    current_user: dict = Depends(get_current_user),
):
    """사업 아이디어 분석 (스트리밍 - 진행 상황 실시간 전송)"""

    if current_user["uid"] != request.user_id:
        raise HTTPException(status_code=403, detail="권한이 없습니다.")

    async def generate():
        progress_queue = asyncio.Queue()

        async def on_progress(step: str, status: str):
            await progress_queue.put({"step": step, "status": status})

        # 분석 태스크 시작
        task = asyncio.create_task(
            business_pm.run(
                idea=request.idea,
                industry=request.industry,
                target_market=request.target_market,
                budget=request.budget,
                on_progress=on_progress,
            )
        )

        # 진행 상황 스트리밍
        steps_completed = set()
        total_steps = {"market_research", "competitor_analysis", "product_planning", "financial_analysis", "final_report"}

        while not task.done() or not progress_queue.empty():
            try:
                progress = await asyncio.wait_for(progress_queue.get(), timeout=0.5)
                if progress["status"] == "completed":
                    steps_completed.add(progress["step"])

                yield f"data: {json.dumps(progress)}\n\n"
            except asyncio.TimeoutError:
                continue

        # 최종 결과
        result = await task
        yield f"data: {json.dumps({'type': 'result', 'data': result})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")


@router.post(
    "/chat",
    response_model=BusinessChatResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def chat_business(
    request: BusinessChatRequest,
    current_user: dict = Depends(get_current_user),
):
    """사업 검토 대화 (이전 분석 결과 컨텍스트 활용)"""
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
                "context": None,
                "created_at": datetime.utcnow(),
            }

        # 대화 히스토리
        history = session.get("history", [])
        context = session.get("context")

        # PM 에이전트로 대화
        reply = await business_pm.chat(history, request.message, context)

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


@router.post("/session/{session_id}/set-context")
async def set_session_context(
    session_id: str,
    context: dict,
    current_user: dict = Depends(get_current_user),
):
    """세션에 분석 결과 컨텍스트 설정 (대화 시 활용)"""
    user_id = current_user["uid"]

    session = await FirestoreCache.get_business_session(user_id, session_id)
    if not session:
        session = {"id": session_id, "history": [], "turn": 0}

    session["context"] = context
    await FirestoreCache.set_business_session(user_id, session_id, session)

    return {"success": True, "session_id": session_id}
