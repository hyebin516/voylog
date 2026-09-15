import asyncio
from typing import Dict, List

import httpx

from app.config import KAKAO_REST_API_KEY, KAKAO_TIMEOUT_SECONDS
from app.schemas.request_schema import NearbyPlaceCandidate
from app.utils.logger import logger

KAKAO_CATEGORY_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/category.json"
KAKAO_KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"

# Search terms that actually pull a different set of places per mood. The
# category search alone returns the same cafes/restaurants/attractions no
# matter which mood was picked, which is why every mood used to produce an
# identical course -- the mood only nudged tag scores, and Kakao candidates
# carry no tags to nudge.
MOOD_SEARCH_KEYWORDS: Dict[str, List[str]] = {
    "조용한": ["조용한 카페", "책방", "산책로"],
    "활기찬": ["시장", "번화가 맛집", "놀거리"],
    "감성적인": ["감성 카페", "전시", "사진 명소"],
    "힙한": ["소품샵", "편집샵", "루프탑"],
    "전통적인": ["한옥", "전통 찻집", "고택"],
    "로컬스러운": ["노포", "로컬 맛집", "동네 카페"],
}

# Kakao's fixed category-group codes, mapped to the same free-text category
# strings this app already uses for LLM-extracted places (see
# recommendation_scoring_policy.py's _TIME_OF_DAY_CATEGORY_HINTS) so these
# candidates score identically on the timeOfDay signal.
CATEGORY_GROUP_CODES: Dict[str, str] = {
    "CE7": "cafe",
    "FD6": "restaurant",
    "AT4": "attraction",
    # Museums/galleries/theaters. Without this the only non-eating option
    # was AT4, so a course had little to offer besides cafes.
    "CT1": "museum",
}

# Kakao caps a single category search page at 15 results.
MAX_PAGE_SIZE = 15


async def _search_category(client: httpx.AsyncClient, code: str, category: str, latitude: float, longitude: float, radius_m: int) -> List[NearbyPlaceCandidate]:
    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    params = {
        "category_group_code": code,
        "x": longitude,
        "y": latitude,
        "radius": min(radius_m, 20000),
        "size": MAX_PAGE_SIZE,
    }

    try:
        response = await client.get(KAKAO_CATEGORY_SEARCH_URL, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
    except Exception as exc:
        logger.warning("Kakao category search failed for %s: %s", code, exc)
        return []

    candidates = []
    for doc in data.get("documents", []):
        candidates.append(
            NearbyPlaceCandidate(
                placeId=f"kakao:{doc['id']}",
                name=doc["place_name"],
                latitude=float(doc["y"]),
                longitude=float(doc["x"]),
                category=category,
                businessHours=None,
                embedding=None,
                tags=[],
            )
        )
    return candidates


async def _search_keyword(
    client: httpx.AsyncClient, keyword: str, latitude: float, longitude: float, radius_m: int
) -> List[NearbyPlaceCandidate]:
    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    params = {
        "query": keyword,
        "x": longitude,
        "y": latitude,
        "radius": min(radius_m, 20000),
        "size": MAX_PAGE_SIZE,
    }

    try:
        response = await client.get(KAKAO_KEYWORD_SEARCH_URL, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
    except Exception as exc:
        logger.warning("Kakao keyword search failed for '%s': %s", keyword, exc)
        return []

    candidates = []
    for doc in data.get("documents", []):
        candidates.append(
            NearbyPlaceCandidate(
                placeId=f"kakao:{doc['id']}",
                name=doc["place_name"],
                latitude=float(doc["y"]),
                longitude=float(doc["x"]),
                category=CATEGORY_GROUP_CODES.get(doc.get("category_group_code"), "other"),
                businessHours=None,
                embedding=None,
                tags=[],
            )
        )
    return candidates


async def search_nearby_by_mood(
    latitude: float, longitude: float, radius_m: int, mood: str
) -> List[NearbyPlaceCandidate]:
    """Mood-specific Kakao listings near a point, so picking a different
    mood actually changes which places are in the running."""
    keywords = MOOD_SEARCH_KEYWORDS.get(mood)
    if not keywords or not KAKAO_REST_API_KEY:
        return []

    async with httpx.AsyncClient(timeout=KAKAO_TIMEOUT_SECONDS) as client:
        results = await asyncio.gather(
            *(_search_keyword(client, keyword, latitude, longitude, radius_m) for keyword in keywords)
        )

    candidates: List[NearbyPlaceCandidate] = []
    for result in results:
        candidates.extend(result)
    return candidates


async def search_nearby_by_category(latitude: float, longitude: float, radius_m: int) -> List[NearbyPlaceCandidate]:
    """Live Kakao Local business listings (cafes/restaurants/attractions) near
    a point -- used to guarantee candidate coverage even in regions with no
    bookmarked places yet (cold start)."""
    if not KAKAO_REST_API_KEY:
        logger.warning("KAKAO_REST_API_KEY is not configured; skipping Kakao category search")
        return []

    async with httpx.AsyncClient(timeout=KAKAO_TIMEOUT_SECONDS) as client:
        results = await asyncio.gather(
            *(
                _search_category(client, code, category, latitude, longitude, radius_m)
                for code, category in CATEGORY_GROUP_CODES.items()
            )
        )

    candidates: List[NearbyPlaceCandidate] = []
    for result in results:
        candidates.extend(result)
    return candidates
