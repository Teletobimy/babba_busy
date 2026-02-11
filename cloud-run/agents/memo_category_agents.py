import asyncio
import json
import math
import re
from datetime import datetime
from typing import Any, Callable, Optional

from .base_agent import BaseAgent


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


def _normalize_string_list(raw: object, limit: int) -> list[str]:
    if not isinstance(raw, list):
        return []
    values: list[str] = []
    for item in raw:
        value = str(item).strip()
        if not value or value in values:
            continue
        values.append(value)
        if len(values) >= limit:
            break
    return values


def _coerce_int(raw: object, default: int = 0) -> int:
    try:
        return int(raw)
    except Exception:
        return default


def _short_text(value: str, max_len: int) -> str:
    if len(value) <= max_len:
        return value
    return f"{value[:max_len]}..."


def _memo_headline(memo: dict) -> str:
    title = str(memo.get("title", "")).strip()
    content = str(memo.get("content", "")).strip().splitlines()
    if title:
        return _short_text(title, 80)
    for line in content:
        line = line.strip()
        if line:
            return _short_text(line, 80)
    return "제목 없음"


class MemoCategoryPlannerAgent(BaseAgent):
    """카테고리 분석 기준을 수립하는 메인 에이전트"""

    def __init__(self):
        super().__init__(model_type="pm")

    async def run(
        self,
        category_name: str,
        memo_count: int,
        memo_preview: list[dict],
        requested_focus: Optional[list[str]] = None,
    ) -> dict:
        preview_lines = []
        for item in memo_preview[:6]:
            preview_lines.append(
                f"- ({item.get('id')}) {_memo_headline(item)} / tags={item.get('tags', [])}"
            )

        prompt = f"""당신은 메모 카테고리 분석 PM입니다.
카테고리: {category_name}
메모 수: {memo_count}
요청된 중점 분석 축: {requested_focus or []}

샘플 메모:
{chr(10).join(preview_lines) if preview_lines else "- 샘플 없음"}

다음 JSON으로만 답변하세요.
{{
  "analysis_axes": ["분석 축1", "분석 축2", "분석 축3", "분석 축4"],
  "expected_outputs": ["결정사항", "실행 항목", "리스크", "미해결 질문"],
  "quality_checks": ["근거 없는 주장 금지", "모순 여부 점검", "실행 우선순위 제시"],
  "compaction_schema": ["summary", "decisions", "actions", "risks", "questions", "evidence"],
  "planner_note": "이번 분석에서 특히 주의할 점"
}}
"""

        fallback = {
            "analysis_axes": requested_focus
            if requested_focus
            else ["핵심 결정사항", "실행 계획", "리스크", "미해결 이슈"],
            "expected_outputs": ["결정사항", "실행 항목", "리스크", "미해결 질문"],
            "quality_checks": ["근거 없는 주장 금지", "모순 여부 점검", "실행 우선순위 제시"],
            "compaction_schema": [
                "summary",
                "decisions",
                "actions",
                "risks",
                "questions",
                "evidence",
            ],
            "planner_note": "근거가 부족한 항목은 unknown으로 표기",
        }
        payload = await self._generate_json_with_fallback(prompt, fallback)
        return {
            "analysis_axes": _normalize_string_list(payload.get("analysis_axes"), 8)
            or fallback["analysis_axes"],
            "expected_outputs": _normalize_string_list(payload.get("expected_outputs"), 8)
            or fallback["expected_outputs"],
            "quality_checks": _normalize_string_list(payload.get("quality_checks"), 10)
            or fallback["quality_checks"],
            "compaction_schema": _normalize_string_list(payload.get("compaction_schema"), 10)
            or fallback["compaction_schema"],
            "planner_note": str(payload.get("planner_note", fallback["planner_note"])).strip(),
        }

    async def _generate_json_with_fallback(self, prompt: str, fallback: dict) -> dict:
        try:
            raw_text = await self._generate(prompt)
            payload = _extract_json_payload(raw_text)
            if payload is None:
                return fallback
            return payload
        except Exception:
            return fallback


