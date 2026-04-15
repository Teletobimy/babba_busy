from datetime import datetime, timezone
from typing import Any, Optional


def utcnow_naive() -> datetime:
    """Return the current UTC time as a naive datetime for existing Firestore usage."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def normalize_utc_naive(value: datetime) -> datetime:
    """Convert aware datetimes to naive UTC while leaving naive UTC values unchanged."""
    if value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def parse_datetime_or_none(raw: Any) -> Optional[datetime]:
    """Parse datetime-like input into naive UTC when possible."""
    if raw is None:
        return None
    if isinstance(raw, datetime):
        return normalize_utc_naive(raw)

    value = str(raw).strip()
    if not value:
        return None

    candidates = [value]
    if value.endswith("Z"):
        candidates.append(f"{value[:-1]}+00:00")

    for candidate in candidates:
        try:
            return normalize_utc_naive(datetime.fromisoformat(candidate))
        except ValueError:
            continue

    for date_format in ("%Y-%m-%d", "%Y/%m/%d"):
        try:
            return datetime.strptime(value, date_format)
        except ValueError:
            continue

    return None


def sortable_datetime_or(raw: Any, default: datetime) -> datetime:
    """Parse a sortable datetime and fall back to the provided default."""
    parsed = parse_datetime_or_none(raw)
    if parsed is None:
        return default
    return parsed
