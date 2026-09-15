from typing import List, Optional

import httpx

from app.config import KAKAO_REST_API_KEY, KAKAO_TIMEOUT_SECONDS
from app.utils.logger import logger

KAKAO_KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"
KAKAO_COORD_TO_ADDRESS_URL = "https://dapi.kakao.com/v2/local/geo/coord2address.json"

# Kakao caps a single keyword search page at 15 results.
MAX_SEARCH_SIZE = 15


async def geocode_place(name: str) -> Optional[dict]:
    if not KAKAO_REST_API_KEY:
        logger.warning("KAKAO_REST_API_KEY is not configured; skipping geocoding for %s", name)
        return None

    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    params = {"query": name, "size": 1}

    try:
        async with httpx.AsyncClient(timeout=KAKAO_TIMEOUT_SECONDS) as client:
            response = await client.get(KAKAO_KEYWORD_SEARCH_URL, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        logger.error("Kakao geocoding failed for '%s': %s", name, exc)
        return None

    documents = data.get("documents", [])
    if not documents:
        return None

    place = documents[0]
    return {
        "latitude": float(place["y"]),
        "longitude": float(place["x"]),
        "address": place.get("road_address_name") or place.get("address_name"),
    }


async def search_places(query: str, size: int = 8) -> List[dict]:
    """Keyword search returning multiple candidates (unlike geocode_place,
    which only resolves the single best match) -- used for hotel search so
    the user can pick among several results by name/address."""
    if not KAKAO_REST_API_KEY:
        logger.warning("KAKAO_REST_API_KEY is not configured; skipping place search for %s", query)
        return []

    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    params = {"query": query, "size": min(size, MAX_SEARCH_SIZE)}

    try:
        async with httpx.AsyncClient(timeout=KAKAO_TIMEOUT_SECONDS) as client:
            response = await client.get(KAKAO_KEYWORD_SEARCH_URL, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        logger.warning("Kakao keyword search failed for '%s': %s", query, exc)
        return []

    candidates = []
    for doc in data.get("documents", []):
        candidates.append(
            {
                "placeId": f"kakao:{doc['id']}",
                "name": doc["place_name"],
                "address": doc.get("road_address_name") or doc.get("address_name"),
                "latitude": float(doc["y"]),
                "longitude": float(doc["x"]),
            }
        )
    return candidates


async def reverse_geocode(latitude: float, longitude: float) -> Optional[str]:
    """Resolves a coordinate (e.g. a dragged map center with no keyword
    match) back to a street address, for the "지도에서 직접 고르기" fallback
    where the user didn't pick a keyword-search candidate."""
    if not KAKAO_REST_API_KEY:
        logger.warning("KAKAO_REST_API_KEY is not configured; skipping reverse geocoding")
        return None

    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}
    params = {"x": longitude, "y": latitude}

    try:
        async with httpx.AsyncClient(timeout=KAKAO_TIMEOUT_SECONDS) as client:
            response = await client.get(KAKAO_COORD_TO_ADDRESS_URL, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        logger.error("Kakao reverse geocoding failed for (%s, %s): %s", latitude, longitude, exc)
        return None

    documents = data.get("documents", [])
    if not documents:
        return None

    doc = documents[0]
    road_address = doc.get("road_address")
    if road_address and road_address.get("address_name"):
        return road_address["address_name"]
    address = doc.get("address")
    return address.get("address_name") if address else None
