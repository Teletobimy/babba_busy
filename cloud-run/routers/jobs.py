from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from datetime import datetime
import uuid

from models import (
    SubmitBusinessAnalysisRequest,
    SubmitBusinessAnalysisResponse,
    SubmitPsychologyAnalysisRequest,
    SubmitPsychologyAnalysisResponse,
    SubmitMemoCategoryAnalysisRequest,
    SubmitMemoCategoryAnalysisResponse,
    AnalysisJobResponse,
    AnalysisJobProgress,
    AnalysisJobStatus,
    AnalysisJobType,
    CancelJobResponse,
    ErrorResponse,
)
from services import FirestoreCache
from agents import BusinessPMAgent, MemoCategoryPMAgent
from agents.psychology_agents import PsychologyPMAgent, TestType
from dependencies import get_current_user
from time_utils import utcnow_naive as _utcnow

router = APIRouter(prefix="/api/jobs", tags=["Analysis Jobs"])

# PM 에이전트 싱글톤
business_pm = BusinessPMAgent()
psychology_pm = PsychologyPMAgent()
memo_category_pm = MemoCategoryPMAgent()

# 사용자당 동시 진행 가능한 작업 수 제한
MAX_CONCURRENT_JOBS = 1


def _build_job_data(
    user_id: str,
    job_type: AnalysisJobType,
    input_data: dict,
) -> dict:
    """작업 데이터 구조 생성"""
    now = _utcnow()
    return {
        "userId": user_id,
        "jobType": job_type.value,
        "status": AnalysisJobStatus.PENDING.value,
        "priority": 5,
        "input": input_data,
        "progress": {
            "currentStep": 0,
            "totalSteps": 5,
            "percentage": 0.0,
        },
        "resultId": None,
        "error": None,
        "retryCount": 0,
        "maxRetries": 3,
        "createdAt": now,
        "startedAt": None,
        "completedAt": None,
        "updatedAt": now,
        "notificationSent": False,
    }


async def _create_analysis_job_atomic(
    user_id: str,
    job_type: AnalysisJobType,
    input_data: dict,
) -> tuple[str | None, str]:
    """분석 작업을 트랜잭션으로 생성 (Race Condition 방지)

    Returns:
        (job_id, message): 성공 시 job_id, 실패 시 None과 에러 메시지
    """
    job_id = str(uuid.uuid4())
    job_data = _build_job_data(user_id, job_type, input_data)

    success, message = await FirestoreCache.create_analysis_job_atomic(
        user_id=user_id,
        job_id=job_id,
        data=job_data,
        max_concurrent=MAX_CONCURRENT_JOBS,
    )

    if success:
        return job_id, "success"
    return None, message


