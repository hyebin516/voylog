from fastapi.testclient import TestClient

from app.main import app
from app.schemas.response_schema import PlaceSummaryResponse
import app.routers.place_router as place_router_module

client = TestClient(app)


def test_summarize_place_returns_the_pros_and_cons(monkeypatch):
    async def fake_summarize(request):
        assert request.placeName == "해운대해수욕장"
        assert request.notes == ["뷰가 좋다", "웨이팅이 길다"]
        return PlaceSummaryResponse(pros="뷰가 좋다는 평이 많아요.", cons="웨이팅이 길다는 평이 많아요.")

    monkeypatch.setattr(place_router_module.place_summary_service, "summarize_place", fake_summarize)

    res = client.post(
        "/places/summarize",
        json={"placeName": "해운대해수욕장", "notes": ["뷰가 좋다", "웨이팅이 길다"], "llmProvider": "auto"},
    )

    assert res.status_code == 200
    assert res.json() == {"pros": "뷰가 좋다는 평이 많아요.", "cons": "웨이팅이 길다는 평이 많아요."}
