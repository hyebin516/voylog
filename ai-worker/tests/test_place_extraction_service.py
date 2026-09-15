import asyncio

import pytest

from app.schemas.request_schema import PlaceExtractionRequest, TranscriptSegment, VideoMeta
from app.schemas.response_schema import LlmPlaceExtractionResult, PlaceMatchResult, PlaceCandidate, PlaceTag
from app.services import place_extraction_service


def make_request(**overrides):
    defaults = dict(
        video=VideoMeta(videoId="v1", youtubeUrl="https://youtu.be/dQw4w9WgXcQ", title="t", hashtags=[]),
        transcript=[TranscriptSegment(text="hi", timestampSec=0)],
        llmProvider="auto",
    )
    defaults.update(overrides)
    return PlaceExtractionRequest(**defaults)


async def _no_location(candidate, region, provider):
    return None


@pytest.fixture(autouse=True)
def never_download_video(monkeypatch):
    """The OCR fallback now also runs for videos whose transcript yielded
    few places, so without this any test with a small result set would
    really download a video. Tests that care about the fallback override
    this with their own stub."""

    async def _no_frames(youtube_url, **kwargs):
        return []

    monkeypatch.setattr(
        place_extraction_service.frame_extraction_service, "download_and_sample_frames", _no_frames
    )


