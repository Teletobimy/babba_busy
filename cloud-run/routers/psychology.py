from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
import uuid
from typing import Optional

from models import (
    PsychologyStartResponse,
    PsychologyAnswerResponse,
    PsychologyResultResponse,
    PsychologyQuestion,
    ErrorResponse,
)
from services import FirestoreCache
from agents.psychology_agents import PsychologyPMAgent, TestType, PSYCHOLOGY_TESTS
from dependencies import get_current_user

router = APIRouter(prefix="/api/psychology", tags=["Psychology"])

# PM 에이전트 싱글톤
psychology_pm = PsychologyPMAgent()


# ============ 검사 목록 ============

@router.get("/tests")
async def get_available_tests():
    """사용 가능한 모든 심리검사 목록"""
    return {
        "tests": psychology_pm.get_all_tests(),
    }


@router.get("/tests/{test_type}")
async def get_test_info(test_type: str):
    """특정 검사 정보 조회"""
    try:
        t_type = TestType(test_type)
        info = psychology_pm.get_test_info(t_type)
        if not info:
            raise HTTPException(status_code=404, detail="검사를 찾을 수 없습니다.")
        return info
    except ValueError:
        raise HTTPException(status_code=400, detail="잘못된 검사 유형입니다.")


# ============ 검사 시작 ============

@router.post("/start")
async def start_psychology_test(
    user_id: str,
    test_type: str,
    current_user: dict = Depends(get_current_user),
):
    """심리검사 시작"""
    try:
        # 권한 확인
        if current_user["uid"] != user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 검사 유형 확인
        try:
            t_type = TestType(test_type)
        except ValueError:
            raise HTTPException(status_code=400, detail="지원하지 않는 검사 유형입니다.")

        test = PSYCHOLOGY_TESTS.get(t_type)
        if not test:
            raise HTTPException(status_code=400, detail="검사 데이터를 찾을 수 없습니다.")

        # 세션 생성
        session_id = str(uuid.uuid4())
        questions = psychology_pm.get_questions(t_type)

        session = {
            "id": session_id,
            "test_type": test_type,
            "answers": [],
            "current_index": 0,
            "total_questions": len(questions),
            "started_at": datetime.utcnow(),
        }

        await FirestoreCache.set_psychology_session(user_id, session_id, session)

        # 첫 번째 질문
        first_q = questions[0]

        return {
            "success": True,
            "session_id": session_id,
            "test_type": test_type,
            "test_name": test["name"],
            "total_questions": len(questions),
            "first_question": {
                "question_id": first_q["id"],
                "question": first_q["text"],
                "options": first_q["options"],
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Psychology start error: {e}")
        raise HTTPException(status_code=500, detail="검사 시작 중 오류가 발생했습니다.")


# ============ 답변 제출 ============

@router.post("/answer")
async def submit_psychology_answer(
    user_id: str,
    session_id: str,
    question_id: str,
    answer_index: int,
    current_user: dict = Depends(get_current_user),
):
    """심리검사 답변 제출"""
    try:
        # 권한 확인
        if current_user["uid"] != user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 세션 조회
        session = await FirestoreCache.get_psychology_session(user_id, session_id)
        if not session:
            raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다.")

        test_type = TestType(session["test_type"])
        questions = psychology_pm.get_questions(test_type)

        # 답변 저장
        answers = session.get("answers", [])
        answers.append({
            "question_id": question_id,
            "answer_index": answer_index,
        })
        session["answers"] = answers

        # 다음 질문 인덱스
        next_index = len(answers)
        session["current_index"] = next_index

        # 진행률
        progress = next_index / session["total_questions"]

        # 완료 여부
        is_complete = next_index >= session["total_questions"]

        # 세션 업데이트
        await FirestoreCache.set_psychology_session(user_id, session_id, session)

        # 다음 질문 또는 완료
        next_question = None
        if not is_complete and next_index < len(questions):
            next_q = questions[next_index]
            next_question = {
                "question_id": next_q["id"],
                "question": next_q["text"],
                "options": next_q["options"],
            }

        return {
            "success": True,
            "session_id": session_id,
            "progress": progress,
            "answered": next_index,
            "total": session["total_questions"],
            "next_question": next_question,
            "is_complete": is_complete,
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Psychology answer error: {e}")
        raise HTTPException(status_code=500, detail="답변 처리 중 오류가 발생했습니다.")


# ============ 결과 조회 ============

@router.get("/result/{session_id}")
async def get_psychology_result(
    session_id: str,
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    """심리검사 결과 조회 (AI 분석 포함)"""
    try:
        # 권한 확인
        if current_user["uid"] != user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 세션 조회
        session = await FirestoreCache.get_psychology_session(user_id, session_id)
        if not session:
            raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다.")

        # 완료 확인
        if len(session.get("answers", [])) < session.get("total_questions", 0):
            raise HTTPException(status_code=400, detail="검사가 완료되지 않았습니다.")

        # 이미 결과가 있으면 반환
        if session.get("analysis_result"):
            return {
                "success": True,
                "session_id": session_id,
                "test_type": session["test_type"],
                "scores": session.get("scores", {}),
                "analysis": session["analysis_result"],
                "completed_at": session.get("completed_at"),
            }

        # 점수 계산
        test_type = TestType(session["test_type"])
        answers = session.get("answers", [])
        scores = psychology_pm.calculate_scores(test_type, answers)

        # AI 분석
        analysis = await psychology_pm.analyze(test_type, scores)

        # 세션에 결과 저장
        session["scores"] = scores
        session["analysis_result"] = analysis
        session["completed_at"] = datetime.utcnow()

        await FirestoreCache.set_psychology_session(user_id, session_id, session)

        return {
            "success": True,
            "session_id": session_id,
            "test_type": session["test_type"],
            "scores": scores,
            "analysis": analysis,
            "completed_at": session["completed_at"],
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Psychology result error: {e}")
        raise HTTPException(status_code=500, detail="결과 조회 중 오류가 발생했습니다.")


# ============ 히스토리 ============

@router.get("/history")
async def get_test_history(
    user_id: str,
    limit: int = 10,
    current_user: dict = Depends(get_current_user),
):
    """사용자의 검사 히스토리 조회"""
    if current_user["uid"] != user_id:
        raise HTTPException(status_code=403, detail="권한이 없습니다.")

    # TODO: Firestore에서 히스토리 조회 구현
    # 현재는 빈 배열 반환
    return {
        "history": [],
        "total": 0,
    }


# ============ 종합 리포트 ============

@router.post("/comprehensive-report")
async def generate_comprehensive_report(
    user_id: str,
    session_ids: list[str],
    current_user: dict = Depends(get_current_user),
):
    """여러 검사 결과를 종합한 리포트 생성"""
    try:
        if current_user["uid"] != user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 각 세션의 결과 수집
        results = []
        for sid in session_ids:
            session = await FirestoreCache.get_psychology_session(user_id, sid)
            if session and session.get("analysis_result"):
                results.append({
                    "test_type": session["test_type"],
                    "scores": session.get("scores", {}),
                    "analysis": session["analysis_result"],
                })

        if not results:
            raise HTTPException(status_code=400, detail="분석할 결과가 없습니다.")

        # 종합 리포트 생성
        report = await psychology_pm.generate_comprehensive_report(results)

        return {
            "success": True,
            "comprehensive_report": report,
            "included_tests": [r["test_type"] for r in results],
            "generated_at": datetime.utcnow(),
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Comprehensive report error: {e}")
        raise HTTPException(status_code=500, detail="종합 리포트 생성 중 오류가 발생했습니다.")
