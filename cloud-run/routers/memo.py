from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
import google.generativeai as genai

from config import get_settings
from dependencies import get_current_user

router = APIRouter(prefix="/api/memo", tags=["Memo"])

settings = get_settings()


class MemoAnalyzeRequest(BaseModel):
    user_id: str
    content: str
    category_name: Optional[str] = None


class MemoAnalyzeResponse(BaseModel):
    analysis: str
    cached: bool = False


@router.post(
    "/analyze",
    response_model=MemoAnalyzeResponse,
)
async def analyze_memo(
    request: MemoAnalyzeRequest,
    current_user: dict = Depends(get_current_user),
):
    """메모 내용을 AI로 분석하여 인사이트 제공"""
    try:
        # 권한 확인
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        # 내용 검증
        if len(request.content) < 20:
            raise HTTPException(
                status_code=400, detail="내용이 너무 짧습니다 (최소 20자)"
            )

        # Gemini 모델 설정
        genai.configure(api_key=settings.gemini_api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")

        # 프롬프트 구성
        prompt = f"""당신은 개인 메모 분석 AI입니다.
다음 메모를 분석하여 핵심 인사이트를 2-3문장으로 요약해주세요.
따뜻하고 도움이 되는 톤으로 작성하세요.
{f'카테고리: {request.category_name}' if request.category_name else ''}

메모 내용:
{request.content}

응답 형식:
- 핵심 주제나 감정 파악
- 실행 가능한 조언이나 인사이트 (해당 시)
- 격려나 공감의 한마디
"""

        # AI 분석 실행
        response = model.generate_content(prompt)
        analysis = response.text if response.text else ""

        if not analysis:
            raise HTTPException(status_code=500, detail="AI 분석을 수행할 수 없습니다.")

        return MemoAnalyzeResponse(analysis=analysis)

    except HTTPException:
        raise
    except Exception as e:
        print(f"Memo analyze error: {e}")
        raise HTTPException(status_code=500, detail="분석 중 오류가 발생했습니다.")
