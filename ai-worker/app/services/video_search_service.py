import httpx

from app.config import YOUTUBE_API_KEY, YOUTUBE_TIMEOUT_SECONDS
from app.schemas.request_schema import HashtagSearchRequest
from app.schemas.response_schema import HashtagSearchResponse, VideoSearchResult
from app.utils.exceptions import YoutubeSearchError
from app.utils.logger import logger

YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"


def _normalize_hashtag(hashtag: str) -> str:
    hashtag = hashtag.strip()
    return hashtag if hashtag.startswith("#") else f"#{hashtag}"


async def search_by_hashtag(request: HashtagSearchRequest) -> HashtagSearchResponse:
    if not YOUTUBE_API_KEY:
        raise YoutubeSearchError("YouTube API key is not configured")

    params = {
        "part": "snippet",
        "q": _normalize_hashtag(request.hashtag),
        "type": "video",
        "maxResults": request.maxResults,
        "key": YOUTUBE_API_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=YOUTUBE_TIMEOUT_SECONDS) as client:
            response = await client.get(YOUTUBE_SEARCH_URL, params=params)
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        logger.error("YouTube hashtag search failed for '%s': %s", request.hashtag, exc)
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
