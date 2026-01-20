import os
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """애플리케이션 설정"""

    # 환경
    environment: str = os.getenv("ENVIRONMENT", "development")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Google Cloud
    gcp_project_id: str = os.getenv("GCP_PROJECT_ID", "***REMOVED_PROJECT_ID***")

    # Gemini AI
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    gemini_model: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite-preview-09-2025")

    # 캐시 설정 (초 단위)
    cache_daily_summary_ttl: int = 86400  # 24시간
    cache_weekly_summary_ttl: int = 604800  # 7일

    # Rate Limiting
    rate_limit_per_user_daily: int = 100  # 사용자당 일일 요청 제한

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """설정 싱글톤 반환"""
    return Settings()
