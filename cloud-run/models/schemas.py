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


# ============ Agent 홈 요약 ============

class AgentHomeSummaryRequest(BaseModel):
    """BABBA 서브에이전트 홈 요약 요청"""
    user_id: str
    user_name: str = "사용자"
    selected_member_id: Optional[str] = None
    selected_member_name: Optional[str] = None
    pending_todos: int = Field(default=0, ge=0)
    completed_today: int = Field(default=0, ge=0)
    upcoming_events: int = Field(default=0, ge=0)


class AgentHomeSummaryResponse(BaseModel):
    """BABBA 서브에이전트 홈 요약 응답"""
    success: bool = True
    capability: str = "home_summary"
    source: str = "babba_subagent_import"
    scope: str = "read_only"
    subject_name: str
    summary: str
    cached: bool = False
    trace_id: str
    generated_at: datetime


class AgentFamilyChatSummaryRequest(BaseModel):
    """BABBA 서브에이전트 가족 채팅 요약 요청"""
    user_id: str
    family_id: str
    family_name: Optional[str] = None
    limit_messages: int = Field(default=40, ge=10, le=80)


class AgentFamilyChatSummaryResponse(BaseModel):
    """BABBA 서브에이전트 가족 채팅 요약 응답"""
    success: bool = True
    capability: str = "family_chat_summary"
    source: str = "babba_subagent_import"
    scope: str = "read_only"
    family_id: str
    family_name: str
    summary: str
    highlights: List[str] = Field(default_factory=list)
    message_count: int = 0
    participant_count: int = 0
    latest_message_at: Optional[datetime] = None
    cached: bool = False
    trace_id: str
    generated_at: datetime


class AgentMemoSummaryRequest(BaseModel):
    """BABBA 서브에이전트 메모 요약 요청"""
    user_id: str
    memo_title: Optional[str] = None
    content: str = Field(..., min_length=20, max_length=20000)
    category_name: Optional[str] = None


class AgentMemoSummaryResponse(BaseModel):
    """BABBA 서브에이전트 메모 요약 응답"""
    success: bool = True
    capability: str = "memo_summary"
    source: str = "babba_subagent_import"
    scope: str = "read_only"
    summary: str
    analysis: str
    validation_points: List[str] = Field(default_factory=list)
    suggested_category: Optional[str] = None
    suggested_tags: List[str] = Field(default_factory=list)
    cached: bool = False
    trace_id: str
    generated_at: datetime


class AgentTodoCreatePreviewRequest(BaseModel):
    """BABBA 서브에이전트 개인 todo 생성 preview 요청"""
    user_id: str
    prompt: str = Field(..., min_length=2, max_length=500)
    source: Optional[str] = None
    current_group_id: Optional[str] = None


class AgentTodoCreatePreview(BaseModel):
    """개인 todo 생성 preview 데이터"""
    title: str
    note: Optional[str] = None
    due_date: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    priority: int = Field(default=1, ge=0, le=2)
    priority_label: str = "보통"
    reminder_minutes: List[int] = Field(default_factory=list)
    reminder_labels: List[str] = Field(default_factory=list)
    visibility: str = "private"


class AgentToolConsent(BaseModel):
    """도구 consent 상태"""
    required: bool = True
    approved: Optional[bool] = None


class AgentTodoCreatePreviewResponse(BaseModel):
    """개인 todo 생성 preview 응답"""
    ok: bool = True
    tool: str = "manage_todos"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    params_hash: str
    summary: str
    preview: AgentTodoCreatePreview
    consent: AgentToolConsent = Field(default_factory=AgentToolConsent)
    generated_at: datetime


class AgentTodoCreateDecisionRequest(BaseModel):
    """개인 todo 생성 consent 결정 요청"""
    user_id: str
    request_id: str
    approved: bool


class AgentTodoCreateResult(BaseModel):
    """개인 todo 생성 실행 결과"""
    status: str
    todo_id: Optional[str] = None
    title: str
    note: Optional[str] = None
    due_date: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    priority_label: str = "보통"
    visibility: str = "private"


class AgentTodoCreateDecisionResponse(BaseModel):
    """개인 todo 생성 consent 처리 응답"""
    ok: bool = True
    tool: str = "manage_todos"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    audit_id: str
    consent: AgentToolConsent
    result: AgentTodoCreateResult
    executed_at: datetime


class AgentTodoCompletePreviewRequest(BaseModel):
    """BABBA 서브에이전트 개인 todo 완료 preview 요청"""
    user_id: str
    prompt: str = Field(..., min_length=2, max_length=500)
    source: Optional[str] = None


