import json
import re
from typing import List, Optional

import google.generativeai as genai
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

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
    summary: str = ""
    validation_points: List[str] = Field(default_factory=list)
    suggested_category: Optional[str] = None
    suggested_tags: List[str] = Field(default_factory=list)
    cached: bool = False


def _extract_json_payload(raw_text: str) -> Optional[dict]:
    if not raw_text:
        return None

    cleaned = raw_text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?", "", cleaned, flags=re.IGNORECASE).strip()
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3].strip()

    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return None

    candidate = cleaned[start : end + 1]
    try:
        payload = json.loads(candidate)
        if isinstance(payload, dict):
            return payload
    except Exception:
        return None

    return None


def _normalize_string_list(raw: object, limit: int) -> List[str]:
    if not isinstance(raw, list):
        return []

    values: List[str] = []
    for item in raw:
        value = str(item).strip()
        if not value or value in values:
            continue
        values.append(value)
        if len(values) >= limit:
            break
    return values


def _first_non_empty_line(text: str) -> str:
    for line in text.splitlines():
        line = line.strip()
        if line:
            return line
    return text.strip()


@router.post(
    "/analyze",
    response_model=MemoAnalyzeResponse,
)
async def analyze_memo(
    request: MemoAnalyzeRequest,
    current_user: dict = Depends(get_current_user),
):
    """메모 내용을 AI로 요약/검증하여 인사이트 제공"""
    try:
        if current_user["uid"] != request.user_id:
            raise HTTPException(status_code=403, detail="권한이 없습니다.")

        if len(request.content) < 20:
            raise HTTPException(
                status_code=400, detail="내용이 너무 짧습니다 (최소 20자)"
            )

        genai.configure(api_key=settings.gemini_api_key)
        model = genai.GenerativeModel("gemini-1.5-flash")

        prompt = f"""당신은 개인 메모 요약/검증 AI입니다.
아래 메모를 읽고 반드시 JSON으로만 응답하세요.
{f'참고 카테고리: {request.category_name}' if request.category_name else ''}

요구사항:
1) summary: 메모 핵심을 1-2문장으로 요약
2) validation_points: 메모 품질 검증 포인트 2-4개
   - 예: 모호한 표현, 누락 정보, 실행 계획 부재, 위험 신호
3) suggested_category: 가장 적합한 카테고리 이름 1개
4) suggested_tags: 검색에 유용한 태그 최대 5개
5) analysis: 실행 가능한 인사이트를 포함한 3-5문장

응답 JSON 스키마:
{{
  "summary": "요약",
  "validation_points": ["검증1", "검증2"],
  "suggested_category": "카테고리명",
  "suggested_tags": ["태그1", "태그2"],
  "analysis": "상세 분석"
}}

메모 내용:
{request.content}
"""

        response = model.generate_content(prompt)
        raw_text = response.text.strip() if response.text else ""
        if not raw_text:
            raise HTTPException(status_code=500, detail="AI 분석을 수행할 수 없습니다.")

        payload = _extract_json_payload(raw_text)
        if payload is None:
            summary = _first_non_empty_line(raw_text)
            return MemoAnalyzeResponse(
                analysis=raw_text,
                summary=summary[:200],
            )

        summary = str(payload.get("summary", "")).strip()
        validation_points = _normalize_string_list(
            payload.get("validation_points"), limit=6
        )
        suggested_tags = _normalize_string_list(payload.get("suggested_tags"), limit=5)

        suggested_category = str(payload.get("suggested_category", "")).strip()
        if not suggested_category:
            suggested_category = None

        analysis = str(payload.get("analysis", "")).strip()
        if not analysis:
            assembled: List[str] = []
            if summary:
                assembled.append(summary)
            if validation_points:
                assembled.append("검증 포인트: " + ", ".join(validation_points[:3]))
            analysis = "\n".join(assembled).strip()

        if not analysis:
            raise HTTPException(status_code=500, detail="AI 분석을 수행할 수 없습니다.")

        if not summary:
            summary = _first_non_empty_line(analysis)[:200]

        return MemoAnalyzeResponse(
            analysis=analysis,
            summary=summary,
            validation_points=validation_points,
            suggested_category=suggested_category,
            suggested_tags=suggested_tags,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Memo analyze error: {e}")
        raise HTTPException(status_code=500, detail="분석 중 오류가 발생했습니다.")
