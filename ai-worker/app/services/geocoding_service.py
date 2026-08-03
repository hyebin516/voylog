from typing import Optional

import httpx

from app.config import KAKAO_REST_API_KEY, KAKAO_TIMEOUT_SECONDS
from app.utils.logger import logger

KAKAO_KEYWORD_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json"


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
