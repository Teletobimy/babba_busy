from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
import uuid

from models import (
    PsychologyStartRequest,
    PsychologyStartResponse,
    PsychologyAnswerRequest,
    PsychologyAnswerResponse,
    PsychologyResultResponse,
    PsychologyQuestion,
    PsychologyTestType,
    ErrorResponse,
)
from services import FirestoreCache, gemini_service
from dependencies import get_current_user

router = APIRouter(prefix="/api/psychology", tags=["Psychology"])

# 심리검사 질문 데이터베이스 (실제로는 별도 파일이나 DB로 관리)
PSYCHOLOGY_QUESTIONS = {
    PsychologyTestType.STRESS: [
        {
            "id": "stress_1",
            "question": "최근 한 달간 예상치 못한 일이 생겨서 기분이 상한 적이 얼마나 있었나요?",
            "options": ["전혀 없었다", "거의 없었다", "가끔 있었다", "자주 있었다", "매우 자주 있었다"],
        },
        {
            "id": "stress_2",
            "question": "최근 한 달간 중요한 일을 처리할 수 없다고 느낀 적이 얼마나 있었나요?",
            "options": ["전혀 없었다", "거의 없었다", "가끔 있었다", "자주 있었다", "매우 자주 있었다"],
        },
        {
            "id": "stress_3",
            "question": "최근 한 달간 일이 뜻대로 되어간다고 느낀 적이 얼마나 있었나요?",
            "options": ["매우 자주 있었다", "자주 있었다", "가끔 있었다", "거의 없었다", "전혀 없었다"],
        },
        {
            "id": "stress_4",
            "question": "최근 한 달간 일상의 짜증스러운 일들을 처리할 수 없다고 느낀 적이 얼마나 있었나요?",
            "options": ["전혀 없었다", "거의 없었다", "가끔 있었다", "자주 있었다", "매우 자주 있었다"],
        },
        {
            "id": "stress_5",
            "question": "최근 한 달간 긴장하거나 스트레스를 받았다고 느낀 적이 얼마나 있었나요?",
            "options": ["전혀 없었다", "거의 없었다", "가끔 있었다", "자주 있었다", "매우 자주 있었다"],
        },
    ],
    PsychologyTestType.SELF_ESTEEM: [
        {
            "id": "esteem_1",
            "question": "나는 내가 적어도 다른 사람만큼은 가치 있는 사람이라고 생각한다.",
            "options": ["전혀 그렇지 않다", "그렇지 않다", "그렇다", "매우 그렇다"],
        },
        {
            "id": "esteem_2",
            "question": "나는 좋은 자질을 가지고 있다고 생각한다.",
            "options": ["전혀 그렇지 않다", "그렇지 않다", "그렇다", "매우 그렇다"],
        },
        {
            "id": "esteem_3",
            "question": "대체로 나는 실패자라고 느껴진다.",
            "options": ["매우 그렇다", "그렇다", "그렇지 않다", "전혀 그렇지 않다"],
        },
        {
            "id": "esteem_4",
            "question": "나는 다른 사람만큼 일을 잘 할 수 있다.",
            "options": ["전혀 그렇지 않다", "그렇지 않다", "그렇다", "매우 그렇다"],
        },
        {
            "id": "esteem_5",
            "question": "나는 자랑할 만한 것이 별로 없다.",
            "options": ["매우 그렇다", "그렇다", "그렇지 않다", "전혀 그렇지 않다"],
        },
    ],
}


