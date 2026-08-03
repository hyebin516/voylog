from fastapi.testclient import TestClient

from app.main import app
from app.services import video_search_service
from app.utils.exceptions import YoutubeSearchError

client = TestClient(app)


def test_search_hashtag_returns_mapped_results(monkeypatch):
    async def fake_search(request):
        from app.schemas.response_schema import HashtagSearchResponse, VideoSearchResult

        return HashtagSearchResponse(
            videos=[
                VideoSearchResult(
                    videoId="dQw4w9WgXcQ",
                    youtubeUrl="https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    title="title",
                )
            ]
        )

    monkeypatch.setattr(video_search_service, "search_by_hashtag", fake_search)

    res = client.post("/search-hashtag", json={"hashtag": "부산여행"})

    assert res.status_code == 200
    assert res.json()["videos"][0]["videoId"] == "dQw4w9WgXcQ"


def test_search_hashtag_maps_youtube_search_error_to_503(monkeypatch):
    async def fake_search(request):
        raise YoutubeSearchError()

    monkeypatch.setattr(video_search_service, "search_by_hashtag", fake_search)

    res = client.post("/search-hashtag", json={"hashtag": "부산여행"})

    assert res.status_code == 503
    assert res.json()["error"]["code"] == "YOUTUBE_SEARCH_FAILED"


def test_search_hashtag_defaults_max_results_to_20():
    from app.schemas.request_schema import HashtagSearchRequest

    assert HashtagSearchRequest(hashtag="부산여행").maxResults == 20
