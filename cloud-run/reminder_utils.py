from datetime import datetime

from time_utils import normalize_utc_naive


def normalize_datetime_for_firestore(value: datetime) -> datetime:
    """Convert timezone-aware datetimes to naive UTC for Firestore consistency."""
    return normalize_utc_naive(value)


def build_personal_reminder_document(
    *,
    user_id: str,
    message: str,
    remind_at: datetime,
    source: str,
    request_id: str,
    params_hash: str | None,
    created_at: datetime,
    recurrence: str | None = None,
    recurrence_label: str | None = None,
    formatted_remind_at: str | None = None,
) -> dict:
    """Build a Firestore-friendly reminder document for AI-created reminders."""
    normalized_remind_at = normalize_datetime_for_firestore(remind_at)
    normalized_created_at = normalize_datetime_for_firestore(created_at)

    return {
        "userId": user_id,
        "message": message,
        "remindAt": normalized_remind_at,
        "status": "pending",
        "scope": "personal",
        "source": source,
        "requestId": request_id,
        "paramsHash": params_hash,
        "createdAt": normalized_created_at,
        "updatedAt": normalized_created_at,
        "processedAt": None,
        "completedAt": None,
        "retryCount": 0,
        "lastError": None,
        "recurrence": recurrence,
        "recurrenceLabel": recurrence_label,
        "formattedRemindAt": formatted_remind_at,
    }