async def _process_business_analysis(job_id: str, user_id: str, input_data: dict):
    """백그라운드에서 사업 분석 수행"""
    try:
        # 상태를 processing으로 변경
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.PROCESSING.value,
            "startedAt": _utcnow(),
            "updatedAt": _utcnow(),
        })

        step_names = [
            "market_research",
            "competitor_analysis",
            "product_planning",
            "financial_analysis",
            "final_report",
        ]

        async def on_progress(step: str, status: str):
            """진행 상황 업데이트 콜백"""
            if status == "started":
                step_index = step_names.index(step) if step in step_names else 0
                await FirestoreCache.update_analysis_job(job_id, {
                    "progress": {
                        "currentStep": step_index + 1,
                        "totalSteps": 5,
                        "percentage": (step_index / 5) * 100,
                        "currentStepName": step,
                    },
                    "updatedAt": _utcnow(),
                })
            elif status == "completed":
                step_index = step_names.index(step) if step in step_names else 0
                await FirestoreCache.update_analysis_job(job_id, {
                    "progress": {
                        "currentStep": step_index + 1,
                        "totalSteps": 5,
                        "percentage": ((step_index + 1) / 5) * 100,
                        "currentStepName": step,
                    },
                    "updatedAt": _utcnow(),
                })

        # PM 에이전트 실행
        result = await business_pm.run(
            idea=input_data.get("businessIdea", input_data.get("idea", "")),
            industry=input_data.get("industry"),
            target_market=input_data.get("targetMarket", input_data.get("target_market")),
            budget=input_data.get("budget"),
            on_progress=on_progress,
        )

        report = result.get("report", {})
        swot = report.get("swot", {})
        analysis = result.get("analysis", {})

        # next_steps 파싱
        next_steps_raw = report.get("next_steps", [])
        next_steps = []
        for item in next_steps_raw:
            if isinstance(item, dict):
                action = item.get("action", "")
                if action:
                    next_steps.append(action)
            elif isinstance(item, str):
                next_steps.append(item)

        # 시장 조사 데이터 추출
        market_analysis = analysis.get("market_analysis", {})
        competitor_analysis = analysis.get("competitor_analysis", {})

        # 경쟁사 이름 목록 추출
        direct_competitors = competitor_analysis.get("direct_competitors", [])
        competitor_names = []
        for comp in direct_competitors:
            if isinstance(comp, dict) and comp.get("name"):
                competitor_names.append(comp["name"])
            elif isinstance(comp, str):
                competitor_names.append(comp)

        market_research = {
            "targetMarket": market_analysis.get("market_opportunity"),
            "marketSize": market_analysis.get("market_size"),
            "competitors": competitor_names[:5],  # 최대 5개
            "trends": market_analysis.get("trends", [])[:5],  # 최대 5개
            "customerSegment": ", ".join(market_analysis.get("target_customers", [])[:3]),
            "entryBarrier": ", ".join(competitor_analysis.get("entry_barriers", [])[:2]),
        }

        # 결과를 business_reviews 컬렉션에 저장
        review_data = {
            "userId": user_id,
            "businessIdea": input_data.get("businessIdea", input_data.get("idea", "")),
            "industry": input_data.get("industry"),
            "budget": input_data.get("budget"),
            "score": report.get("overall_score", 50),
            "summary": report.get("executive_summary", ""),
            "strengths": swot.get("strengths", []),
            "weaknesses": swot.get("weaknesses", []),
            "opportunities": swot.get("opportunities", []),
            "threats": swot.get("threats", []),
            "nextSteps": next_steps,
            "marketResearch": market_research,
            "createdAt": _utcnow(),
            "status": "completed",
            "jobId": job_id,
        }

        review_id = await FirestoreCache.save_business_review(user_id, review_data)

        # 작업 완료 상태로 업데이트
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.COMPLETED.value,
            "resultId": review_id,
            "progress": {
                "currentStep": 5,
                "totalSteps": 5,
                "percentage": 100.0,
                "currentStepName": "completed",
            },
            "completedAt": _utcnow(),
            "updatedAt": _utcnow(),
        })

        print(f"Business analysis completed for job {job_id}")

    except Exception as e:
        print(f"Business analysis failed for job {job_id}: {e}")

        # 에러 상태로 업데이트
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.FAILED.value,
            "error": {
                "code": "analysis_failed",
                "message": str(e),
                "retryable": True,
            },
            "updatedAt": _utcnow(),
        })