@router.post(
    "/start",
    response_model=PsychologyStartResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def start_psychology_test(
    request: PsychologyStartRequest,
    current_user: dict = Depends(get_current_user),
):
    """심리검사 시작"""
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 검사 유형 확인
        questions = PSYCHOLOGY_QUESTIONS.get(request.test_type)
        if not questions:
            raise HTTPException(status_code=400, detail="지원하지 않는 검사 유형입니다.")

        # 세션 생성
        session_id = str(uuid.uuid4())
        session = {
            "id": session_id,
            "test_type": request.test_type.value,
            "answers": [],
            "current_index": 0,
            "total_questions": len(questions),
            "started_at": datetime.utcnow(),
        }

        await FirestoreCache.set_psychology_session(
            request.user_id, session_id, session
        )

        # 첫 번째 질문 반환
        first_q = questions[0]
        return PsychologyStartResponse(
            session_id=session_id,
            test_type=request.test_type,
            total_questions=len(questions),
            first_question=PsychologyQuestion(
                question_id=first_q["id"],
                question=first_q["question"],
                options=first_q["options"],
            ),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Psychology start error: {e}")
        raise HTTPException(status_code=500, detail="검사 시작 중 오류가 발생했습니다.")


@router.post(
    "/answer",
    response_model=PsychologyAnswerResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def submit_psychology_answer(
    request: PsychologyAnswerRequest,
    current_user: dict = Depends(get_current_user),
):
    """심리검사 답변 제출"""
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 세션 조회
        session = await FirestoreCache.get_psychology_session(
            request.user_id, request.session_id
        )
        if not session:
            raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다.")

        test_type = PsychologyTestType(session["test_type"])
        questions = PSYCHOLOGY_QUESTIONS.get(test_type, [])

        # 답변 저장
        answers = session.get("answers", [])
        answers.append({
            "question_id": request.question_id,
            "answer_index": request.answer_index,
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
        await FirestoreCache.set_psychology_session(
            request.user_id, request.session_id, session
        )

        # 다음 질문 또는 완료
        next_question = None
        if not is_complete and next_index < len(questions):
            next_q = questions[next_index]
            next_question = PsychologyQuestion(
                question_id=next_q["id"],
                question=next_q["question"],
                options=next_q["options"],
            )

        return PsychologyAnswerResponse(
            session_id=request.session_id,
            progress=progress,
            next_question=next_question,
            is_complete=is_complete,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Psychology answer error: {e}")
        raise HTTPException(status_code=500, detail="답변 처리 중 오류가 발생했습니다.")


@router.get(
    "/result/{session_id}",
    response_model=PsychologyResultResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
)
async def get_psychology_result(
    session_id: str,
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    """심리검사 결과 조회"""
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
        if session.get("result"):
            return PsychologyResultResponse(
                session_id=session_id,
                test_type=PsychologyTestType(session["test_type"]),
                result=session["result"],
                summary=session.get("summary", ""),
                recommendations=session.get("recommendations", []),
                completed_at=session.get("completed_at", datetime.utcnow()),
            )

        # 점수 계산
        test_type = PsychologyTestType(session["test_type"])
        answers = session.get("answers", [])
        scores = _calculate_scores(test_type, answers)

        # AI 결과 생성
        ai_result = await gemini_service.generate_psychology_result(
            test_type=test_type.value,
            answers=answers,
            scores=scores,
        )

        # 세션에 결과 저장
        session["result"] = {**scores, **ai_result}
        session["summary"] = ai_result.get("summary", "")
        session["recommendations"] = ai_result.get("recommendations", [])
        session["completed_at"] = datetime.utcnow()

        await FirestoreCache.set_psychology_session(user_id, session_id, session)

        return PsychologyResultResponse(
            session_id=session_id,
            test_type=test_type,
            result=session["result"],
            summary=session["summary"],
            recommendations=session["recommendations"],
            completed_at=session["completed_at"],
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Psychology result error: {e}")
        raise HTTPException(status_code=500, detail="결과 조회 중 오류가 발생했습니다.")


def _calculate_scores(test_type: PsychologyTestType, answers: list) -> dict:
    """검사 유형별 점수 계산"""
    total_score = sum(a["answer_index"] for a in answers)
    max_score = len(answers) * 4  # 대부분 5점 척도 (0-4)

    if test_type == PsychologyTestType.STRESS:
        # 스트레스 점수 (높을수록 스트레스 높음)
        percentage = (total_score / max_score) * 100 if max_score > 0 else 0
        level = (
            "낮음" if percentage < 30 else
            "보통" if percentage < 60 else
            "높음" if percentage < 80 else
            "매우 높음"
        )
        return {
            "total_score": total_score,
            "max_score": max_score,
            "percentage": round(percentage, 1),
            "level": level,
        }

    elif test_type == PsychologyTestType.SELF_ESTEEM:
        # 자존감 점수 (높을수록 자존감 높음)
        percentage = (total_score / max_score) * 100 if max_score > 0 else 0
        level = (
            "낮음" if percentage < 40 else
            "보통" if percentage < 60 else
            "높음" if percentage < 80 else
            "매우 높음"
        )
        return {
            "total_score": total_score,
            "max_score": max_score,
            "percentage": round(percentage, 1),
            "level": level,
        }

    # 기본
    return {"total_score": total_score, "max_score": max_score}