class AgentTodoCompletePreview(BaseModel):
    """개인 todo 완료 preview 데이터"""
    todo_id: str
    title: str
    note: Optional[str] = None
    due_date: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    visibility: str = "private"
    match_reason: Optional[str] = None


class AgentTodoCompletePreviewResponse(BaseModel):
    """개인 todo 완료 preview 응답"""
    ok: bool = True
    tool: str = "manage_todos"
    action: str = "complete"
    scope: str = "personal"
    request_id: str
    params_hash: str
    summary: str
    preview: AgentTodoCompletePreview
    consent: AgentToolConsent = Field(default_factory=AgentToolConsent)
    generated_at: datetime


class AgentTodoCompleteDecisionRequest(BaseModel):
    """개인 todo 완료 consent 결정 요청"""
    user_id: str
    request_id: str
    approved: bool


class AgentTodoCompleteResult(BaseModel):
    """개인 todo 완료 실행 결과"""
    status: str
    todo_id: str
    title: str
    note: Optional[str] = None
    completed_at: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    visibility: str = "private"


class AgentTodoCompleteDecisionResponse(BaseModel):
    """개인 todo 완료 consent 처리 응답"""
    ok: bool = True
    tool: str = "manage_todos"
    action: str = "complete"
    scope: str = "personal"
    request_id: str
    audit_id: str
    consent: AgentToolConsent
    result: AgentTodoCompleteResult
    executed_at: datetime


class AgentCalendarCreatePreviewRequest(BaseModel):
    """BABBA 서브에이전트 개인 일정 생성 preview 요청"""
    user_id: str
    prompt: str = Field(..., min_length=2, max_length=500)
    source: Optional[str] = None
    current_group_id: Optional[str] = None
    selected_date: Optional[datetime] = None


class AgentCalendarCreatePreview(BaseModel):
    """개인 일정 생성 preview 데이터"""
    title: str
    note: Optional[str] = None
    event_type: str = "schedule"
    event_type_label: str = "일정"
    due_date: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    formatted_time_range: Optional[str] = None
    has_time: bool = False
    location: Optional[str] = None
    reminder_minutes: List[int] = Field(default_factory=list)
    reminder_labels: List[str] = Field(default_factory=list)
    visibility: str = "private"


class AgentCalendarCreatePreviewResponse(BaseModel):
    """개인 일정 생성 preview 응답"""
    ok: bool = True
    tool: str = "manage_calendar"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    params_hash: str
    summary: str
    preview: AgentCalendarCreatePreview
    consent: AgentToolConsent = Field(default_factory=AgentToolConsent)
    generated_at: datetime


class AgentCalendarCreateDecisionRequest(BaseModel):
    """개인 일정 생성 consent 결정 요청"""
    user_id: str
    request_id: str
    approved: bool


class AgentCalendarCreateResult(BaseModel):
    """개인 일정 생성 실행 결과"""
    status: str
    event_id: Optional[str] = None
    title: str
    event_type: str = "schedule"
    event_type_label: str = "일정"
    due_date: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    formatted_time_range: Optional[str] = None
    location: Optional[str] = None
    visibility: str = "private"


class AgentCalendarCreateDecisionResponse(BaseModel):
    """개인 일정 생성 consent 처리 응답"""
    ok: bool = True
    tool: str = "manage_calendar"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    audit_id: str
    consent: AgentToolConsent
    result: AgentCalendarCreateResult
    executed_at: datetime


class AgentCalendarUpdatePreviewRequest(BaseModel):
    """BABBA 서브에이전트 개인 일정 수정 preview 요청"""
    user_id: str
    prompt: str = Field(..., min_length=2, max_length=500)
    source: Optional[str] = None
    selected_date: Optional[datetime] = None


class AgentCalendarUpdatePreview(BaseModel):
    """개인 일정 수정 preview 데이터"""
    event_id: str
    original_title: str
    original_formatted_due_date: Optional[str] = None
    original_formatted_time_range: Optional[str] = None
    title: str
    note: Optional[str] = None
    event_type: str = "schedule"
    event_type_label: str = "일정"
    due_date: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    formatted_time_range: Optional[str] = None
    has_time: bool = False
    location: Optional[str] = None
    reminder_minutes: List[int] = Field(default_factory=list)
    reminder_labels: List[str] = Field(default_factory=list)
    visibility: str = "private"
    match_reason: Optional[str] = None


