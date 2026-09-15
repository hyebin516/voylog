import asyncio
from dataclasses import dataclass

import pytest
from youtube_transcript_api import NoTranscriptFound, TranscriptsDisabled

from app.services import transcript_service
from app.utils.exceptions import TranscriptNotFoundError


@dataclass
class FakeSnippet:
    text: str
    start: float
    duration: float = 2.0


class FakeApiSuccess:
    def fetch(self, video_id, languages):
        return [FakeSnippet("hello", 0.0), FakeSnippet("world", 3.5)]


class FakeApiRaising:
    def __init__(self, exc):
        self._exc = exc

    def fetch(self, video_id, languages):
        raise self._exc


# --- extract_video_id -------------------------------------------------


@pytest.mark.parametrize(
    "url,expected",
    [
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"),
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s", "dQw4w9WgXcQ"),
        ("https://youtu.be/dQw4w9WgXcQ", "dQw4w9WgXcQ"),
        ("https://example.com/not-youtube", None),
    ],
)
def test_extract_video_id(url, expected):
    assert transcript_service.extract_video_id(url) == expected


# --- fetch_transcript_segments -----------------------------------------


def test_fetch_transcript_segments_maps_fetched_snippets_to_dicts(monkeypatch):
    monkeypatch.setattr(transcript_service, "YouTubeTranscriptApi", FakeApiSuccess)

    segments = transcript_service.fetch_transcript_segments("dQw4w9WgXcQ")

    assert segments == [
        {"text": "hello", "timestampSec": 0},
        {"text": "world", "timestampSec": 3},
    ]


@pytest.mark.parametrize("exc", [TranscriptsDisabled("id"), NoTranscriptFound("id", ["ko", "en"], {})])
def test_fetch_transcript_segments_raises_not_found_for_known_api_errors(monkeypatch, exc):
    monkeypatch.setattr(transcript_service, "YouTubeTranscriptApi", lambda: FakeApiRaising(exc))

    with pytest.raises(TranscriptNotFoundError):
        transcript_service.fetch_transcript_segments("dQw4w9WgXcQ")


def test_fetch_transcript_segments_raises_not_found_for_unexpected_errors(monkeypatch):
    monkeypatch.setattr(transcript_service, "YouTubeTranscriptApi", lambda: FakeApiRaising(RuntimeError("boom")))

    with pytest.raises(TranscriptNotFoundError):
        transcript_service.fetch_transcript_segments("dQw4w9WgXcQ")


# --- fetch_video_metadata ------------------------------------------------


def test_fetch_video_metadata_returns_empty_dict_without_an_api_key(monkeypatch):
    monkeypatch.setattr(transcript_service, "YOUTUBE_API_KEY", None)

    result = asyncio.run(transcript_service.fetch_video_metadata("dQw4w9WgXcQ"))

    assert result == {}


def test_fetch_video_metadata_returns_empty_dict_when_video_not_found(monkeypatch):
    monkeypatch.setattr(transcript_service, "YOUTUBE_API_KEY", "fake-key")

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {"items": []}

    class FakeAsyncClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def get(self, url, params):
            return FakeResponse()

    monkeypatch.setattr(transcript_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient())

    result = asyncio.run(transcript_service.fetch_video_metadata("dQw4w9WgXcQ"))

    assert result == {}


def test_fetch_video_metadata_maps_snippet_fields(monkeypatch):
    monkeypatch.setattr(transcript_service, "YOUTUBE_API_KEY", "fake-key")

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {
                "items": [
                    {
                        "snippet": {
                            "title": "My trip",
                            "description": "desc",
                            "thumbnails": {"high": {"url": "http://thumb"}},
                            "channelTitle": "channel",
                            "publishedAt": "2026-01-01T00:00:00Z",
                            "tags": ["travel", "vlog"],
                        }
                    }
                ]
            }

    class FakeAsyncClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def get(self, url, params):
            return FakeResponse()

    monkeypatch.setattr(transcript_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient())

    result = asyncio.run(transcript_service.fetch_video_metadata("dQw4w9WgXcQ"))

    assert result == {
        "title": "My trip",
        "description": "desc",
        "thumbnailUrl": "http://thumb",
        "channelName": "channel",
        "publishedAt": "2026-01-01T00:00:00Z",
        "hashtags": ["travel", "vlog"],
    }


# --- get_transcript (end-to-end within this module) ----------------------


def test_get_transcript_raises_when_url_has_no_video_id():
    with pytest.raises(TranscriptNotFoundError):
        asyncio.run(transcript_service.get_transcript("https://example.com/not-youtube"))


def test_get_transcript_combines_segments_and_metadata(monkeypatch):
    monkeypatch.setattr(transcript_service, "YouTubeTranscriptApi", FakeApiSuccess)
    monkeypatch.setattr(transcript_service, "YOUTUBE_API_KEY", None)  # skip metadata HTTP call

    result = asyncio.run(transcript_service.get_transcript("https://youtu.be/dQw4w9WgXcQ"))

    assert result.segments == [
        {"text": "hello", "timestampSec": 0},
        {"text": "world", "timestampSec": 3},
    ]
    assert result.title is None


def test_get_transcript_falls_back_to_empty_segments_when_metadata_is_available(monkeypatch):
    monkeypatch.setattr(transcript_service, "YouTubeTranscriptApi", lambda: FakeApiRaising(TranscriptsDisabled("id")))
    monkeypatch.setattr(
        transcript_service,
        "fetch_video_metadata",
        lambda video_id: _async_result({"title": "My trip", "description": None, "hashtags": ["travel"]}),
    )

    result = asyncio.run(transcript_service.get_transcript("https://youtu.be/dQw4w9WgXcQ"))

    assert result.segments == []
    assert result.title == "My trip"
    assert result.hashtags == ["travel"]


def test_get_transcript_still_raises_when_neither_transcript_nor_metadata_is_available(monkeypatch):
    monkeypatch.setattr(transcript_service, "YouTubeTranscriptApi", lambda: FakeApiRaising(TranscriptsDisabled("id")))
    monkeypatch.setattr(transcript_service, "YOUTUBE_API_KEY", None)  # fetch_video_metadata returns {}

    with pytest.raises(TranscriptNotFoundError):
        asyncio.run(transcript_service.get_transcript("https://youtu.be/dQw4w9WgXcQ"))


async def _async_result(value):
    return value
