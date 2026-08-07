from datetime import datetime

from app.schemas.response_schema import BusinessHoursDay
from app.utils.business_hours import is_open_now


def test_returns_none_when_no_hours_are_known():
    assert is_open_now(None, datetime(2026, 8, 10, 12, 0)) is None


def test_returns_none_when_the_current_weekday_is_not_mentioned():
    # 2026-08-10 is a Monday
    hours = {"tue": BusinessHoursDay(open="09:00", close="18:00")}
    assert is_open_now(hours, datetime(2026, 8, 10, 12, 0)) is None


def test_returns_true_when_within_same_day_hours():
    hours = {"mon": BusinessHoursDay(open="09:00", close="21:00")}
    assert is_open_now(hours, datetime(2026, 8, 10, 12, 0)) is True


def test_returns_false_when_outside_same_day_hours():
    hours = {"mon": BusinessHoursDay(open="09:00", close="21:00")}
    assert is_open_now(hours, datetime(2026, 8, 10, 22, 0)) is False


def test_handles_overnight_hours_that_wrap_past_midnight():
    hours = {"mon": BusinessHoursDay(open="18:00", close="02:00")}
    assert is_open_now(hours, datetime(2026, 8, 10, 23, 0)) is True
    assert is_open_now(hours, datetime(2026, 8, 10, 1, 0)) is True
    assert is_open_now(hours, datetime(2026, 8, 10, 10, 0)) is False
