"""Weights and heuristics for nearby scoring. Kept in one place so tuning
never means hunting through multiple files.

Two weight sets exist because embedding similarity is only meaningful when
*both* the user has a preference embedding (completed the taste survey) and
the candidate place has one (embedded at extraction time). Whenever either
is missing, scoring falls back to WITHOUT_EMBEDDING so a candidate/guest
without personalization data is never penalized for lacking it -- this is
the "재분배" behavior described in the design: personalization weight comes
out of these categories, it doesn't get silently dropped.

Tag-match scoring is not implemented yet (a later phase); when it lands its
share should come out of these too, not be added on top.
"""

SCORE_WEIGHTS_WITHOUT_EMBEDDING = {
    "distance": 0.45,
    "timeOfDay": 0.25,
    "businessHours": 0.30,
}

SCORE_WEIGHTS_WITH_EMBEDDING = {
    "distance": 0.25,
    "timeOfDay": 0.10,
    "businessHours": 0.20,
    "embeddingSimilarity": 0.45,
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


def embedding_similarity_score(cosine_similarity: float | None) -> float:
    """Rescales cosine similarity (-1..1) to a 0..1 score, matching the
    scale of the other components."""
    if cosine_similarity is None:
        return 0.0
    return max(0.0, min(1.0, (cosine_similarity + 1) / 2))


def weights_for(has_embedding_pair: bool) -> dict[str, float]:
    return SCORE_WEIGHTS_WITH_EMBEDDING if has_embedding_pair else SCORE_WEIGHTS_WITHOUT_EMBEDDING
