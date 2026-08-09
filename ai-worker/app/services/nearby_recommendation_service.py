from datetime import datetime
from typing import List, Optional

from app.schemas.request_schema import NearbyScoreRequest
from app.schemas.response_schema import NearbyRecommendation, NearbyScoreResponse, ScoreDetails
from app.services import recommendation_scoring_policy as policy
from app.utils.business_hours import is_open_now
from app.utils.distance import haversine_distance_m
from app.utils.vector_math import cosine_similarity


def _distance_score(distance_m: float, radius_m: int) -> float:
    if radius_m <= 0:
        return 0.0
    return max(0.0, 1.0 - (distance_m / radius_m))


def _build_reason(
    distance_m: int,
    is_open: Optional[bool],
    category: Optional[str],
    has_embedding_pair: bool,
    matched_tags: List[str],
) -> str:
    parts = [f"현재 위치에서 {distance_m}m 떨어져 있어요."]
    if is_open is True:
        parts.append("지금 영업 중이에요.")
    elif is_open is False:
        parts.append("지금은 영업 시간이 아니에요.")
    if matched_tags:
        sample = ", ".join(matched_tags[:2])
        parts.append(f"취향으로 등록하신 {sample}와 잘 맞는 곳이에요.")
    elif has_embedding_pair:
        parts.append("취향에 맞는 장소예요.")
    if category:
        parts.append(f"{category} 카테고리의 장소예요.")
    return " ".join(parts)


def score_nearby(request: NearbyScoreRequest) -> NearbyScoreResponse:
    local_dt = datetime.fromisoformat(request.localTime)
    user_tag_codes = set(request.userTagCodes)

    scored = []
    for candidate in request.candidates:
        distance_m = haversine_distance_m(
            request.latitude, request.longitude, candidate.latitude, candidate.longitude
        )
        if distance_m > request.radiusMeters:
            continue

        is_open = is_open_now(candidate.businessHours, local_dt)

        similarity = None
        if request.userEmbedding and candidate.embedding:
            similarity = cosine_similarity(request.userEmbedding, candidate.embedding)
        has_embedding_pair = similarity is not None

        candidate_tag_confidences = {tag.code: tag.confidence for tag in candidate.tags}
        tag_score = policy.tag_match_score(candidate_tag_confidences, user_tag_codes)
        has_tag_pair = tag_score is not None
        matched_tags = sorted(user_tag_codes & candidate_tag_confidences.keys()) if has_tag_pair else []

        available = {"distance", "timeOfDay", "businessHours"}
        if has_embedding_pair:
            available.add("embeddingSimilarity")
        if has_tag_pair:
            available.add("tagMatch")
        weights = policy.weights_for(available)

        details = ScoreDetails(
            distance=round(_distance_score(distance_m, request.radiusMeters), 3),
            timeOfDay=round(policy.time_of_day_score(candidate.category, local_dt.hour), 3),
            businessHours=round(policy.business_hours_score(is_open), 3),
            embeddingSimilarity=round(policy.embedding_similarity_score(similarity), 3) if has_embedding_pair else None,
            tagMatch=round(tag_score, 3) if has_tag_pair else None,
        )

        score = round(
            details.distance * weights["distance"]
            + details.timeOfDay * weights["timeOfDay"]
            + details.businessHours * weights["businessHours"]
            + (details.embeddingSimilarity * weights["embeddingSimilarity"] if has_embedding_pair else 0.0)
            + (details.tagMatch * weights["tagMatch"] if has_tag_pair else 0.0),
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
                matchedTags=matched_tags,
                reason=_build_reason(round(distance_m), is_open, candidate.category, has_embedding_pair, matched_tags),
            )
        )

    scored.sort(key=lambda r: r.score, reverse=True)
    return NearbyScoreResponse(recommendations=scored[: request.limit])
