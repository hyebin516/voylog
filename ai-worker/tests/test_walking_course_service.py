import asyncio
import random

import pytest

from app.schemas.request_schema import (
    CoursePointInput,
    NearbyPlaceCandidate,
    NearbyPlaceTagInput,
    WalkingCourseRequest,
)
from app.schemas.response_schema import NearbyRecommendation, ScoreDetails
from app.services import kakao_places_service, route_optimization_service, walking_course_service as svc

CENTER_LAT, CENTER_LNG = 37.4979, 127.0276
LOCAL_TIME = "2026-06-01T14:00:00"


@pytest.fixture(autouse=True)
def no_kakao_key_for_route_optimization(monkeypatch):
    # Keeps optimize_route() on the deterministic Haversine fallback so
    # these tests never make a real network call.
    monkeypatch.setattr(route_optimization_service, "KAKAO_REST_API_KEY", None)

    # Same for the mood keyword search -- tests that don't care about it
    # must not reach the real Kakao API (which would also inject unexpected
    # candidates into their assertions).
    async def _no_mood_candidates(*args, **kwargs):
        return []

    monkeypatch.setattr(kakao_places_service, "search_nearby_by_mood", _no_mood_candidates)

    # Pin the seed to the single top-scored candidate so these tests assert
    # on scoring/clustering rather than on the deliberate randomness added
    # for course variety (exercised separately below).
    monkeypatch.setattr(svc, "SEED_POOL_SIZE", 1)
    monkeypatch.setattr(svc, "SCORE_JITTER", 0.0)


def _candidate(place_id, name, lat_offset_deg, lng_offset_deg=0.0):
    return NearbyPlaceCandidate(
        placeId=place_id,
        name=name,
        latitude=CENTER_LAT + lat_offset_deg,
        longitude=CENTER_LNG + lng_offset_deg,
    )


async def _no_kakao_candidates(*args, **kwargs):
    return []


