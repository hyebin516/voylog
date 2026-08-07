from datetime import datetime
from typing import Optional

from app.schemas.request_schema import NearbyScoreRequest
from app.schemas.response_schema import NearbyRecommendation, NearbyScoreResponse, ScoreDetails
from app.services import recommendation_scoring_policy as policy
from app.utils.business_hours import is_open_now
from app.utils.distance import haversine_distance_m


def _distance_score(distance_m: float, radius_m: int) -> float:
    if radius_m <= 0:
        return 0.0
    return max(0.0, 1.0 - (distance_m / radius_m))


def _build_reason(distance_m: int, is_open: Optional[bool], category: Optional[str]) -> str:
    parts = [f"현재 위치에서 {distance_m}m 떨어져 있어요."]
    if is_open is True:
        parts.append("지금 영업 중이에요.")
    elif is_open is False:
        parts.append("지금은 영업 시간이 아니에요.")
    if category:
        parts.append(f"{category} 카테고리의 장소예요.")
    return " ".join(parts)


def score_nearby(request: NearbyScoreRequest) -> NearbyScoreResponse:
    local_dt = datetime.fromisoformat(request.localTime)

    scored = []
    for candidate in request.candidates:
        distance_m = haversine_distance_m(
            request.latitude, request.longitude, candidate.latitude, candidate.longitude
        )
        if distance_m > request.radiusMeters:
            continue

        is_open = is_open_now(candidate.businessHours, local_dt)

        details = ScoreDetails(
            distance=round(_distance_score(distance_m, request.radiusMeters), 3),
            timeOfDay=round(policy.time_of_day_score(candidate.category, local_dt.hour), 3),
            businessHours=round(policy.business_hours_score(is_open), 3),
        )
        score = round(
            details.distance * policy.SCORE_WEIGHTS["distance"]
            + details.timeOfDay * policy.SCORE_WEIGHTS["timeOfDay"]
            + details.businessHours * policy.SCORE_WEIGHTS["businessHours"],
            3,
        )

        scored.append(
            NearbyRecommendation(
                placeId=candidate.placeId,
                name=candidate.name,
                latitude=candidate.latitude,
                longitude=candidate.longitude,
                distanceMeters=round(distance_m),
                category=candidate.category,
                isOpen=is_open,
                isOpenEstimated=candidate.businessHours is not None,
                score=score,
                scoreDetails=details,
                reason=_build_reason(round(distance_m), is_open, candidate.category),
            )
        )

    scored.sort(key=lambda r: r.score, reverse=True)
    return NearbyScoreResponse(recommendations=scored[: request.limit])
