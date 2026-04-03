import google.generativeai as genai
import json
import re
from datetime import datetime, timedelta
from typing import Optional, List
from config import get_settings

settings = get_settings()

# Gemini API 설정
genai.configure(api_key=settings.gemini_api_key)


class GeminiService:
    """Gemini AI 서비스 (일반 요약용 - Lite 모델)"""

    def __init__(self):
        self.model = genai.GenerativeModel(settings.gemini_lite_model)

    async def generate_daily_summary(
        self,
        user_name: str,
        pending_todos: int,
        completed_today: int,
        upcoming_events: int,
        monthly_expense: Optional[int] = None,
        monthly_income: Optional[int] = None,
    ) -> str:
        """일일 요약 생성"""

        expense_info = ""
        if monthly_expense is not None:
            expense_info = f"\n- 이번 달 지출: {monthly_expense:,}원"
            if monthly_income is not None:
                balance = monthly_income - monthly_expense
                expense_info += f"\n- 이번 달 수입: {monthly_income:,}원 (잔액: {balance:,}원)"

        prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 친근한 AI 비서입니다.
{user_name}님에게 오늘의 요약을 2-3문장으로 작성해주세요.

현재 상황:
- 남은 할일: {pending_todos}개
- 오늘 완료한 할일: {completed_today}개
- 다가오는 일정: {upcoming_events}개{expense_info}

작성 지침:
- 따뜻하고 격려하는 톤으로
- 이모지를 적절히 사용
- 구체적인 숫자를 언급
- 한국어로 작성"""

        try:
            response = await self.model.generate_content_async(prompt)
            return response.text.strip()
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_daily_summary(user_name, pending_todos, completed_today)

    async def generate_weekly_summary(
        self,
        user_name: str,
        completed_todos: int,
        total_todos: int,
        events_attended: int,
        weekly_expense: Optional[int] = None,
    ) -> str:
        """주간 요약 생성"""

        completion_rate = (completed_todos / total_todos * 100) if total_todos > 0 else 0

        expense_info = ""
        if weekly_expense is not None:
            expense_info = f"\n- 이번 주 지출: {weekly_expense:,}원"

        prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 친근한 AI 비서입니다.
{user_name}님의 이번 주 활동을 2-3문장으로 요약해주세요.

이번 주 현황:
- 완료한 할일: {completed_todos}개 / {total_todos}개 (완료율: {completion_rate:.0f}%)
- 참여한 일정: {events_attended}개{expense_info}

작성 지침:
- 성과를 칭찬하는 톤
- 다음 주를 위한 간단한 격려
- 이모지 적절히 사용
- 한국어로 작성"""

        try:
            response = await self.model.generate_content_async(prompt)
            return response.text.strip()
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_weekly_summary(user_name, completion_rate)

    async def generate_family_chat_summary(
        self,
        family_name: str,
        messages: List[dict],
    ) -> dict:
        """가족 채팅 요약 생성"""
        if not messages:
            return {
                "summary": "아직 요약할 대화가 없어요.",
                "highlights": [],
            }

        transcript_lines: List[str] = []
        for message in messages:
            sender_name = (message.get("sender_name") or "구성원").strip() or "구성원"
            content = self._normalize_chat_message_content(message)
            created_at = message.get("created_at")
            time_label = ""
            if hasattr(created_at, "strftime"):
                time_label = created_at.strftime("%H:%M")

            if time_label:
                transcript_lines.append(f"[{time_label}] {sender_name}: {content}")
            else:
                transcript_lines.append(f"{sender_name}: {content}")

        transcript = "\n".join(transcript_lines)

        prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 가족 채팅 요약 에이전트입니다.
아래 가족 채팅 최근 대화를 읽고 JSON만 응답하세요.

응답 형식:
{{
  "summary": "최근 대화 핵심을 2-3문장으로 요약",
  "highlights": ["핵심 포인트 1", "핵심 포인트 2", "핵심 포인트 3"]
}}

작성 지침:
- 한국어로 작성
- 실제 대화에 나온 내용만 요약
- 추측이나 과장 금지
- 비난 없이 중립적인 톤 유지
- highlights는 최대 3개
- 일정, 약속, 할 일처럼 보이는 내용이 있으면 우선 포함

가족 이름: {family_name}
최근 대화:
{transcript}
"""

        try:
            response = await self.model.generate_content_async(prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            parsed = json.loads(text)
            raw_highlights = parsed.get("highlights") or []
            highlights = [
                str(item).strip()
                for item in raw_highlights
                if str(item).strip()
            ][:3]
            return {
                "summary": str(parsed.get("summary") or "").strip()
                or self._fallback_family_chat_summary(family_name, messages)["summary"],
                "highlights": highlights,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_family_chat_summary(family_name, messages)

    async def generate_memo_summary(
        self,
        content: str,
        category_name: Optional[str] = None,
        memo_title: Optional[str] = None,
    ) -> dict:
        """개인 메모 요약/검증 생성"""
        normalized_content = content.strip()
        if len(normalized_content) < 20:
            return self._fallback_memo_summary(
                normalized_content,
                memo_title=memo_title,
            )

        title_context = ""
        if memo_title and memo_title.strip():
            title_context = f"\n메모 제목: {memo_title.strip()}"

        category_context = ""
        if category_name and category_name.strip():
            category_context = f"\n참고 카테고리: {category_name.strip()}"

        prompt = f"""당신은 개인 메모 요약/검증 에이전트입니다.
아래 메모를 읽고 반드시 JSON으로만 응답하세요.{title_context}{category_context}

요구사항:
1) summary: 메모 핵심을 1-2문장으로 요약
2) validation_points: 메모 품질 검증 포인트 2-4개
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

작성 지침:
- 한국어로 작성
- 실제 메모 내용에 근거해 요약
- 과도한 추측 금지
- 메모를 더 명확하게 만들 수 있는 지점 우선 언급

