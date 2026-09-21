from app.schemas.request_schema import NearbyPlaceCandidate, NearbyScoreRequest
from app.services import nearby_recommendation_service

LOCAL_TIME = "2026-08-10T12:00:00"  # Monday, lunch bucket


def make_request(**overrides):
    defaults = dict(latitude=37.5, longitude=127.0, localTime=LOCAL_TIME, radiusMeters=2000, limit=20, candidates=[])
    defaults.update(overrides)
    return NearbyScoreRequest(**defaults)


def test_excludes_candidates_beyond_the_radius():
    near = NearbyPlaceCandidate(placeId="p1", name="Near", latitude=37.5005, longitude=127.0)
    far = NearbyPlaceCandidate(placeId="p2", name="Far", latitude=38.5, longitude=127.0)

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[near, far], radiusMeters=1000))

    place_ids = [r.placeId for r in result.recommendations]
    assert "p1" in place_ids
    assert "p2" not in place_ids


def test_sorts_by_score_descending_and_closer_places_score_higher():
    near = NearbyPlaceCandidate(placeId="near", name="Near", latitude=37.5005, longitude=127.0)
    farther = NearbyPlaceCandidate(placeId="farther", name="Farther", latitude=37.508, longitude=127.0)

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[farther, near], radiusMeters=2000))

    assert [r.placeId for r in result.recommendations] == ["near", "farther"]
    assert result.recommendations[0].score >= result.recommendations[1].score


def test_unknown_business_hours_do_not_penalize_the_score():
    candidate = NearbyPlaceCandidate(placeId="p1", name="No hours", latitude=37.5005, longitude=127.0)

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[candidate]))

    rec = result.recommendations[0]
    assert rec.isOpen is None
    assert rec.isOpenEstimated is False
    assert rec.scoreDetails.businessHours == 0.5


def test_open_business_hours_score_higher_than_closed():
    open_candidate = NearbyPlaceCandidate(
        placeId="open",
        name="Open now",
        latitude=37.5005,
        longitude=127.0,
        businessHours={"mon": {"open": "09:00", "close": "21:00"}},
    )
    closed_candidate = NearbyPlaceCandidate(
        placeId="closed",
        name="Closed now",
        latitude=37.5006,
        longitude=127.0,
        businessHours={"mon": {"open": "00:00", "close": "01:00"}},
    )

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[open_candidate, closed_candidate]))

    by_id = {r.placeId: r for r in result.recommendations}
    assert by_id["open"].isOpen is True
    assert by_id["closed"].isOpen is False
    assert by_id["open"].score > by_id["closed"].score


def test_respects_the_limit():
    # Distinct names: look-alikes ("Place 0", "Place 1") collapse into one spot.
    names = ["북촌서점", "연남공방", "성수갤러리", "망원책방", "서촌카페"]
    candidates = [
        NearbyPlaceCandidate(placeId=f"p{i}", name=names[i], latitude=37.5 + i * 0.0001, longitude=127.0)
        for i in range(5)
    ]

    result = nearby_recommendation_service.score_nearby(make_request(candidates=candidates, limit=2))

    assert len(result.recommendations) == 2


def test_reason_mentions_distance_and_open_state():
    candidate = NearbyPlaceCandidate(
        placeId="p1",
        name="Place",
        latitude=37.5005,
        longitude=127.0,
        businessHours={"mon": {"open": "09:00", "close": "21:00"}},
    )

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[candidate]))

    assert "m 떨어져" in result.recommendations[0].reason
    assert "영업 중" in result.recommendations[0].reason


def test_no_embedding_similarity_when_the_user_has_no_preference_embedding():
    candidate = NearbyPlaceCandidate(placeId="p1", name="Place", latitude=37.5005, longitude=127.0, embedding=[1.0, 0.0])

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[candidate], userEmbedding=None))

    rec = result.recommendations[0]
    assert rec.scoreDetails.embeddingSimilarity is None


def test_no_embedding_similarity_when_the_candidate_has_no_embedding():
    candidate = NearbyPlaceCandidate(placeId="p1", name="Place", latitude=37.5005, longitude=127.0)

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[candidate], userEmbedding=[1.0, 0.0])
    )

    assert result.recommendations[0].scoreDetails.embeddingSimilarity is None


def test_a_closer_taste_match_outscores_a_worse_match_at_the_same_distance():
    matching = NearbyPlaceCandidate(placeId="match", name="Match", latitude=37.5005, longitude=127.0, embedding=[1.0, 0.0])
    opposite = NearbyPlaceCandidate(placeId="opposite", name="Opposite", latitude=37.5005, longitude=127.001, embedding=[-1.0, 0.0])

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[matching, opposite], userEmbedding=[1.0, 0.0])
    )

    by_id = {r.placeId: r for r in result.recommendations}
    assert by_id["match"].scoreDetails.embeddingSimilarity == 1.0
    assert by_id["opposite"].scoreDetails.embeddingSimilarity == 0.0
    assert by_id["match"].score > by_id["opposite"].score


def test_reason_mentions_taste_match_when_an_embedding_pair_is_present():
    candidate = NearbyPlaceCandidate(placeId="p1", name="Place", latitude=37.5005, longitude=127.0, embedding=[1.0, 0.0])

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[candidate], userEmbedding=[1.0, 0.0])
    )

    assert "취향" in result.recommendations[0].reason


def test_no_tag_match_when_the_user_has_no_tag_preferences():
    candidate = NearbyPlaceCandidate(
        placeId="p1", name="Place", latitude=37.5005, longitude=127.0, tags=[{"code": "소금빵", "confidence": 0.9}]
    )

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[candidate], userTagScores={}))

    assert result.recommendations[0].scoreDetails.tagMatch is None
    assert result.recommendations[0].matchedTags == []


