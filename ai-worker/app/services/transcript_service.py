import re
from typing import Optional

import httpx
from youtube_transcript_api import NoTranscriptFound, TranscriptsDisabled, YouTubeTranscriptApi

from app.config import YOUTUBE_API_KEY
from app.schemas.response_schema import TranscriptResponse
from app.utils.exceptions import TranscriptNotFoundError
from app.utils.logger import logger

YOUTUBE_ID_PATTERN = re.compile(r"(?:v=|youtu\.be/)([\w-]{11})")


def extract_video_id(youtube_url: str) -> Optional[str]:
    match = YOUTUBE_ID_PATTERN.search(youtube_url)
    return match.group(1) if match else None


async def fetch_video_metadata(video_id: str) -> dict:
    if not YOUTUBE_API_KEY:
        return {}

    params = {
        "part": "snippet,contentDetails",
        "id": video_id,
        "key": YOUTUBE_API_KEY,
    }

    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get("https://www.googleapis.com/youtube/v3/videos", params=params)
        response.raise_for_status()
        data = response.json()

    items = data.get("items", [])
    if not items:
        return {}

    snippet = items[0]["snippet"]
    return {
        "title": snippet.get("title"),
        "description": snippet.get("description"),
        "thumbnailUrl": snippet.get("thumbnails", {}).get("high", {}).get("url"),
        "channelName": snippet.get("channelTitle"),
        "publishedAt": snippet.get("publishedAt"),
        "hashtags": snippet.get("tags", []) or [],
    }


def fetch_transcript_segments(video_id: str) -> list[dict]:
    try:
        fetched = YouTubeTranscriptApi().fetch(video_id, languages=["ko", "en"])
    except (TranscriptsDisabled, NoTranscriptFound):
        raise TranscriptNotFoundError()
    except Exception as exc:
        logger.error("Failed to fetch transcript for %s: %s", video_id, exc)
        raise TranscriptNotFoundError()

    return [{"text": seg.text, "timestampSec": int(seg.start)} for seg in fetched]


async def get_transcript(youtube_url: str) -> TranscriptResponse:
    video_id = extract_video_id(youtube_url)
    if not video_id:
        raise TranscriptNotFoundError("Could not parse a YouTube video id from the given URL")

    segments = fetch_transcript_segments(video_id)
    metadata = await fetch_video_metadata(video_id)

    return TranscriptResponse(segments=segments, **metadata)