def test_extract_places_geocodes_each_llm_candidate(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[
            PlaceCandidate(name="해운대해수욕장", timestampSec=12, source="transcript", confidence=0.9),
            PlaceCandidate(name="감천문화마을", timestampSec=None, source="title", confidence=0.5),
        ]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

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

    async def fake_geocode(candidate, region, provider):
        return None

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

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
    monkeypatch.setattr(place_extraction_service, "_resolve_location", _no_location)

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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

    # Empty transcript means the on-screen-text fallback now runs too (not
    # what this test is about) -- keep it fast/deterministic by simulating
    # "no frames found" instead of letting it hit the real network.
    async def fake_download_and_sample_frames(youtube_url, **kwargs):
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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

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
    monkeypatch.setattr(place_extraction_service, "_resolve_location", _no_location)
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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

    async def fake_download_and_sample_frames(youtube_url, **kwargs):
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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 36.9, "longitude": 127.9, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

    async def fake_download_and_sample_frames(youtube_url, **kwargs):
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
    monkeypatch.setattr(place_extraction_service, "_resolve_location", _no_location)

    async def fake_download_and_sample_frames(youtube_url, **kwargs):
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

    async def fake_geocode(candidate, region, provider):
        return {"latitude": 35.1, "longitude": 129.1, "address": f"addr for {candidate.name}"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

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
    monkeypatch.setattr(place_extraction_service, "_resolve_location", _no_location)

    asyncio.run(place_extraction_service.extract_places(make_request(llmProvider="claude")))

    assert seen["provider"] == "claude"


def _candidate(name, category=None, mention_note=None):
    return PlaceCandidate(
        name=name,
        timestampSec=None,
        source="transcript",
        confidence=0.8,
        category=category,
        mentionNote=mention_note,
    )


def test_resolve_location_scopes_the_map_search_to_the_video_region(monkeypatch):
    queries = []

    async def fake_search(query, size):
        queries.append(query)
        return [{"name": "정동", "address": "대전 중구 정동", "latitude": 36.3, "longitude": 127.4}]

    monkeypatch.setattr(place_extraction_service, "search_places", fake_search)
    monkeypatch.setattr(
        place_extraction_service.llm_service, "match_place", lambda prompt, provider: PlaceMatchResult(index=0)
    )

    result = asyncio.run(place_extraction_service._resolve_location(_candidate("정동"), "대전", "auto"))

    assert queries == ["대전 정동"]
    assert result["latitude"] == 36.3
    assert result["address"] == "대전 중구 정동"


def test_resolve_location_falls_back_to_the_bare_name_when_the_region_search_finds_nothing(monkeypatch):
    queries = []

    async def fake_search(query, size):
        queries.append(query)
        if query.startswith("대전 "):
            return []
        return [{"name": "성심당", "address": "대전 중구", "latitude": 36.32, "longitude": 127.42}]

    monkeypatch.setattr(place_extraction_service, "search_places", fake_search)
    monkeypatch.setattr(
        place_extraction_service.llm_service, "match_place", lambda prompt, provider: PlaceMatchResult(index=0)
    )

    result = asyncio.run(place_extraction_service._resolve_location(_candidate("성심당"), "대전", "auto"))

    assert queries == ["대전 성심당", "성심당"]
    assert result["latitude"] == 36.32


def test_resolve_location_returns_none_when_the_llm_rejects_every_candidate(monkeypatch):
    async def fake_search(query, size):
        return [{"name": "정동", "address": "서울 중구 덕수궁길 15", "latitude": 37.56, "longitude": 126.97}]

    monkeypatch.setattr(place_extraction_service, "search_places", fake_search)
    monkeypatch.setattr(
        place_extraction_service.llm_service,
        "match_place",
        lambda prompt, provider: PlaceMatchResult(index=None, reason="다른 도시"),
    )

    result = asyncio.run(place_extraction_service._resolve_location(_candidate("정동"), "대전", "auto"))

    # Better no pin than a pin on the Seoul 정동 for a 대전 video.
    assert result is None


def test_resolve_location_returns_none_for_an_out_of_range_llm_index(monkeypatch):
    async def fake_search(query, size):
        return [{"name": "어딘가", "address": "대전", "latitude": 36.3, "longitude": 127.4}]

    monkeypatch.setattr(place_extraction_service, "search_places", fake_search)
    monkeypatch.setattr(
        place_extraction_service.llm_service, "match_place", lambda prompt, provider: PlaceMatchResult(index=7)
    )

    result = asyncio.run(place_extraction_service._resolve_location(_candidate("어딘가"), "대전", "auto"))

    assert result is None


def test_resolve_location_returns_none_without_calling_the_llm_when_the_map_search_is_empty(monkeypatch):
    called = {"match": False}

    async def fake_search(query, size):
        return []

    def fake_match(prompt, provider):
        called["match"] = True
        return PlaceMatchResult(index=0)

    monkeypatch.setattr(place_extraction_service, "search_places", fake_search)
    monkeypatch.setattr(place_extraction_service.llm_service, "match_place", fake_match)

    result = asyncio.run(place_extraction_service._resolve_location(_candidate("영춘 멋찌"), "대전", "auto"))

    assert result is None
    assert called["match"] is False


def test_extract_places_passes_the_llm_region_through_to_location_resolution(monkeypatch):
    candidates = LlmPlaceExtractionResult(
        places=[PlaceCandidate(name="정동", timestampSec=None, source="transcript", confidence=0.8)],
        region="대전",
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    seen = {}

    async def fake_resolve(candidate, region, provider):
        seen["region"] = region
        return None

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_resolve)

    asyncio.run(place_extraction_service.extract_places(make_request()))

    assert seen["region"] == "대전"


def test_extract_places_runs_the_screen_text_pass_when_the_caller_forces_it(monkeypatch):
    """The background enrichment job asks for the OCR pass explicitly on a
    video that already has a transcript."""
    calls = {"count": 0}

    def fake_extract(prompt, provider):
        calls["count"] += 1
        if calls["count"] == 1:
            return LlmPlaceExtractionResult(
                places=[PlaceCandidate(name="정동", timestampSec=1, source="transcript", confidence=0.4)]
            )
        return LlmPlaceExtractionResult(
            places=[
                PlaceCandidate(name=f"장소{i}", timestampSec=i, source="on_screen_text", confidence=0.8)
                for i in range(6)
            ]
        )

    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", fake_extract)
    monkeypatch.setattr(place_extraction_service, "_resolve_location", _no_location)

    sampling = {}

    async def fake_frames(youtube_url, **kwargs):
        sampling.update(kwargs)
        return [b"frame"]

    monkeypatch.setattr(
        place_extraction_service.frame_extraction_service, "download_and_sample_frames", fake_frames
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_screen_text", lambda frames, provider: "성심당")

    result = asyncio.run(place_extraction_service.extract_places(make_request(forceScreenText=True)))

    # Nobody waits on the background pass, so it samples far more densely.
    assert sampling["max_frames"] == place_extraction_service.ENRICHMENT_MAX_FRAMES

    assert calls["count"] == 2
    assert len(result.places) == 6


def test_extract_places_does_not_run_the_screen_text_pass_by_default(monkeypatch):
    """A user is waiting on this request, and the OCR pass takes minutes."""
    few = LlmPlaceExtractionResult(
        places=[PlaceCandidate(name="정동", timestampSec=1, source="transcript", confidence=0.4)]
    )
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: few)
    monkeypatch.setattr(place_extraction_service, "_resolve_location", _no_location)

    async def _never_called(youtube_url, **kwargs):
        raise AssertionError("the OCR pass must not run on the request the user is waiting on")

    monkeypatch.setattr(
        place_extraction_service.frame_extraction_service, "download_and_sample_frames", _never_called
    )

    result = asyncio.run(place_extraction_service.extract_places(make_request()))

    assert len(result.places) == 1
