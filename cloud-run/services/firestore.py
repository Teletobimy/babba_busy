import firebase_admin
from firebase_admin import credentials, firestore, auth
from google.cloud.firestore_v1 import FieldFilter
from datetime import datetime, timedelta
from typing import Optional, Any
import os
import asyncio
from functools import partial

from config import get_settings

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
            if data.get("expires_at") and data["expires_at"].replace(tzinfo=None) > datetime.utcnow():
                return data
        return None

    @staticmethod
    async def get_daily_summary(user_id: str, date: str) -> Optional[dict]:
        """일일 요약 캐시 조회"""
        return await asyncio.to_thread(
            FirestoreCache._get_daily_summary_sync, user_id, date
        )

    @staticmethod
    def _set_daily_summary_sync(user_id: str, date: str, content: str, ttl_seconds: int) -> None:
        """일일 요약 캐시 저장 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("daily_summary").document(date)
        now = datetime.utcnow()
        doc_ref.set({
            "content": content,
            "created_at": now,
            "expires_at": now + timedelta(seconds=ttl_seconds),
        })

    @staticmethod
    async def set_daily_summary(user_id: str, date: str, content: str, ttl_seconds: int = 86400) -> None:
        """일일 요약 캐시 저장"""
        await asyncio.to_thread(
            FirestoreCache._set_daily_summary_sync, user_id, date, content, ttl_seconds
        )

    @staticmethod
    def _get_weekly_summary_sync(user_id: str, week_key: str) -> Optional[dict]:
        """주간 요약 캐시 조회 (동기)"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("weekly_summary").document(week_key)
        doc = doc_ref.get()

        if doc.exists:
            data = doc.to_dict()
            if data.get("expires_at") and data["expires_at"].replace(tzinfo=None) > datetime.utcnow():
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
        now = datetime.utcnow()
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
        data["updated_at"] = datetime.utcnow()
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
        data["updated_at"] = datetime.utcnow()
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

        def _as_sort_datetime(raw: Any) -> datetime:
            if isinstance(raw, datetime):
                return raw
            if isinstance(raw, str):
                try:
                    return datetime.fromisoformat(raw.replace("Z", "+00:00")).replace(tzinfo=None)
                except Exception:
                    return datetime.min
            return datetime.min

        items: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["id"] = doc.id
            items.append(data)
            if len(items) >= limit:
                break

        def _sort_key(item: dict) -> datetime:
            updated_at = _as_sort_datetime(item.get("updatedAt"))
            if updated_at != datetime.min:
                return updated_at
            return _as_sort_datetime(item.get("createdAt"))

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

        def _as_sort_datetime(raw: Any) -> datetime:
            if isinstance(raw, datetime):
                return raw
            if isinstance(raw, str):
                try:
                    return datetime.fromisoformat(raw.replace("Z", "+00:00")).replace(tzinfo=None)
                except Exception:
                    return datetime.min
            return datetime.min

        items: list[dict] = []
        for doc in docs:
            data = doc.to_dict() or {}
            data["id"] = doc.id
            items.append(data)

        def _sort_key(item: dict) -> datetime:
            completed_at = _as_sort_datetime(item.get("completedAt"))
            if completed_at != datetime.min:
                return completed_at
            return _as_sort_datetime(item.get("createdAt"))

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