class MemoContextCompactorAgent(BaseAgent):
    """메모 청크를 구조화 컨텍스트로 압축하는 서브 에이전트"""

    def __init__(self):
        super().__init__(model_type="agent")

    async def run(self, chunk_index: int, memos: list[dict], planner_strategy: dict) -> dict:
        memo_lines = []
        for memo in memos:
            memo_lines.append(
                (
                    f"[memo_id={memo.get('id')}] title={_memo_headline(memo)}\n"
                    f"tags={memo.get('tags', [])}\n"
                    f"content={_short_text(str(memo.get('content', '')).strip(), 1600)}"
                )
            )

        prompt = f"""당신은 긴 메모를 분석 가능한 컨텍스트로 압축하는 에이전트입니다.
아래 스키마를 지키고 JSON으로만 응답하세요.

planner_strategy:
{json.dumps(planner_strategy, ensure_ascii=False)}

입력 청크 번호: {chunk_index}
청크 메모:
{chr(10).join(memo_lines)}

출력 JSON 스키마:
{{
  "summary": "청크 핵심 요약",
  "decisions": ["결정사항"],
  "actions": ["실행 항목"],
  "risks": ["리스크"],
  "questions": ["미해결 질문"],
  "entities": ["핵심 엔티티/키워드"],
  "evidence": [
    {{"memo_id": "원문 id", "quote": "근거 문장(짧게)", "reason": "왜 근거인지"}}
  ]
}}
"""

        fallback = self._fallback_compaction(memos)
        payload = await self._generate_json_with_fallback(prompt, fallback)

        return {
            "chunk_index": chunk_index,
            "summary": str(payload.get("summary", fallback["summary"])).strip(),
            "decisions": _normalize_string_list(payload.get("decisions"), 12),
            "actions": _normalize_string_list(payload.get("actions"), 12),
            "risks": _normalize_string_list(payload.get("risks"), 12),
            "questions": _normalize_string_list(payload.get("questions"), 12),
            "entities": _normalize_string_list(payload.get("entities"), 20),
            "evidence": self._normalize_evidence(payload.get("evidence"), memos),
        }

    async def _generate_json_with_fallback(self, prompt: str, fallback: dict) -> dict:
        try:
            raw_text = await self._generate(prompt)
            payload = _extract_json_payload(raw_text)
            if payload is None:
                return fallback
            return payload
        except Exception:
            return fallback

    def _normalize_evidence(self, raw: object, memos: list[dict]) -> list[dict]:
        valid_ids = {str(m.get("id", "")).strip() for m in memos if m.get("id")}
        values: list[dict] = []
        if isinstance(raw, list):
            for item in raw:
                if not isinstance(item, dict):
                    continue
                memo_id = str(item.get("memo_id", "")).strip()
                quote = str(item.get("quote", "")).strip()
                reason = str(item.get("reason", "")).strip()
                if not memo_id or memo_id not in valid_ids or not quote:
                    continue
                values.append({
                    "memo_id": memo_id,
                    "quote": _short_text(quote, 220),
                    "reason": _short_text(reason, 180),
                })
                if len(values) >= 20:
                    break

        if values:
            return values

        # fallback evidence
        fallback: list[dict] = []
        for memo in memos[:3]:
            content_lines = str(memo.get("content", "")).splitlines()
            quote = ""
            for line in content_lines:
                line = line.strip()
                if line:
                    quote = line
                    break
            if not quote:
                quote = _memo_headline(memo)
            memo_id = str(memo.get("id", "")).strip()
            if not memo_id:
                continue
            fallback.append({
                "memo_id": memo_id,
                "quote": _short_text(quote, 220),
                "reason": "청크 핵심 맥락의 대표 문장",
            })
        return fallback

    def _fallback_compaction(self, memos: list[dict]) -> dict:
        actions: list[str] = []
        risks: list[str] = []
        questions: list[str] = []
        entities: list[str] = []
        for memo in memos:
            tags = memo.get("tags", [])
            if isinstance(tags, list):
                for tag in tags:
                    tag_v = str(tag).strip()
                    if tag_v and tag_v not in entities:
                        entities.append(tag_v)
            content = str(memo.get("content", "")).strip()
            for line in content.splitlines():
                v = line.strip()
                if not v:
                    continue
                if "?" in v and len(questions) < 8:
                    questions.append(_short_text(v, 100))
                if any(key in v for key in ["해야", "일정", "TODO", "다음", "진행"]):
                    if len(actions) < 8:
                        actions.append(_short_text(v, 100))
                if any(key in v for key in ["리스크", "위험", "문제", "막힘", "지연"]):
                    if len(risks) < 8:
                        risks.append(_short_text(v, 100))

        summary_head = _memo_headline(memos[0]) if memos else "요약 불가"
        return {
            "summary": f"청크 요약: {summary_head}",
            "decisions": [],
            "actions": actions,
            "risks": risks,
            "questions": questions,
            "entities": entities[:12],
            "evidence": [],
        }


