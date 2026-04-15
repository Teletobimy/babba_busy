import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))


from reminder_utils import (  # noqa: E402
    build_personal_reminder_document,
    normalize_datetime_for_firestore,
)


def test_normalize_datetime_for_firestore_keeps_naive_utc():
    remind_at = datetime(2026, 4, 14, 9, 30, 0)

    normalized = normalize_datetime_for_firestore(remind_at)

    assert normalized == remind_at
    assert normalized.tzinfo is None


def test_normalize_datetime_for_firestore_converts_aware_datetime_to_naive_utc():
    remind_at = datetime(
        2026,
        4,
        14,
        18,
        30,
        0,
        tzinfo=timezone(timedelta(hours=9)),
    )

    normalized = normalize_datetime_for_firestore(remind_at)

    assert normalized == datetime(2026, 4, 14, 9, 30, 0)
    assert normalized.tzinfo is None


def test_build_personal_reminder_document_uses_firestore_ready_datetimes():
    remind_at = datetime(
        2026,
        4,
        14,
        18,
        30,
        0,
        tzinfo=timezone(timedelta(hours=9)),
    )
    created_at = datetime(2026, 4, 14, 10, 0, 0, tzinfo=timezone.utc)

    payload = build_personal_reminder_document(
        user_id="user-1",
        message="장보기",
        remind_at=remind_at,
        source="home_quick_add_ai_reminder",
        request_id="req-1",
        params_hash="hash-1",
        created_at=created_at,
        recurrence="weekly",
        recurrence_label="매주",
        formatted_remind_at="04월 14일 18:30",
    )

    assert payload["userId"] == "user-1"
    assert payload["message"] == "장보기"
    assert payload["remindAt"] == datetime(2026, 4, 14, 9, 30, 0)
    assert payload["remindAt"].tzinfo is None
    assert payload["createdAt"] == datetime(2026, 4, 14, 10, 0, 0)
    assert payload["updatedAt"] == datetime(2026, 4, 14, 10, 0, 0)
    assert payload["status"] == "pending"
    assert payload["recurrence"] == "weekly"
    assert payload["recurrenceLabel"] == "매주"
    assert payload["formattedRemindAt"] == "04월 14일 18:30"