@router.post(
    "/business/submit",
    response_model=SubmitBusinessAnalysisResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def submit_business_analysis(
    request: SubmitBusinessAnalysisRequest,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    """사업 아이디어 분석 요청 (비동기)

    요청을 접수하고 즉시 job_id를 반환합니다.
    분석은 백그라운드에서 수행되며, 완료 시 푸시 알림이 전송됩니다.
    """
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 입력 데이터 준비
        input_data = {
            "businessIdea": request.idea,
            "industry": request.industry,
            "targetMarket": request.target_market,
            "budget": request.budget,
        }

        # 트랜잭션으로 동시 작업 수 확인 + 작업 생성 (Race Condition 방지)
        job_id, message = await _create_analysis_job_atomic(
            user_id=request.user_id,
            job_type=AnalysisJobType.BUSINESS_REVIEW,
            input_data=input_data,
        )

        if job_id is None:
            raise HTTPException(
                status_code=400,
                detail=f"{message} 완료 후 다시 시도해주세요."
            )

        # 백그라운드에서 분석 시작
        background_tasks.add_task(
            _process_business_analysis,
            job_id,
            request.user_id,
            input_data,
        )

        return SubmitBusinessAnalysisResponse(
            job_id=job_id,
            status=AnalysisJobStatus.PENDING,
            estimated_time_seconds=120,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Submit business analysis error: {e}")
        raise HTTPException(status_code=500, detail="분석 요청 중 오류가 발생했습니다.")


@router.get(
    "/{job_id}",
    response_model=AnalysisJobResponse,
    responses={404: {"model": ErrorResponse}},
)
async def get_job_status(
    job_id: str,
    current_user: dict = Depends(get_current_user),
):
    """분석 작업 상태 조회"""
    try:
        job = await FirestoreCache.get_analysis_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="작업을 찾을 수 없습니다.")

        # 권한 확인
        if job.get("userId") != current_user["uid"]:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        progress_data = job.get("progress", {})

        return AnalysisJobResponse(
            job_id=job_id,
            user_id=job.get("userId", ""),
            job_type=AnalysisJobType(job.get("jobType", "business_review")),
            status=AnalysisJobStatus(job.get("status", "pending")),
            progress=AnalysisJobProgress(
                current_step=progress_data.get("currentStep", 0),
                total_steps=progress_data.get("totalSteps", 5),
                percentage=progress_data.get("percentage", 0.0),
                current_step_name=progress_data.get("currentStepName"),
            ),
            result_id=job.get("resultId"),
            error=job.get("error"),
            created_at=job.get("createdAt", _utcnow()),
            started_at=job.get("startedAt"),
            completed_at=job.get("completedAt"),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Get job status error: {e}")
        raise HTTPException(status_code=500, detail="작업 상태 조회 중 오류가 발생했습니다.")


@router.post(
    "/{job_id}/cancel",
    response_model=CancelJobResponse,
    responses={400: {"model": ErrorResponse}, 404: {"model": ErrorResponse}},
)
async def cancel_job(
    job_id: str,
    current_user: dict = Depends(get_current_user),
):
    """분석 작업 취소"""
    try:
        job = await FirestoreCache.get_analysis_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="작업을 찾을 수 없습니다.")

        # 권한 확인
        if job.get("userId") != current_user["uid"]:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 이미 완료되었거나 실패한 작업은 취소 불가
        status = job.get("status")
        if status in [AnalysisJobStatus.COMPLETED.value, AnalysisJobStatus.FAILED.value]:
            raise HTTPException(status_code=400, detail="이미 완료된 작업은 취소할 수 없습니다.")

        # 취소 상태로 업데이트
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.CANCELLED.value,
            "updatedAt": _utcnow(),
        })

        return CancelJobResponse(
            job_id=job_id,
            message="작업이 취소되었습니다.",
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Cancel job error: {e}")
        raise HTTPException(status_code=500, detail="작업 취소 중 오류가 발생했습니다.")


@router.get(
    "/user/pending",
    response_model=list[AnalysisJobResponse],
)
async def get_user_pending_jobs(
    current_user: dict = Depends(get_current_user),
):
    """사용자의 진행 중인 작업 목록 조회"""
    try:
        jobs = await FirestoreCache.get_user_pending_jobs(current_user["uid"])

        result = []
        for job in jobs:
            progress_data = job.get("progress", {})
            result.append(AnalysisJobResponse(
                job_id=job.get("id", ""),
                user_id=job.get("userId", ""),
                job_type=AnalysisJobType(job.get("jobType", "business_review")),
                status=AnalysisJobStatus(job.get("status", "pending")),
                progress=AnalysisJobProgress(
                    current_step=progress_data.get("currentStep", 0),
                    total_steps=progress_data.get("totalSteps", 5),
                    percentage=progress_data.get("percentage", 0.0),
                    current_step_name=progress_data.get("currentStepName"),
                ),
                result_id=job.get("resultId"),
                error=job.get("error"),
                created_at=job.get("createdAt", _utcnow()),
                started_at=job.get("startedAt"),
                completed_at=job.get("completedAt"),
            ))

        return result

    except Exception as e:
        print(f"Get user pending jobs error: {e}")
        raise HTTPException(status_code=500, detail="작업 목록 조회 중 오류가 발생했습니다.")


async def _process_psychology_analysis(job_id: str, user_id: str, input_data: dict):
    """백그라운드에서 심리검사 분석 수행"""
    try:
        # 상태를 processing으로 변경
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.PROCESSING.value,
            "startedAt": _utcnow(),
            "updatedAt": _utcnow(),
        })

        session_id = input_data.get("sessionId", "")
        test_type_str = input_data.get("testType", "big5")

        # 세션 조회
        session = await FirestoreCache.get_psychology_session(user_id, session_id)
        if not session:
            raise Exception("세션을 찾을 수 없습니다.")

        test_type = TestType(test_type_str)
        answers = session.get("answers", [])
        scores = psychology_pm.calculate_scores(test_type, answers)

        step_names = [
            "score_calculation",
            "pattern_analysis",
            "strength_analysis",
            "growth_analysis",
            "final_report",
        ]

        async def on_progress(step: str, status: str):
            """진행 상황 업데이트 콜백"""
            if status == "started":
                step_index = step_names.index(step) if step in step_names else 0
                await FirestoreCache.update_analysis_job(job_id, {
                    "progress": {
                        "currentStep": step_index + 1,
                        "totalSteps": 5,
                        "percentage": (step_index / 5) * 100,
                        "currentStepName": step,
                    },
                    "updatedAt": _utcnow(),
                })
            elif status == "completed":
                step_index = step_names.index(step) if step in step_names else 0
                await FirestoreCache.update_analysis_job(job_id, {
                    "progress": {
                        "currentStep": step_index + 1,
                        "totalSteps": 5,
                        "percentage": ((step_index + 1) / 5) * 100,
                        "currentStepName": step,
                    },
                    "updatedAt": _utcnow(),
                })

        # PM 에이전트 실행
        result = await psychology_pm.run(
            test_type=test_type,
            scores=scores,
            on_progress=on_progress,
        )

        # 세션에 결과 저장
        session["scores"] = scores
        session["analysis_result"] = result["final_report"]
        session["agent_reports"] = result.get("agent_reports", {})
        session["completed_at"] = _utcnow()
        session["status"] = "completed"
        session["jobId"] = job_id

        await FirestoreCache.set_psychology_session(user_id, session_id, session)

        # psychology_results 컬렉션에 결과 저장 (히스토리 화면 동기화)
        final_report = result.get("final_report", {})
        answer_indexes = []
        for item in answers:
            if isinstance(item, dict):
                index = item.get("answer_index")
                if isinstance(index, int):
                    answer_indexes.append(index)
            elif isinstance(item, int):
                answer_indexes.append(item)

        result_payload = {}
        if isinstance(final_report, dict):
            nested_result = final_report.get("result")
            if isinstance(nested_result, dict):
                result_payload.update(nested_result)

            summary = final_report.get("summary")
            if summary is not None:
                result_payload["summary"] = summary

            recommendations = final_report.get("recommendations")
            if isinstance(recommendations, list):
                result_payload["recommendations"] = recommendations
        else:
            result_payload["summary"] = str(final_report)

        await FirestoreCache.save_psychology_result(
            user_id,
            {
                "userId": user_id,
                "testType": test_type_str,
                "answers": answer_indexes,
                "result": result_payload,
                "completedAt": _utcnow(),
                "isShared": False,
                "jobId": job_id,
                "sessionId": session_id,
            },
            result_id=session_id,
        )

        # 작업 완료 상태로 업데이트
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.COMPLETED.value,
            "resultId": session_id,
            "progress": {
                "currentStep": 5,
                "totalSteps": 5,
                "percentage": 100.0,
                "currentStepName": "completed",
            },
            "completedAt": _utcnow(),
            "updatedAt": _utcnow(),
        })

        print(f"Psychology analysis completed for job {job_id}")

    except Exception as e:
        print(f"Psychology analysis failed for job {job_id}: {e}")

        # 에러 상태로 업데이트
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.FAILED.value,
            "error": {
                "code": "analysis_failed",
                "message": str(e),
                "retryable": True,
            },
            "updatedAt": _utcnow(),
        })


