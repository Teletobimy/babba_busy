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
    BIG5 = "big5"
    ATTACHMENT = "attachment"
    MBTI = "mbti"
    LOVE_LANGUAGE = "love_language"
    STRESS = "stress"
    ANXIETY = "anxiety"
    DEPRESSION = "depression"


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


# ============ 분석 작업 (Analysis Jobs) ============

class AnalysisJobType(str, Enum):
    """분석 작업 유형"""
    BUSINESS_REVIEW = "business_review"
    PSYCHOLOGY_TEST = "psychology_test"


class AnalysisJobStatus(str, Enum):
    """분석 작업 상태"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class AnalysisJobProgress(BaseModel):
    """분석 작업 진행 상황"""
    current_step: int = 0
    total_steps: int = 5
    percentage: float = 0.0
    current_step_name: Optional[str] = None


class AnalysisJobError(BaseModel):
    """분석 작업 에러 정보"""
    code: str
    message: str
    retryable: bool = True


class BusinessAnalysisInput(BaseModel):
    """사업 검토 입력 데이터"""
    business_idea: str = Field(..., min_length=10, max_length=2000)
    industry: Optional[str] = None
    target_market: Optional[str] = None
    budget: Optional[str] = None


class SubmitBusinessAnalysisRequest(BaseModel):
    """사업 검토 비동기 요청"""
    user_id: str
    idea: str = Field(..., min_length=10, max_length=2000)
    industry: Optional[str] = None
    target_market: Optional[str] = None
    budget: Optional[str] = None
    wait_for_result: bool = False  # True면 기존 동기 방식으로 대기


class SubmitBusinessAnalysisResponse(BaseModel):
    """사업 검토 비동기 응답"""
    success: bool = True
    job_id: str
    status: AnalysisJobStatus = AnalysisJobStatus.PENDING
    estimated_time_seconds: int = 120  # 약 2분


class AnalysisJobResponse(BaseModel):
    """분석 작업 상태 응답"""
    success: bool = True
    job_id: str
    user_id: str
    job_type: AnalysisJobType
    status: AnalysisJobStatus
    progress: AnalysisJobProgress
    result_id: Optional[str] = None
    error: Optional[AnalysisJobError] = None
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None


class CancelJobResponse(BaseModel):
    """작업 취소 응답"""
    success: bool = True
    job_id: str
    message: str


class ProcessJobRequest(BaseModel):
    """내부 작업 처리 요청 (Cloud Tasks에서 호출)"""
    job_id: str
