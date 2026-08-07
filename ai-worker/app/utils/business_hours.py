from datetime import datetime, time
from typing import Optional

from app.schemas.response_schema import BusinessHours

_WEEKDAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


def _parse_time(value: str) -> Optional[time]:
    try:
        hour, minute = value.split(":")
        return time(int(hour), int(minute))
    except (ValueError, AttributeError):
        return None


def is_open_now(business_hours: Optional[BusinessHours], local_dt: datetime) -> Optional[bool]:
    """Returns None when we don't have enough information to tell -- an
    unknown day is never treated as "closed"."""
    if not business_hours:
        return None

    day = business_hours.get(_WEEKDAY_KEYS[local_dt.weekday()])
    if day is None or day.open is None or day.close is None:
        return None

    open_t = _parse_time(day.open)
    close_t = _parse_time(day.close)
    if open_t is None or close_t is None:
        return None

    current_t = local_dt.time()
    if open_t <= close_t:
        return open_t <= current_t <= close_t
    # Overnight hours (e.g. 18:00-02:00) wrap past midnight.
    return current_t >= open_t or current_t <= close_t
