import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))


from time_utils import normalize_utc_naive, utcnow_naive  # noqa: E402
from time_utils import parse_datetime_or_none, sortable_datetime_or  # noqa: E402


def test_utcnow_naive_returns_naive_utc_datetime():
    before = datetime.now(timezone.utc).replace(tzinfo=None)

    current = utcnow_naive()

    after = datetime.now(timezone.utc).replace(tzinfo=None)
    assert current.tzinfo is None
    assert before <= current <= after


def test_normalize_utc_naive_converts_aware_datetime_to_naive_utc():
    aware = datetime(
        2026,
        4,
        15,
        18,
        45,
        0,
        tzinfo=timezone(timedelta(hours=9)),
    )

    normalized = normalize_utc_naive(aware)

    assert normalized == datetime(2026, 4, 15, 9, 45, 0)
    assert normalized.tzinfo is None


def test_normalize_utc_naive_preserves_naive_input():
    naive = datetime(2026, 4, 15, 9, 45, 0)

    normalized = normalize_utc_naive(naive)

    assert normalized == naive
    assert normalized.tzinfo is None


def test_parse_datetime_or_none_parses_iso_z_string_to_naive_utc():
    parsed = parse_datetime_or_none("2026-04-15T09:45:00Z")

    assert parsed == datetime(2026, 4, 15, 9, 45, 0)
    assert parsed.tzinfo is None


def test_parse_datetime_or_none_normalizes_aware_datetime_input():
    aware = datetime(
        2026,
        4,
        15,
        18,
        45,
        0,
        tzinfo=timezone(timedelta(hours=9)),
    )

    parsed = parse_datetime_or_none(aware)

    assert parsed == datetime(2026, 4, 15, 9, 45, 0)
    assert parsed.tzinfo is None


def test_parse_datetime_or_none_returns_none_for_blank_and_invalid_values():
    assert parse_datetime_or_none("") is None
    assert parse_datetime_or_none("   ") is None
    assert parse_datetime_or_none("not-a-datetime") is None


def test_sortable_datetime_or_uses_default_only_when_parsing_fails():
    default = datetime(2024, 1, 1, 0, 0, 0)

    assert sortable_datetime_or("invalid", default) == default
    assert sortable_datetime_or("2026-04-15T09:45:00Z", default) == datetime(
        2026, 4, 15, 9, 45, 0
    )
