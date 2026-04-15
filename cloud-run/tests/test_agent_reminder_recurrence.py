import sys
import types
from datetime import datetime, timedelta, timezone
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
    stored_requests: dict[tuple[str, str], dict] = {}

    @staticmethod
    async def is_family_member(user_id: str, family_id: str) -> bool:
        return True

    @staticmethod
    async def set_ai_action_request(
        user_id: str,
        request_id: str,
        payload: dict,
        merge: bool = False,
    ):
        _FakeFirestoreCache.stored_requests[(user_id, request_id)] = payload
        return None

    @staticmethod
    async def get_ai_action_request(user_id: str, request_id: str):
        return _FakeFirestoreCache.stored_requests.get((user_id, request_id))

    @staticmethod
    async def finalize_personal_reminder_create_action(
        user_id: str,
        request_id: str,
        approved: bool,
    ):
        stored = _FakeFirestoreCache.stored_requests[(user_id, request_id)]
        preview = stored["preview"]
        result = {
            "status": "created" if approved else "cancelled",
            "reminder_id": f"reminder_{request_id}" if approved else None,
            "message": preview["message"],
            "remind_at": preview["remind_at"],
            "formatted_remind_at": preview.get("formatted_remind_at"),
            "recurrence": preview.get("recurrence"),
            "recurrence_label": preview.get("recurrence_label"),
        }
        return {
            "request_id": request_id,
            "audit_id": f"audit_{request_id}",
            "approved": approved,
            "executed_at": datetime.now(timezone.utc),
            "result": result,
        }


class _FakeGeminiService:
    async def plan_personal_reminder_create(self, prompt: str, current_time_iso: str):
        return {
            "message": "분리수거",
            "remind_at": datetime.now(timezone.utc) + timedelta(days=1),
            "recurrence": "WEEKLY",
            "summary": "개인 리마인더 '분리수거'를 매주 반복으로 만들어요.",
        }


fake_services = types.ModuleType("services")
fake_services.FirebaseAuth = _FakeFirebaseAuth
fake_services.FirestoreCache = _FakeFirestoreCache
fake_services.gemini_service = _FakeGeminiService()
sys.modules.pop("services", None)
sys.modules.pop("dependencies", None)
sys.modules.pop("routers.agent", None)
sys.modules["services"] = fake_services

from dependencies import get_current_user  # noqa: E402
from routers.agent import router as agent_router  # noqa: E402


@pytest.fixture
def client():
    _FakeFirestoreCache.stored_requests = {}
    app = FastAPI()
    app.include_router(agent_router)
    app.dependency_overrides[get_current_user] = lambda: {"uid": "user-1"}
    with TestClient(app) as test_client:
        yield test_client


def test_reminder_preview_and_decision_keep_recurrence_contract(client: TestClient):
    preview_response = client.post(
        "/api/agent/actions/reminders/create/preview",
        json={
            "user_id": "user-1",
            "prompt": "매주 분리수거 알림 만들어줘",
        },
    )

    assert preview_response.status_code == 200
    preview_payload = preview_response.json()
    assert preview_payload["preview"]["recurrence"] == "weekly"
    assert preview_payload["preview"]["recurrence_label"] == "매주"
    assert "매주 반복" in preview_payload["summary"]

    request_id = preview_payload["request_id"]
    decision_response = client.post(
        "/api/agent/actions/reminders/create/decision",
        json={
            "user_id": "user-1",
            "request_id": request_id,
            "approved": True,
        },
    )

    assert decision_response.status_code == 200
    decision_payload = decision_response.json()
    assert decision_payload["result"]["status"] == "created"
    assert decision_payload["result"]["recurrence"] == "weekly"
    assert decision_payload["result"]["recurrence_label"] == "매주"
