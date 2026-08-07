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
    candidates = [
        NearbyPlaceCandidate(placeId=f"p{i}", name=f"Place {i}", latitude=37.5 + i * 0.0001, longitude=127.0)
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