class MemoCategorySynthesizerAgent(BaseAgent):
    """압축 컨텍스트를 최종 리포트로 통합하는 에이전트"""

    def __init__(self):
        super().__init__(model_type="pm")

    async def run(
        self,
        category_name: str,
        planner_strategy: dict,
        compacted_contexts: list[dict],
        memo_count: int,
    ) -> dict:
        compact_payload = []
        for item in compacted_contexts:
            compact_payload.append({
                "chunk_index": item.get("chunk_index"),
                "summary": item.get("summary"),
                "decisions": item.get("decisions", []),
                "actions": item.get("actions", []),
                "risks": item.get("risks", []),
                "questions": item.get("questions", []),
                "entities": item.get("entities", []),
                "evidence": item.get("evidence", [])[:8],
            })

        prompt = f"""당신은 메모 카테고리 통합 분석 에이전트입니다.
카테고리: {category_name}
총 메모 수: {memo_count}
planner_strategy: {json.dumps(planner_strategy, ensure_ascii=False)}

compacted_contexts:
{json.dumps(compact_payload, ensure_ascii=False)}

다음 JSON으로만 응답하세요:
{{
  "summary": "카테고리 전체 요약 (3-5문장)",
  "key_insights": ["핵심 인사이트"],
  "action_items": [
    {{"task": "실행 항목", "priority": "high|medium|low", "owner_hint": "담당 추정", "due_hint": "기한 힌트"}}
  ],
  "risks": ["주요 리스크"],
  "open_questions": ["미해결 질문"],
  "contradictions": ["상충되는 내용"],
  "recommended_tags": ["추천 태그"],
  "confidence": 0.0,
  "evidence": [
    {{"memo_id": "근거 메모 ID", "quote": "근거 문장", "point": "연결 인사이트"}}
  ]
}}
"""

        fallback = {
            "summary": "카테고리 메모를 기반으로 통합 요약을 생성했습니다.",
            "key_insights": [],
            "action_items": [],
            "risks": [],
            "open_questions": [],
            "contradictions": [],
            "recommended_tags": [],
            "confidence": 0.55,
            "evidence": [],
        }
        payload = await self._generate_json_with_fallback(prompt, fallback)
        return {
            "summary": str(payload.get("summary", fallback["summary"])).strip(),
            "key_insights": _normalize_string_list(payload.get("key_insights"), 12),
            "action_items": self._normalize_action_items(payload.get("action_items")),
            "risks": _normalize_string_list(payload.get("risks"), 12),
            "open_questions": _normalize_string_list(payload.get("open_questions"), 12),
            "contradictions": _normalize_string_list(payload.get("contradictions"), 10),
            "recommended_tags": _normalize_string_list(payload.get("recommended_tags"), 12),
            "confidence": self._normalize_confidence(payload.get("confidence")),
            "evidence": self._normalize_evidence(payload.get("evidence")),
        }

    async def _generate_json_with_fallback(self, prompt: str, fallback: dict) -> dict:
        try:
            raw_text = await self._generate(prompt)
            payload = _extract_json_payload(raw_text)
            if payload is None:
                return fallback
            return payload
        except Exception:
            return fallback

    def _normalize_action_items(self, raw: object) -> list[dict]:
        if not isinstance(raw, list):
            return []
        values: list[dict] = []
        for item in raw:
            if not isinstance(item, dict):
                continue
            task = str(item.get("task", "")).strip()
            if not task:
                continue
            priority = str(item.get("priority", "medium")).strip().lower()
            if priority not in {"high", "medium", "low"}:
                priority = "medium"
            owner_hint = str(item.get("owner_hint", "")).strip()
            due_hint = str(item.get("due_hint", "")).strip()
            values.append({
                "task": _short_text(task, 120),
                "priority": priority,
                "owner_hint": _short_text(owner_hint, 80) if owner_hint else "",
                "due_hint": _short_text(due_hint, 80) if due_hint else "",
            })
            if len(values) >= 15:
                break
        return values

    def _normalize_confidence(self, raw: object) -> float:
        try:
            value = float(raw)
            if math.isnan(value):
                return 0.55
            return max(0.0, min(1.0, value))
        except Exception:
            return 0.55

    def _normalize_evidence(self, raw: object) -> list[dict]:
        if not isinstance(raw, list):
            return []
        values: list[dict] = []
        for item in raw:
            if not isinstance(item, dict):
                continue
            memo_id = str(item.get("memo_id", "")).strip()
            quote = str(item.get("quote", "")).strip()
            point = str(item.get("point", "")).strip()
            if not memo_id or not quote:
                continue
            values.append({
                "memo_id": memo_id,
                "quote": _short_text(quote, 220),
                "point": _short_text(point, 150),
            })
            if len(values) >= 30:
                break
        return values