class AgentCalendarUpdatePreviewResponse(BaseModel):
    """개인 일정 수정 preview 응답"""
    ok: bool = True
    tool: str = "manage_calendar"
    action: str = "update"
    scope: str = "personal"
    request_id: str
    params_hash: str
    summary: str
    preview: AgentCalendarUpdatePreview
    consent: AgentToolConsent = Field(default_factory=AgentToolConsent)
    generated_at: datetime


class AgentCalendarUpdateDecisionRequest(BaseModel):
    """개인 일정 수정 consent 결정 요청"""
    user_id: str
    request_id: str
    approved: bool


class AgentCalendarUpdateResult(BaseModel):
    """개인 일정 수정 실행 결과"""
    status: str
    event_id: Optional[str] = None
    title: str
    event_type: str = "schedule"
    event_type_label: str = "일정"
    due_date: Optional[datetime] = None
    formatted_due_date: Optional[str] = None
    formatted_time_range: Optional[str] = None
    location: Optional[str] = None
    visibility: str = "private"


class AgentCalendarUpdateDecisionResponse(BaseModel):
    """개인 일정 수정 consent 처리 응답"""
    ok: bool = True
    tool: str = "manage_calendar"
    action: str = "update"
    scope: str = "personal"
    request_id: str
    audit_id: str
    consent: AgentToolConsent
    result: AgentCalendarUpdateResult
    executed_at: datetime


class AgentNoteCreatePreviewRequest(BaseModel):
    """BABBA 서브에이전트 개인 메모 생성 preview 요청"""
    user_id: str
    prompt: str = Field(..., min_length=2, max_length=1000)
    source: Optional[str] = None


class AgentNoteCreatePreview(BaseModel):
    """개인 메모 생성 preview 데이터"""
    title: str
    content: str = ""
    category_name: Optional[str] = None
    tags: List[str] = Field(default_factory=list)
    is_pinned: bool = False


class AgentNoteCreatePreviewResponse(BaseModel):
    """개인 메모 생성 preview 응답"""
    ok: bool = True
    tool: str = "manage_notes"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    params_hash: str
    summary: str
    preview: AgentNoteCreatePreview
    consent: AgentToolConsent = Field(default_factory=AgentToolConsent)
    generated_at: datetime


class AgentNoteCreateDecisionRequest(BaseModel):
    """개인 메모 생성 consent 결정 요청"""
    user_id: str
    request_id: str
    approved: bool


class AgentNoteCreateResult(BaseModel):
    """개인 메모 생성 실행 결과"""
    status: str
    memo_id: Optional[str] = None
    title: str
    category_name: Optional[str] = None
    tags: List[str] = Field(default_factory=list)


class AgentNoteCreateDecisionResponse(BaseModel):
    """개인 메모 생성 consent 처리 응답"""
    ok: bool = True
    tool: str = "manage_notes"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    audit_id: str
    consent: AgentToolConsent
    result: AgentNoteCreateResult
    executed_at: datetime


class AgentNoteUpdatePreviewRequest(BaseModel):
    """BABBA 서브에이전트 개인 메모 수정 preview 요청"""
    user_id: str
    prompt: str = Field(..., min_length=2, max_length=1000)
    source: Optional[str] = None


class AgentNoteUpdatePreview(BaseModel):
    """개인 메모 수정 preview 데이터"""
    memo_id: str
    original_title: str
    original_category_name: Optional[str] = None
    title: str
    content: str = ""
    category_name: Optional[str] = None
    tags: List[str] = Field(default_factory=list)
    is_pinned: bool = False
    match_reason: Optional[str] = None


class AgentNoteUpdatePreviewResponse(BaseModel):
    """개인 메모 수정 preview 응답"""
    ok: bool = True
    tool: str = "manage_notes"
    action: str = "update"
    scope: str = "personal"
    request_id: str
    params_hash: str
    summary: str
    preview: AgentNoteUpdatePreview
    consent: AgentToolConsent = Field(default_factory=AgentToolConsent)
    generated_at: datetime


class AgentNoteUpdateDecisionRequest(BaseModel):
    """개인 메모 수정 consent 결정 요청"""
    user_id: str
    request_id: str
    approved: bool


class AgentNoteUpdateResult(BaseModel):
    """개인 메모 수정 실행 결과"""
    status: str
    memo_id: Optional[str] = None
    title: str
    category_name: Optional[str] = None
    tags: List[str] = Field(default_factory=list)
    is_pinned: bool = False


