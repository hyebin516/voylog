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


def test_embedding_similarity_score_rescales_cosine_range_to_zero_one():
    assert policy.embedding_similarity_score(1.0) == 1.0
    assert policy.embedding_similarity_score(-1.0) == 0.0
    assert policy.embedding_similarity_score(0.0) == 0.5


def test_embedding_similarity_score_is_zero_when_unavailable():
    assert policy.embedding_similarity_score(None) == 0.0


def test_tag_match_score_returns_none_when_either_side_has_no_tags():
    assert policy.tag_match_score({}, {"소금빵": 1.0}) is None
    assert policy.tag_match_score({"소금빵": 0.9}, {}) is None


def test_tag_match_score_is_zero_when_both_sides_have_tags_but_none_overlap():
    assert policy.tag_match_score({"오션뷰": 0.9}, {"소금빵": 1.0}) == 0.0


def test_tag_match_score_weights_by_both_confidence_and_learned_preference_strength():
    score = policy.tag_match_score({"소금빵": 0.8, "오션뷰": 0.6}, {"소금빵": 1.0, "오션뷰": 1.0, "야경": 1.0})
    assert round(score, 4) == round((0.8 * 1.0 + 0.6 * 1.0) / 3.0, 4)


def test_tag_match_score_is_floored_at_zero_when_the_user_dislikes_the_matched_tag():
    score = policy.tag_match_score({"소금빵": 0.9}, {"소금빵": -1.0})
    assert score == 0.0


def test_tag_match_score_rewards_a_stronger_relative_preference_more():
    candidate_tags = {"소금빵": 0.9}
    weak_pref = policy.tag_match_score(candidate_tags, {"소금빵": 0.5, "오션뷰": 1.0})
    strong_pref = policy.tag_match_score(candidate_tags, {"소금빵": 2.0, "오션뷰": 1.0})
    assert strong_pref > weak_pref


def test_weights_for_only_available_base_signals_matches_phase_two_ratios():
    weights = policy.weights_for({"distance", "timeOfDay", "businessHours"})

    assert round(weights["distance"], 3) == 0.45
    assert round(weights["timeOfDay"], 3) == 0.25
    assert round(weights["businessHours"], 3) == 0.30
    assert round(sum(weights.values()), 6) == 1.0


def test_weights_for_includes_only_the_requested_signals():
    weights = policy.weights_for({"distance", "timeOfDay", "businessHours", "embeddingSimilarity"})

    assert "embeddingSimilarity" in weights
    assert "tagMatch" not in weights
    assert round(sum(weights.values()), 6) == 1.0


def test_weights_for_all_five_signals_matches_base_weights_exactly():
    weights = policy.weights_for(set(policy.BASE_WEIGHTS.keys()))

    assert weights == policy.BASE_WEIGHTS