def test_generate_walking_course_returns_no_course_when_there_are_no_candidates_at_all(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    request = WalkingCourseRequest(
        regionName="어딘가", centerLatitude=CENTER_LAT, centerLongitude=CENTER_LNG, localTime=LOCAL_TIME
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is None
    assert result.recommendations == []


def test_generate_walking_course_builds_a_course_from_mutually_close_bookmarked_places(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # ~0.005 deg lat ~= 550m apart -- close enough to cluster together.
    close_places = [_candidate(f"p{i}", f"장소{i}", 0.005 * i) for i in range(3)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=close_places,
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is not None
    assert result.course.transportMode == "walk"
    assert result.course.routeType == "roundTrip"
    selected_place_ids = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert selected_place_ids == {"p0", "p1", "p2"}
    assert len(result.recommendations) == 3


def test_generate_walking_course_excludes_places_too_far_from_the_walkable_cluster(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    close_places = [_candidate("near-1", "가까운곳1", 0.003), _candidate("near-2", "가까운곳2", 0.006)]
    # ~0.02 deg latitude is ~2.2km away: within the default 3000m scoring
    # radius (so score_nearby doesn't filter it out on its own), but well
    # beyond MAX_WALK_LEG_M from both near places -- this is what should
    # exercise the clustering logic itself, not just the radius filter.
    far_place = _candidate("far-1", "먼곳", 0.02)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=close_places + [far_place],
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is not None
    selected_place_ids = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert "far-1" not in selected_place_ids
    assert selected_place_ids == {"near-1", "near-2"}


def test_generate_walking_course_returns_no_course_when_fewer_than_two_places_are_mutually_walkable(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # Every place is far from every other place -- at most 1 can ever be
    # "selected" (the seed), never enough for a route.
    scattered_places = [_candidate("s1", "곳1", 0.2), _candidate("s2", "곳2", -0.2), _candidate("s3", "곳3", 0.0, 0.2)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        radiusMeters=50000,  # wide enough that scoring doesn't filter them out before clustering
        bookmarkCandidates=scattered_places,
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is None
    assert len(result.recommendations) == 1  # only the single seed candidate "survives" clustering


def test_generate_walking_course_boosts_a_place_tagged_with_the_selected_mood(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # All 5 candidates sit at the exact same distance from the center (same
    # lat offset magnitude, different longitude) and are mutually within
    # MAX_WALK_LEG_M -- so absent any tag boost every candidate's score
    # ties exactly and Python's stable sort keeps this original order.
    # "moody" is listed last, so without the mood boost it's the one
    # target_places=4 would cut.
    # Distinct names: numbered look-alikes ("평범한곳0", "평범한곳1") would be
    # merged as one listing by _same_spot_as_selected.
    plain_names = ["북촌서점", "연남공방", "성수갤러리", "망원책방"]
    plain_places = [_candidate(f"plain-{i}", plain_names[i], 0.004, 0.001 * i) for i in range(4)]
    moody_place = NearbyPlaceCandidate(
        placeId="moody-1",
        name="힙한곳",
        latitude=CENTER_LAT + 0.004,
        longitude=CENTER_LNG + 0.005,
        tags=[NearbyPlaceTagInput(code="힙한 분위기", confidence=1.0)],
    )

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=plain_places + [moody_place],
        walkDuration="2~3시간",  # targetPlaces=4, one fewer than the 5 candidates
        mood="힙한",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    selected_place_ids = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert "moody-1" in selected_place_ids
    assert len(selected_place_ids) == 4


def test_generate_walking_course_ignores_an_unrecognized_mood(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)
    close_places = [_candidate(f"p{i}", f"장소{i}", 0.005 * i) for i in range(3)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=close_places,
        mood="존재하지않는분위기",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is not None


def test_generate_walking_course_shorter_duration_targets_fewer_stops(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)
    # 6 mutually-close places -- the default (no duration filter) target of
    # 6 would include all of them.
    close_places = [_candidate(f"p{i}", f"장소{i}", 0.001 * i) for i in range(6)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=close_places,
        walkDuration="1시간 이내",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    selected_place_ids = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert len(selected_place_ids) <= 2


def test_generate_walking_course_longer_duration_allows_more_stops_than_the_default_target(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)
    # 8 mutually-close places -- more than the default target of 6.
    close_places = [_candidate(f"p{i}", f"장소{i}", 0.0008 * i) for i in range(8)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=close_places,
        walkDuration="반나절",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    selected_place_ids = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert len(selected_place_ids) == 8


def test_generate_walking_course_merges_bookmarked_and_kakao_candidates(monkeypatch):
    async def fake_kakao_search(latitude, longitude, radius_m):
        return [_candidate("kakao:1", "카카오카페", 0.004)]

    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", fake_kakao_search)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=[_candidate("bookmark-1", "북마크장소", 0.002)],
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is not None
    selected_place_ids = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert selected_place_ids == {"bookmark-1", "kakao:1"}


def test_generate_walking_course_anchors_on_the_region_center_when_no_hotel_is_given(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=[_candidate(f"p{i}", f"장소{i}", 0.005 * i) for i in range(3)],
    )
    result = asyncio.run(svc.generate_walking_course(request))

    hotel_points = [p for p in result.course.optimizedRoute if p.type == "hotel"]
    assert hotel_points
    assert all(p.hotelId == svc.VIRTUAL_REGION_ANCHOR_ID for p in hotel_points)
    assert all(p.name == "강남" for p in hotel_points)


def test_generate_walking_course_starts_and_ends_at_the_given_start_point(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=[_candidate(f"p{i}", f"장소{i}", 0.005 * i) for i in range(3)],
        startPoint=CoursePointInput(
            pointId="start-point",
            name="강남역 2번 출구",
            latitude=CENTER_LAT + 0.001,
            longitude=CENTER_LNG,
        ),
    )
    result = asyncio.run(svc.generate_walking_course(request))

    hotel_points = [p for p in result.course.optimizedRoute if p.type == "hotel"]
    assert hotel_points
    assert all(p.hotelId == "start-point" for p in hotel_points)
    assert all(p.name == "강남역 2번 출구" for p in hotel_points)
    # Still a round trip -- the hotel is both the start and the end.
    assert result.course.routeType == "roundTrip"


def test_select_walkable_cluster_varies_the_seed_across_runs(monkeypatch):
    monkeypatch.setattr(svc, "SEED_POOL_SIZE", 8)

    # 8 mutually-far places, so each run can only ever keep its seed --
    # whatever comes out first IS the seed the run picked.
    scored = [
        NearbyRecommendation(
            placeId=f"p{i}",
            name=f"장소{i}",
            latitude=CENTER_LAT + 0.2 * i,
            longitude=CENTER_LNG,
            score=1.0,
            distanceMeters=0,
            isOpenEstimated=False,
            scoreDetails=ScoreDetails(distance=1.0, timeOfDay=1.0, businessHours=1.0),
            matchedTags=[],
            reason="",
        )
        for i in range(8)
    ]

    seeds = {svc._select_walkable_cluster(scored, rng=random.Random(i))[0].placeId for i in range(20)}

    # A deterministic top-score seed would make this exactly one id.
    assert len(seeds) > 1


def test_select_walkable_cluster_is_reproducible_for_a_given_rng(monkeypatch):
    monkeypatch.setattr(svc, "SEED_POOL_SIZE", 8)

    scored = [
        NearbyRecommendation(
            placeId=f"p{i}",
            name=f"장소{i}",
            latitude=CENTER_LAT + 0.2 * i,
            longitude=CENTER_LNG,
            score=1.0,
            distanceMeters=0,
            isOpenEstimated=False,
            scoreDetails=ScoreDetails(distance=1.0, timeOfDay=1.0, businessHours=1.0),
            matchedTags=[],
            reason="",
        )
        for i in range(8)
    ]

    first = svc._select_walkable_cluster(scored, rng=random.Random(7))
    second = svc._select_walkable_cluster(scored, rng=random.Random(7))

    assert [p.placeId for p in first] == [p.placeId for p in second]


def test_generate_walking_course_adds_mood_specific_candidates_to_the_pool(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    asked = {}

    async def fake_mood_search(latitude, longitude, radius_m, mood):
        asked["mood"] = mood
        return [_candidate("mood-1", "감성카페", 0.004)]

    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_mood", fake_mood_search)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=[_candidate("p0", "장소0", 0.003)],
        mood="감성적인",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert asked["mood"] == "감성적인"
    selected_place_ids = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert "mood-1" in selected_place_ids


def test_generate_walking_course_does_not_search_by_mood_when_none_was_picked(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    called = {"mood_search": False}

    async def fake_mood_search(latitude, longitude, radius_m, mood):
        called["mood_search"] = True
        return []

    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_mood", fake_mood_search)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=[_candidate(f"p{i}", f"장소{i}", 0.005 * i) for i in range(3)],
    )
    asyncio.run(svc.generate_walking_course(request))

    assert called["mood_search"] is False


def test_generate_walking_course_does_not_repeat_a_place_found_by_both_searches(monkeypatch):
    duplicate = _candidate("kakao:dup", "중복장소", 0.004)

    async def fake_category_search(*args, **kwargs):
        return [duplicate]

    async def fake_mood_search(latitude, longitude, radius_m, mood):
        return [duplicate]

    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", fake_category_search)
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_mood", fake_mood_search)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=[_candidate("p0", "장소0", 0.003)],
        mood="감성적인",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    place_ids = [p.placeId for p in result.course.optimizedRoute if p.type == "place"]
    assert place_ids.count("kakao:dup") == 1


def test_generate_walking_course_duration_includes_time_spent_at_each_stop(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # Two cafes ~110m apart: a couple of minutes of walking, but a real
    # outing is dominated by the time spent in them.
    cafes = [
        NearbyPlaceCandidate(
            placeId=f"c{i}",
            name=f"카페{i}",
            latitude=CENTER_LAT + 0.001 * i,
            longitude=CENTER_LNG,
            category="cafe",
        )
        for i in range(2)
    ]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=cafes,
    )
    result = asyncio.run(svc.generate_walking_course(request))

    # 2 cafes x 40min dwell = 80min floor, plus whatever the walking adds.
    assert result.course.totalDurationSec >= 80 * 60


def test_generate_walking_course_keeps_a_half_day_course_within_its_budget(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    close_places = [_candidate(f"p{i}", f"장소{i}", 0.0008 * i) for i in range(10)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=close_places,
        walkDuration="반나절",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    # A full-day course should read like a full day, not like the ~20
    # minutes of walking between its stops.
    assert result.course.totalDurationSec >= 4 * 3600
    assert result.course.totalDurationSec <= 9 * 3600


def _categorized(place_id, name, category, lat_offset_deg):
    return NearbyPlaceCandidate(
        placeId=place_id,
        name=name,
        latitude=CENTER_LAT + lat_offset_deg,
        longitude=CENTER_LNG,
        category=category,
    )


def test_generate_walking_course_caps_cafes_per_course(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # Nothing but cafe-likes nearby -- the cap must still hold.
    candidates = [_categorized(f"cafe-{i}", f"카페{i}", "cafe", 0.0006 * i) for i in range(5)]
    candidates += [_categorized(f"bakery-{i}", f"빵집{i}", "bakery", 0.0006 * (i + 5)) for i in range(3)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=candidates,
    )
    result = asyncio.run(svc.generate_walking_course(request))

    selected = [p for p in result.course.optimizedRoute if p.type == "place"]
    by_id = {c.placeId: c.category for c in candidates}
    cafe_like = [p for p in selected if by_id[p.placeId] in {"cafe", "bakery", "dessert"}]
    assert len(cafe_like) <= svc.MAX_CAFE_LIKE_STOPS


def test_generate_walking_course_prefers_things_to_do_over_cafes(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # Same location/score profile, so only the category preference can
    # decide the ordering.
    cafes = [_categorized(f"cafe-{i}", f"카페{i}", "cafe", 0.0006 * i) for i in range(4)]
    attractions = [_categorized(f"play-{i}", f"놀거리{i}", "attraction", 0.0006 * (i + 4)) for i in range(4)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=cafes + attractions,
    )
    result = asyncio.run(svc.generate_walking_course(request))

    selected_ids = [p.placeId for p in result.course.optimizedRoute if p.type == "place"]
    play_count = len([i for i in selected_ids if i.startswith("play-")])
    cafe_count = len([i for i in selected_ids if i.startswith("cafe-")])
    assert play_count > cafe_count


def test_generate_walking_course_still_returns_a_course_when_the_budget_is_tighter_than_two_stops(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # Two restaurants (60min dwell each) against the 75-minute "1시간 이내"
    # budget: the budget alone can't fit both, but one stop isn't a course.
    restaurants = [_categorized(f"r{i}", f"식당{i}", "restaurant", 0.0006 * i) for i in range(2)]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=restaurants,
        walkDuration="1시간 이내",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is not None
    stops = [p for p in result.course.optimizedRoute if p.type == "place"]
    assert len(stops) == 2


def test_generate_walking_course_tops_up_with_the_shortest_stops_when_the_budget_is_tight(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    # A 20-minute bakery fits the tight budget far better than the
    # 60-minute restaurants, so the top-up should reach for it.
    candidates = [
        _categorized("r0", "식당0", "restaurant", 0.0),
        _categorized("r1", "식당1", "restaurant", 0.0006),
        _categorized("b0", "빵집0", "bakery", 0.0012),
    ]

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        bookmarkCandidates=candidates,
        walkDuration="1시간 이내",
    )
    result = asyncio.run(svc.generate_walking_course(request))

    stops = {p.placeId for p in result.course.optimizedRoute if p.type == "place"}
    assert len(stops) >= svc.MIN_COURSE_PLACES
    assert "b0" in stops


def _rec(place_id, lat_offset_deg, score=0.8, category=None, lng_offset_deg=0.0):
    return NearbyRecommendation(
        placeId=place_id,
        name=place_id,
        latitude=CENTER_LAT + lat_offset_deg,
        longitude=CENTER_LNG + lng_offset_deg,
        score=score,
        distanceMeters=0,
        category=category,
        isOpenEstimated=False,
        scoreDetails=ScoreDetails(distance=1.0, timeOfDay=1.0, businessHours=1.0),
        matchedTags=[],
        reason="",
    )


def test_mood_matched_places_outrank_generic_play_places():
    """Base scores only differ by a few hundredths, so a play-category bonus
    alone used to put the same attractions on top for every mood."""
    scored = [
        _rec("gallery", 0.0001, score=0.84, category="gallery"),
        _rec("market", 0.0002, score=0.82, category="other"),
    ]

    selected = svc._select_walkable_cluster(
        scored, target_places=1, rng=random.Random(0), mood_place_ids=frozenset({"market"})
    )

    assert selected[0].placeId == "market"


def test_different_moods_can_produce_different_courses():
    scored = [
        _rec("gallery", 0.0001, score=0.84, category="gallery"),
        _rec("bookstore", 0.0003, score=0.82),
        _rec("market", 0.0005, score=0.82),
    ]

    quiet = svc._select_walkable_cluster(
        scored, target_places=1, rng=random.Random(0), mood_place_ids=frozenset({"bookstore"})
    )
    lively = svc._select_walkable_cluster(
        scored, target_places=1, rng=random.Random(0), mood_place_ids=frozenset({"market"})
    )

    assert quiet[0].placeId != lively[0].placeId


def test_regenerating_pushes_the_previous_course_down_the_ranking():
    scored = [_rec(f"p{i}", 0.0005 * i, score=0.9 - 0.01 * i, category="attraction") for i in range(8)]
    first = svc._select_walkable_cluster(scored, target_places=3, rng=random.Random(0))

    again = svc._select_walkable_cluster(
        scored,
        target_places=3,
        rng=random.Random(0),
        avoid_place_ids=frozenset(p.placeId for p in first),
    )

    assert not {p.placeId for p in first} & {p.placeId for p in again}


def test_avoided_places_are_still_used_when_nothing_else_fits():
    """A penalty, not an exclusion -- a sparse area must still yield a course."""
    scored = [_rec("a", 0.0), _rec("b", 0.001)]

    selected = svc._select_walkable_cluster(
        scored, target_places=2, rng=random.Random(0), avoid_place_ids=frozenset({"a", "b"})
    )

    assert {p.placeId for p in selected} == {"a", "b"}


def test_does_not_pick_two_stops_at_the_same_spot():
    """Two listings in one building share coordinates, which also stacked
    their map pins so one of them was invisible."""
    scored = [
        _rec("art-center", 0.0, score=0.9),
        _rec("gallery-same-building", 0.0, score=0.89),
        _rec("park", 0.003, score=0.5),
    ]

    selected = svc._select_walkable_cluster(scored, target_places=3, rng=random.Random(0))
    ids = {p.placeId for p in selected}

    assert not {"art-center", "gallery-same-building"} <= ids
    assert "park" in ids


def test_jitter_varies_the_order_between_runs(monkeypatch):
    monkeypatch.setattr(svc, "SCORE_JITTER", 0.1)
    scored = [_rec(f"p{i}", 0.0005 * i, score=0.85 - 0.002 * i) for i in range(10)]

    courses = {
        tuple(p.placeId for p in svc._select_walkable_cluster(scored, target_places=3, rng=random.Random(seed)))
        for seed in range(15)
    }

    assert len(courses) > 1


def test_generate_walking_course_uses_stored_place_candidates(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)

    request = WalkingCourseRequest(
        regionName="강남",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        placeCandidates=[_candidate("dataset-1", "고궁", 0.002), _candidate("dataset-2", "미술관", 0.004)],
    )
    result = asyncio.run(svc.generate_walking_course(request))

    assert result.course is not None
    assert {p.placeId for p in result.course.optimizedRoute if p.type == "place"} == {"dataset-1", "dataset-2"}


def test_dedupe_same_place_drops_a_second_source_listing_of_the_same_shop():
    stored = _candidate("dataset-1", "스타벅스 판교점", 0.0)
    kakao_same_shop = _candidate("kakao:1", "스타벅스판교점", 0.0002)  # ~22m away
    other_branch_far = _candidate("kakao:2", "스타벅스 판교점", 0.01)  # ~1.1km away
    different_shop = _candidate("kakao:3", "블루보틀", 0.0002)

    kept = svc._dedupe_same_place([stored, kakao_same_shop, other_branch_far, different_shop])

    assert [c.placeId for c in kept] == ["dataset-1", "kakao:2", "kakao:3"]


def test_dedupe_same_place_catches_a_large_site_listed_at_different_points():
    tour_api = _candidate("dataset-1", "경복궁", 0.0)
    kakao = _candidate("kakao:1", "경복궁", 0.0015)  # ~170m away on the same grounds

    assert [c.placeId for c in svc._dedupe_same_place([tour_api, kakao])] == ["dataset-1"]


def test_generate_walking_course_gives_the_mood_bonus_to_stored_places_tagged_with_it(monkeypatch):
    monkeypatch.setattr(svc.kakao_places_service, "search_nearby_by_category", _no_kakao_candidates)
    captured = {}
    original = svc._select_walkable_cluster

    def spy(scored, **kwargs):
        captured["mood_place_ids"] = kwargs["mood_place_ids"]
        return original(scored, **kwargs)

    monkeypatch.setattr(svc, "_select_walkable_cluster", spy)
    palace = NearbyPlaceCandidate(
        placeId="dataset-1",
        name="고궁",
        latitude=CENTER_LAT + 0.002,
        longitude=CENTER_LNG,
        category="attraction",
        tags=[NearbyPlaceTagInput(code="전통적인 분위기", confidence=1)],
    )
    tagged_bar = NearbyPlaceCandidate(
        placeId="dataset-3",
        name="전통주점",
        latitude=CENTER_LAT + 0.0025,
        longitude=CENTER_LNG,
        category="bar",
        tags=[NearbyPlaceTagInput(code="전통적인 분위기", confidence=1)],
    )

    request = WalkingCourseRequest(
        regionName="종로",
        centerLatitude=CENTER_LAT,
        centerLongitude=CENTER_LNG,
        localTime=LOCAL_TIME,
        mood="전통적인",
        placeCandidates=[palace, tagged_bar, _candidate("dataset-2", "카페", 0.003)],
    )
    asyncio.run(svc.generate_walking_course(request))

    assert captured["mood_place_ids"] == frozenset({"dataset-1"})


def test_brand_key_strips_only_a_trailing_branch_word():
    assert svc._brand_key("한복남 경복궁점") == svc._brand_key("한복남 프리미엄점") == "한복남"
    assert svc._brand_key("강릉의 밤") == "강릉의밤"
    assert svc._brand_key("본점") == "본점"


def test_a_course_keeps_only_the_higher_ranked_branch_of_a_chain():
    lower = _rec("hanbok-premium", 0.001, score=0.70, category="attraction")
    lower.name = "한복남 프리미엄점"
    higher = _rec("hanbok-gyeongbokgung", 0.002, score=0.90, category="attraction")
    higher.name = "한복남 경복궁점"
    other = _rec("palace", 0.003, score=0.80, category="attraction")
    other.name = "경복궁"

    selected = svc._select_walkable_cluster([lower, higher, other], target_places=3, rng=random.Random(0))

    assert {s.placeId for s in selected} == {"hanbok-gyeongbokgung", "palace"}


def test_a_course_includes_at_most_one_meal_stop_by_default():
    scored = [
        _rec("restaurant-1", 0.001, score=0.95, category="restaurant"),
        _rec("restaurant-2", 0.002, score=0.94, category="restaurant"),
        _rec("bar-1", 0.003, score=0.93, category="bar"),
        _rec("museum", 0.004, score=0.60, category="museum"),
        _rec("shop", 0.005, score=0.55, category="shopping"),
    ]

    selected = svc._select_walkable_cluster(scored, target_places=5, rng=random.Random(0))

    meals = [s.placeId for s in selected if s.category in {"restaurant", "bar"}]
    assert meals == ["restaurant-1"]
    assert {"museum", "shop"} <= {s.placeId for s in selected}


def test_a_half_day_course_allows_two_meal_stops():
    scored = [_rec(f"restaurant-{i}", 0.001 * (i + 1), score=0.9 - i * 0.01, category="restaurant") for i in range(4)]

    selected = svc._select_walkable_cluster(scored, target_places=10, rng=random.Random(0), max_meal_stops=2)

    assert len(selected) == 2
    assert svc._DURATION_PROFILES["반나절"]["maxMealStops"] == 2


def _named(place_id, name, lat_offset_deg, score, category):
    rec = _rec(place_id, lat_offset_deg, score=score, category=category)
    rec.name = name
    return rec


def test_a_course_keeps_one_listing_of_a_place_listed_under_overlapping_names():
    scored = [
        _named("market-main", "제주동문시장", 0.0010, 0.95, "other"),
        _named("market-public", "제주동문공설시장", 0.0012, 0.90, "other"),
        _named("market-fish", "제주동문수산시장", 0.0014, 0.85, "other"),
        _named("market-cafe", "동문시장 과일모찌 운화당", 0.0016, 0.80, "cafe"),
        _named("gallery", "갤러리 세이브", 0.0030, 0.60, "museum"),
    ]

    selected = svc._select_walkable_cluster(scored, target_places=5, rng=random.Random(0))

    assert {s.placeId for s in selected} == {"market-main", "market-cafe", "gallery"}


def test_overlapping_names_far_apart_stay_separate_stops():
    scored = [
        _named("bowling-a", "케이락", 0.0010, 0.9, "attraction"),
        _named("bowling-b", "케이락볼링장", 0.0100, 0.8, "attraction"),  # ~1.1km away
    ]

    selected = svc._select_walkable_cluster(scored, target_places=2, rng=random.Random(0))

    assert len(selected) == 2