class MemoCategoryPMAgent(BaseAgent):
    """Planner -> Compactor -> Synthesizer 파이프라인 PM"""

    def __init__(self):
        super().__init__(model_type="pm")
        self.planner = MemoCategoryPlannerAgent()
        self.compactor = MemoContextCompactorAgent()
        self.synthesizer = MemoCategorySynthesizerAgent()

    async def run(
        self,
        category_name: str,
        memos: list[dict],
        requested_focus: Optional[list[str]] = None,
        on_progress: Optional[Callable[[str, str], Any]] = None,
    ) -> dict:
        normalized_memos = self._normalize_memos(memos)
        if not normalized_memos:
            raise ValueError("분석할 메모가 없습니다.")

        if on_progress:
            await on_progress("planning", "started")
        strategy = await self.planner.run(
            category_name=category_name,
            memo_count=len(normalized_memos),
            memo_preview=normalized_memos[:10],
            requested_focus=requested_focus,
        )
        if on_progress:
            await on_progress("planning", "completed")

        if on_progress:
            await on_progress("context_compaction", "started")
        memo_chunks = self._chunk_memos(normalized_memos)
        compacted = await self._compact_chunks(memo_chunks, strategy)
        if on_progress:
            await on_progress("context_compaction", "completed")

        if on_progress:
            await on_progress("synthesis", "started")
        synthesis = await self.synthesizer.run(
            category_name=category_name,
            planner_strategy=strategy,
            compacted_contexts=compacted,
            memo_count=len(normalized_memos),
        )
        if on_progress:
            await on_progress("synthesis", "completed")

        if on_progress:
            await on_progress("quality_validation", "started")
        quality = self._validate_quality(
            memos=normalized_memos,
            compacted=compacted,
            synthesis=synthesis,
        )
        if on_progress:
            await on_progress("quality_validation", "completed")

        if on_progress:
            await on_progress("finalization", "started")
        final_result = {
            "category": category_name,
            "memo_count": len(normalized_memos),
            "planner_strategy": strategy,
            "chunk_count": len(memo_chunks),
            "summary": synthesis.get("summary", ""),
            "key_insights": synthesis.get("key_insights", []),
            "action_items": synthesis.get("action_items", []),
            "risks": synthesis.get("risks", []),
            "open_questions": synthesis.get("open_questions", []),
            "contradictions": synthesis.get("contradictions", []),
            "recommended_tags": synthesis.get("recommended_tags", []),
            "evidence": synthesis.get("evidence", []),
            "confidence": synthesis.get("confidence", 0.55),
            "quality": quality,
            "compacted_contexts": compacted,
            "generated_at": datetime.utcnow().isoformat(),
        }
        if on_progress:
            await on_progress("finalization", "completed")
        return final_result

    def _normalize_memos(self, memos: list[dict]) -> list[dict]:
        normalized: list[dict] = []
        for memo in memos:
            if not isinstance(memo, dict):
                continue
            memo_id = str(memo.get("id", "")).strip()
            if not memo_id:
                continue
            title = str(memo.get("title", "")).strip()
            content = str(memo.get("content", "")).strip()
            tags = _normalize_string_list(memo.get("tags"), 20)
            category_name = str(memo.get("categoryName", "")).strip()
            updated_at = memo.get("updatedAt")
            updated_at_iso = ""
            if isinstance(updated_at, datetime):
                updated_at_iso = updated_at.isoformat()
            elif updated_at is not None:
                updated_at_iso = str(updated_at)
            normalized.append({
                "id": memo_id,
                "title": title,
                "content": content,
                "tags": tags,
                "categoryName": category_name,
                "updatedAt": updated_at_iso,
            })

        normalized.sort(key=lambda x: x.get("updatedAt", ""), reverse=True)
        return normalized

    def _chunk_memos(
        self,
        memos: list[dict],
        max_items: int = 10,
        max_total_chars: int = 7000,
    ) -> list[list[dict]]:
        chunks: list[list[dict]] = []
        current: list[dict] = []
        current_chars = 0
        for memo in memos:
            candidate_chars = len(str(memo.get("title", ""))) + len(str(memo.get("content", "")))
            if current and (
                len(current) >= max_items or current_chars + candidate_chars > max_total_chars
            ):
                chunks.append(current)
                current = []
                current_chars = 0
            current.append(memo)
            current_chars += candidate_chars
        if current:
            chunks.append(current)
        return chunks

    async def _compact_chunks(self, memo_chunks: list[list[dict]], strategy: dict) -> list[dict]:
        semaphore = asyncio.Semaphore(4)

        async def _run(index: int, memos: list[dict]) -> dict:
            async with semaphore:
                return await self.compactor.run(index, memos, strategy)

        tasks = [_run(index + 1, chunk) for index, chunk in enumerate(memo_chunks)]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        compacted: list[dict] = []
        for index, result in enumerate(results):
            if isinstance(result, Exception):
                fallback = self.compactor._fallback_compaction(memo_chunks[index])  # pylint: disable=protected-access
                compacted.append({
                    "chunk_index": index + 1,
                    "summary": fallback.get("summary", ""),
                    "decisions": fallback.get("decisions", []),
                    "actions": fallback.get("actions", []),
                    "risks": fallback.get("risks", []),
                    "questions": fallback.get("questions", []),
                    "entities": fallback.get("entities", []),
                    "evidence": fallback.get("evidence", []),
                    "error": str(result),
                })
            else:
                compacted.append(result)

        compacted.sort(key=lambda x: _coerce_int(x.get("chunk_index"), 0))
        return compacted

    def _validate_quality(self, memos: list[dict], compacted: list[dict], synthesis: dict) -> dict:
        memo_ids = {str(m.get("id", "")).strip() for m in memos if m.get("id")}

        evidence_items: list[dict] = []
        for source in compacted:
            ev = source.get("evidence", [])
            if isinstance(ev, list):
                evidence_items.extend([item for item in ev if isinstance(item, dict)])
        final_evidence = synthesis.get("evidence", [])
        if isinstance(final_evidence, list):
            evidence_items.extend([item for item in final_evidence if isinstance(item, dict)])

        valid_evidence = []
        referenced_memo_ids = set()
        for item in evidence_items:
            memo_id = str(item.get("memo_id", "")).strip()
            quote = str(item.get("quote", "")).strip()
            if memo_id and memo_id in memo_ids and quote:
                valid_evidence.append(item)
                referenced_memo_ids.add(memo_id)

        coverage_ratio = (
            len(referenced_memo_ids) / len(memo_ids)
            if memo_ids
            else 0.0
        )

        raw_confidence = synthesis.get("confidence", 0.55)
        try:
            confidence = float(raw_confidence)
        except Exception:
            confidence = 0.55
        confidence = max(0.0, min(1.0, confidence))

        adjusted_confidence = confidence
        if coverage_ratio >= 0.5:
            adjusted_confidence = min(1.0, confidence + 0.1)
        elif coverage_ratio < 0.2:
            adjusted_confidence = max(0.1, confidence - 0.15)

        return {
            "memo_count": len(memo_ids),
            "evidence_count": len(valid_evidence),
            "evidence_coverage_ratio": round(coverage_ratio, 4),
            "raw_confidence": round(confidence, 4),
            "adjusted_confidence": round(adjusted_confidence, 4),
            "checks": {
                "has_summary": bool(str(synthesis.get("summary", "")).strip()),
                "has_actions": bool(synthesis.get("action_items")),
                "has_evidence": len(valid_evidence) > 0,
            },
        }
