from typing import Dict

from app.schemas.request_schema import SimilarTasteRequest
from app.schemas.response_schema import SimilarTasteRecommendation, SimilarTasteResponse
from app.utils.vector_math import cosine_similarity

# Below this, a user's taste is considered "not similar enough" to count as
# a signal at all -- without a floor, everyone's bookmarks would contribute
# *some* weight (even a slightly-negative one), turning this into "globally
# popular places" rather than "places people like me bookmarked".
MIN_SIMILARITY = 0.3


def score_similar_taste(request: SimilarTasteRequest) -> SimilarTasteResponse:
    entries: Dict[str, dict] = {}

    for other in request.otherUsers:
        if not other.embedding:
            continue
        similarity = cosine_similarity(request.userEmbedding, other.embedding)
        if similarity is None or similarity < MIN_SIMILARITY:
            continue

        for place in other.bookmarkedPlaces:
            entry = entries.setdefault(place.placeId, {"place": place, "score": 0.0, "contributorCount": 0})
            entry["score"] += similarity
            entry["contributorCount"] += 1

    ranked = sorted(entries.values(), key=lambda e: e["score"], reverse=True)[: request.limit]

    recommendations = [
        SimilarTasteRecommendation(
            placeId=entry["place"].placeId,
            name=entry["place"].name,
            latitude=entry["place"].latitude,
            longitude=entry["place"].longitude,
            address=entry["place"].address,
            category=entry["place"].category,
            score=round(entry["score"], 3),
            contributorCount=entry["contributorCount"],
            reason=f"취향이 비슷한 사용자 {entry['contributorCount']}명이 북마크한 곳이에요.",
        )
        for entry in ranked
    ]

    return SimilarTasteResponse(recommendations=recommendations)
