from typing import List

from app.schemas.request_schema import (
    HotelInput,
    NearbyScoreRequest,
    PlaceInput,
    RouteOptimizationRequest,
    WalkingCourseRequest,
)
from app.schemas.response_schema import NearbyRecommendation, WalkingCourseResponse
from app.services import kakao_places_service, nearby_recommendation_service, route_optimization_service
from app.utils.distance import haversine_distance_m

MIN_COURSE_PLACES = 2
MAX_COURSE_PLACES = 10
TARGET_COURSE_PLACES = 6

# Legs longer than this aren't "walkable" for the purposes of clustering --
# a candidate is only added to the course if it's within this distance of
# at least one place already selected, so the final course can't sprawl
# across a whole city even if a far-away candidate scores well on its own.
MAX_WALK_LEG_M = 1200


def _select_walkable_cluster(scored: List[NearbyRecommendation]) -> List[NearbyRecommendation]:
    """Greedily builds a mutually-walkable cluster from candidates already
    sorted by score (descending): the top-scored candidate seeds the
    cluster, and each subsequent candidate is only added if it's within
    MAX_WALK_LEG_M of at least one place already in the cluster. This is
    what keeps the generated course realistically walkable, rather than
    just computing a (possibly huge) walking time after the fact."""
    selected: List[NearbyRecommendation] = []

    for candidate in scored:
        if len(selected) >= TARGET_COURSE_PLACES:
            break
        if selected and not any(
            haversine_distance_m(candidate.latitude, candidate.longitude, s.latitude, s.longitude) <= MAX_WALK_LEG_M
            for s in selected
        ):
            continue
        selected.append(candidate)

    return selected


async def generate_walking_course(request: WalkingCourseRequest) -> WalkingCourseResponse:
    kakao_candidates = await kakao_places_service.search_nearby_by_category(
        request.centerLatitude, request.centerLongitude, request.radiusMeters
    )
    all_candidates = list(request.bookmarkCandidates) + kakao_candidates

    if not all_candidates:
        return WalkingCourseResponse(course=None, recommendations=[])

    scored = nearby_recommendation_service.score_nearby(
        NearbyScoreRequest(
            latitude=request.centerLatitude,
            longitude=request.centerLongitude,
            localTime=request.localTime,
            radiusMeters=request.radiusMeters,
            limit=len(all_candidates),
            candidates=all_candidates,
            userEmbedding=request.userEmbedding,
            userTagScores=request.userTagScores,
        )
    ).recommendations

    selected = _select_walkable_cluster(scored)
    if len(selected) < MIN_COURSE_PLACES:
        return WalkingCourseResponse(course=None, recommendations=selected)

    # The course starts and ends at the region's center point -- there's no
    # real hotel here (this is a discovery flow, not a saved trip), so this
    # id is synthetic and never persisted.
    center_point = HotelInput(
        hotelId="region-center",
        name=request.regionName,
        latitude=request.centerLatitude,
        longitude=request.centerLongitude,
    )
    course = await route_optimization_service.optimize_route(
        RouteOptimizationRequest(
            startHotel=center_point,
            endHotel=center_point,
            places=[PlaceInput(placeId=c.placeId, name=c.name, latitude=c.latitude, longitude=c.longitude) for c in selected],
            routeType="roundTrip",
            optimizationPriority="duration",
            transportMode="walk",
        )
    )

    return WalkingCourseResponse(course=course, recommendations=selected)
