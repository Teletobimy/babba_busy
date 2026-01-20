import firebase_admin
from firebase_admin import credentials, firestore, auth
from google.cloud.firestore_v1 import FieldFilter
from datetime import datetime, timedelta
from typing import Optional, Any
import os

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


class FirestoreCache:
    """Firestore 캐시 서비스"""

    COLLECTION_AI_CACHE = "ai_cache"

    @staticmethod
    async def get_daily_summary(user_id: str, date: str) -> Optional[dict]:
        """일일 요약 캐시 조회"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("daily_summary").document(date)
        doc = doc_ref.get()

        if doc.exists:
            data = doc.to_dict()
            # 만료 시간 확인
            if data.get("expires_at") and data["expires_at"].replace(tzinfo=None) > datetime.utcnow():
                return data
        return None

    @staticmethod
    async def set_daily_summary(user_id: str, date: str, content: str, ttl_seconds: int = 86400) -> None:
        """일일 요약 캐시 저장"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("daily_summary").document(date)

        now = datetime.utcnow()
        doc_ref.set({
            "content": content,
            "created_at": now,
            "expires_at": now + timedelta(seconds=ttl_seconds),
        })

    @staticmethod
    async def get_weekly_summary(user_id: str, week_key: str) -> Optional[dict]:
        """주간 요약 캐시 조회"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("weekly_summary").document(week_key)
        doc = doc_ref.get()

        if doc.exists:
            data = doc.to_dict()
            if data.get("expires_at") and data["expires_at"].replace(tzinfo=None) > datetime.utcnow():
                return data
        return None

    @staticmethod
    async def set_weekly_summary(user_id: str, week_key: str, content: str, completion_rate: float, ttl_seconds: int = 604800) -> None:
        """주간 요약 캐시 저장"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("weekly_summary").document(week_key)

        now = datetime.utcnow()
        doc_ref.set({
            "content": content,
            "completion_rate": completion_rate,
            "created_at": now,
            "expires_at": now + timedelta(seconds=ttl_seconds),
        })

    @staticmethod
    async def get_psychology_session(user_id: str, session_id: str) -> Optional[dict]:
        """심리검사 세션 조회"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("psychology_sessions").document(session_id)
        doc = doc_ref.get()
        return doc.to_dict() if doc.exists else None

    @staticmethod
    async def set_psychology_session(user_id: str, session_id: str, data: dict) -> None:
        """심리검사 세션 저장"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("psychology_sessions").document(session_id)
        data["updated_at"] = datetime.utcnow()
        doc_ref.set(data, merge=True)

    @staticmethod
    async def get_business_session(user_id: str, session_id: str) -> Optional[dict]:
        """사업 검토 세션 조회"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("business_sessions").document(session_id)
        doc = doc_ref.get()
        return doc.to_dict() if doc.exists else None

    @staticmethod
    async def set_business_session(user_id: str, session_id: str, data: dict) -> None:
        """사업 검토 세션 저장"""
        doc_ref = db.collection(FirestoreCache.COLLECTION_AI_CACHE).document(user_id).collection("business_sessions").document(session_id)
        data["updated_at"] = datetime.utcnow()
        doc_ref.set(data, merge=True)


class FirebaseAuth:
    """Firebase 인증 서비스"""

    @staticmethod
    async def verify_token(id_token: str) -> Optional[dict]:
        """Firebase ID 토큰 검증"""
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
