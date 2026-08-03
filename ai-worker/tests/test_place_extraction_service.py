import asyncio

from app.schemas.request_schema import PlaceExtractionRequest, TranscriptSegment, VideoMeta
from app.schemas.response_schema import LlmPlaceExtractionResult, PlaceCandidate
from app.services import place_extraction_service


def make_request(**overrides):
    defaults = dict(
        video=VideoMeta(videoId="v1", youtubeUrl="https://youtu.be/dQw4w9WgXcQ", title="t", hashtags=[]),
        transcript=[TranscriptSegment(text="hi", timestampSec=0)],
        llmProvider="auto",
    )
    defaults.update(overrides)
    return PlaceExtractionRequest(**defaults)


def test_extract_places_geocodes_each_llm_candidate(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[
            PlaceCandidate(name="해운대해수욕장", timestampSec=12, source="transcript", confidence=0.9),
            PlaceCandidate(name="감천문화마을", timestampSec=None, source="title", confidence=0.5),
        ]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert len(result.places) == 2
    assert result.places[0].name == "해운대해수욕장"
    assert result.places[0].latitude == 35.1
    assert result.places[0].address == "addr for 해운대해수욕장"
    assert result.places[0].source == "transcript"
    assert result.places[0].confidence == 0.9


def test_extract_places_leaves_coordinates_null_when_geocoding_fails(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[PlaceCandidate(name="Unknown Place", timestampSec=None, source="description", confidence=0.3)]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return None

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert len(result.places) == 1
    assert result.places[0].latitude is None
    assert result.places[0].longitude is None
    assert result.places[0].address is None


def test_extract_places_returns_empty_list_when_llm_finds_nothing(monkeypatch):
    monkeypatch.setattr(
        place_extraction_service.llm_service,
        "extract_places",
        lambda prompt, provider: LlmPlaceExtractionResult(places=[]),
    )
    monkeypatch.setattr(place_extraction_service, "geocode_place", lambda name: None)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert result.places == []


def test_extract_places_forwards_the_requested_llm_provider(monkeypatch):
    seen = {}

    def fake_extract(prompt, provider):
        seen["provider"] = provider
        return LlmPlaceExtractionResult(places=[])

    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", fake_extract)
    monkeypatch.setattr(place_extraction_service, "geocode_place", lambda name: None)

    asyncio.run(place_extraction_service.extract_places(make_request(llmProvider="claude")))

    assert seen["provider"] == "claude"
