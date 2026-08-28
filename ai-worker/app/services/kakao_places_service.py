import asyncio
from typing import Dict, List

import httpx

from app.config import KAKAO_REST_API_KEY, KAKAO_TIMEOUT_SECONDS
from app.schemas.request_schema import NearbyPlaceCandidate
from app.utils.logger import logger

KAKAO_CATEGORY_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/category.json"

# Kakao's fixed category-group codes, mapped to the same free-text category
# strings this app already uses for LLM-extracted places (see
# recommendation_scoring_policy.py's _TIME_OF_DAY_CATEGORY_HINTS) so these
# candidates score identically on the timeOfDay signal.
CATEGORY_GROUP_CODES: Dict[str, str] = {
    "CE7": "cafe",
    "FD6": "restaurant",
    "AT4": "attraction",
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
