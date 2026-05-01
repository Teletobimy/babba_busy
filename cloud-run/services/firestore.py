import firebase_admin
from firebase_admin import credentials, firestore, auth
from google.cloud.firestore_v1 import FieldFilter
from datetime import datetime, timedelta
from typing import Optional, Any
import os
import asyncio
from functools import partial

from config import get_settings
from reminder_utils import (
    build_personal_reminder_document,
    normalize_datetime_for_firestore,
)
from time_utils import sortable_datetime_or, utcnow_naive

settings = get_settings()

# Firebase 초기화 (Cloud Run에서는 기본 서비스 계정 사용)
if not firebase_admin._apps:
    if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        # 로컬 개발: 서비스 계정 키 파일 사용
        cred = credentials.Certificate(os.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
        firebase_admin.initialize_app(cred, {"projectId": settings.gcp_project_id})
    else:
        # Cloud Run: 기본 서비스 계정 사용
        firebase_admin.initialize_app(options={"projectId": settings.gcp_project_id})

db = firestore.client()


def _run_sync(func, *args, **kwargs):
    """동기 함수를 실행하기 위한 헬퍼"""
    return func(*args, **kwargs)


class FirestoreCache:
    """Firestore 캐시 서비스

    Note: Firebase Admin SDK는 동기 API를 제공하므로
    asyncio.to_thread()를 사용하여 비동기 컨텍스트에서 실행합니다.
    """

    COLLECTION_AI_CACHE = "ai_cache"

    @staticmethod
    def _get_daily_summary_sync(user_id: str, date: str) -> Optional[dict]:
        """일일 요약 캐시 조회 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("daily_summary").document(date)
        doc = doc_ref.get()

        if doc.exists:
            data = doc.to_dict()
            if data.get("expires_at") and normalize_datetime_for_firestore(data["expires_at"]) > utcnow_naive():
                return data
        return None

    @staticmethod
    async def get_daily_summary(user_id: str, date: str) -> Optional[dict]:
        """일일 요약 캐시 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_daily_summary_sync, user_id, date
        )

    @staticmethod
    def _set_daily_summary_sync(
        user_id: str,
        date: str,
        content: str,
        ttl_seconds: int,
        metadata: Optional[dict] = None,
    ) -> None:
        """일일 요약 캐시 저장 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("daily_summary").document(date)
        now = utcnow_naive()
        payload = {
            "content": content,
            "created_at": now,
            "expires_at": now + timedelta(seconds=ttl_seconds),
        }
        if metadata:
            payload.update(metadata)
        doc_ref.set(payload)

    @staticmethod
    async def set_daily_summary(
        user_id: str,
        date: str,
        content: str,
        ttl_seconds: int = 86400,
        metadata: Optional[dict] = None,
    ) -> None:
        """일일 요약 캐시 저장"""
        await asyncio.to_thread(
            FirestoreCache._set_daily_summary_sync,
            user_id,
            date,
            content,
            ttl_seconds,
            metadata,
        )

    @staticmethod
    def _get_weekly_summary_sync(user_id: str, week_key: str) -> Optional[dict]:
        """주간 요약 캐시 조회 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("weekly_summary").document(week_key)
        doc = doc_ref.get()

        if doc.exists:
            data = doc.to_dict()
            if data.get("expires_at") and normalize_datetime_for_firestore(data["expires_at"]) > utcnow_naive():
                return data
        return None

    @staticmethod
    async def get_weekly_summary(user_id: str, week_key: str) -> Optional[dict]:
        """주간 요약 캐시 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_weekly_summary_sync, user_id, week_key
        )

    @staticmethod
    def _set_weekly_summary_sync(user_id: str, week_key: str, content: str, completion_rate: float, ttl_seconds: int) -> None:
        """주간 요약 캐시 저장 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("weekly_summary").document(week_key)
        now = utcnow_naive()
        doc_ref.set({
            "content": content,
            "completion_rate": completion_rate,
            "created_at": now,
            "expires_at": now + timedelta(seconds=ttl_seconds),
        })

    @staticmethod
    async def set_weekly_summary(user_id: str, week_key: str, content: str, completion_rate: float, ttl_seconds: int = 604800) -> None:
        """주간 요약 캐시 저장"""
        await asyncio.to_thread(
            FirestoreCache._set_weekly_summary_sync, user_id, week_key, content, completion_rate, ttl_seconds
        )

    @staticmethod
    def _get_psychology_session_sync(user_id: str, session_id: str) -> Optional[dict]:
        """심리검사 세션 조회 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("psychology_sessions").document(session_id)
        doc = doc_ref.get()
        return doc.to_dict() if doc.exists else None

    @staticmethod
    async def get_psychology_session(user_id: str, session_id: str) -> Optional[dict]:
        """심리검사 세션 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_psychology_session_sync, user_id, session_id
        )

    @staticmethod
    def _set_psychology_session_sync(user_id: str, session_id: str, data: dict) -> None:
        """심리검사 세션 저장 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("psychology_sessions").document(session_id)
        data["updated_at"] = utcnow_naive()
        doc_ref.set(data, merge=True)

    @staticmethod
    async def set_psychology_session(user_id: str, session_id: str, data: dict) -> None:
        """심리검사 세션 저장"""
        await asyncio.to_thread(
            FirestoreCache._set_psychology_session_sync, user_id, session_id, data
        )

    @staticmethod
    def _get_business_session_sync(user_id: str, session_id: str) -> Optional[dict]:
        """사업 검토 세션 조회 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("business_sessions").document(session_id)
        doc = doc_ref.get()
        return doc.to_dict() if doc.exists else None

    @staticmethod
    async def get_business_session(user_id: str, session_id: str) -> Optional[dict]:
        """사업 검토 세션 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_business_session_sync, user_id, session_id
        )

    @staticmethod
    def _set_business_session_sync(user_id: str, session_id: str, data: dict) -> None:
        """사업 검토 세션 저장 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("business_sessions").document(session_id)
        data["updated_at"] = utcnow_naive()
        doc_ref.set(data, merge=True)

    @staticmethod
    async def set_business_session(user_id: str, session_id: str, data: dict) -> None:
        """사업 검토 세션 저장"""
        await asyncio.to_thread(
            FirestoreCache._set_business_session_sync, user_id, session_id, data
        )

    # ============ Analysis Jobs ============

    COLLECTION_ANALYSIS_JOBS = "analysis_jobs"

    @staticmethod
    def _create_analysis_job_sync(job_id: str, data: dict) -> str:
        """분석 작업 생성 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_ANALYSIS_JOBS).document(job_id)
        doc_ref.set(data)
        return job_id

    @staticmethod
    async def create_analysis_job(job_id: str, data: dict) -> str:
        """분석 작업 생성"""
        return await asyncio.to_thread(
            FirestoreCache._create_analysis_job_sync, job_id, data
        )

    @staticmethod
    def _create_analysis_job_atomic_sync(user_id: str, job_id: str, data: dict, max_concurrent: int) -> tuple[bool, str]:
        """동시 작업 수 확인 후 작업 생성 (동기)

        Returns:
            (success, message): 성공 여부와 메시지
        """
        jobs_ref = db.collection(FirestoreCache.COLLECTION_ANALYSIS_JOBS)
        job_ref = jobs_ref.document(job_id)
        transaction = db.transaction()

        @firestore.transactional
        def _create_job(txn):
            query = jobs_ref.where(filter=FieldFilter("userId", "==", user_id)).where(
                filter=FieldFilter("status", "in", ["pending", "processing"])
            )
            docs = list(query.stream(transaction=txn))

            if len(docs) >= max_concurrent:
                return False, "이미 진행 중인 분석이 있습니다."

            txn.set(job_ref, data)
            return True, "success"

        return _create_job(transaction)

    @staticmethod
    async def create_analysis_job_atomic(user_id: str, job_id: str, data: dict, max_concurrent: int = 1) -> tuple[bool, str]:
        """트랜잭션으로 동시 작업 수 확인 후 작업 생성 (Race Condition 방지)"""
        return await asyncio.to_thread(
            FirestoreCache._create_analysis_job_atomic_sync, user_id, job_id, data, max_concurrent
        )

    @staticmethod
    def _get_analysis_job_sync(job_id: str) -> Optional[dict]:
        """분석 작업 조회 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_ANALYSIS_JOBS).document(job_id)
        doc = doc_ref.get()
        if doc.exists:
            data = doc.to_dict()
            data["id"] = doc.id
            return data
        return None

    @staticmethod
    async def get_analysis_job(job_id: str) -> Optional[dict]:
        """분석 작업 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_analysis_job_sync, job_id
        )

    @staticmethod
    def _update_analysis_job_sync(job_id: str, data: dict) -> None:
        """분석 작업 업데이트 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_ANALYSIS_JOBS).document(job_id)
        doc_ref.update(data)

    @staticmethod
    async def update_analysis_job(job_id: str, data: dict) -> None:
        """분석 작업 업데이트"""
        await asyncio.to_thread(
            FirestoreCache._update_analysis_job_sync, job_id, data
        )

    @staticmethod
    def _get_user_pending_jobs_sync(user_id: str) -> list[dict]:
        """사용자의 진행 중인 작업 목록 조회 (동기)"""
        jobs_ref = db.collection(FirestoreCache.COLLECTION_ANALYSIS_JOBS)
        query = jobs_ref.where(filter=FieldFilter("userId", "==", user_id)).where(
            filter=FieldFilter("status", "in", ["pending", "processing"])
        )
        docs = query.stream()

        result = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            result.append(data)

        return result

    @staticmethod
    async def get_user_pending_jobs(user_id: str) -> list[dict]:
        """사용자의 진행 중인 작업 목록 조회 (pending, processing)"""
        return await asyncio.to_thread(
            FirestoreCache._get_user_pending_jobs_sync, user_id
        )

    @staticmethod
    def _save_business_review_sync(user_id: str, review_data: dict) -> str:
        """사업 검토 결과 저장 (동기)"""
        doc_ref = db.collection("users").document(user_id).collection("business_reviews").document()
        doc_ref.set(review_data)
        return doc_ref.id

    @staticmethod
    async def save_business_review(user_id: str, review_data: dict) -> str:
        """사업 검토 결과 저장"""
        return await asyncio.to_thread(
            FirestoreCache._save_business_review_sync, user_id, review_data
        )

    @staticmethod
    def _save_psychology_result_sync(
        user_id: str,
        result_data: dict,
        result_id: Optional[str] = None,
    ) -> str:
        """심리검사 결과 저장 (동기)"""
        if result_id:
            doc_ref = (
                db.collection("users")
                .document(user_id)
                .collection("psychology_results")
                .document(result_id)
            )
            doc_ref.set(result_data, merge=True)
        else:
            doc_ref = (
                db.collection("users")
                .document(user_id)
                .collection("psychology_results")
                .document()
            )
            doc_ref.set(result_data)

        return doc_ref.id

    @staticmethod
    async def save_psychology_result(
        user_id: str,
        result_data: dict,
        result_id: Optional[str] = None,
    ) -> str:
        """심리검사 결과 저장"""
        return await asyncio.to_thread(
            FirestoreCache._save_psychology_result_sync, user_id, result_data, result_id
        )

    @staticmethod
    def _get_psychology_results_sync(user_id: str, limit: int = 10) -> list[dict]:
        """심리검사 결과 목록 조회 (동기)"""
        query = (
            db.collection("users")
            .document(user_id)
            .collection("psychology_results")
            .order_by("completedAt", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )
        docs = query.stream()

        results: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["id"] = doc.id
            results.append(data)
        return results

    @staticmethod
    async def get_psychology_results(user_id: str, limit: int = 10) -> list[dict]:
        """심리검사 결과 목록 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_psychology_results_sync,
            user_id,
            limit,
        )

    @staticmethod
    def _get_user_memos_sync(
        user_id: str,
        category_id: Optional[str] = None,
        category_name: Optional[str] = None,
        limit: int = 120,
    ) -> list[dict]:
        """사용자 메모 목록 조회 (동기)"""
        query = db.collection("users").document(user_id).collection("memos")

        if category_id:
            query = query.where(filter=FieldFilter("categoryId", "==", category_id))
        elif category_name:
            query = query.where(filter=FieldFilter("categoryName", "==", category_name))

        docs = query.stream()

        items: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["id"] = doc.id
            items.append(data)
            if len(items) >= limit:
                break

        def _sort_key(item: dict) -> datetime:
            updated_at = sortable_datetime_or(item.get("updatedAt"), datetime.min)
            if updated_at != datetime.min:
                return updated_at
            return sortable_datetime_or(item.get("createdAt"), datetime.min)

        items.sort(key=_sort_key, reverse=True)
        return items[:limit]

    @staticmethod
    async def get_user_memos(
        user_id: str,
        category_id: Optional[str] = None,
        category_name: Optional[str] = None,
        limit: int = 120,
    ) -> list[dict]:
        """사용자 메모 목록 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_user_memos_sync,
            user_id,
            category_id,
            category_name,
            limit,
        )

    @staticmethod
    def _save_memo_category_analysis_sync(
        user_id: str,
        analysis_data: dict,
        analysis_id: Optional[str] = None,
    ) -> str:
        """메모 카테고리 분석 결과 저장 (동기)"""
        if analysis_id:
            doc_ref = (
                db.collection("users")
                .document(user_id)
                .collection("memo_category_analyses")
                .document(analysis_id)
            )
            doc_ref.set(analysis_data, merge=True)
        else:
            doc_ref = (
                db.collection("users")
                .document(user_id)
                .collection("memo_category_analyses")
                .document()
            )
            doc_ref.set(analysis_data)
        return doc_ref.id

    @staticmethod
    async def save_memo_category_analysis(
        user_id: str,
        analysis_data: dict,
        analysis_id: Optional[str] = None,
    ) -> str:
        """메모 카테고리 분석 결과 저장"""
        return await asyncio.to_thread(
            FirestoreCache._save_memo_category_analysis_sync,
            user_id,
            analysis_data,
            analysis_id,
        )

    @staticmethod
    def _get_memo_category_analysis_sync(user_id: str, analysis_id: str) -> Optional[dict]:
        """메모 카테고리 분석 결과 단건 조회 (동기)"""
        doc_ref = (
            db.collection("users")
            .document(user_id)
            .collection("memo_category_analyses")
            .document(analysis_id)
        )
        doc = doc_ref.get()
        if not doc.exists:
            return None
        data = doc.to_dict() or {}
        data["id"] = doc.id
        return data

    @staticmethod
    async def get_memo_category_analysis(user_id: str, analysis_id: str) -> Optional[dict]:
        """메모 카테고리 분석 결과 단건 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_memo_category_analysis_sync,
            user_id,
            analysis_id,
        )

    @staticmethod
    def _get_memo_category_analyses_sync(
        user_id: str,
        limit: int = 20,
        category_id: Optional[str] = None,
    ) -> list[dict]:
        """메모 카테고리 분석 결과 목록 조회 (동기)"""
        query = db.collection("users").document(user_id).collection("memo_category_analyses")
        if category_id:
            query = query.where(filter=FieldFilter("categoryId", "==", category_id))

        docs = query.stream()

        items: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["id"] = doc.id
            items.append(data)

        def _sort_key(item: dict) -> datetime:
            completed_at = sortable_datetime_or(item.get("completedAt"), datetime.min)
            if completed_at != datetime.min:
                return completed_at
            return sortable_datetime_or(item.get("createdAt"), datetime.min)

        items.sort(key=_sort_key, reverse=True)
        return items[:limit]

    @staticmethod
    async def get_memo_category_analyses(
        user_id: str,
        limit: int = 20,
        category_id: Optional[str] = None,
    ) -> list[dict]:
        """메모 카테고리 분석 결과 목록 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_memo_category_analyses_sync,
            user_id,
            limit,
            category_id,
        )

    @staticmethod
    def _is_family_member_sync(user_id: str, family_id: str) -> bool:
        """사용자가 가족 그룹의 멤버인지 확인 (동기)"""
        query = (
            db.collection("memberships")
            .where(filter=FieldFilter("userId", "==", user_id))
            .where(filter=FieldFilter("groupId", "==", family_id))
            .limit(1)
        )
        docs = list(query.stream())
        return bool(docs)

    @staticmethod
    async def is_family_member(user_id: str, family_id: str) -> bool:
        """사용자가 가족 그룹의 멤버인지 확인"""
        return await asyncio.to_thread(
            FirestoreCache._is_family_member_sync,
            user_id,
            family_id,
        )

    @staticmethod
    def _get_recent_family_chat_messages_sync(
        family_id: str,
        limit: int = 40,
    ) -> list[dict]:
        """가족 채팅 최근 메시지 조회 (동기)"""
        query = (
            db.collection("families")
            .doc(family_id)
            .collection("chat_messages")
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )
        docs = list(query.stream())
        items: list[dict] = []

        for doc in reversed(docs):
            data = doc.to_dict() or {}
            items.append(
                {
                    "id": doc.id,
                    "family_id": family_id,
                    "sender_id": data.get("senderId", ""),
                    "sender_name": data.get("senderName", ""),
                    "content": data.get("content", ""),
                    "type": data.get("type", "text"),
                    "attachment_name": data.get("attachmentName"),
                    "attachment_mime_type": data.get("attachmentMimeType"),
                    "created_at": data.get("createdAt"),
                }
            )

        return items

    @staticmethod
    async def get_recent_family_chat_messages(
        family_id: str,
        limit: int = 40,
    ) -> list[dict]:
        """가족 채팅 최근 메시지 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_recent_family_chat_messages_sync,
            family_id,
            limit,
        )

    @staticmethod
    def _get_recent_private_pending_todos_sync(
        user_id: str,
        limit: int = 30,
    ) -> list[dict]:
        """최근 private pending todo 조회 (동기)"""
        docs = list(
            db.collection("users")
            .document(user_id)
            .collection("todos")
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(max(limit * 3, 40))
            .stream()
        )

        items: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            if data.get("visibility") != "private":
                continue
            if bool(data.get("isCompleted")):
                continue

            reminder_minutes_raw = data.get("reminderMinutes")
            reminder_minutes = (
                reminder_minutes_raw if isinstance(reminder_minutes_raw, list) else []
            )

            items.append(
                {
                    "id": doc.id,
                    "title": str(data.get("title") or "").strip(),
                    "note": str(data.get("note") or "").strip() or None,
                    "due_date": data.get("dueDate"),
                    "created_at": data.get("createdAt"),
                    "visibility": str(data.get("visibility") or "private"),
                    "reminder_minutes": reminder_minutes,
                }
            )

            if len(items) >= limit:
                break

        return items

    @staticmethod
    async def get_recent_private_pending_todos(
        user_id: str,
        limit: int = 30,
    ) -> list[dict]:
        """최근 private pending todo 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_recent_private_pending_todos_sync,
            user_id,
            limit,
        )

    @staticmethod
    def _get_recent_private_calendar_items_sync(
        user_id: str,
        limit: int = 30,
    ) -> list[dict]:
        """최근 private calendar item 조회 (동기)"""
        docs = list(
            db.collection("users")
            .document(user_id)
            .collection("todos")
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(max(limit * 3, 50))
            .stream()
        )

        items: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            if data.get("visibility") != "private":
                continue
            if bool(data.get("isCompleted")):
                continue

            event_type = str(data.get("eventType") or "").strip()
            if event_type not in {"schedule", "event"}:
                continue

            reminder_minutes = data.get("reminderMinutes")
            if not isinstance(reminder_minutes, list):
                reminder_minutes = []

            items.append(
                {
                    "id": doc.id,
                    "title": str(data.get("title") or "").strip(),
                    "note": str(data.get("note") or "").strip() or None,
                    "due_date": data.get("dueDate"),
                    "start_time": data.get("startTime"),
                    "end_time": data.get("endTime"),
                    "has_time": bool(data.get("hasTime")),
                    "location": str(data.get("location") or "").strip() or None,
                    "event_type": event_type,
                    "visibility": str(data.get("visibility") or "private"),
                    "reminder_minutes": reminder_minutes,
                    "created_at": data.get("createdAt"),
                }
            )

            if len(items) >= limit:
                break

        return items

    @staticmethod
    async def get_recent_private_calendar_items(
        user_id: str,
        limit: int = 30,
    ) -> list[dict]:
        """최근 private calendar item 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_recent_private_calendar_items_sync,
            user_id,
            limit,
        )

    @staticmethod
    def _resolve_memo_category_sync(
        user_id: str,
        category_name: Optional[str],
    ) -> Optional[dict]:
        """메모 카테고리 이름으로 사용자 카테고리 조회 (동기)"""
        normalized_name = str(category_name or "").strip().lower()
        if not normalized_name:
            return None

        docs = list(
            db.collection("users")
            .document(user_id)
            .collection("memo_categories")
            .stream()
        )
        for doc in docs:
            data = doc.to_dict() or {}
            name = str(data.get("name") or "").strip()
            if name.lower() != normalized_name:
                continue
            return {
                "id": doc.id,
                "name": name,
            }

        return None

    @staticmethod
    def _normalize_note_tags(raw: Any) -> list[str]:
        """메모 태그 리스트 정규화"""
        if not isinstance(raw, list):
            return []

        normalized: list[str] = []
        for item in raw:
            tag = str(item or "").strip().lstrip("#")
            if not tag:
                continue
            if any(existing.lower() == tag.lower() for existing in normalized):
                continue
            normalized.append(tag[:24])

        return normalized[:5]

    @staticmethod
    def _get_recent_memos_sync(
        user_id: str,
        limit: int = 30,
    ) -> list[dict]:
        """최근 메모 조회 (동기)"""
        docs = list(
            db.collection("users")
            .document(user_id)
            .collection("memos")
            .order_by("updatedAt", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )

        items: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            items.append(
                {
                    "id": doc.id,
                    "title": str(data.get("title") or "").strip(),
                    "content": str(data.get("content") or "").strip(),
                    "category_id": str(data.get("categoryId") or "").strip() or None,
                    "category_name": str(data.get("categoryName") or "").strip() or None,
                    "tags": FirestoreCache._normalize_note_tags(data.get("tags")),
                    "is_pinned": bool(data.get("isPinned")),
                    "updated_at": data.get("updatedAt"),
                    "created_at": data.get("createdAt"),
                }
            )

        return items

    @staticmethod
    async def get_recent_memos(
        user_id: str,
        limit: int = 30,
    ) -> list[dict]:
        """최근 메모 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_recent_memos_sync,
            user_id,
            limit,
        )

    @staticmethod
    def _set_ai_action_request_sync(
        user_id: str,
        request_id: str,
        payload: dict,
        merge: bool = True,
    ) -> None:
        """AI 액션 요청 저장 (동기)"""
        (
            db.collection("users")
            .document(user_id)
            .collection("ai_action_requests")
            .document(request_id)
            .set(payload, merge=merge)
        )

    @staticmethod
    async def set_ai_action_request(
        user_id: str,
        request_id: str,
        payload: dict,
        merge: bool = True,
    ) -> None:
        """AI 액션 요청 저장"""
        await asyncio.to_thread(
            FirestoreCache._set_ai_action_request_sync,
            user_id,
            request_id,
            payload,
            merge,
        )

    @staticmethod
    def _get_ai_action_request_sync(user_id: str, request_id: str) -> Optional[dict]:
        """AI 액션 요청 조회 (동기)"""
        doc = (
            db.collection("users")
            .document(user_id)
            .collection("ai_action_requests")
            .document(request_id)
            .get()
        )
        if not doc.exists:
            return None
        data = doc.to_dict() or {}
        data["id"] = doc.id
        return data

    @staticmethod
    async def get_ai_action_request(
        user_id: str,
        request_id: str,
    ) -> Optional[dict]:
        """AI 액션 요청 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_ai_action_request_sync,
            user_id,
            request_id,
        )

    @staticmethod
    def _validate_optional_group_context_sync(
        user_id: str,
        group_id: Optional[str],
    ) -> str:
        """선택적 그룹 컨텍스트가 현재 사용자 멤버십과 일치하는지 검증"""
        normalized_group_id = str(group_id or "").strip()
        if not normalized_group_id:
            return ""
        if not FirestoreCache._is_family_member_sync(user_id, normalized_group_id):
            raise ValueError("현재 가족 컨텍스트가 유효하지 않습니다.")
        return normalized_group_id

    @staticmethod
    def _normalize_reminder_minutes(raw: Any) -> list[int]:
        """알림 분 리스트 정규화"""
        if not isinstance(raw, list):
            return []

        normalized: list[int] = []
        for item in raw:
            try:
                minutes = int(item)
            except (TypeError, ValueError):
                continue

            if minutes < 0 or minutes in normalized:
                continue
            normalized.append(minutes)

        return normalized[:4]

    @staticmethod
    def _calculate_next_reminder_at(
        due_date: Optional[datetime],
        reminder_minutes: list[int],
        reminders_sent: list[int],
    ) -> Optional[datetime]:
        """다음 알림 시간 계산"""
        if due_date is None or not reminder_minutes:
            return None

        pending_minutes = [m for m in reminder_minutes if m not in reminders_sent]
        if not pending_minutes:
            return None

        max_minutes = max(pending_minutes)
        return due_date - timedelta(minutes=max_minutes)

    @staticmethod
    def _finalize_personal_todo_action_sync(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 todo AI 액션 확정 처리 (동기)"""
        user_ref = db.collection("users").document(user_id)
        request_ref = user_ref.collection("ai_action_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("요청을 찾을 수 없습니다.")

        request_data = request_doc.to_dict() or {}
        current_status = str(request_data.get("status") or "").strip()

        if current_status in {"approved", "denied"} and request_data.get("result"):
            consent = request_data.get("consent") or {}
            return {
                "request_id": request_id,
                "audit_id": str(request_data.get("audit_id") or f"audit_{request_id}"),
                "approved": bool(consent.get("approved"))
                if "approved" in consent
                else current_status == "approved",
                "executed_at": request_data.get("executed_at")
                or request_data.get("updated_at")
                or request_data.get("created_at")
                or utcnow_naive(),
                "result": request_data.get("result") or {},
            }

        preview = request_data.get("preview") or {}
        title = str(preview.get("title") or "").strip()
        if not title:
            raise ValueError("생성할 할 일 제목이 없습니다.")

        note = str(preview.get("note") or "").strip() or None
        due_date = preview.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None

        priority = preview.get("priority")
        try:
            priority = int(priority)
        except (TypeError, ValueError):
            priority = 1
        priority = min(max(priority, 0), 2)

        priority_label = str(preview.get("priority_label") or "보통").strip() or "보통"
        reminder_minutes = FirestoreCache._normalize_reminder_minutes(
            preview.get("reminder_minutes")
        )
        formatted_due_date = str(preview.get("formatted_due_date") or "").strip() or None
        source = str(request_data.get("source") or "").strip() or "home_quick_add_ai"
        current_group_id = FirestoreCache._validate_optional_group_context_sync(
            user_id,
            request_data.get("current_group_id"),
        )

        executed_at = utcnow_naive()
        todo_id = str(request_data.get("todo_id") or f"ai_{request_id}")
        audit_id = str(request_data.get("audit_id") or f"audit_{request_id}")
        reminders_sent: list[int] = []
        next_reminder_at = FirestoreCache._calculate_next_reminder_at(
            due_date,
            reminder_minutes,
            reminders_sent,
        )

        result_payload = {
            "status": "created" if approved else "cancelled",
            "todo_id": todo_id if approved else None,
            "title": title,
            "note": note,
            "due_date": due_date,
            "formatted_due_date": formatted_due_date,
            "priority_label": priority_label,
            "visibility": "private",
        }

        audit_payload = {
            "requestId": request_id,
            "auditId": audit_id,
            "userId": user_id,
            "tool": "manage_todos",
            "action": "create",
            "scope": "personal",
            "source": source,
            "prompt": request_data.get("prompt"),
            "paramsHash": request_data.get("params_hash"),
            "preview": preview,
            "consentRequired": True,
            "consentApproved": approved,
            "executionStatus": result_payload["status"],
            "resultTodoId": todo_id if approved else None,
            "executedAt": executed_at,
            "createdAt": request_data.get("created_at") or executed_at,
        }

        batch = db.batch()

        if approved:
            todo_payload = {
                "ownerId": user_id,
                "sharedGroups": [],
                "visibility": "private",
                "familyId": current_group_id,
                "title": title,
                "note": note,
                "assigneeId": user_id,
                "isCompleted": False,
                "dueDate": due_date,
                "repeatType": None,
                "priority": priority,
                "createdBy": user_id,
                "createdAt": executed_at,
                "eventType": "todo",
                "startTime": None,
                "endTime": None,
                "hasTime": False,
                "completedAt": None,
                "participants": [user_id],
                "location": None,
                "calendarGroupId": None,
                "isPersonal": True,
                "color": None,
                "recurrenceType": None,
                "recurrenceDays": None,
                "recurrenceEndDate": None,
                "excludeHolidays": False,
                "reminderMinutes": reminder_minutes or None,
                "remindersSent": reminders_sent,
                "nextReminderAt": next_reminder_at,
                "aiGenerated": True,
                "aiRequestId": request_id,
                "aiParamsHash": request_data.get("params_hash"),
                "aiSource": source,
            }
            batch.set(user_ref.collection("todos").document(todo_id), todo_payload)

        batch.set(user_ref.collection("tool_audit_log").document(audit_id), audit_payload)
        batch.set(
            request_ref,
            {
                "status": "approved" if approved else "denied",
                "audit_id": audit_id,
                "todo_id": todo_id if approved else None,
                "updated_at": executed_at,
                "executed_at": executed_at,
                "consent": {
                    "required": True,
                    "approved": approved,
                },
                "result": result_payload,
            },
            merge=True,
        )
        batch.commit()

        return {
            "request_id": request_id,
            "audit_id": audit_id,
            "approved": approved,
            "executed_at": executed_at,
            "result": result_payload,
        }

    @staticmethod
    async def finalize_personal_todo_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 todo AI 액션 확정 처리"""
        return await asyncio.to_thread(
            FirestoreCache._finalize_personal_todo_action_sync,
            user_id,
            request_id,
            approved,
        )

    @staticmethod
    def _finalize_personal_todo_complete_action_sync(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 todo 완료 AI 액션 확정 처리 (동기)"""
        user_ref = db.collection("users").document(user_id)
        request_ref = user_ref.collection("ai_action_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("요청을 찾을 수 없습니다.")

        request_data = request_doc.to_dict() or {}
        current_status = str(request_data.get("status") or "").strip()

        if current_status in {"approved", "denied"} and request_data.get("result"):
            consent = request_data.get("consent") or {}
            return {
                "request_id": request_id,
                "audit_id": str(request_data.get("audit_id") or f"audit_{request_id}"),
                "approved": bool(consent.get("approved"))
                if "approved" in consent
                else current_status == "approved",
                "executed_at": request_data.get("executed_at")
                or request_data.get("updated_at")
                or request_data.get("created_at")
                or utcnow_naive(),
                "result": request_data.get("result") or {},
            }

        preview = request_data.get("preview") or {}
        todo_id = str(preview.get("todo_id") or "").strip()
        title = str(preview.get("title") or "").strip()
        if not todo_id or not title:
            raise ValueError("완료할 할 일 정보가 없습니다.")

        todo_ref = user_ref.collection("todos").document(todo_id)
        todo_doc = todo_ref.get()
        if not todo_doc.exists:
            raise ValueError("완료할 할 일을 찾을 수 없습니다.")

        todo_data = todo_doc.to_dict() or {}
        visibility = str(todo_data.get("visibility") or preview.get("visibility") or "private")
        if visibility != "private":
            raise ValueError("공유 할 일은 아직 AI 완료 처리 대상이 아닙니다.")

        note = str(todo_data.get("note") or preview.get("note") or "").strip() or None
        due_date = todo_data.get("dueDate") or preview.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None
        formatted_due_date = str(preview.get("formatted_due_date") or "").strip() or None

        executed_at = utcnow_naive()
        audit_id = str(request_data.get("audit_id") or f"audit_{request_id}")
        already_completed = bool(todo_data.get("isCompleted"))
        completed_at = todo_data.get("completedAt") if already_completed else None
        if completed_at is not None and not isinstance(completed_at, datetime):
            completed_at = None

        if approved:
            if already_completed:
                status = "already_completed"
            else:
                status = "completed"
                completed_at = executed_at
        else:
            status = "cancelled"

        result_payload = {
            "status": status,
            "todo_id": todo_id,
            "title": title,
            "note": note,
            "completed_at": completed_at,
            "formatted_due_date": formatted_due_date,
            "visibility": visibility,
        }

        audit_payload = {
            "requestId": request_id,
            "auditId": audit_id,
            "userId": user_id,
            "tool": "manage_todos",
            "action": "complete",
            "scope": "personal",
            "source": str(request_data.get("source") or "").strip() or "home_quick_add_ai",
            "prompt": request_data.get("prompt"),
            "paramsHash": request_data.get("params_hash"),
            "preview": preview,
            "consentRequired": True,
            "consentApproved": approved,
            "executionStatus": status,
            "resultTodoId": todo_id,
            "executedAt": executed_at,
            "createdAt": request_data.get("created_at") or executed_at,
        }

        batch = db.batch()
        if approved and not already_completed:
            batch.update(
                todo_ref,
                {
                    "isCompleted": True,
                    "completedAt": completed_at,
                },
            )

        batch.set(user_ref.collection("tool_audit_log").document(audit_id), audit_payload)
        batch.set(
            request_ref,
            {
                "status": "approved" if approved else "denied",
                "audit_id": audit_id,
                "updated_at": executed_at,
                "executed_at": executed_at,
                "consent": {
                    "required": True,
                    "approved": approved,
                },
                "result": result_payload,
            },
            merge=True,
        )
        batch.commit()

        return {
            "request_id": request_id,
            "audit_id": audit_id,
            "approved": approved,
            "executed_at": executed_at,
            "result": result_payload,
        }

    @staticmethod
    async def finalize_personal_todo_complete_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 todo 완료 AI 액션 확정 처리"""
        return await asyncio.to_thread(
            FirestoreCache._finalize_personal_todo_complete_action_sync,
            user_id,
            request_id,
            approved,
        )

    @staticmethod
    def _finalize_personal_calendar_create_action_sync(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 일정 생성 AI 액션 확정 처리 (동기)"""
        user_ref = db.collection("users").document(user_id)
        request_ref = user_ref.collection("ai_action_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("요청을 찾을 수 없습니다.")

        request_data = request_doc.to_dict() or {}
        current_status = str(request_data.get("status") or "").strip()

        if current_status in {"approved", "denied"} and request_data.get("result"):
            consent = request_data.get("consent") or {}
            return {
                "request_id": request_id,
                "audit_id": str(request_data.get("audit_id") or f"audit_{request_id}"),
                "approved": bool(consent.get("approved"))
                if "approved" in consent
                else current_status == "approved",
                "executed_at": request_data.get("executed_at")
                or request_data.get("updated_at")
                or request_data.get("created_at")
                or utcnow_naive(),
                "result": request_data.get("result") or {},
            }

        preview = request_data.get("preview") or {}
        title = str(preview.get("title") or "").strip()
        if not title:
            raise ValueError("생성할 일정 제목이 없습니다.")

        event_type = str(preview.get("event_type") or "schedule").strip() or "schedule"
        if event_type not in {"schedule", "event"}:
            event_type = "schedule"

        event_type_label = (
            str(preview.get("event_type_label") or "").strip()
            or ("이벤트" if event_type == "event" else "일정")
        )
        note = str(preview.get("note") or "").strip() or None
        location = str(preview.get("location") or "").strip() or None
        visibility = str(preview.get("visibility") or "private").strip() or "private"
        if visibility != "private":
            raise ValueError("공유 일정 쓰기는 아직 지원하지 않습니다.")

        due_date = preview.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None
        start_time = preview.get("start_time")
        if start_time is not None and not isinstance(start_time, datetime):
            start_time = None
        end_time = preview.get("end_time")
        if end_time is not None and not isinstance(end_time, datetime):
            end_time = None

        has_time = bool(preview.get("has_time"))
        formatted_due_date = str(preview.get("formatted_due_date") or "").strip() or None
        formatted_time_range = (
            str(preview.get("formatted_time_range") or "").strip() or None
        )
        reminder_minutes = FirestoreCache._normalize_reminder_minutes(
            preview.get("reminder_minutes")
        )
        event_time = start_time or due_date
        next_reminder_at = FirestoreCache._calculate_next_reminder_at(
            event_time,
            reminder_minutes,
            [],
        )
        current_group_id = FirestoreCache._validate_optional_group_context_sync(
            user_id,
            request_data.get("current_group_id"),
        )

        executed_at = utcnow_naive()
        event_id = str(request_data.get("event_id") or f"ai_{request_id}")
        audit_id = str(request_data.get("audit_id") or f"audit_{request_id}")

        result_payload = {
            "status": "created" if approved else "cancelled",
            "event_id": event_id if approved else None,
            "title": title,
            "event_type": event_type,
            "event_type_label": event_type_label,
            "due_date": due_date,
            "formatted_due_date": formatted_due_date,
            "formatted_time_range": formatted_time_range,
            "location": location,
            "visibility": visibility,
        }

        audit_payload = {
            "requestId": request_id,
            "auditId": audit_id,
            "userId": user_id,
            "tool": "manage_calendar",
            "action": "create",
            "scope": "personal",
            "source": str(request_data.get("source") or "").strip()
            or "calendar_ai_fab",
            "prompt": request_data.get("prompt"),
            "paramsHash": request_data.get("params_hash"),
            "preview": preview,
            "consentRequired": True,
            "consentApproved": approved,
            "executionStatus": result_payload["status"],
            "resultEventId": event_id if approved else None,
            "executedAt": executed_at,
            "createdAt": request_data.get("created_at") or executed_at,
        }

        batch = db.batch()

        if approved:
            event_payload = {
                "ownerId": user_id,
                "sharedGroups": [],
                "visibility": "private",
                "familyId": current_group_id,
                "title": title,
                "note": note,
                "assigneeId": user_id,
                "isCompleted": False,
                "dueDate": due_date,
                "repeatType": None,
                "priority": 1,
                "createdBy": user_id,
                "createdAt": executed_at,
                "eventType": event_type,
                "startTime": start_time,
                "endTime": end_time,
                "hasTime": has_time,
                "completedAt": None,
                "participants": [user_id],
                "location": location,
                "calendarGroupId": None,
                "isPersonal": True,
                "color": None,
                "recurrenceType": None,
                "recurrenceDays": None,
                "recurrenceEndDate": None,
                "excludeHolidays": False,
                "reminderMinutes": reminder_minutes or None,
                "remindersSent": [],
                "nextReminderAt": next_reminder_at,
                "aiGenerated": True,
                "aiRequestId": request_id,
                "aiParamsHash": request_data.get("params_hash"),
                "aiSource": str(request_data.get("source") or "").strip()
                or "calendar_ai_fab",
            }
            batch.set(user_ref.collection("todos").document(event_id), event_payload)

        batch.set(user_ref.collection("tool_audit_log").document(audit_id), audit_payload)
        batch.set(
            request_ref,
            {
                "status": "approved" if approved else "denied",
                "audit_id": audit_id,
                "event_id": event_id if approved else None,
                "updated_at": executed_at,
                "executed_at": executed_at,
                "consent": {
                    "required": True,
                    "approved": approved,
                },
                "result": result_payload,
            },
            merge=True,
        )
        batch.commit()

        return {
            "request_id": request_id,
            "audit_id": audit_id,
            "approved": approved,
            "executed_at": executed_at,
            "result": result_payload,
        }

    @staticmethod
    async def finalize_personal_calendar_create_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 일정 생성 AI 액션 확정 처리"""
        return await asyncio.to_thread(
            FirestoreCache._finalize_personal_calendar_create_action_sync,
            user_id,
            request_id,
            approved,
        )

    @staticmethod
    def _finalize_personal_calendar_update_action_sync(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 일정 수정 AI 액션 확정 처리 (동기)"""
        user_ref = db.collection("users").document(user_id)
        request_ref = user_ref.collection("ai_action_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("요청을 찾을 수 없습니다.")

        request_data = request_doc.to_dict() or {}
        current_status = str(request_data.get("status") or "").strip()

        if current_status in {"approved", "denied"} and request_data.get("result"):
            consent = request_data.get("consent") or {}
            return {
                "request_id": request_id,
                "audit_id": str(request_data.get("audit_id") or f"audit_{request_id}"),
                "approved": bool(consent.get("approved"))
                if "approved" in consent
                else current_status == "approved",
                "executed_at": request_data.get("executed_at")
                or request_data.get("updated_at")
                or request_data.get("created_at")
                or utcnow_naive(),
                "result": request_data.get("result") or {},
            }

        preview = request_data.get("preview") or {}
        event_id = str(preview.get("event_id") or "").strip()
        title = str(preview.get("title") or "").strip()
        if not event_id or not title:
            raise ValueError("수정할 일정 정보가 없습니다.")

        event_ref = user_ref.collection("todos").document(event_id)
        event_doc = event_ref.get()
        if not event_doc.exists:
            raise ValueError("수정할 개인 일정을 찾을 수 없습니다.")

        event_data = event_doc.to_dict() or {}
        visibility = str(
            event_data.get("visibility") or preview.get("visibility") or "private"
        ).strip() or "private"
        if visibility != "private":
            raise ValueError("공유 일정 쓰기는 아직 지원하지 않습니다.")

        event_type = str(
            event_data.get("eventType") or preview.get("event_type") or "schedule"
        ).strip() or "schedule"
        if event_type not in {"schedule", "event"}:
            raise ValueError("개인 일정만 수정할 수 있습니다.")

        note = str(preview.get("note") or "").strip() or None
        location = str(preview.get("location") or "").strip() or None

        due_date = preview.get("due_date")
        if due_date is not None and not isinstance(due_date, datetime):
            due_date = None
        start_time = preview.get("start_time")
        if start_time is not None and not isinstance(start_time, datetime):
            start_time = None
        end_time = preview.get("end_time")
        if end_time is not None and not isinstance(end_time, datetime):
            end_time = None

        has_time = bool(preview.get("has_time")) and start_time is not None
        if due_date is None:
            if start_time is not None:
                due_date = datetime(start_time.year, start_time.month, start_time.day)
            else:
                current_due = event_data.get("dueDate")
                if isinstance(current_due, datetime):
                    due_date = current_due

        formatted_due_date = str(preview.get("formatted_due_date") or "").strip() or None
        formatted_time_range = (
            str(preview.get("formatted_time_range") or "").strip() or None
        )
        event_type_label = (
            str(preview.get("event_type_label") or "").strip()
            or ("이벤트" if event_type == "event" else "일정")
        )
        reminder_minutes = FirestoreCache._normalize_reminder_minutes(
            preview.get("reminder_minutes")
        )
        reminders_sent: list[int] = []
        next_reminder_at = FirestoreCache._calculate_next_reminder_at(
            start_time if has_time else due_date,
            reminder_minutes,
            reminders_sent,
        )

        executed_at = utcnow_naive()
        audit_id = str(request_data.get("audit_id") or f"audit_{request_id}")
        source = str(request_data.get("source") or "").strip() or "calendar_ai_fab"

        result_payload = {
            "status": "updated" if approved else "cancelled",
            "event_id": event_id,
            "title": title,
            "event_type": event_type,
            "event_type_label": event_type_label,
            "due_date": due_date,
            "formatted_due_date": formatted_due_date,
            "formatted_time_range": formatted_time_range,
            "location": location,
            "visibility": visibility,
        }

        audit_payload = {
            "requestId": request_id,
            "auditId": audit_id,
            "userId": user_id,
            "tool": "manage_calendar",
            "action": "update",
            "scope": "personal",
            "source": source,
            "prompt": request_data.get("prompt"),
            "paramsHash": request_data.get("params_hash"),
            "preview": preview,
            "consentRequired": True,
            "consentApproved": approved,
            "executionStatus": result_payload["status"],
            "resultEventId": event_id,
            "executedAt": executed_at,
            "createdAt": request_data.get("created_at") or executed_at,
        }

        batch = db.batch()
        if approved:
            batch.update(
                event_ref,
                {
                    "title": title,
                    "note": note,
                    "dueDate": due_date,
                    "startTime": start_time if has_time else None,
                    "endTime": end_time if has_time else None,
                    "hasTime": has_time,
                    "location": location,
                    "eventType": event_type,
                    "reminderMinutes": reminder_minutes or None,
                    "remindersSent": reminders_sent,
                    "nextReminderAt": next_reminder_at,
                    "updatedAt": executed_at,
                    "aiUpdated": True,
                    "aiRequestId": request_id,
                    "aiParamsHash": request_data.get("params_hash"),
                    "aiSource": source,
                },
            )

        batch.set(user_ref.collection("tool_audit_log").document(audit_id), audit_payload)
        batch.set(
            request_ref,
            {
                "status": "approved" if approved else "denied",
                "audit_id": audit_id,
                "updated_at": executed_at,
                "executed_at": executed_at,
                "consent": {
                    "required": True,
                    "approved": approved,
                },
                "result": result_payload,
            },
            merge=True,
        )
        batch.commit()

        return {
            "request_id": request_id,
            "audit_id": audit_id,
            "approved": approved,
            "executed_at": executed_at,
            "result": result_payload,
        }

    @staticmethod
    async def finalize_personal_calendar_update_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 일정 수정 AI 액션 확정 처리"""
        return await asyncio.to_thread(
            FirestoreCache._finalize_personal_calendar_update_action_sync,
            user_id,
            request_id,
            approved,
        )

    @staticmethod
    def _finalize_personal_note_create_action_sync(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 메모 생성 AI 액션 확정 처리 (동기)"""
        user_ref = db.collection("users").document(user_id)
        request_ref = user_ref.collection("ai_action_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("요청을 찾을 수 없습니다.")

        request_data = request_doc.to_dict() or {}
        current_status = str(request_data.get("status") or "").strip()

        if current_status in {"approved", "denied"} and request_data.get("result"):
            consent = request_data.get("consent") or {}
            return {
                "request_id": request_id,
                "audit_id": str(request_data.get("audit_id") or f"audit_{request_id}"),
                "approved": bool(consent.get("approved"))
                if "approved" in consent
                else current_status == "approved",
                "executed_at": request_data.get("executed_at")
                or request_data.get("updated_at")
                or request_data.get("created_at")
                or utcnow_naive(),
                "result": request_data.get("result") or {},
            }

        preview = request_data.get("preview") or {}
        title = str(preview.get("title") or "").strip()
        content = str(preview.get("content") or "").strip()
        if not title and not content:
            raise ValueError("생성할 메모 내용이 없습니다.")
        if not title:
            title = content[:40] or "새 메모"

        category_name = str(preview.get("category_name") or "").strip() or None
        category_match = FirestoreCache._resolve_memo_category_sync(user_id, category_name)
        category_id = category_match.get("id") if category_match else None
        if category_match is not None:
            category_name = category_match.get("name")

        tags = FirestoreCache._normalize_note_tags(preview.get("tags"))
        is_pinned = bool(preview.get("is_pinned"))

        executed_at = utcnow_naive()
        memo_id = str(request_data.get("memo_id") or f"ai_{request_id}")
        audit_id = str(request_data.get("audit_id") or f"audit_{request_id}")
        source = str(request_data.get("source") or "").strip() or "memo_ai_fab"

        result_payload = {
            "status": "created" if approved else "cancelled",
            "memo_id": memo_id if approved else None,
            "title": title,
            "category_name": category_name,
            "tags": tags,
        }

        audit_payload = {
            "requestId": request_id,
            "auditId": audit_id,
            "userId": user_id,
            "tool": "manage_notes",
            "action": "create",
            "scope": "personal",
            "source": source,
            "prompt": request_data.get("prompt"),
            "paramsHash": request_data.get("params_hash"),
            "preview": preview,
            "consentRequired": True,
            "consentApproved": approved,
            "executionStatus": result_payload["status"],
            "resultMemoId": memo_id if approved else None,
            "executedAt": executed_at,
            "createdAt": request_data.get("created_at") or executed_at,
        }

        batch = db.batch()
        if approved:
            batch.set(
                user_ref.collection("memos").document(memo_id),
                {
                    "userId": user_id,
                    "title": title,
                    "content": content,
                    "categoryId": category_id,
                    "categoryName": category_name,
                    "tags": tags,
                    "isPinned": is_pinned,
                    "aiAnalysis": None,
                    "analyzedAt": None,
                    "createdBy": user_id,
                    "createdAt": executed_at,
                    "updatedAt": executed_at,
                    "aiGenerated": True,
                    "aiRequestId": request_id,
                    "aiParamsHash": request_data.get("params_hash"),
                    "aiSource": source,
                },
            )

        batch.set(user_ref.collection("tool_audit_log").document(audit_id), audit_payload)
        batch.set(
            request_ref,
            {
                "status": "approved" if approved else "denied",
                "audit_id": audit_id,
                "memo_id": memo_id if approved else None,
                "updated_at": executed_at,
                "executed_at": executed_at,
                "consent": {
                    "required": True,
                    "approved": approved,
                },
                "result": result_payload,
            },
            merge=True,
        )
        batch.commit()

        return {
            "request_id": request_id,
            "audit_id": audit_id,
            "approved": approved,
            "executed_at": executed_at,
            "result": result_payload,
        }

    @staticmethod
    async def finalize_personal_note_create_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 메모 생성 AI 액션 확정 처리"""
        return await asyncio.to_thread(
            FirestoreCache._finalize_personal_note_create_action_sync,
            user_id,
            request_id,
            approved,
        )

    @staticmethod
    def _finalize_personal_note_update_action_sync(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 메모 수정 AI 액션 확정 처리 (동기)"""
        user_ref = db.collection("users").document(user_id)
        request_ref = user_ref.collection("ai_action_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("요청을 찾을 수 없습니다.")

        request_data = request_doc.to_dict() or {}
        current_status = str(request_data.get("status") or "").strip()

        if current_status in {"approved", "denied"} and request_data.get("result"):
            consent = request_data.get("consent") or {}
            return {
                "request_id": request_id,
                "audit_id": str(request_data.get("audit_id") or f"audit_{request_id}"),
                "approved": bool(consent.get("approved"))
                if "approved" in consent
                else current_status == "approved",
                "executed_at": request_data.get("executed_at")
                or request_data.get("updated_at")
                or request_data.get("created_at")
                or utcnow_naive(),
                "result": request_data.get("result") or {},
            }

        preview = request_data.get("preview") or {}
        memo_id = str(preview.get("memo_id") or "").strip()
        title = str(preview.get("title") or "").strip()
        content = str(preview.get("content") or "").strip()
        if not memo_id or not title:
            raise ValueError("수정할 메모 정보가 없습니다.")

        memo_ref = user_ref.collection("memos").document(memo_id)
        memo_doc = memo_ref.get()
        if not memo_doc.exists:
            raise ValueError("수정할 메모를 찾을 수 없습니다.")

        memo_data = memo_doc.to_dict() or {}
        category_name = str(preview.get("category_name") or "").strip() or None
        category_match = FirestoreCache._resolve_memo_category_sync(user_id, category_name)
        category_id = category_match.get("id") if category_match else None
        if category_match is not None:
            category_name = category_match.get("name")

        tags = FirestoreCache._normalize_note_tags(preview.get("tags"))
        is_pinned = bool(preview.get("is_pinned"))

        executed_at = utcnow_naive()
        audit_id = str(request_data.get("audit_id") or f"audit_{request_id}")
        source = str(request_data.get("source") or "").strip() or "memo_ai_fab"

        result_payload = {
            "status": "updated" if approved else "cancelled",
            "memo_id": memo_id,
            "title": title,
            "category_name": category_name,
            "tags": tags,
            "is_pinned": is_pinned,
        }

        audit_payload = {
            "requestId": request_id,
            "auditId": audit_id,
            "userId": user_id,
            "tool": "manage_notes",
            "action": "update",
            "scope": "personal",
            "source": source,
            "prompt": request_data.get("prompt"),
            "paramsHash": request_data.get("params_hash"),
            "preview": preview,
            "consentRequired": True,
            "consentApproved": approved,
            "executionStatus": result_payload["status"],
            "resultMemoId": memo_id,
            "executedAt": executed_at,
            "createdAt": request_data.get("created_at") or executed_at,
        }

        batch = db.batch()
        if approved:
            batch.update(
                memo_ref,
                {
                    "title": title,
                    "content": content,
                    "categoryId": category_id,
                    "categoryName": category_name,
                    "tags": tags,
                    "isPinned": is_pinned,
                    "aiAnalysis": None,
                    "analyzedAt": None,
                    "updatedAt": executed_at,
                    "aiUpdated": True,
                    "aiRequestId": request_id,
                    "aiParamsHash": request_data.get("params_hash"),
                    "aiSource": source,
                    "createdBy": memo_data.get("createdBy") or user_id,
                },
            )

        batch.set(user_ref.collection("tool_audit_log").document(audit_id), audit_payload)
        batch.set(
            request_ref,
            {
                "status": "approved" if approved else "denied",
                "audit_id": audit_id,
                "updated_at": executed_at,
                "executed_at": executed_at,
                "consent": {
                    "required": True,
                    "approved": approved,
                },
                "result": result_payload,
            },
            merge=True,
        )
        batch.commit()

        return {
            "request_id": request_id,
            "audit_id": audit_id,
            "approved": approved,
            "executed_at": executed_at,
            "result": result_payload,
        }

    @staticmethod
    async def finalize_personal_note_update_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 메모 수정 AI 액션 확정 처리"""
        return await asyncio.to_thread(
            FirestoreCache._finalize_personal_note_update_action_sync,
            user_id,
            request_id,
            approved,
        )

    @staticmethod
    def _finalize_personal_reminder_create_action_sync(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 리마인더 생성 AI 액션 확정 처리 (동기)"""
        user_ref = db.collection("users").document(user_id)
        request_ref = user_ref.collection("ai_action_requests").document(request_id)
        request_doc = request_ref.get()

        if not request_doc.exists:
            raise ValueError("요청을 찾을 수 없습니다.")

        request_data = request_doc.to_dict() or {}
        current_status = str(request_data.get("status") or "").strip()

        if current_status in {"approved", "denied"} and request_data.get("result"):
            consent = request_data.get("consent") or {}
            return {
                "request_id": request_id,
                "audit_id": str(request_data.get("audit_id") or f"audit_{request_id}"),
                "approved": bool(consent.get("approved"))
                if "approved" in consent
                else current_status == "approved",
                "executed_at": request_data.get("executed_at")
                or request_data.get("updated_at")
                or request_data.get("created_at")
                or utcnow_naive(),
                "result": request_data.get("result") or {},
            }

        preview = request_data.get("preview") or {}
        message = str(preview.get("message") or "").strip()
        remind_at = preview.get("remind_at")
        if not message or not isinstance(remind_at, datetime):
            raise ValueError("리마인더 정보가 올바르지 않습니다.")
        remind_at = normalize_datetime_for_firestore(remind_at)

        recurrence = str(preview.get("recurrence") or "").strip() or None
        recurrence_label = str(preview.get("recurrence_label") or "").strip() or None
        formatted_remind_at = (
            str(preview.get("formatted_remind_at") or "").strip() or None
        )

        executed_at = utcnow_naive()
        reminder_id = str(request_data.get("reminder_id") or f"reminder_{request_id}")
        audit_id = str(request_data.get("audit_id") or f"audit_{request_id}")
        source = str(request_data.get("source") or "").strip() or "home_quick_add_ai_reminder"

        result_payload = {
            "status": "created" if approved else "cancelled",
            "reminder_id": reminder_id if approved else None,
            "message": message,
            "remind_at": remind_at,
            "formatted_remind_at": formatted_remind_at,
            "recurrence": recurrence,
            "recurrence_label": recurrence_label,
        }

        audit_payload = {
            "requestId": request_id,
            "auditId": audit_id,
            "userId": user_id,
            "tool": "create_reminder",
            "action": "create",
            "scope": "personal",
            "source": source,
            "prompt": request_data.get("prompt"),
            "paramsHash": request_data.get("params_hash"),
            "preview": preview,
            "consentRequired": True,
            "consentApproved": approved,
            "executionStatus": result_payload["status"],
            "resultReminderId": reminder_id if approved else None,
            "executedAt": executed_at,
            "createdAt": request_data.get("created_at") or executed_at,
        }

        batch = db.batch()
        if approved:
            batch.set(
                db.collection("reminders").document(reminder_id),
                build_personal_reminder_document(
                    user_id=user_id,
                    message=message,
                    remind_at=remind_at,
                    source=source,
                    request_id=request_id,
                    params_hash=request_data.get("params_hash"),
                    created_at=executed_at,
                    recurrence=recurrence,
                    recurrence_label=recurrence_label,
                    formatted_remind_at=formatted_remind_at,
                ),
                merge=True,
            )

        batch.set(user_ref.collection("tool_audit_log").document(audit_id), audit_payload)
        batch.set(
            request_ref,
            {
                "status": "approved" if approved else "denied",
                "audit_id": audit_id,
                "reminder_id": reminder_id if approved else None,
                "updated_at": executed_at,
                "executed_at": executed_at,
                "consent": {
                    "required": True,
                    "approved": approved,
                },
                "result": result_payload,
            },
            merge=True,
        )
        batch.commit()

        return {
            "request_id": request_id,
            "audit_id": audit_id,
            "approved": approved,
            "executed_at": executed_at,
            "result": result_payload,
        }

    @staticmethod
    async def finalize_personal_reminder_create_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ) -> dict:
        """개인 리마인더 생성 AI 액션 확정 처리"""
        return await asyncio.to_thread(
            FirestoreCache._finalize_personal_reminder_create_action_sync,
            user_id,
            request_id,
            approved,
        )

    @staticmethod
    def _extract_audit_target_label(audit_data: dict) -> Optional[str]:
        preview = audit_data.get("preview") or {}
        for key in ("title", "original_title", "message"):
            value = str(preview.get(key) or "").strip()
            if value:
                return value
        return None

    @staticmethod
    def _extract_audit_result_ref(audit_data: dict) -> tuple[Optional[str], Optional[str]]:
        ref_keys = (
            ("resultTodoId", "todo"),
            ("resultEventId", "event"),
            ("resultMemoId", "memo"),
            ("resultReminderId", "reminder"),
        )
        for key, ref_type in ref_keys:
            value = str(audit_data.get(key) or "").strip()
            if value:
                return value, ref_type
        return None, None

    @staticmethod
    def _list_recent_tool_audit_logs_sync(user_id: str, limit: int = 12) -> list[dict]:
        user_ref = db.collection("users").document(user_id)
        safe_limit = min(max(int(limit or 12), 1), 30)
        query = (
            user_ref.collection("tool_audit_log")
            .order_by("executedAt", direction=firestore.Query.DESCENDING)
            .limit(safe_limit)
        )

        items: list[dict] = []
        for doc in query.stream():
            audit_data = doc.to_dict() or {}
            result_ref_id, result_ref_type = FirestoreCache._extract_audit_result_ref(
                audit_data
            )
            items.append(
                {
                    "audit_id": str(audit_data.get("auditId") or doc.id),
                    "request_id": str(audit_data.get("requestId") or "").strip(),
                    "tool": str(audit_data.get("tool") or "").strip(),
                    "action": str(audit_data.get("action") or "").strip(),
                    "scope": str(audit_data.get("scope") or "").strip() or "personal",
                    "source": str(audit_data.get("source") or "").strip() or None,
                    "prompt": str(audit_data.get("prompt") or "").strip() or None,
                    "params_hash": str(audit_data.get("paramsHash") or "").strip() or None,
                    "consent_required": audit_data.get("consentRequired") != False,
                    "consent_approved": audit_data.get("consentApproved") == True,
                    "execution_status": str(audit_data.get("executionStatus") or "").strip(),
                    "target_label": FirestoreCache._extract_audit_target_label(audit_data),
                    "result_ref_id": result_ref_id,
                    "result_ref_type": result_ref_type,
                    "created_at": audit_data.get("createdAt"),
                    "executed_at": audit_data.get("executedAt"),
                }
            )

        return items

    @staticmethod
    async def list_recent_tool_audit_logs(user_id: str, limit: int = 12) -> list[dict]:
        return await asyncio.to_thread(
            FirestoreCache._list_recent_tool_audit_logs_sync,
            user_id,
            limit,
        )

    # ============ User Brain (Phase B1) ============
    # 경로 메모: subcollection 양식 (path = collection/document/collection/document...)
    #   users/{uid}/ai_brain_kb/main          — 단일 KB 문서
    #   users/{uid}/ai_brain_reflections/{id} — reflection 컬렉션
    #   users/{uid}/ai_brain_suggestions/{id} — suggestion 컬렉션

    @staticmethod
    def _get_user_brain_kb_sync(user_id: str) -> Optional[dict]:
        doc = (
            db.collection("users")
            .document(user_id)
            .collection("ai_brain_kb")
            .document("main")
            .get()
        )
        return doc.to_dict() if doc.exists else None

    @staticmethod
    async def get_user_brain_kb(user_id: str) -> Optional[dict]:
        return await asyncio.to_thread(
            FirestoreCache._get_user_brain_kb_sync, user_id
        )

    @staticmethod
    def _set_user_brain_kb_sync(
        user_id: str, payload: dict, merge: bool = True
    ) -> None:
        (
            db.collection("users")
            .document(user_id)
            .collection("ai_brain_kb")
            .document("main")
            .set(payload, merge=merge)
        )

    @staticmethod
    async def set_user_brain_kb(
        user_id: str, payload: dict, merge: bool = True
    ) -> None:
        await asyncio.to_thread(
            FirestoreCache._set_user_brain_kb_sync, user_id, payload, merge
        )

    @staticmethod
    def _list_user_brain_reflections_sync(
        user_id: str, limit: int = 10
    ) -> list[dict]:
        docs = (
            db.collection("users")
            .document(user_id)
            .collection("ai_brain_reflections")
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [doc.to_dict() | {"period": doc.id} for doc in docs]

    @staticmethod
    async def list_user_brain_reflections(
        user_id: str, limit: int = 10
    ) -> list[dict]:
        return await asyncio.to_thread(
            FirestoreCache._list_user_brain_reflections_sync, user_id, limit
        )

    @staticmethod
    def _list_user_brain_suggestions_sync(
        user_id: str, limit: int = 20
    ) -> list[dict]:
        docs = (
            db.collection("users")
            .document(user_id)
            .collection("ai_brain_suggestions")
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .stream()
        )
        return [doc.to_dict() | {"suggestion_id": doc.id} for doc in docs]

    @staticmethod
    async def list_user_brain_suggestions(
        user_id: str, limit: int = 20
    ) -> list[dict]:
        return await asyncio.to_thread(
            FirestoreCache._list_user_brain_suggestions_sync, user_id, limit
        )

    @staticmethod
    def _get_user_brain_suggestion_sync(user_id: str, suggestion_id: str) -> Optional[dict]:
        doc = (
            db.collection("users")
            .document(user_id)
            .collection("ai_brain_suggestions")
            .document(suggestion_id)
            .get()
        )
        return doc.to_dict() if doc.exists else None

    @staticmethod
    async def get_user_brain_suggestion(
        user_id: str, suggestion_id: str
    ) -> Optional[dict]:
        return await asyncio.to_thread(
            FirestoreCache._get_user_brain_suggestion_sync, user_id, suggestion_id
        )

    @staticmethod
    def _update_user_brain_suggestion_sync(
        user_id: str, suggestion_id: str, updates: dict
    ) -> None:
        """dot-path key 지원 (예: 'stages.shown'). update()는 dot-path 자동 처리."""
        (
            db.collection("users")
            .document(user_id)
            .collection("ai_brain_suggestions")
            .document(suggestion_id)
            .update(updates)
        )

    @staticmethod
    async def update_user_brain_suggestion(
        user_id: str, suggestion_id: str, updates: dict
    ) -> None:
        await asyncio.to_thread(
            FirestoreCache._update_user_brain_suggestion_sync,
            user_id, suggestion_id, updates,
        )


class FirebaseAuth:
    """Firebase 인증 서비스"""

    @staticmethod
    def _verify_token_sync(id_token: str) -> Optional[dict]:
        """Firebase ID 토큰 검증 (동기)"""
        try:
            decoded_token = auth.verify_id_token(id_token)
            return {
                "uid": decoded_token["uid"],
                "email": decoded_token.get("email"),
                "name": decoded_token.get("name"),
            }
        except Exception as e:
            print(f"Token verification failed: {e}")
            return None

    @staticmethod
    async def verify_token(id_token: str) -> Optional[dict]:
        """Firebase ID 토큰 검증"""
        return await asyncio.to_thread(
            FirebaseAuth._verify_token_sync, id_token
        )
