from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


# ============ 공통 ============

class BaseResponse(BaseModel):
    """기본 응답 모델"""
    success: bool = True
    message: str = "OK"


class ErrorResponse(BaseModel):
    """에러 응답 모델"""
    success: bool = False
    error: str
    detail: Optional[str] = None


# ============ 일일 요약 ============

class DailySummaryRequest(BaseModel):
    """일일 요약 요청"""
    user_id: str
    user_name: str = "사용자"
    pending_todos: int = 0
    completed_today: int = 0
    upcoming_events: int = 0
    monthly_expense: Optional[int] = None  # 이번 달 지출 (원)
    monthly_income: Optional[int] = None   # 이번 달 수입 (원)


class DailySummaryResponse(BaseModel):
    """일일 요약 응답"""
    success: bool = True
    summary: str
    cached: bool = False
    generated_at: datetime


# ============ 주간 요약 ============

class WeeklySummaryRequest(BaseModel):
    """주간 요약 요청"""
    user_id: str
    user_name: str = "사용자"
    completed_todos: int = 0
    total_todos: int = 0
    events_attended: int = 0
    weekly_expense: Optional[int] = None


class WeeklySummaryResponse(BaseModel):
    """주간 요약 응답"""
    success: bool = True
    summary: str
    completion_rate: float = 0.0
    cached: bool = False
    generated_at: datetime


# ============ 사업 검토 ============

class BusinessAnalyzeRequest(BaseModel):
    """사업 아이디어 분석 요청"""
    user_id: str
    idea: str = Field(..., min_length=10, max_length=2000)
    industry: Optional[str] = None
    target_market: Optional[str] = None
    budget: Optional[str] = None


class BusinessAnalyzeResponse(BaseModel):
    """사업 아이디어 분석 응답"""
    success: bool = True
    analysis: dict  # 구조화된 분석 결과
    summary: str
    score: int = Field(..., ge=0, le=100)  # 0-100점
    generated_at: datetime


class BusinessChatRequest(BaseModel):
    """사업 검토 대화 요청"""
    user_id: str
    session_id: str
    message: str = Field(..., min_length=1, max_length=1000)


class BusinessChatResponse(BaseModel):
    """사업 검토 대화 응답"""
    success: bool = True
    reply: str
    session_id: str
    turn: int  # 대화 턴 수


# ============ 심리검사 ============

class PsychologyTestType(str, Enum):
    """심리검사 유형"""
    MBTI = "mbti"
    STRESS = "stress"
    ANXIETY = "anxiety"
    DEPRESSION = "depression"
    SELF_ESTEEM = "self_esteem"


class PsychologyStartRequest(BaseModel):
    """심리검사 시작 요청"""
    user_id: str
    test_type: PsychologyTestType


class PsychologyQuestion(BaseModel):
    """심리검사 질문"""
    question_id: str
    question: str
    options: List[str]


class PsychologyStartResponse(BaseModel):
    """심리검사 시작 응답"""
    success: bool = True
    session_id: str
    test_type: PsychologyTestType
    total_questions: int
    first_question: PsychologyQuestion


class PsychologyAnswerRequest(BaseModel):
    """심리검사 답변 요청"""
    user_id: str
    session_id: str
    question_id: str
    answer_index: int  # 선택한 옵션 인덱스


class PsychologyAnswerResponse(BaseModel):
    """심리검사 답변 응답"""
    success: bool = True
    session_id: str
    progress: float  # 0.0 ~ 1.0
    next_question: Optional[PsychologyQuestion] = None
    is_complete: bool = False


class PsychologyResultResponse(BaseModel):
    """심리검사 결과 응답"""
    success: bool = True
    session_id: str
    test_type: PsychologyTestType
    result: dict  # 검사 유형별 결과
    summary: str  # AI 생성 요약
    recommendations: List[str]  # 추천 사항
    completed_at: datetime
