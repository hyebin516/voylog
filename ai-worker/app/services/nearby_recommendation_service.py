from datetime import datetime
from typing import List, Optional

from app.schemas.request_schema import NearbyScoreRequest
from app.schemas.response_schema import NearbyRecommendation, NearbyScoreResponse, ScoreDetails
from app.services import recommendation_scoring_policy as policy
from app.utils.business_hours import is_open_now
from app.utils.distance import haversine_distance_m
from app.utils.place_similarity import collapse_same_spots
from app.utils.vector_math import cosine_similarity


def _distance_score(distance_m: float, radius_m: int) -> float:
    if radius_m <= 0:
        return 0.0
    return max(0.0, 1.0 - (distance_m / radius_m))


# Shown to users inside the reason sentence, so the internal category codes
# need Korean names. A category without a label (e.g. "other", or free text
# from an older extraction) is simply not mentioned.
_CATEGORY_LABELS = {
    "cafe": "카페",
    "bakery": "베이커리",
    "restaurant": "음식점",
    "dessert": "디저트 가게",
    "bar": "술집",
    "museum": "박물관",
    "gallery": "미술관",
    "attraction": "관광 명소",
    "shopping": "쇼핑 장소",
    "beach": "바닷가",
    "night_view": "전망 명소",
}


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
    category_label = _CATEGORY_LABELS.get(category or "")
    if category_label:
        parts.append(f"{category_label}예요." if _ends_with_vowel(category_label) else f"{category_label}이에요.")
    return " ".join(parts)


def _ends_with_vowel(word: str) -> bool:
    """True when the last Hangul syllable has no final consonant, which picks
    "예요" over "이에요" ("카페예요" / "음식점이에요")."""
    last = word[-1]
    if not "가" <= last <= "힣":
        return True
    return (ord(last) - ord("가")) % 28 == 0


def score_nearby(request: NearbyScoreRequest) -> NearbyScoreResponse:
    local_dt = datetime.fromisoformat(request.localTime)
    user_tag_scores = request.userTagScores

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
        tag_score = policy.tag_match_score(candidate_tag_confidences, user_tag_scores)
        has_tag_pair = tag_score is not None
        matched_tags = (
            sorted(code for code in (set(user_tag_scores) & candidate_tag_confidences.keys()) if user_tag_scores[code] > 0)
            if has_tag_pair
            else []
        )

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
                address=candidate.address,
                businessHours=candidate.businessHours,
                businessHoursIsEstimated=candidate.businessHoursIsEstimated,
                tags=[tag.code for tag in candidate.tags],
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
    if request.collapseSameSpots:
        # Before the limit, so a collapsed duplicate frees its slot for
        # another place rather than shortening the list.
        scored = collapse_same_spots(scored)
    return NearbyScoreResponse(recommendations=scored[: request.limit])
