import asyncio

import pytest

from app.schemas.request_schema import HashtagSearchRequest
from app.services import video_search_service
from app.utils.exceptions import YoutubeSearchError


class FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._payload


class FakeAsyncClient:
    def __init__(self, payload=None, error=None):
        self._payload = payload
        self._error = error
        self.last_params = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def get(self, url, params):
        self.last_params = params
        if self._error:
            raise self._error
        return FakeResponse(self._payload)


def test_search_by_hashtag_raises_without_an_api_key(monkeypatch):
    monkeypatch.setattr(video_search_service, "YOUTUBE_API_KEY", None)

    with pytest.raises(YoutubeSearchError):
        asyncio.run(video_search_service.search_by_hashtag(HashtagSearchRequest(hashtag="부산여행")))


def test_search_by_hashtag_normalizes_a_bare_hashtag_with_a_leading_hash(monkeypatch):
    monkeypatch.setattr(video_search_service, "YOUTUBE_API_KEY", "fake-key")
    client = FakeAsyncClient(payload={"items": []})
    monkeypatch.setattr(video_search_service.httpx, "AsyncClient", lambda timeout=None: client)

    asyncio.run(video_search_service.search_by_hashtag(HashtagSearchRequest(hashtag="부산여행")))

    assert client.last_params["q"] == "#부산여행"


def test_search_by_hashtag_does_not_double_up_an_existing_hash(monkeypatch):
    monkeypatch.setattr(video_search_service, "YOUTUBE_API_KEY", "fake-key")
    client = FakeAsyncClient(payload={"items": []})
    monkeypatch.setattr(video_search_service.httpx, "AsyncClient", lambda timeout=None: client)

    asyncio.run(video_search_service.search_by_hashtag(HashtagSearchRequest(hashtag="#부산여행")))

    assert client.last_params["q"] == "#부산여행"


def test_search_by_hashtag_maps_results_and_builds_the_watch_url(monkeypatch):
    monkeypatch.setattr(video_search_service, "YOUTUBE_API_KEY", "fake-key")
    payload = {
        "items": [
            {
                "id": {"videoId": "dQw4w9WgXcQ"},
                "snippet": {
                    "title": "부산 여행 브이로그",
                    "channelTitle": "채널",
                    "publishedAt": "2026-01-01T00:00:00Z",
                    "thumbnails": {"high": {"url": "http://thumb"}},
                },
            }
        ]
    }
    monkeypatch.setattr(
        video_search_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient(payload=payload)
    )

    result = asyncio.run(video_search_service.search_by_hashtag(HashtagSearchRequest(hashtag="부산여행")))

    assert len(result.videos) == 1
    video = result.videos[0]
    assert video.videoId == "dQw4w9WgXcQ"
    assert video.youtubeUrl == "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    assert video.title == "부산 여행 브이로그"
    assert video.channelName == "채널"
    assert video.thumbnailUrl == "http://thumb"


def test_search_by_hashtag_skips_items_without_a_video_id(monkeypatch):
    monkeypatch.setattr(video_search_service, "YOUTUBE_API_KEY", "fake-key")
    payload = {"items": [{"id": {"kind": "youtube#channel"}, "snippet": {"title": "not a video"}}]}
    monkeypatch.setattr(
        video_search_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient(payload=payload)
    )

    result = asyncio.run(video_search_service.search_by_hashtag(HashtagSearchRequest(hashtag="부산여행")))

    assert result.videos == []


def test_search_by_hashtag_raises_when_the_http_call_fails(monkeypatch):
    monkeypatch.setattr(video_search_service, "YOUTUBE_API_KEY", "fake-key")
    monkeypatch.setattr(
        video_search_service.httpx,
        "AsyncClient",
        lambda timeout=None: FakeAsyncClient(error=RuntimeError("network down")),
    )

    with pytest.raises(YoutubeSearchError):
        asyncio.run(video_search_service.search_by_hashtag(HashtagSearchRequest(hashtag="부산여행")))