class AgentNoteUpdateDecisionResponse(BaseModel):
    """개인 메모 수정 consent 처리 응답"""
    ok: bool = True
    tool: str = "manage_notes"
    action: str = "update"
    scope: str = "personal"
    request_id: str
    audit_id: str
    consent: AgentToolConsent
    result: AgentNoteUpdateResult
    executed_at: datetime


class AgentReminderCreatePreviewRequest(BaseModel):
    """BABBA 서브에이전트 개인 리마인더 생성 preview 요청"""
    user_id: str
    prompt: str = Field(..., min_length=2, max_length=1000)
    source: Optional[str] = None


class AgentReminderCreatePreview(BaseModel):
    """개인 리마인더 생성 preview 데이터"""
    message: str
    remind_at: datetime
    formatted_remind_at: Optional[str] = None
    recurrence: Optional[str] = None
    recurrence_label: Optional[str] = None


class AgentReminderCreatePreviewResponse(BaseModel):
    """개인 리마인더 생성 preview 응답"""
    ok: bool = True
    tool: str = "create_reminder"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    params_hash: str
    summary: str
    preview: AgentReminderCreatePreview
    consent: AgentToolConsent = Field(default_factory=AgentToolConsent)
    generated_at: datetime


class AgentReminderCreateDecisionRequest(BaseModel):
    """개인 리마인더 생성 consent 결정 요청"""
    user_id: str
    request_id: str
    approved: bool


class AgentReminderCreateResult(BaseModel):
    """개인 리마인더 생성 실행 결과"""
    status: str
    reminder_id: Optional[str] = None
    message: str
    remind_at: datetime
    formatted_remind_at: Optional[str] = None
    recurrence: Optional[str] = None
    recurrence_label: Optional[str] = None


class AgentReminderCreateDecisionResponse(BaseModel):
    """개인 리마인더 생성 consent 처리 응답"""
    ok: bool = True
    tool: str = "create_reminder"
    action: str = "create"
    scope: str = "personal"
    request_id: str
    audit_id: str
    consent: AgentToolConsent
    result: AgentReminderCreateResult
    executed_at: datetime


class AgentAuditLogEntry(BaseModel):
    """최근 AI tool audit 로그 엔트리"""
    audit_id: str
    request_id: str
    tool: str
    action: str
    scope: str
    source: Optional[str] = None
    prompt: Optional[str] = None
    params_hash: Optional[str] = None
    consent_required: bool = True
    consent_approved: bool = False
    execution_status: str
    target_label: Optional[str] = None
    result_ref_id: Optional[str] = None
    result_ref_type: Optional[str] = None
    created_at: Optional[datetime] = None
    executed_at: Optional[datetime] = None


class AgentAuditLogListResponse(BaseModel):
    """최근 AI tool audit 로그 목록 응답"""
    ok: bool = True
    user_id: str
    limit: int
    total_count: int
    items: List[AgentAuditLogEntry] = Field(default_factory=list)
    fetched_at: datetime


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
    MEMO_CATEGORY_ANALYSIS = "memo_category_analysis"


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


class SubmitPsychologyAnalysisRequest(BaseModel):
    """심리검사 비동기 분석 요청"""
    user_id: str
    session_id: str
    test_type: str


class SubmitPsychologyAnalysisResponse(BaseModel):
    """심리검사 비동기 분석 응답"""
    success: bool = True
    job_id: str
    status: AnalysisJobStatus = AnalysisJobStatus.PENDING
    estimated_time_seconds: int = 60  # 약 1분


class SubmitMemoCategoryAnalysisRequest(BaseModel):
    """메모 카테고리 비동기 분석 요청"""
    user_id: str
    category_id: Optional[str] = None
    category_name: Optional[str] = None
    focus: List[str] = Field(default_factory=list)
    max_memos: int = Field(default=120, ge=10, le=400)


class SubmitMemoCategoryAnalysisResponse(BaseModel):
    """메모 카테고리 비동기 분석 응답"""
    success: bool = True
    job_id: str
    status: AnalysisJobStatus = AnalysisJobStatus.PENDING
    estimated_time_seconds: int = 90


class MemoCategoryAnalysisResultResponse(BaseModel):
    """메모 카테고리 분석 결과 응답"""
    success: bool = True
    analysis_id: str
    category_id: Optional[str] = None
    category_name: str
    memo_count: int = 0
    result: dict = Field(default_factory=dict)
    created_at: datetime
    completed_at: Optional[datetime] = None


class ProcessJobRequest(BaseModel):
    """내부 작업 처리 요청 (Cloud Tasks에서 호출)"""
    job_id: str