@router.post(
    "/psychology/submit",
    response_model=SubmitPsychologyAnalysisResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def submit_psychology_analysis(
    request: SubmitPsychologyAnalysisRequest,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    """심리검사 분석 요청 (비동기)

    검사 완료 후 분석을 백그라운드에서 수행합니다.
    완료 시 푸시 알림이 전송됩니다.
    """
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 세션 확인
        session = await FirestoreCache.get_psychology_session(request.user_id, request.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다.")

        # 검사 완료 확인
        if len(session.get("answers", [])) < session.get("total_questions", 0):
            raise HTTPException(status_code=400, detail="검사가 완료되지 않았습니다.")

        # 입력 데이터 준비
        input_data = {
            "sessionId": request.session_id,
            "testType": request.test_type,
        }

        # 트랜잭션으로 동시 작업 수 확인 + 작업 생성
        job_id, message = await _create_analysis_job_atomic(
            user_id=request.user_id,
            job_type=AnalysisJobType.PSYCHOLOGY_TEST,
            input_data=input_data,
        )

        if job_id is None:
            raise HTTPException(
                status_code=400,
                detail=f"{message} 완료 후 다시 시도해주세요."
            )

        # 백그라운드에서 분석 시작
        background_tasks.add_task(
            _process_psychology_analysis,
            job_id,
            request.user_id,
            input_data,
        )

        return SubmitPsychologyAnalysisResponse(
            job_id=job_id,
            status=AnalysisJobStatus.PENDING,
            estimated_time_seconds=60,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Submit psychology analysis error: {e}")
        raise HTTPException(status_code=500, detail="분석 요청 중 오류가 발생했습니다.")


async def _process_memo_category_analysis(job_id: str, user_id: str, input_data: dict):
    """백그라운드에서 메모 카테고리 분석 수행"""
    try:
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.PROCESSING.value,
            "startedAt": _utcnow(),
            "updatedAt": _utcnow(),
        })

        category_id = str(input_data.get("categoryId", "")).strip() or None
        category_name = str(input_data.get("categoryName", "")).strip()
        max_memos_raw = input_data.get("maxMemos", 120)
        try:
            max_memos = int(max_memos_raw)
        except Exception:
            max_memos = 120
        max_memos = max(10, min(max_memos, 400))

        focus_raw = input_data.get("focus", [])
        focus: list[str] = []
        if isinstance(focus_raw, list):
            for item in focus_raw:
                value = str(item).strip()
                if value and value not in focus:
                    focus.append(value)
                    if len(focus) >= 8:
                        break

        memos = await FirestoreCache.get_user_memos(
            user_id=user_id,
            category_id=category_id,
            category_name=category_name or None,
            limit=max_memos,
        )

        if not memos:
            raise Exception("분석할 메모가 없습니다.")

        resolved_category_name = category_name
        if not resolved_category_name:
            for memo in memos:
                value = str(memo.get("categoryName", "")).strip()
                if value:
                    resolved_category_name = value
                    break

        if not resolved_category_name:
            resolved_category_name = "전체 메모"

        step_names = [
            "planning",
            "context_compaction",
            "synthesis",
            "quality_validation",
            "finalization",
        ]

        async def on_progress(step: str, status: str):
            if status == "started":
                step_index = step_names.index(step) if step in step_names else 0
                await FirestoreCache.update_analysis_job(job_id, {
                    "progress": {
                        "currentStep": step_index + 1,
                        "totalSteps": 5,
                        "percentage": (step_index / 5) * 100,
                        "currentStepName": step,
                    },
                    "updatedAt": _utcnow(),
                })
            elif status == "completed":
                step_index = step_names.index(step) if step in step_names else 0
                await FirestoreCache.update_analysis_job(job_id, {
                    "progress": {
                        "currentStep": step_index + 1,
                        "totalSteps": 5,
                        "percentage": ((step_index + 1) / 5) * 100,
                        "currentStepName": step,
                    },
                    "updatedAt": _utcnow(),
                })

        result = await memo_category_pm.run(
            category_name=resolved_category_name,
            memos=memos,
            requested_focus=focus,
            on_progress=on_progress,
        )

        now = _utcnow()
        analysis_data = {
            "userId": user_id,
            "jobId": job_id,
            "categoryId": category_id,
            "categoryName": resolved_category_name,
            "memoCount": len(memos),
            "focus": focus,
            "result": result,
            "status": "completed",
            "createdAt": now,
            "completedAt": now,
        }

        analysis_id = await FirestoreCache.save_memo_category_analysis(
            user_id=user_id,
            analysis_data=analysis_data,
        )

        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.COMPLETED.value,
            "resultId": analysis_id,
            "progress": {
                "currentStep": 5,
                "totalSteps": 5,
                "percentage": 100.0,
                "currentStepName": "completed",
            },
            "completedAt": now,
            "updatedAt": now,
        })

        print(f"Memo category analysis completed for job {job_id}")

    except Exception as e:
        print(f"Memo category analysis failed for job {job_id}: {e}")
        await FirestoreCache.update_analysis_job(job_id, {
            "status": AnalysisJobStatus.FAILED.value,
            "error": {
                "code": "analysis_failed",
                "message": str(e),
                "retryable": True,
            },
            "updatedAt": _utcnow(),
        })


