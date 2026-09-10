import asyncio

from app.schemas.request_schema import PlaceExtractionRequest, TranscriptSegment, VideoMeta
from app.schemas.response_schema import LlmPlaceExtractionResult, PlaceCandidate, PlaceTag
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


def test_extract_places_forwards_category_and_business_hours(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[
            PlaceCandidate(
                name="해운대해수욕장",
                timestampSec=12,
                source="transcript",
                confidence=0.9,
                category="beach",
                businessHours={"mon": {"open": "09:00", "close": "21:00"}},
            )
        ]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert result.places[0].category == "beach"
    assert result.places[0].businessHours["mon"].open == "09:00"


def test_extract_places_forwards_valid_tags_and_drops_hallucinated_ones(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[
            PlaceCandidate(
                name="해운대해수욕장",
                timestampSec=12,
                source="transcript",
                confidence=0.9,
                tags=[
                    PlaceTag(code="소금빵", confidence=0.9),
                    PlaceTag(code="made_up_tag_not_in_catalog", confidence=0.9),
                ],
            )
        ]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    tag_codes = [tag.code for tag in result.places[0].tags]
    assert tag_codes == ["소금빵"]


def test_extract_places_forwards_mention_note(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[
            PlaceCandidate(
                name="해운대해수욕장",
                timestampSec=12,
                source="transcript",
                confidence=0.9,
                mentionNote="웨이팅이 길었지만 뷰가 좋다고 언급함",
            ),
            PlaceCandidate(name="감천문화마을", timestampSec=None, source="title", confidence=0.5),
        ]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert result.places[0].mentionNote == "웨이팅이 길었지만 뷰가 좋다고 언급함"
    assert result.places[1].mentionNote is None


def test_extract_places_corrects_a_hallucinated_transcript_source_when_transcript_was_empty(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[
            PlaceCandidate(name="충주", timestampSec=0, source="transcript", confidence=0.6),
            PlaceCandidate(name="대림여인숙", timestampSec=None, source="description", confidence=0.5),
        ]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    # Empty transcript means the on-screen-text fallback now runs too (not
    # what this test is about) -- keep it fast/deterministic by simulating
    # "no frames found" instead of letting it hit the real network.
    async def fake_download_and_sample_frames(youtube_url, max_frames=8):
        return []

    monkeypatch.setattr(
        place_extraction_service.frame_extraction_service, "download_and_sample_frames", fake_download_and_sample_frames
    )

    result = asyncio.run(place_extraction_service.extract_places(make_request(transcript=[])))

    assert result.places[0].source == "description"
    assert result.places[0].timestampSec is None
    assert result.places[1].source == "description"
    assert result.places[1].timestampSec is None


def test_extract_places_keeps_a_genuine_transcript_source_when_transcript_was_available(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[PlaceCandidate(name="해운대해수욕장", timestampSec=12, source="transcript", confidence=0.9)]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert result.places[0].source == "transcript"
    assert result.places[0].timestampSec == 12


def _never_called_download(*args, **kwargs):
    raise AssertionError("download_and_sample_frames should not have been called")


def test_extract_places_skips_on_screen_text_fallback_when_transcript_is_available(monkeypatch):
    monkeypatch.setattr(
        place_extraction_service.llm_service,
        "extract_places",
        lambda prompt, provider: LlmPlaceExtractionResult(places=[]),
    )
    monkeypatch.setattr(place_extraction_service, "geocode_place", lambda name: None)
    monkeypatch.setattr(place_extraction_service.frame_extraction_service, "download_and_sample_frames", _never_called_download)

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert result.places == []


def test_extract_places_runs_on_screen_text_fallback_even_when_metadata_already_found_a_place(monkeypatch):
    """The fallback triggers on "no transcript" alone -- metadata finding
    one place doesn't mean it found every place the video actually shows,
    so this must still run (and its result, from a prompt that includes the
    same metadata plus screen text, replaces the metadata-only pass)."""
    calls = {"n": 0}

    def fake_extract_places(prompt, provider):
        calls["n"] += 1
        if calls["n"] == 1:
            return LlmPlaceExtractionResult(
                places=[PlaceCandidate(name="감천문화마을", timestampSec=None, source="title", confidence=0.5)]
            )
        return LlmPlaceExtractionResult(
            places=[
                PlaceCandidate(name="감천문화마을", timestampSec=None, source="title", confidence=0.5),
                PlaceCandidate(name="대림여인숙", timestampSec=None, source="on_screen_text", confidence=0.7),
            ]
        )

    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", fake_extract_places)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    async def fake_download_and_sample_frames(youtube_url, max_frames=8):
        return [b"frame1"]

    monkeypatch.setattr(
        place_extraction_service.frame_extraction_service, "download_and_sample_frames", fake_download_and_sample_frames
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_screen_text", lambda frames, provider: "대림여인숙")

    result = asyncio.run(place_extraction_service.extract_places(make_request(transcript=[])))

    assert calls["n"] == 2
    assert {p.name for p in result.places} == {"감천문화마을", "대림여인숙"}


def test_extract_places_runs_on_screen_text_fallback_when_transcript_is_missing_and_metadata_found_nothing(monkeypatch):
    calls = {"n": 0}

    def fake_extract_places(prompt, provider):
        calls["n"] += 1
        if calls["n"] == 1:
            return LlmPlaceExtractionResult(places=[])
        # Second pass, after the OCR fallback added on-screen text to the prompt.
        assert "온천 대림여인숙" in prompt
        return LlmPlaceExtractionResult(
            places=[PlaceCandidate(name="대림여인숙", timestampSec=None, source="on_screen_text", confidence=0.7)]
        )

    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", fake_extract_places)

    async def fake_geocode(name):
        return {"latitude": 36.9, "longitude": 127.9, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    async def fake_download_and_sample_frames(youtube_url, max_frames=8):
        return [b"frame1", b"frame2"]

    monkeypatch.setattr(
        place_extraction_service.frame_extraction_service, "download_and_sample_frames", fake_download_and_sample_frames
    )
    monkeypatch.setattr(
        place_extraction_service.llm_service, "extract_screen_text", lambda frames, provider: "온천 대림여인숙"
    )

    result = asyncio.run(place_extraction_service.extract_places(make_request(transcript=[])))

    assert calls["n"] == 2
    assert len(result.places) == 1
    assert result.places[0].name == "대림여인숙"
    assert result.places[0].source == "on_screen_text"
    assert result.places[0].timestampSec is None


def test_extract_places_does_not_retry_when_the_on_screen_text_fallback_finds_no_readable_text(monkeypatch):
    calls = {"n": 0}

    def fake_extract_places(prompt, provider):
        calls["n"] += 1
        return LlmPlaceExtractionResult(places=[])

    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", fake_extract_places)
    monkeypatch.setattr(place_extraction_service, "geocode_place", lambda name: None)

    async def fake_download_and_sample_frames(youtube_url, max_frames=8):
        return [b"frame1"]

    monkeypatch.setattr(
        place_extraction_service.frame_extraction_service, "download_and_sample_frames", fake_download_and_sample_frames
    )
    # OCR ran but found nothing readable.
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_screen_text", lambda frames, provider: "")

    result = asyncio.run(place_extraction_service.extract_places(make_request(transcript=[])))

    assert calls["n"] == 1  # never re-ran extraction with an empty screen_text
    assert result.places == []


def test_extract_places_sanitizes_a_hallucinated_on_screen_text_source_when_the_fallback_never_ran(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[PlaceCandidate(name="해운대해수욕장", timestampSec=None, source="on_screen_text", confidence=0.6)]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(name):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {name}"}

    monkeypatch.setattr(place_extraction_service, "geocode_place", fake_geocode)

    # Transcript IS available here, so the fallback path is never entered at
    # all -- yet the LLM still (incorrectly) self-labeled this candidate as
    # on_screen_text on the very first pass. Must be downgraded just like the
    # existing hallucinated-transcript-source case.
    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert result.places[0].source == "description"


def test_extract_places_forwards_the_requested_llm_provider(monkeypatch):
    seen = {}

    def fake_extract(prompt, provider):
        seen["provider"] = provider
        return LlmPlaceExtractionResult(places=[])

    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", fake_extract)
    monkeypatch.setattr(place_extraction_service, "geocode_place", lambda name: None)

    asyncio.run(place_extraction_service.extract_places(make_request(llmProvider="claude")))

    assert seen["provider"] == "claude"
