import asyncio

from app.schemas.request_schema import PlaceSummaryRequest
from app.schemas.response_schema import PlaceSummaryResult
from app.services import place_summary_service


def test_summarize_place_returns_pros_and_cons_from_the_llm(monkeypatch):
    seen = {}

    def fake_summarize(prompt, provider):
        seen["prompt"] = prompt
        seen["provider"] = provider
        return PlaceSummaryResult(pros="뷰가 좋다는 평이 많아요.", cons="웨이팅이 길다는 평이 많아요.")

    monkeypatch.setattr(place_summary_service.llm_service, "summarize_place", fake_summarize)

    request = PlaceSummaryRequest(placeName="해운대해수욕장", notes=["뷰가 좋다", "웨이팅이 길다"], llmProvider="auto")
    result = asyncio.run(place_summary_service.summarize_place(request))

    assert result.pros == "뷰가 좋다는 평이 많아요."
    assert result.cons == "웨이팅이 길다는 평이 많아요."
    assert "해운대해수욕장" in seen["prompt"]
    assert seen["provider"] == "auto"


def test_summarize_place_allows_a_null_pros_or_cons(monkeypatch):
    monkeypatch.setattr(
        place_summary_service.llm_service, "summarize_place", lambda prompt, provider: PlaceSummaryResult(pros=None, cons="비싸다는 평이 있어요.")
    )

    request = PlaceSummaryRequest(placeName="어느 카페", notes=["비싸다"], llmProvider="auto")
    result = asyncio.run(place_summary_service.summarize_place(request))

    assert result.pros is None
    assert result.cons == "비싸다는 평이 있어요."
