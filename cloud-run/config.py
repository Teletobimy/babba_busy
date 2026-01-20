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

    # Gemini AI Models
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    gemini_pm_model: str = os.getenv("GEMINI_PM_MODEL", "gemini-3-pro-preview")  # PM Agent
    gemini_agent_model: str = os.getenv("GEMINI_AGENT_MODEL", "gemini-3-flash-preview")  # Sub Agents
    gemini_lite_model: str = os.getenv("GEMINI_LITE_MODEL", "gemini-3-flash-preview")  # 일반 요약용

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
