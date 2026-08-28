import asyncio

import pytest

from app.schemas.request_schema import NearbyPlaceCandidate, WalkingCourseRequest
from app.services import route_optimization_service, walking_course_service as svc

CENTER_LAT, CENTER_LNG = 37.4979, 127.0276
LOCAL_TIME = "2026-06-01T14:00:00"


@pytest.fixture(autouse=True)
def no_kakao_key_for_route_optimization(monkeypatch):
    # Keeps optimize_route() on the deterministic Haversine fallback so
    # these tests never make a real network call.
    monkeypatch.setattr(route_optimization_service, "KAKAO_REST_API_KEY", None)


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
