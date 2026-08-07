from app.services import recommendation_scoring_policy as policy


def test_time_of_day_bucket_boundaries():
    assert policy.time_of_day_bucket(5) == "morning"
    assert policy.time_of_day_bucket(10) == "morning"
    assert policy.time_of_day_bucket(11) == "lunch"
    assert policy.time_of_day_bucket(14) == "afternoon"
    assert policy.time_of_day_bucket(18) == "evening"
    assert policy.time_of_day_bucket(22) == "late_night"
    assert policy.time_of_day_bucket(3) == "late_night"


def test_time_of_day_score_matches_category_in_bucket():
    assert policy.time_of_day_score("cafe", 8) == policy.TIME_OF_DAY_MATCH_SCORE
    assert policy.time_of_day_score("bar", 8) == policy.TIME_OF_DAY_NEUTRAL_SCORE


def test_time_of_day_score_is_neutral_when_category_is_missing():
    assert policy.time_of_day_score(None, 8) == policy.TIME_OF_DAY_NEUTRAL_SCORE


def test_business_hours_score_by_open_state():
    assert policy.business_hours_score(True) == policy.BUSINESS_HOURS_OPEN_SCORE
    assert policy.business_hours_score(False) == policy.BUSINESS_HOURS_CLOSED_SCORE
    assert policy.business_hours_score(None) == policy.BUSINESS_HOURS_UNKNOWN_SCORE
