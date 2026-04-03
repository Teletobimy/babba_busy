import sys
import types
from pathlib import Path

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient


ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))


class _FakeFirebaseAuth:
    @staticmethod
    async def verify_token(token: str):
        return {
            "uid": "user-1",
            "email": "user-1@example.com",
            "name": "Test User",
        }


class _FakeFirestoreCache:
    is_family_member_result = True
    recent_items = [
        {
            "audit_id": "audit_002",
            "request_id": "req_002",
            "tool": "manage_notes",
            "action": "update",
            "scope": "personal",
            "source": "memo_ai_fab",
            "prompt": "회의 메모 수정해줘",
            "params_hash": "hash_002",
            "consent_required": True,
            "consent_approved": True,
            "execution_status": "updated",
            "target_label": "회의 메모",
            "result_ref_id": "memo_11",
            "result_ref_type": "memo",
        },
        {
            "audit_id": "audit_001",
            "request_id": "req_001",
            "tool": "manage_todos",
            "action": "create",
            "scope": "personal",
            "source": "home_quick_add_ai",
            "prompt": "내일 세탁 맡기기 추가",
            "params_hash": "hash_001",
            "consent_required": True,
            "consent_approved": False,
            "execution_status": "cancelled",
            "target_label": "세탁 맡기기",
            "result_ref_id": None,
            "result_ref_type": None,
        },
    ]

    @staticmethod
    async def list_recent_tool_audit_logs(user_id: str, limit: int = 12) -> list[dict]:
        return _FakeFirestoreCache.recent_items[:limit]

    @staticmethod
    async def is_family_member(user_id: str, family_id: str) -> bool:
        return _FakeFirestoreCache.is_family_member_result


class _FakeGeminiService:
    def __getattr__(self, name):  # pragma: no cover
        raise AssertionError(f"Unexpected gemini access: {name}")


fake_services = types.ModuleType("services")
fake_services.FirebaseAuth = _FakeFirebaseAuth
fake_services.FirestoreCache = _FakeFirestoreCache
fake_services.gemini_service = _FakeGeminiService()
sys.modules["services"] = fake_services

from dependencies import get_current_user  # noqa: E402
from routers.agent import router as agent_router  # noqa: E402


@pytest.fixture
def client():
    app = FastAPI()
    app.include_router(agent_router)
    app.dependency_overrides[get_current_user] = lambda: {"uid": "user-1"}
    with TestClient(app) as test_client:
        yield test_client


def test_recent_agent_audit_logs_returns_items(client: TestClient):
    response = client.get("/api/agent/audit/recent?limit=2")

    assert response.status_code == 200
    payload = response.json()
    assert payload["user_id"] == "user-1"
    assert payload["limit"] == 2
    assert payload["total_count"] == 2
    assert payload["items"][0]["audit_id"] == "audit_002"
    assert payload["items"][0]["result_ref_type"] == "memo"
    assert payload["items"][1]["execution_status"] == "cancelled"


def test_recent_agent_audit_logs_clamps_limit(client: TestClient):
    response = client.get("/api/agent/audit/recent?limit=0")

    assert response.status_code == 200
    payload = response.json()
    assert payload["limit"] == 1
    assert payload["total_count"] == 1