메모 내용:
{normalized_content}
"""

        try:
            response = await self.model.generate_content_async(prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            parsed = json.loads(text)
            summary = str(parsed.get("summary") or "").strip()
            validation_points = [
                str(item).strip()
                for item in (parsed.get("validation_points") or [])
                if str(item).strip()
            ][:6]
            suggested_tags = [
                str(item).strip()
                for item in (parsed.get("suggested_tags") or [])
                if str(item).strip()
            ][:5]
            suggested_category = str(parsed.get("suggested_category") or "").strip()
            analysis = str(parsed.get("analysis") or "").strip()

            fallback = self._fallback_memo_summary(
                normalized_content,
                memo_title=memo_title,
            )
            if not summary:
                summary = fallback["summary"]
            if not analysis:
                analysis = fallback["analysis"]

            return {
                "summary": summary,
                "analysis": analysis,
                "validation_points": validation_points,
                "suggested_category": suggested_category or None,
                "suggested_tags": suggested_tags,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_memo_summary(
                normalized_content,
                memo_title=memo_title,
            )

    async def plan_personal_todo_create(
        self,
        prompt: str,
        current_time_iso: str,
    ) -> dict:
        """자연어 입력을 개인 todo 생성 preview로 구조화"""
        normalized_prompt = prompt.strip()
        if not normalized_prompt:
            return self._fallback_personal_todo_plan(normalized_prompt)

        planning_prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 개인 할 일 생성 에이전트입니다.
사용자 입력을 읽고 개인(private) todo 1건 생성 초안을 JSON으로만 응답하세요.

현재 기준 시각: {current_time_iso}

응답 JSON 스키마:
{{
  "title": "짧고 명확한 할 일 제목",
  "note": "세부 메모 또는 null",
  "due_date_iso": "절대 시각 ISO 8601 또는 null",
  "priority": 0,
  "reminder_minutes": [60],
  "summary": "이 작업을 어떻게 생성할지 1문장 설명"
}}

규칙:
- 한국어로 작성
- title은 40자 이내
- note는 필요 없으면 null
- due_date_iso는 날짜/시간이 명확할 때만 설정
- priority는 0(낮음), 1(보통), 2(높음) 중 하나
- reminder_minutes는 due_date_iso가 있을 때만 최대 2개
- shared/group/family 범위로 쓰지 말고 항상 개인 할 일 기준으로 정리
- JSON 이외의 텍스트 금지

사용자 입력:
{normalized_prompt}
"""

        try:
            response = await self.model.generate_content_async(planning_prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)
            title = str(parsed.get("title") or "").strip()[:40]
            if not title:
                return self._fallback_personal_todo_plan(normalized_prompt)

            due_date = self._parse_optional_datetime(parsed.get("due_date_iso"))
            priority = parsed.get("priority")
            try:
                priority = int(priority)
            except (TypeError, ValueError):
                priority = 1
            priority = min(max(priority, 0), 2)

            reminder_minutes = self._normalize_reminder_minutes(
                parsed.get("reminder_minutes"),
                allow_values=due_date is not None,
            )
            note = str(parsed.get("note") or "").strip() or None
            summary = str(parsed.get("summary") or "").strip()
            if not summary:
                summary = self._build_todo_plan_summary(title, due_date, priority)

            return {
                "title": title,
                "note": note,
                "due_date": due_date,
                "priority": priority,
                "reminder_minutes": reminder_minutes,
                "summary": summary,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_personal_todo_plan(normalized_prompt)

    async def plan_personal_todo_complete(
        self,
        prompt: str,
        pending_todos: List[dict],
        current_time_iso: str,
    ) -> Optional[dict]:
        """자연어 입력을 개인 todo 완료 preview로 구조화"""
        normalized_prompt = prompt.strip()
        if not normalized_prompt or not pending_todos:
            return self._fallback_personal_todo_complete_plan(
                normalized_prompt,
                pending_todos,
            )

        candidates: List[str] = []
        for item in pending_todos[:20]:
            due_date = item.get("due_date")
            if isinstance(due_date, datetime):
                if due_date.hour == 0 and due_date.minute == 0:
                    due_label = due_date.strftime("%m월 %d일")
                else:
                    due_label = due_date.strftime("%m월 %d일 %H:%M")
            else:
                due_label = "-"

            note = str(item.get("note") or "").strip()
            note_label = note[:60] if note else "-"
            candidates.append(
                f'- id={item["id"]} | title={str(item.get("title") or "").strip()} '
                f'| note={note_label} | due={due_label}'
            )

        candidate_block = "\n".join(candidates)
        planning_prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 개인 할 일 완료 에이전트입니다.
아래 pending private todo 후보 중에서 사용자 요청과 가장 잘 맞는 1건만 선택하고 JSON으로만 응답하세요.
애매하면 todo_id를 null로 반환하세요.

현재 기준 시각: {current_time_iso}

응답 JSON 스키마:
{{
  "todo_id": "선택한 todo id 또는 null",
  "summary": "왜 이 할 일을 완료 처리하는지 1문장",
  "reason": "매칭 근거를 짧게 설명"
}}

규칙:
- 한국어로 작성
- 후보 목록에 없는 id를 만들지 말 것
- 명시적 근거가 부족하면 todo_id는 null
- shared/group/family 범위로 확장하지 말고 개인 todo만 고를 것
- JSON 이외의 텍스트 금지

후보 목록:
{candidate_block}

사용자 요청:
{normalized_prompt}
"""

        try:
            response = await self.model.generate_content_async(planning_prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)
            todo_id = str(parsed.get("todo_id") or "").strip()
            if not todo_id:
                return self._fallback_personal_todo_complete_plan(
                    normalized_prompt,
                    pending_todos,
                )

            candidate = next(
                (
                    item
                    for item in pending_todos
                    if str(item.get("id") or "").strip() == todo_id
                ),
                None,
            )
            if candidate is None:
                return self._fallback_personal_todo_complete_plan(
                    normalized_prompt,
                    pending_todos,
                )

            summary = str(parsed.get("summary") or "").strip()
            if not summary:
                summary = self._build_todo_complete_summary(candidate)

            reason = str(parsed.get("reason") or "").strip() or None
            return {
                "todo_id": todo_id,
                "title": str(candidate.get("title") or "").strip(),
                "note": str(candidate.get("note") or "").strip() or None,
                "due_date": candidate.get("due_date"),
                "visibility": str(candidate.get("visibility") or "private"),
                "summary": summary,
                "reason": reason,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_personal_todo_complete_plan(
                normalized_prompt,
                pending_todos,
            )

    async def plan_personal_calendar_create(
        self,
        prompt: str,
        current_time_iso: str,
        selected_date_iso: Optional[str] = None,
    ) -> dict:
        """자연어 입력을 개인 일정 생성 preview로 구조화"""
        normalized_prompt = prompt.strip()
        selected_date = self._parse_optional_datetime(selected_date_iso)
        if not normalized_prompt:
            return self._fallback_personal_calendar_create_plan(
                normalized_prompt,
                selected_date=selected_date,
            )

        selected_date_context = ""
        if selected_date is not None:
            selected_date_context = (
                f"\n기본 선택 날짜: {selected_date.strftime('%Y-%m-%d')}"
                "\n사용자 문장에 날짜가 없으면 이 날짜를 우선 사용하세요."
            )

        planning_prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 개인 일정 생성 에이전트입니다.
사용자 입력을 읽고 개인(private) 일정 1건 생성 초안을 JSON으로만 응답하세요.

현재 기준 시각: {current_time_iso}{selected_date_context}

응답 JSON 스키마:
{{
  "title": "짧고 명확한 일정 제목",
  "note": "세부 메모 또는 null",
  "event_type": "schedule",
  "due_date_iso": "일정 날짜 ISO 8601 또는 null",
  "start_time_iso": "시작 시각 ISO 8601 또는 null",
  "end_time_iso": "종료 시각 ISO 8601 또는 null",
  "has_time": true,
  "location": "장소 또는 null",
  "reminder_minutes": [60],
  "summary": "이 일정을 어떻게 생성할지 1문장 설명"
}}

규칙:
- 한국어로 작성
- title은 40자 이내
- event_type은 schedule 또는 event
- 시간 정보가 분명하면 has_time=true 와 start/end 시각을 함께 설정
- 시간이 없으면 has_time=false, start/end는 null
- due_date_iso는 일정 날짜 기준으로 항상 채우기
- reminder_minutes는 일정 시각이 있을 때만 최대 2개
- shared/group/family 범위로 쓰지 말고 항상 개인 일정 기준으로 정리
- JSON 이외의 텍스트 금지

사용자 입력:
{normalized_prompt}
"""

        try:
            response = await self.model.generate_content_async(planning_prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)
            title = str(parsed.get("title") or "").strip()[:40]
            if not title:
                return self._fallback_personal_calendar_create_plan(
                    normalized_prompt,
                    selected_date=selected_date,
                )

            due_date = self._parse_optional_datetime(parsed.get("due_date_iso"))
            start_time = self._parse_optional_datetime(parsed.get("start_time_iso"))
            end_time = self._parse_optional_datetime(parsed.get("end_time_iso"))
            has_time = bool(parsed.get("has_time"))

            if due_date is None:
                if start_time is not None:
                    due_date = datetime(
                        start_time.year,
                        start_time.month,
                        start_time.day,
                    )
                elif selected_date is not None:
                    due_date = datetime(
                        selected_date.year,
                        selected_date.month,
                        selected_date.day,
                    )

            if has_time and start_time is None and due_date is not None:
                has_time = False
            if has_time and start_time is not None and end_time is None:
                end_time = start_time.replace(minute=start_time.minute) + self._one_hour()

            event_type = str(parsed.get("event_type") or "").strip().lower()
            if event_type not in {"schedule", "event"}:
                event_type = "schedule"

            reminder_minutes = self._normalize_reminder_minutes(
                parsed.get("reminder_minutes"),
                allow_values=has_time and start_time is not None,
            )
            note = str(parsed.get("note") or "").strip() or None
            location = str(parsed.get("location") or "").strip() or None
            summary = str(parsed.get("summary") or "").strip()
            if not summary:
                summary = self._build_calendar_plan_summary(
                    title=title,
                    due_date=due_date,
                    start_time=start_time,
                    event_type=event_type,
                )

            return {
                "title": title,
                "note": note,
                "event_type": event_type,
                "due_date": due_date,
                "start_time": start_time if has_time else None,
                "end_time": end_time if has_time else None,
                "has_time": has_time and start_time is not None,
                "location": location,
                "reminder_minutes": reminder_minutes,
                "summary": summary,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_personal_calendar_create_plan(
                normalized_prompt,
                selected_date=selected_date,
            )

    async def plan_personal_calendar_update(
        self,
        prompt: str,
        calendar_items: List[dict],
        current_time_iso: str,
        selected_date_iso: Optional[str] = None,
    ) -> Optional[dict]:
        """자연어 입력을 개인 일정 수정 preview로 구조화"""
        normalized_prompt = prompt.strip()
        selected_date = self._parse_optional_datetime(selected_date_iso)
        if not normalized_prompt or not calendar_items:
            return self._fallback_personal_calendar_update_plan(
                normalized_prompt,
                calendar_items,
                selected_date=selected_date,
            )

        candidates: List[str] = []
        for item in calendar_items[:20]:
            due_date = item.get("due_date")
            if isinstance(due_date, datetime):
                due_label = due_date.strftime("%m월 %d일")
            else:
                due_label = "-"

            start_time = item.get("start_time")
            end_time = item.get("end_time")
            if isinstance(start_time, datetime):
                time_label = start_time.strftime("%H:%M")
                if isinstance(end_time, datetime):
                    time_label = f"{time_label} - {end_time.strftime('%H:%M')}"
            else:
                time_label = "-"

            location = str(item.get("location") or "").strip()
            note = str(item.get("note") or "").strip()
            candidates.append(
                f'- event_id={item["id"]} | title={str(item.get("title") or "").strip()} '
                f'| type={str(item.get("event_type") or "schedule").strip()} '
                f'| due={due_label} | time={time_label} '
                f'| location={location or "-"} | note={(note[:60] if note else "-")}'
            )

        selected_date_context = ""
        if selected_date is not None:
            selected_date_context = (
                f"\n현재 사용자가 보고 있는 날짜: {selected_date.strftime('%Y-%m-%d')}"
                "\n사용자 문장이 상대 날짜만 말할 때 이 날짜 문맥을 참고할 수 있습니다."
            )

        planning_prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 개인 일정 수정 에이전트입니다.
아래 private 개인 일정 후보 중에서 사용자 요청과 가장 잘 맞는 1건을 고르고,
수정 후의 전체 상태를 JSON으로만 응답하세요. 애매하면 event_id를 null로 반환하세요.

현재 기준 시각: {current_time_iso}{selected_date_context}

응답 JSON 스키마:
{{
  "event_id": "선택한 일정 id 또는 null",
  "title": "수정 후 제목",
  "note": "수정 후 메모 또는 null",
  "due_date_iso": "수정 후 날짜 ISO 8601 또는 null",
  "start_time_iso": "수정 후 시작 시각 ISO 8601 또는 null",
  "end_time_iso": "수정 후 종료 시각 ISO 8601 또는 null",
  "has_time": true,
  "location": "수정 후 장소 또는 null",
  "reminder_minutes": [60],
  "summary": "무엇을 어떻게 바꾸는지 1문장 설명",
  "reason": "왜 이 일정을 골랐는지 짧게 설명"
}}

규칙:
- 한국어로 작성
- 후보 목록에 없는 id를 만들지 말 것
- 명시되지 않은 값은 현재 값을 유지
- title은 40자 이내
- 시간 제거 요청이면 has_time=false, start/end는 null, reminder_minutes는 []
- 시간이 있으면 has_time=true, start_time_iso를 함께 채울 것
- 장소/메모 삭제 요청은 null로 표현
- shared/group/family 범위로 확장하지 말고 개인 일정만 수정할 것
- JSON 이외의 텍스트 금지

후보 목록:
{chr(10).join(candidates)}

사용자 요청:
{normalized_prompt}
"""

        try:
            response = await self.model.generate_content_async(planning_prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)
            event_id = str(parsed.get("event_id") or "").strip()
            if not event_id:
                return self._fallback_personal_calendar_update_plan(
                    normalized_prompt,
                    calendar_items,
                    selected_date=selected_date,
                )

            candidate = next(
                (
                    item
                    for item in calendar_items
                    if str(item.get("id") or "").strip() == event_id
                ),
                None,
            )
            if candidate is None:
                return self._fallback_personal_calendar_update_plan(
                    normalized_prompt,
                    calendar_items,
                    selected_date=selected_date,
                )

            current_title = str(candidate.get("title") or "").strip() or "개인 일정"
            title = str(parsed.get("title") or "").strip()[:40] or current_title

            if "note" in parsed:
                note = str(parsed.get("note") or "").strip() or None
            else:
                note = str(candidate.get("note") or "").strip() or None

            if "location" in parsed:
                location = str(parsed.get("location") or "").strip() or None
            else:
                location = str(candidate.get("location") or "").strip() or None

            current_due_date = candidate.get("due_date")
            if not isinstance(current_due_date, datetime):
                current_due_date = None
            current_start_time = candidate.get("start_time")
            if not isinstance(current_start_time, datetime):
                current_start_time = None
            current_end_time = candidate.get("end_time")
            if not isinstance(current_end_time, datetime):
                current_end_time = None
            current_has_time = bool(candidate.get("has_time")) and current_start_time is not None

            due_date = (
                self._parse_optional_datetime(parsed.get("due_date_iso"))
                if "due_date_iso" in parsed
                else current_due_date
            )
            start_time = (
                self._parse_optional_datetime(parsed.get("start_time_iso"))
                if "start_time_iso" in parsed
                else current_start_time
            )
            end_time = (
                self._parse_optional_datetime(parsed.get("end_time_iso"))
                if "end_time_iso" in parsed
                else current_end_time
            )

            if "has_time" in parsed:
                has_time = bool(parsed.get("has_time"))
            else:
                has_time = current_has_time

            if due_date is None:
                if start_time is not None:
                    due_date = datetime(start_time.year, start_time.month, start_time.day)
                elif current_start_time is not None:
                    due_date = datetime(
                        current_start_time.year,
                        current_start_time.month,
                        current_start_time.day,
                    )
                elif selected_date is not None and current_due_date is None:
                    due_date = datetime(
                        selected_date.year,
                        selected_date.month,
                        selected_date.day,
                    )

            if has_time:
                if start_time is None:
                    start_time = current_start_time
                if start_time is None:
                    has_time = False
                elif end_time is None:
                    end_time = current_end_time or (start_time + self._one_hour())

            if not has_time:
                start_time = None
                end_time = None

            reminder_source = (
                parsed.get("reminder_minutes")
                if "reminder_minutes" in parsed
                else candidate.get("reminder_minutes")
            )
            reminder_minutes = self._normalize_reminder_minutes(
                reminder_source,
                allow_values=has_time and start_time is not None,
            )

            event_type = str(candidate.get("event_type") or "schedule").strip().lower()
            if event_type not in {"schedule", "event"}:
                event_type = "schedule"

            summary = str(parsed.get("summary") or "").strip()
            if not summary:
                summary = self._build_calendar_update_summary(
                    candidate,
                    title=title,
                    due_date=due_date,
                    start_time=start_time,
                    event_type=event_type,
                )

            reason = str(parsed.get("reason") or "").strip() or None
            return {
                "event_id": event_id,
                "title": title,
                "note": note,
                "event_type": event_type,
                "due_date": due_date,
                "start_time": start_time,
                "end_time": end_time,
                "has_time": has_time and start_time is not None,
                "location": location,
                "reminder_minutes": reminder_minutes,
                "visibility": str(candidate.get("visibility") or "private"),
                "summary": summary,
                "reason": reason,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_personal_calendar_update_plan(
                normalized_prompt,
                calendar_items,
                selected_date=selected_date,
            )

    async def plan_personal_note_create(
        self,
        prompt: str,
        current_time_iso: str,
    ) -> dict:
        """자연어 입력을 개인 메모 생성 preview로 구조화"""
        normalized_prompt = prompt.strip()
        if not normalized_prompt:
            return self._fallback_personal_note_create_plan(normalized_prompt)

        planning_prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 개인 메모 생성 에이전트입니다.
사용자 입력을 읽고 개인 메모 1건 생성 초안을 JSON으로만 응답하세요.

현재 기준 시각: {current_time_iso}

응답 JSON 스키마:
{{
  "title": "메모 제목",
  "content": "메모 본문",
  "category_name": "추천 카테고리 이름 또는 null",
  "tags": ["태그1", "태그2"],
  "is_pinned": false,
  "summary": "이 메모를 어떻게 만들지 1문장 설명"
}}

규칙:
- 한국어로 작성
- title은 40자 이내
- content는 실제로 저장 가능한 메모 본문 형태로 정리
- category_name은 확신이 없으면 null
- tags는 최대 5개
- is_pinned는 특별히 강조가 필요한 경우가 아니면 false
- shared/group/family 범위로 확장하지 말고 개인 메모 기준으로 정리
- JSON 이외의 텍스트 금지

사용자 입력:
{normalized_prompt}
"""

        try:
            response = await self.model.generate_content_async(planning_prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)
            title = str(parsed.get("title") or "").strip()[:40]
            content = str(parsed.get("content") or "").strip()
            if not title and not content:
                return self._fallback_personal_note_create_plan(normalized_prompt)
            if not title:
                title = (content[:40] or normalized_prompt[:40] or "새 메모").strip()

            category_name = str(parsed.get("category_name") or "").strip() or None
            tags = self._normalize_note_tags(parsed.get("tags"))
            is_pinned = bool(parsed.get("is_pinned"))
            summary = str(parsed.get("summary") or "").strip()
            if not summary:
                summary = self._build_note_create_summary(
                    title=title,
                    category_name=category_name,
                )

            return {
                "title": title,
                "content": content or normalized_prompt,
                "category_name": category_name,
                "tags": tags,
                "is_pinned": is_pinned,
                "summary": summary,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_personal_note_create_plan(normalized_prompt)

    async def plan_personal_note_update(
        self,
        prompt: str,
        memos: List[dict],
        current_time_iso: str,
    ) -> Optional[dict]:
        """자연어 입력을 개인 메모 수정 preview로 구조화"""
        normalized_prompt = prompt.strip()
        if not normalized_prompt or not memos:
            return self._fallback_personal_note_update_plan(normalized_prompt, memos)

        candidates: List[str] = []
        for item in memos[:20]:
            title = str(item.get("title") or "").strip()
            content = str(item.get("content") or "").strip()
            category_name = str(item.get("category_name") or "").strip()
            tags = item.get("tags") or []
            tag_label = ", ".join([str(tag).strip() for tag in tags if str(tag).strip()][:4])
            snippet = content[:80] if content else "-"
            candidates.append(
                f'- memo_id={item["id"]} | title={title} | category={category_name or "-"} '
                f'| tags={tag_label or "-"} | content={snippet or "-"}'
            )

        planning_prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 개인 메모 수정 에이전트입니다.
아래 개인 메모 후보 중에서 사용자 요청과 가장 잘 맞는 1건을 고르고, 수정 후의 전체 메모 상태를 JSON으로만 응답하세요.
애매하면 memo_id를 null로 반환하세요.

현재 기준 시각: {current_time_iso}

응답 JSON 스키마:
{{
  "memo_id": "선택한 memo id 또는 null",
  "title": "수정 후 제목",
  "content": "수정 후 전체 본문",
  "category_name": "수정 후 카테고리 이름 또는 null",
  "tags": ["수정 후 태그"],
  "is_pinned": false,
  "summary": "무엇을 어떻게 바꾸는지 1문장 설명",
  "reason": "왜 이 메모를 골랐는지 짧게 설명"
}}

규칙:
- 한국어로 작성
- 후보 목록에 없는 id를 만들지 말 것
- 명시되지 않은 값은 현재 값을 유지
- title은 40자 이내
- tags는 최대 5개
- category_name이 불확실하면 현재 값을 유지
- shared/group/family 범위로 확장하지 말고 개인 메모만 수정할 것
- JSON 이외의 텍스트 금지

후보 목록:
{chr(10).join(candidates)}

사용자 요청:
{normalized_prompt}
"""

        try:
            response = await self.model.generate_content_async(planning_prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)
            memo_id = str(parsed.get("memo_id") or "").strip()
            if not memo_id:
                return self._fallback_personal_note_update_plan(normalized_prompt, memos)

            candidate = next(
                (
                    item
                    for item in memos
                    if str(item.get("id") or "").strip() == memo_id
                ),
                None,
            )
            if candidate is None:
                return self._fallback_personal_note_update_plan(normalized_prompt, memos)

            current_title = str(candidate.get("title") or "").strip() or "메모"
            current_content = str(candidate.get("content") or "").strip()
            current_category_name = str(candidate.get("category_name") or "").strip() or None
            current_tags = self._normalize_note_tags(candidate.get("tags"))
            current_is_pinned = bool(candidate.get("is_pinned"))

            title = str(parsed.get("title") or "").strip()[:40] or current_title

            if "content" in parsed:
                content = str(parsed.get("content") or "").strip() or current_content
            else:
                content = current_content

            if "category_name" in parsed:
                category_name = str(parsed.get("category_name") or "").strip() or None
            else:
                category_name = current_category_name

            if "tags" in parsed:
                tags = self._normalize_note_tags(parsed.get("tags"))
            else:
                tags = current_tags

            if "is_pinned" in parsed:
                is_pinned = bool(parsed.get("is_pinned"))
            else:
                is_pinned = current_is_pinned

            summary = str(parsed.get("summary") or "").strip()
            if not summary:
                summary = self._build_note_update_summary(
                    candidate,
                    title=title,
                    category_name=category_name,
                )

            reason = str(parsed.get("reason") or "").strip() or None
            return {
                "memo_id": memo_id,
                "title": title,
                "content": content,
                "category_name": category_name,
                "tags": tags,
                "is_pinned": is_pinned,
                "summary": summary,
                "reason": reason,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_personal_note_update_plan(normalized_prompt, memos)

    async def plan_personal_reminder_create(
        self,
        prompt: str,
        current_time_iso: str,
    ) -> dict:
        """자연어 입력을 개인 리마인더 생성 preview로 구조화"""
        normalized_prompt = prompt.strip()
        current_time = self._parse_optional_datetime(current_time_iso) or datetime.utcnow()
        if not normalized_prompt:
            return self._fallback_personal_reminder_create_plan(
                normalized_prompt,
                current_time=current_time,
            )

        planning_prompt = f"""당신은 가족 일정 관리 앱 'BABBA'의 개인 리마인더 생성 에이전트입니다.
사용자 입력을 읽고 개인 리마인더 1건 생성 초안을 JSON으로만 응답하세요.

현재 기준 시각: {current_time_iso}

응답 JSON 스키마:
{{
  "message": "리마인더 문구",
  "remind_at_iso": "2026-03-14T09:00:00",
  "recurrence": "daily|weekly|monthly|null",
  "summary": "이 리마인더를 어떻게 만들지 1문장 설명"
}}

규칙:
- 한국어로 작성
- remind_at_iso는 반드시 미래 시각으로 작성
- 사용자가 날짜만 말하면 기본 시각은 오전 9시로 보정
- recurrence는 반복 요청이 명시된 경우에만 daily, weekly, monthly 중 하나를 사용
- shared/group/family 범위로 확장하지 말고 개인 리마인더 기준으로 정리
- JSON 이외의 텍스트 금지

사용자 입력:
{normalized_prompt}
"""

        try:
            response = await self.model.generate_content_async(planning_prompt)
            text = (response.text or "").strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]

            parsed = json.loads(text)
            message = str(parsed.get("message") or "").strip()[:120]
            remind_at = self._parse_optional_datetime(parsed.get("remind_at_iso"))
            recurrence = self._normalize_recurrence(parsed.get("recurrence"))
            if not message or remind_at is None:
                return self._fallback_personal_reminder_create_plan(
                    normalized_prompt,
                    current_time=current_time,
                )

            summary = str(parsed.get("summary") or "").strip()
            if not summary:
                summary = self._build_reminder_create_summary(
                    message=message,
                    remind_at=remind_at,
                    recurrence=recurrence,
                )

            return {
                "message": message,
                "remind_at": remind_at,
                "recurrence": recurrence,
                "summary": summary,
            }
        except Exception as e:
            print(f"Gemini API error: {e}")
            return self._fallback_personal_reminder_create_plan(
                normalized_prompt,
                current_time=current_time,
            )

    async def analyze_business_idea(
        self,
        idea: str,
        industry: Optional[str] = None,
        target_market: Optional[str] = None,
        budget: Optional[str] = None,
    ) -> dict:
        """사업 아이디어 분석"""

        context = ""
        if industry:
            context += f"\n- 산업: {industry}"
        if target_market:
            context += f"\n- 타겟 시장: {target_market}"
        if budget:
            context += f"\n- 예산: {budget}"

        prompt = f"""당신은 스타트업 비즈니스 컨설턴트입니다.
다음 사업 아이디어를 분석해주세요.

사업 아이디어:
{idea}
{context}

다음 JSON 형식으로 응답해주세요:
{{
    "strengths": ["강점1", "강점2", "강점3"],
    "weaknesses": ["약점1", "약점2"],
    "opportunities": ["기회1", "기회2"],
    "threats": ["위협1", "위협2"],
    "market_size": "예상 시장 규모 설명",
    "competitors": ["경쟁사1", "경쟁사2"],
    "recommendation": "종합 추천 의견 (2-3문장)",
    "next_steps": ["다음 단계1", "다음 단계2", "다음 단계3"],
    "score": 75
}}

score는 0-100 사이의 정수로, 사업성 점수입니다."""

        try:
            response = await self.model.generate_content_async(prompt)
            # JSON 파싱 시도
            import json
            text = response.text.strip()
            # ```json ... ``` 형식 처리
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            return json.loads(text)
        except Exception as e:
            print(f"Gemini API error: {e}")
            return {
                "strengths": ["분석 중 오류가 발생했습니다"],
                "weaknesses": [],
                "opportunities": [],
                "threats": [],
                "market_size": "분석 불가",
                "competitors": [],
                "recommendation": "다시 시도해주세요.",
                "next_steps": [],
                "score": 0,
            }

    async def chat_business(self, history: List[dict], user_message: str) -> str:
        """사업 검토 대화"""

        system_prompt = """당신은 스타트업 비즈니스 컨설턴트입니다.
사용자의 사업 아이디어에 대해 건설적인 피드백을 제공하세요.
질문을 통해 아이디어를 구체화하도록 도와주세요.
한국어로 응답하세요."""

        # 대화 히스토리 구성
        messages = [{"role": "user", "parts": [system_prompt]}]
        for msg in history:
            messages.append({"role": msg["role"], "parts": [msg["content"]]})
        messages.append({"role": "user", "parts": [user_message]})

        try:
            chat = self.model.start_chat(history=messages[:-1])
            response = await chat.send_message_async(user_message)
            return response.text.strip()
        except Exception as e:
            print(f"Gemini API error: {e}")
            return "죄송합니다. 응답을 생성하는 중 오류가 발생했습니다. 다시 시도해주세요."

    async def generate_psychology_result(
        self,
        test_type: str,
        answers: List[dict],
        scores: dict,
    ) -> dict:
        """심리검사 결과 분석"""

        prompt = f"""당신은 심리상담 전문가입니다.
다음 심리검사 결과를 분석해주세요.

검사 유형: {test_type}
점수: {scores}

다음 JSON 형식으로 응답해주세요:
{{
    "summary": "전체 결과 요약 (2-3문장)",
    "detailed_analysis": "상세 분석 (3-4문장)",
    "recommendations": ["추천1", "추천2", "추천3"],
    "positive_aspects": ["긍정적 측면1", "긍정적 측면2"],
    "areas_for_growth": ["성장 영역1", "성장 영역2"]
}}

따뜻하고 지지적인 톤으로 작성하세요. 한국어로 응답하세요."""

        try:
            response = await self.model.generate_content_async(prompt)
            import json
            text = response.text.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            return json.loads(text)
        except Exception as e:
            print(f"Gemini API error: {e}")
            return {
                "summary": "검사 결과 분석 중 오류가 발생했습니다.",
                "detailed_analysis": "",
                "recommendations": ["전문 상담사와 상담을 권장합니다."],
                "positive_aspects": [],
                "areas_for_growth": [],
            }

    def _fallback_daily_summary(self, user_name: str, pending: int, completed: int) -> str:
        """일일 요약 폴백"""
        if pending == 0 and completed == 0:
            return f"안녕하세요 {user_name}님! 오늘의 할일을 추가해보세요 ✨"
        elif pending == 0:
            return f"대단해요 {user_name}님! 할일을 모두 완료했어요 🎉"
        elif pending <= 3:
            return f"{user_name}님, 오늘 할일 {pending}개만 남았어요. 조금만 더 힘내세요! 💪"
        else:
            return f"{user_name}님, 오늘 할일이 {pending}개 있어요. 하나씩 해결해봐요! 📝"

    def _fallback_weekly_summary(self, user_name: str, rate: float) -> str:
        """주간 요약 폴백"""
        if rate >= 80:
            return f"{user_name}님, 이번 주 완료율 {rate:.0f}%! 정말 잘하셨어요! 🎉"
        elif rate >= 50:
            return f"{user_name}님, 이번 주 완료율 {rate:.0f}%예요. 다음 주도 화이팅! 💪"
        else:
            return f"{user_name}님, 이번 주 완료율 {rate:.0f}%네요. 다음 주는 더 잘할 수 있어요! ✨"

    def _normalize_chat_message_content(self, message: dict) -> str:
        """첨부/시스템 메시지를 요약용 텍스트로 정규화"""
        message_type = (message.get("type") or "text").strip()
        content = (message.get("content") or "").strip()
        attachment_name = (message.get("attachment_name") or "").strip()

        if message_type == "image":
            if content and content != "사진":
                return f"[사진] {content[:120]}"
            return "[사진 공유]"
        if message_type == "file":
            if attachment_name:
                return f"[파일] {attachment_name}"
            return "[파일 공유]"
        if message_type == "system":
            return f"[시스템] {content[:120]}"

        if content:
            return content[:180]
        return "[내용 없음]"

    def _fallback_family_chat_summary(
        self,
        family_name: str,
        messages: List[dict],
    ) -> dict:
        """가족 채팅 요약 폴백"""
        if not messages:
            return {
                "summary": "아직 요약할 대화가 없어요.",
                "highlights": [],
            }

        participant_names = []
        for message in messages:
            sender_id = (message.get("sender_id") or "").strip()
            sender_name = (message.get("sender_name") or "구성원").strip() or "구성원"
            if sender_id == "system":
                continue
            if sender_name not in participant_names:
                participant_names.append(sender_name)

        participant_count = len(participant_names)
        last_message = messages[-1]
        last_sender = (last_message.get("sender_name") or "구성원").strip() or "구성원"
        last_content = self._normalize_chat_message_content(last_message)

        summary = (
            f"{family_name} 가족의 최근 대화 {len(messages)}개를 확인했어요. "
            f"{participant_count}명이 참여했고, 가장 최근 메시지는 {last_sender}님이 남겼어요."
        )

        highlights = [
            f"최근 메시지 {len(messages)}개를 읽었어요.",
            f"대화 참여 인원은 {participant_count}명이에요.",
            f"가장 최근 메시지: {last_sender}님 - {last_content[:40]}",
        ]

        return {
            "summary": summary,
            "highlights": highlights,
        }

    def _fallback_memo_summary(
        self,
        content: str,
        memo_title: Optional[str] = None,
    ) -> dict:
        """메모 요약 폴백"""
        normalized_content = content.strip()
        if not normalized_content:
            return {
                "summary": "아직 요약할 메모 내용이 없어요.",
                "analysis": "메모 내용을 더 작성한 뒤 다시 요약해 보세요.",
                "validation_points": [],
                "suggested_category": None,
                "suggested_tags": [],
            }

        first_line = ""
        for line in normalized_content.splitlines():
            candidate = line.strip()
            if candidate:
                first_line = candidate
                break
        if not first_line:
            first_line = normalized_content

        summary = first_line[:160]
        title_label = (memo_title or "").strip()
        if title_label:
            analysis = (
                f'"{title_label}" 메모의 핵심 내용을 먼저 정리했어요. '
                "중요한 결정이나 다음 행동이 있다면 한 줄로 더 명확하게 적어두면 좋아요."
            )
        else:
            analysis = (
                "메모의 핵심 내용을 먼저 정리했어요. "
                "중요한 결정이나 다음 행동이 있다면 한 줄로 더 명확하게 적어두면 좋아요."
            )

        return {
            "summary": summary,
            "analysis": analysis,
            "validation_points": [],
            "suggested_category": None,
            "suggested_tags": [],
        }

    def _parse_optional_datetime(self, raw: Optional[str]) -> Optional[datetime]:
        """ISO 문자열을 datetime으로 파싱"""
        if raw is None:
            return None

        value = str(raw).strip()
        if not value:
            return None

        candidates = [value]
        if value.endswith("Z"):
            candidates.append(f"{value[:-1]}+00:00")

        for candidate in candidates:
            try:
                return datetime.fromisoformat(candidate)
            except ValueError:
                continue

        for date_format in ("%Y-%m-%d", "%Y/%m/%d"):
            try:
                return datetime.strptime(value, date_format)
            except ValueError:
                continue

        return None

    def _normalize_reminder_minutes(
        self,
        raw: Optional[list],
        allow_values: bool,
    ) -> List[int]:
        """알림 분 리스트 정규화"""
        if not allow_values or not isinstance(raw, list):
            return []

        normalized: List[int] = []
        for item in raw:
            try:
                minutes = int(item)
            except (TypeError, ValueError):
                continue

            if minutes < 0 or minutes in normalized:
                continue
            normalized.append(minutes)

        return normalized[:2]

    def _build_todo_plan_summary(
        self,
        title: str,
        due_date: Optional[datetime],
        priority: int,
    ) -> str:
        """todo preview 설명 생성"""
        priority_label = self._priority_label(priority)
        if due_date is None:
            return f"개인 할 일 '{title}'을 {priority_label} 우선순위로 만들어요."

        if due_date.hour == 0 and due_date.minute == 0:
            due_label = due_date.strftime("%m월 %d일")
        else:
            due_label = due_date.strftime("%m월 %d일 %H:%M")
        return (
            f"개인 할 일 '{title}'을 {due_label} 마감으로 만들어요. "
            f"우선순위는 {priority_label}로 설정했어요."
        )

    def _priority_label(self, priority: int) -> str:
        """우선순위 라벨"""
        if priority >= 2:
            return "높음"
        if priority <= 0:
            return "낮음"
        return "보통"

    def _fallback_personal_todo_plan(self, prompt: str) -> dict:
        """개인 todo 생성 preview 폴백"""
        normalized_prompt = prompt.strip()
        title = normalized_prompt[:40] or "새 할 일"
        summary = self._build_todo_plan_summary(title, None, 1)
        return {
            "title": title,
            "note": None,
            "due_date": None,
            "priority": 1,
            "reminder_minutes": [],
            "summary": summary,
        }

    def _todo_prompt_tokens(self, text: str) -> List[str]:
        """todo 매칭용 토큰 분리"""
        raw_tokens = re.split(r"[\s,./!?()\[\]{}:;\"'`~\-_|]+", text.lower())
        return [token for token in raw_tokens if len(token.strip()) >= 2]

    def _fallback_personal_todo_complete_plan(
        self,
        prompt: str,
        pending_todos: List[dict],
    ) -> Optional[dict]:
        """개인 todo 완료 preview 폴백"""
        normalized_prompt = prompt.strip().lower()
        if not normalized_prompt or not pending_todos:
            return None

        prompt_tokens = self._todo_prompt_tokens(normalized_prompt)
        best_candidate: Optional[dict] = None
        best_score = 0

        for candidate in pending_todos:
            title = str(candidate.get("title") or "").strip().lower()
            note = str(candidate.get("note") or "").strip().lower()
            score = 0

            if title and title in normalized_prompt:
                score += 8
            if normalized_prompt and normalized_prompt in title:
                score += 6

            for token in prompt_tokens:
                if token in title:
                    score += 3
                elif note and token in note:
                    score += 1

            if score > best_score:
                best_score = score
                best_candidate = candidate

        if best_candidate is None or best_score <= 0:
            return None

        return {
            "todo_id": str(best_candidate.get("id") or "").strip(),
            "title": str(best_candidate.get("title") or "").strip(),
            "note": str(best_candidate.get("note") or "").strip() or None,
            "due_date": best_candidate.get("due_date"),
            "visibility": str(best_candidate.get("visibility") or "private"),
            "summary": self._build_todo_complete_summary(best_candidate),
            "reason": "제목과 요청 문구의 핵심 단어가 가장 많이 겹쳤어요.",
        }

    def _build_todo_complete_summary(self, candidate: dict) -> str:
        """todo 완료 preview 설명 생성"""
        title = str(candidate.get("title") or "").strip() or "선택한 할 일"
        return f"개인 할 일 '{title}'을 완료 처리해요."

    def _build_calendar_plan_summary(
        self,
        title: str,
        due_date: Optional[datetime],
        start_time: Optional[datetime],
        event_type: str,
    ) -> str:
        """calendar preview 설명 생성"""
        type_label = "이벤트" if event_type == "event" else "일정"
        if start_time is not None:
            return (
                f"개인 {type_label} '{title}'을 "
                f"{start_time.strftime('%m월 %d일 %H:%M')}에 만들어요."
            )
        if due_date is not None:
            return (
                f"개인 {type_label} '{title}'을 "
                f"{due_date.strftime('%m월 %d일')} 일정으로 만들어요."
            )
        return f"개인 {type_label} '{title}'을 새 일정으로 만들어요."

    def _fallback_personal_calendar_create_plan(
        self,
        prompt: str,
        selected_date: Optional[datetime] = None,
    ) -> dict:
        """개인 일정 생성 preview 폴백"""
        normalized_prompt = prompt.strip()
        title = normalized_prompt[:40] or "새 일정"
        due_date = None
        if selected_date is not None:
            due_date = datetime(
                selected_date.year,
                selected_date.month,
                selected_date.day,
            )
        summary = self._build_calendar_plan_summary(
            title=title,
            due_date=due_date,
            start_time=None,
            event_type="schedule",
        )
        return {
            "title": title,
            "note": None,
            "event_type": "schedule",
            "due_date": due_date,
            "start_time": None,
            "end_time": None,
            "has_time": False,
            "location": None,
            "reminder_minutes": [],
            "summary": summary,
        }

    def _fallback_personal_calendar_update_plan(
        self,
        prompt: str,
        calendar_items: List[dict],
        selected_date: Optional[datetime] = None,
    ) -> Optional[dict]:
        """개인 일정 수정 preview 폴백"""
        normalized_prompt = prompt.strip().lower()
        if not normalized_prompt or not calendar_items:
            return None

        prompt_tokens = self._todo_prompt_tokens(normalized_prompt)
        best_candidate: Optional[dict] = None
        best_score = 0

        for candidate in calendar_items:
            title = str(candidate.get("title") or "").strip().lower()
            note = str(candidate.get("note") or "").strip().lower()
            location = str(candidate.get("location") or "").strip().lower()
            score = 0

            if title and title in normalized_prompt:
                score += 8
            if normalized_prompt and normalized_prompt in title:
                score += 6

            for token in prompt_tokens:
                if token in title:
                    score += 3
                elif note and token in note:
                    score += 1
                elif location and token in location:
                    score += 2

            if score > best_score:
                best_score = score
                best_candidate = candidate

        if best_candidate is None or best_score <= 0:
            return None

        due_date = best_candidate.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None
        start_time = best_candidate.get("start_time")
        if start_time is not None and not isinstance(start_time, datetime):
            start_time = None
        end_time = best_candidate.get("end_time")
        if end_time is not None and not isinstance(end_time, datetime):
            end_time = None

        if due_date is None and selected_date is not None:
            due_date = datetime(
                selected_date.year,
                selected_date.month,
                selected_date.day,
            )

        event_type = str(best_candidate.get("event_type") or "schedule").strip()
        if event_type not in {"schedule", "event"}:
            event_type = "schedule"

        return {
            "event_id": str(best_candidate.get("id") or "").strip(),
            "title": str(best_candidate.get("title") or "").strip() or "개인 일정",
            "note": str(best_candidate.get("note") or "").strip() or None,
            "event_type": event_type,
            "due_date": due_date,
            "start_time": start_time,
            "end_time": end_time,
            "has_time": bool(best_candidate.get("has_time")) and start_time is not None,
            "location": str(best_candidate.get("location") or "").strip() or None,
            "reminder_minutes": self._normalize_reminder_minutes(
                best_candidate.get("reminder_minutes"),
                allow_values=bool(best_candidate.get("has_time")) and start_time is not None,
            ),
            "visibility": str(best_candidate.get("visibility") or "private"),
            "summary": self._build_calendar_update_summary(
                best_candidate,
                title=str(best_candidate.get("title") or "").strip() or "개인 일정",
                due_date=due_date,
                start_time=start_time,
                event_type=event_type,
            ),
            "reason": "제목, 메모, 장소의 핵심 단어가 가장 많이 겹쳤어요.",
        }

    def _build_calendar_update_summary(
        self,
        candidate: dict,
        title: str,
        due_date: Optional[datetime],
        start_time: Optional[datetime],
        event_type: str,
    ) -> str:
        """calendar update preview 설명 생성"""
        original_title = str(candidate.get("title") or "").strip() or title
        type_label = "이벤트" if event_type == "event" else "일정"

        if title.strip() and title.strip() != original_title:
            return f"개인 {type_label} '{original_title}'을 '{title.strip()}'으로 수정해요."
        if start_time is not None:
            return (
                f"개인 {type_label} '{original_title}' 시간을 "
                f"{start_time.strftime('%m월 %d일 %H:%M')} 기준으로 수정해요."
            )
        if due_date is not None:
            return (
                f"개인 {type_label} '{original_title}' 날짜를 "
                f"{due_date.strftime('%m월 %d일')} 기준으로 수정해요."
            )
        return f"개인 {type_label} '{original_title}' 정보를 수정해요."

    def _normalize_note_tags(self, raw: object) -> List[str]:
        """메모 태그 리스트 정규화"""
        if not isinstance(raw, list):
            return []

        normalized: List[str] = []
        for item in raw:
            tag = str(item or "").strip().lstrip("#")
            if not tag:
                continue
            if any(existing.lower() == tag.lower() for existing in normalized):
                continue
            normalized.append(tag[:24])

        return normalized[:5]

    def _build_note_create_summary(
        self,
        title: str,
        category_name: Optional[str],
    ) -> str:
        """note create preview 설명 생성"""
        if category_name and category_name.strip():
            return f"개인 메모 '{title}'을 {category_name.strip()} 카테고리 초안으로 만들어요."
        return f"개인 메모 '{title}' 초안을 만들어요."

    def _fallback_personal_note_create_plan(self, prompt: str) -> dict:
        """개인 메모 생성 preview 폴백"""
        normalized_prompt = prompt.strip()
        title = normalized_prompt[:40] or "새 메모"
        summary = self._build_note_create_summary(title, None)
        return {
            "title": title,
            "content": normalized_prompt,
            "category_name": None,
            "tags": [],
            "is_pinned": False,
            "summary": summary,
        }

    def _fallback_personal_note_update_plan(
        self,
        prompt: str,
        memos: List[dict],
    ) -> Optional[dict]:
        """개인 메모 수정 preview 폴백"""
        normalized_prompt = prompt.strip().lower()
        if not normalized_prompt or not memos:
            return None

        prompt_tokens = self._todo_prompt_tokens(normalized_prompt)
        best_candidate: Optional[dict] = None
        best_score = 0

        for candidate in memos:
            title = str(candidate.get("title") or "").strip().lower()
            content = str(candidate.get("content") or "").strip().lower()
            category_name = str(candidate.get("category_name") or "").strip().lower()
            score = 0

            if title and title in normalized_prompt:
                score += 8
            if normalized_prompt and normalized_prompt in title:
                score += 6

            for token in prompt_tokens:
                if token in title:
                    score += 3
                elif content and token in content:
                    score += 1
                elif category_name and token in category_name:
                    score += 2

            if score > best_score:
                best_score = score
                best_candidate = candidate

        if best_candidate is None or best_score <= 0:
            return None

        title = str(best_candidate.get("title") or "").strip() or "메모"
        category_name = str(best_candidate.get("category_name") or "").strip() or None

        return {
            "memo_id": str(best_candidate.get("id") or "").strip(),
            "title": title,
            "content": str(best_candidate.get("content") or "").strip(),
            "category_name": category_name,
            "tags": self._normalize_note_tags(best_candidate.get("tags")),
            "is_pinned": bool(best_candidate.get("is_pinned")),
            "summary": self._build_note_update_summary(
                best_candidate,
                title=title,
                category_name=category_name,
            ),
            "reason": "제목과 본문의 핵심 단어가 가장 많이 겹쳤어요.",
        }

    def _build_note_update_summary(
        self,
        candidate: dict,
        title: str,
        category_name: Optional[str],
    ) -> str:
        """note update preview 설명 생성"""
        original_title = str(candidate.get("title") or "").strip() or title
        if title.strip() and title.strip() != original_title:
            return f"개인 메모 '{original_title}' 제목을 '{title.strip()}'으로 수정해요."
        if category_name and category_name.strip():
            return f"개인 메모 '{original_title}' 내용을 정리하고 {category_name.strip()} 카테고리로 맞춰요."
        return f"개인 메모 '{original_title}' 내용을 정리해 수정해요."

    def _normalize_recurrence(self, raw: object) -> Optional[str]:
        """리마인더 반복 주기 정규화"""
        value = str(raw or "").strip().lower()
        if value in {"daily", "weekly", "monthly"}:
            return value
        return None

    def _recurrence_label(self, recurrence: Optional[str]) -> Optional[str]:
        """리마인더 반복 주기 라벨"""
        if recurrence == "daily":
            return "매일"
        if recurrence == "weekly":
            return "매주"
        if recurrence == "monthly":
            return "매월"
        return None

    def _build_reminder_create_summary(
        self,
        message: str,
        remind_at: datetime,
        recurrence: Optional[str],
    ) -> str:
        """reminder create preview 설명 생성"""
        remind_at_label = remind_at.strftime("%m월 %d일 %H:%M")
        recurrence_label = self._recurrence_label(recurrence)
        if recurrence_label:
            return (
                f"개인 리마인더 '{message}'를 {remind_at_label}부터 "
                f"{recurrence_label} 반복으로 만들어요."
            )
        return f"개인 리마인더 '{message}'를 {remind_at_label}에 만들어요."

    def _fallback_personal_reminder_create_plan(
        self,
        prompt: str,
        current_time: Optional[datetime] = None,
    ) -> dict:
        """개인 리마인더 생성 preview 폴백"""
        normalized_prompt = prompt.strip()
        base_time = (current_time or datetime.utcnow()).replace(
            second=0,
            microsecond=0,
        ) + timedelta(hours=1)
        message = normalized_prompt[:120] or "새 리마인더"
        summary = self._build_reminder_create_summary(
            message=message,
            remind_at=base_time,
            recurrence=None,
        )
        return {
            "message": message,
            "remind_at": base_time,
            "recurrence": None,
            "summary": summary,
        }

    def _one_hour(self):
        """기본 일정 길이"""
        return timedelta(hours=1)


# 싱글톤 인스턴스
gemini_service = GeminiService()
