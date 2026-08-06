import httpx

from app.config import YOUTUBE_API_KEY, YOUTUBE_TIMEOUT_SECONDS
from app.schemas.request_schema import HashtagSearchRequest, VideoSearchRequest
from app.schemas.response_schema import HashtagSearchResponse, VideoSearchResult
from app.utils.exceptions import YoutubeSearchError
from app.utils.logger import logger

YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"


def _normalize_hashtag(hashtag: str) -> str:
    hashtag = hashtag.strip()
    return hashtag if hashtag.startswith("#") else f"#{hashtag}"


async def _search_youtube(query: str, max_results: int) -> HashtagSearchResponse:
    if not YOUTUBE_API_KEY:
        raise YoutubeSearchError("YouTube API key is not configured")

    params = {
        "part": "snippet",
        "q": query,
        "type": "video",
        "maxResults": max_results,
        "key": YOUTUBE_API_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=YOUTUBE_TIMEOUT_SECONDS) as client:
            response = await client.get(YOUTUBE_SEARCH_URL, params=params)
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        logger.error("YouTube search failed for '%s': %s", query, exc)
        raise YoutubeSearchError()

    videos = []
    for item in data.get("items", []):
        video_id = item.get("id", {}).get("videoId")
        if not video_id:
            continue

        snippet = item.get("snippet", {})
        videos.append(
            VideoSearchResult(
                videoId=video_id,
                youtubeUrl=f"https://www.youtube.com/watch?v={video_id}",
                title=snippet.get("title", ""),
                thumbnailUrl=snippet.get("thumbnails", {}).get("high", {}).get("url"),
                channelName=snippet.get("channelTitle"),
                publishedAt=snippet.get("publishedAt"),
            )
        )

    return HashtagSearchResponse(videos=videos)


async def search_by_hashtag(request: HashtagSearchRequest) -> HashtagSearchResponse:
    return await _search_youtube(_normalize_hashtag(request.hashtag), request.maxResults)


async def search_by_query(request: VideoSearchRequest) -> HashtagSearchResponse:
    """Free-form keyword search — used by the region/theme/duration
    recommendation wizard, which composes its own query string
    (e.g. "제주도 자연 1박2일 브이로그") rather than a single hashtag."""
    return await _search_youtube(request.query, request.maxResults)
