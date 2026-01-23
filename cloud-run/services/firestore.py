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
        # 진행 중인 작업 수 확인
        jobs_ref = db.collection(FirestoreCache.COLLECTION_ANALYSIS_JOBS)
        query = jobs_ref.where(filter=FieldFilter("userId", "==", user_id)).where(
            filter=FieldFilter("status", "in", ["pending", "processing"])
        )
        docs = list(query.stream())

        if len(docs) >= max_concurrent:
            return False, "이미 진행 중인 분석이 있습니다."

        # 새 작업 생성
        doc_ref = db.collection(FirestoreCache.COLLECTION_ANALYSIS_JOBS).document(job_id)
        doc_ref.set(data)
        return True, "success"

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
