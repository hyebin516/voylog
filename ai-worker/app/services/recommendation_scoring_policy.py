"""Weights and heuristics for phase-2 nearby scoring (distance/time-of-day/
business-hours only -- no embeddings or tags yet). Kept in one place so
tuning never means hunting through multiple files.

When personalization signals (embedding similarity, tag match) land in a
later phase, their share of SCORE_WEIGHTS should come out of these three,
not be added on top of them.
"""

SCORE_WEIGHTS = {
    "distance": 0.45,
    "timeOfDay": 0.25,
    "businessHours": 0.30,
}

# A day is split into buckets; within each bucket, place categories in the
# list score higher on time-of-day fit. Categories not listed get a neutral
# 0.5 -- this is a light heuristic, not a claim about the place's real
# popularity at that hour.
_TIME_OF_DAY_CATEGORY_HINTS = {
    "morning": ["cafe", "bakery"],
    "lunch": ["restaurant", "dessert", "cafe"],
    "afternoon": ["cafe", "gallery", "museum", "attraction"],
    "evening": ["restaurant", "bar", "night_view"],
    "late_night": ["bar", "night_view"],
}

TIME_OF_DAY_MATCH_SCORE = 1.0
TIME_OF_DAY_NEUTRAL_SCORE = 0.5

# Unknown business hours are neutral (no penalty for missing data); a
# confirmed-closed place is scored low but not filtered out entirely, since
# "closed right now" can still be worth showing for later.
BUSINESS_HOURS_OPEN_SCORE = 1.0
BUSINESS_HOURS_UNKNOWN_SCORE = 0.5
BUSINESS_HOURS_CLOSED_SCORE = 0.1


def time_of_day_bucket(hour: int) -> str:
    if 5 <= hour < 11:
        return "morning"
    if 11 <= hour < 14:
        return "lunch"
    if 14 <= hour < 18:
        return "afternoon"
    if 18 <= hour < 22:
        return "evening"
    return "late_night"


def time_of_day_score(category: str | None, hour: int) -> float:
    if not category:
        return TIME_OF_DAY_NEUTRAL_SCORE
    bucket = time_of_day_bucket(hour)
    if category in _TIME_OF_DAY_CATEGORY_HINTS[bucket]:
        return TIME_OF_DAY_MATCH_SCORE
    return TIME_OF_DAY_NEUTRAL_SCORE


def business_hours_score(is_open: bool | None) -> float:
    if is_open is None:
        return BUSINESS_HOURS_UNKNOWN_SCORE
    return BUSINESS_HOURS_OPEN_SCORE if is_open else BUSINESS_HOURS_CLOSED_SCORE