@router.post(
    "/memo/category/submit",
    response_model=SubmitMemoCategoryAnalysisResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def submit_memo_category_analysis(
    request: SubmitMemoCategoryAnalysisRequest,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    """메모 카테고리 분석 요청 (비동기)"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        category_id = request.category_id.strip() if request.category_id else None
        category_name = request.category_name.strip() if request.category_name else None

        focus: list[str] = []
        for item in request.focus:
            value = str(item).strip()
            if value and value not in focus:
                focus.append(value)
            if len(focus) >= 8:
                break

        input_data = {
            "categoryId": category_id,
            "categoryName": category_name,
            "focus": focus,
            "maxMemos": request.max_memos,
        }

        job_id, message = await _create_analysis_job_atomic(
            user_id=request.user_id,
            job_type=AnalysisJobType.MEMO_CATEGORY_ANALYSIS,
            input_data=input_data,
        )

        if job_id is None:
            raise HTTPException(
                status_code=400,
                detail=f"{message} 완료 후 다시 시도해주세요.",
            )

        background_tasks.add_task(
            _process_memo_category_analysis,
            job_id,
            request.user_id,
            input_data,
        )

        estimated = max(45, min(240, int(request.max_memos * 0.8)))

        return SubmitMemoCategoryAnalysisResponse(
            job_id=job_id,
            status=AnalysisJobStatus.PENDING,
            estimated_time_seconds=estimated,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Submit memo category analysis error: {e}")
        raise HTTPException(status_code=500, detail="분석 요청 중 오류가 발생했습니다.")
