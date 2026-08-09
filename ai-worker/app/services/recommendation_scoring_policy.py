"""Weights and heuristics for nearby scoring. Kept in one place so tuning
never means hunting through multiple files.

distance/timeOfDay/businessHours are always computable. embeddingSimilarity
and tagMatch are only meaningful when *both* sides have the data (the user
completed the taste survey / has behavior-derived preferences, and the
candidate place has an embedding or tags from extraction). weights_for()
renormalizes BASE_WEIGHTS over whichever signals are actually available, so
a guest or a candidate lacking personalization data is never penalized for
it -- its share is redistributed, never silently dropped, and never added
on top of the always-available signals either.
"""

BASE_WEIGHTS = {
    "distance": 0.225,
    "timeOfDay": 0.125,
    "businessHours": 0.15,
    "embeddingSimilarity": 0.35,
    "tagMatch": 0.15,
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


def tag_match_score(candidate_tag_confidences: dict[str, float], user_tag_scores: dict[str, float]) -> float | None:
    """user_tag_scores is a *learned* preference strength per tag (seeded at
    1.0 from the taste survey, then nudged by behavior -- see phase 5's
    updateUserPreferenceFromBehavior), not just a flat set of chosen codes.

    None means "can't compare" (one side has no tags at all) -- distinct
    from a real 0.0, which means both sides have tags but the overlap is
    net non-positive (no overlap, or the user has behaviorally soured on
    the tags this place has)."""
    if not candidate_tag_confidences or not user_tag_scores:
        return None

    overlap = set(candidate_tag_confidences) & set(user_tag_scores)
    if not overlap:
        return 0.0

    matched_weight = sum(candidate_tag_confidences[code] * user_tag_scores[code] for code in overlap)
    total_possible = sum(abs(score) for score in user_tag_scores.values())
    if total_possible == 0:
        return 0.0

    return max(0.0, min(1.0, matched_weight / total_possible))


def weights_for(available: set[str]) -> dict[str, float]:
    total = sum(BASE_WEIGHTS[key] for key in available)
    if total == 0:
        return {key: 0.0 for key in available}
    return {key: BASE_WEIGHTS[key] / total for key in available}