def test_no_tag_match_when_the_candidate_has_no_tags():
    candidate = NearbyPlaceCandidate(placeId="p1", name="Place", latitude=37.5005, longitude=127.0)

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[candidate], userTagScores={"소금빵": 1.0})
    )

    assert result.recommendations[0].scoreDetails.tagMatch is None


def test_matched_tags_lists_the_overlapping_codes():
    candidate = NearbyPlaceCandidate(
        placeId="p1",
        name="Place",
        latitude=37.5005,
        longitude=127.0,
        tags=[{"code": "소금빵", "confidence": 0.9}, {"code": "야경", "confidence": 0.8}],
    )

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[candidate], userTagScores={"소금빵": 1.0, "오션뷰": 1.0})
    )

    rec = result.recommendations[0]
    assert rec.matchedTags == ["소금빵"]
    assert rec.scoreDetails.tagMatch is not None


def test_a_tag_match_outscores_no_match_at_the_same_distance():
    matching = NearbyPlaceCandidate(
        placeId="match",
        name="Match",
        latitude=37.5005,
        longitude=127.0,
        tags=[{"code": "소금빵", "confidence": 1.0}],
    )
    no_match = NearbyPlaceCandidate(
        placeId="no_match",
        name="Other",
        latitude=37.5005,
        longitude=127.001,
        tags=[{"code": "야경", "confidence": 1.0}],
    )

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[matching, no_match], userTagScores={"소금빵": 1.0})
    )

    by_id = {r.placeId: r for r in result.recommendations}
    assert by_id["match"].scoreDetails.tagMatch == 1.0
    assert by_id["no_match"].scoreDetails.tagMatch == 0.0
    assert by_id["match"].score > by_id["no_match"].score


def test_reason_names_the_matched_tags():
    candidate = NearbyPlaceCandidate(
        placeId="p1", name="Place", latitude=37.5005, longitude=127.0, tags=[{"code": "소금빵", "confidence": 0.9}]
    )

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[candidate], userTagScores={"소금빵": 1.0})
    )

    assert "소금빵" in result.recommendations[0].reason


def test_embedding_and_tag_signals_combine_without_error():
    candidate = NearbyPlaceCandidate(
        placeId="p1",
        name="Place",
        latitude=37.5005,
        longitude=127.0,
        embedding=[1.0, 0.0],
        tags=[{"code": "소금빵", "confidence": 0.9}],
    )

    result = nearby_recommendation_service.score_nearby(
        make_request(candidates=[candidate], userEmbedding=[1.0, 0.0], userTagScores={"소금빵": 1.0})
    )

    rec = result.recommendations[0]
    assert rec.scoreDetails.embeddingSimilarity is not None
    assert rec.scoreDetails.tagMatch is not None
    assert 0.0 <= rec.score <= 1.0


def test_reason_names_the_category_in_korean_with_the_right_particle():
    cafe = NearbyPlaceCandidate(placeId="p1", name="A", latitude=37.5005, longitude=127.0, category="cafe")
    restaurant = NearbyPlaceCandidate(placeId="p2", name="B", latitude=37.5005, longitude=127.0, category="restaurant")

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[cafe, restaurant]))
    reasons = {rec.placeId: rec.reason for rec in result.recommendations}

    assert "카페예요." in reasons["p1"]
    assert "음식점이에요." in reasons["p2"]
    assert "cafe" not in reasons["p1"]


def test_reason_omits_a_category_without_a_korean_label():
    candidate = NearbyPlaceCandidate(placeId="p1", name="A", latitude=37.5005, longitude=127.0, category="other")

    result = nearby_recommendation_service.score_nearby(make_request(candidates=[candidate]))

    assert "other" not in result.recommendations[0].reason


def test_nearby_list_shows_one_card_per_spot_and_backfills_the_slot():
    candidates = [
        NearbyPlaceCandidate(placeId="a", name="케이락", latitude=37.5005, longitude=127.0, category="attraction"),
        NearbyPlaceCandidate(placeId="b", name="케이락볼링장", latitude=37.5006, longitude=127.0, category="attraction"),
        NearbyPlaceCandidate(placeId="c", name="갤러리", latitude=37.5010, longitude=127.0, category="gallery"),
    ]

    result = nearby_recommendation_service.score_nearby(make_request(candidates=candidates, limit=2))

    ids = [rec.placeId for rec in result.recommendations]
    assert len(ids) == 2
    assert "c" in ids
    assert not {"a", "b"} <= set(ids)


def test_a_recommendation_carries_the_place_address_hours_and_tags_for_its_detail_screen():
    candidate = NearbyPlaceCandidate(
        placeId="p1",
        name="소베",
        latitude=37.5005,
        longitude=127.0,
        address="대구 중구 중앙대로79길 6",
        category="bakery",
        businessHours={"mon": {"open": "09:00", "close": "21:00"}},
        businessHoursIsEstimated=True,
        tags=[{"code": "소금빵", "confidence": 0.9}],
    )

    rec = nearby_recommendation_service.score_nearby(make_request(candidates=[candidate])).recommendations[0]

    assert rec.address == "대구 중구 중앙대로79길 6"
    assert rec.businessHours["mon"].open == "09:00"
    # The detail screen only labels hours as an estimate when the place's own
    # row says so -- carried instead of re-guessed from the hours' presence.
    assert rec.businessHoursIsEstimated is True
    assert rec.tags == ["소금빵"]
