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


@pytest.mark.parametrize(
    ("path", "prompt", "expected_detail"),
    [
        (
            "/api/agent/actions/todo/preview",
            "가족 할 일로 올려줘",
            "개인 할 일 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.",
        ),
        (
            "/api/agent/actions/notes/create/preview",
            "공유 메모로 남겨줘",
            "개인 메모 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.",
        ),
        (
            "/api/agent/actions/calendar/create/preview",
            "우리 캘린더에 넣어줘",
            "개인 일정 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.",
        ),
        (
            "/api/agent/actions/reminders/create/preview",
            "모두에게 알림 보내줘",
            "개인 리마인더 AI 액션은 아직 공유/가족 범위를 지원하지 않습니다. 개인 범위 요청으로 다시 입력해주세요.",
        ),
    ],
)
def test_personal_write_routes_reject_shared_scope_prompts(
    client: TestClient,
    path: str,
    prompt: str,
    expected_detail: str,
):
    _FakeFirestoreCache.is_family_member_result = True

    response = client.post(
        path,
        json={
            "user_id": "user-1",
            "prompt": prompt,
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"] == expected_detail


@pytest.mark.parametrize(
    "path",
    [
        "/api/agent/actions/todo/preview",
        "/api/agent/actions/calendar/create/preview",
    ],
)
def test_personal_create_routes_reject_invalid_family_context(
    client: TestClient,
    path: str,
):
    _FakeFirestoreCache.is_family_member_result = False

    response = client.post(
        path,
        json={
            "user_id": "user-1",
            "prompt": "내일 개인 작업 추가해줘",
            "current_group_id": "group-404",
        },
    )

    assert response.status_code == 403
    assert (
        response.json()["detail"]
        == "현재 가족 컨텍스트가 유효하지 않습니다. 그룹을 다시 선택해주세요."
    )
