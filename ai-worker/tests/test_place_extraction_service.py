import asyncio

import pytest

from app.schemas.request_schema import PlaceExtractionRequest, TranscriptSegment, VideoMeta
from app.schemas.response_schema import (
    GeocodedPlace,
    LlmPlaceExtractionResult,
    PlaceCandidate,
    PlaceMatchResult,
    PlaceTag,
    PlaceVerificationResult,
)
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
def never_verify_places(monkeypatch):
    """Extraction now asks the LLM whether its unlocated names are places at
    all. Without this the suite makes real, paid calls -- and the real model
    answers honestly, so a synthetic fixture place like "대전" gets dropped
    and the test fails for a reason that has nothing to do with it. Tests
    that care about the check stub it themselves."""

    def _nothing_to_drop(user_prompt, provider):
        return PlaceVerificationResult(notPlaces=[])

    monkeypatch.setattr(place_extraction_service.llm_service, "verify_places", _nothing_to_drop)


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

    def fake_extract_places(prompt, provider, thorough=False):
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

    def fake_extract_places(prompt, provider, thorough=False):
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

    def fake_extract_places(prompt, provider, thorough=False):
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

    def fake_extract(prompt, provider, thorough=False):
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

    def fake_extract(prompt, provider, thorough=False):
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


# --- auto-generated captions: cross-checking heard names ---------------


def _heard(name, alternatives, source="transcript"):
    return PlaceCandidate(name=name, source=source, confidence=0.8, alternativeNames=alternatives)


def test_resolve_location_tries_the_written_spelling_when_the_heard_name_is_not_on_the_map(monkeypatch):
    queries = []

    async def fake_search(query, size):
        queries.append(query)
        if "소베" in query:
            return [{"name": "소베", "address": "대구 중구 중앙대로79길 6", "latitude": 35.86, "longitude": 128.59}]
        return []

    monkeypatch.setattr(place_extraction_service, "search_places", fake_search)
    monkeypatch.setattr(
        place_extraction_service.llm_service, "match_place", lambda prompt, provider: PlaceMatchResult(index=0)
    )

    result = asyncio.run(place_extraction_service._resolve_location(_heard("소배", ["소베"]), "대구", "auto"))

    assert queries == ["대구 소배", "소배", "대구 소베"]
    assert result["name"] == "소베"
    assert result["address"] == "대구 중구 중앙대로79길 6"


def test_resolve_location_keeps_the_heard_name_when_it_is_found_first(monkeypatch):
    async def fake_search(query, size):
        return [{"name": "따끈따끈베이커리", "address": "대구 중구 중앙대로 395", "latitude": 35.86, "longitude": 128.59}]

    monkeypatch.setattr(place_extraction_service, "search_places", fake_search)
    monkeypatch.setattr(
        place_extraction_service.llm_service, "match_place", lambda prompt, provider: PlaceMatchResult(index=0)
    )

    result = asyncio.run(
        place_extraction_service._resolve_location(_heard("따끈따끈베이커리", ["따끈따끈 베이커리"]), "대구", "auto")
    )

    assert result["name"] == "따끈따끈베이커리"


def test_an_unmatched_heard_name_gives_way_to_the_written_spelling_only_for_auto_captions():
    heard = _heard("바카", ["vaca"])

    assert place_extraction_service._display_name(heard, None, transcript_auto_generated=True) == "vaca"
    assert place_extraction_service._display_name(heard, None, transcript_auto_generated=False) == "바카"
    assert place_extraction_service._display_name(_heard("히오리", []), None, True) == "히오리"
    assert place_extraction_service._display_name(heard, {"name": "바카"}, True) == "바카"


def test_extract_places_names_each_place_by_the_spelling_that_matched(monkeypatch):
    candidates = LlmPlaceExtractionResult(region="대구", places=[_heard("소배", ["소베"])])
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)

    async def fake_geocode(candidate, region, provider):
        return {"name": "소베", "latitude": 35.86, "longitude": 128.59, "address": "대구 중구"}

    monkeypatch.setattr(place_extraction_service, "_resolve_location", fake_geocode)

    result = asyncio.run(place_extraction_service.extract_places(make_request(transcriptAutoGenerated=True)))

    assert [p.name for p in result.places] == ["소베"]


def test_extraction_prompt_marks_an_auto_generated_transcript():
    from app.prompts.place_extraction_prompt import build_user_prompt

    auto = build_user_prompt("t", "d", [], [{"text": "소배 가요", "timestampSec": 3}], transcript_auto_generated=True)
    manual = build_user_prompt("t", "d", [], [{"text": "소베 가요", "timestampSec": 3}])

    assert "auto-generated speech recognition" in auto
    assert "auto-generated" not in manual


def test_extract_places_tries_a_sound_alike_from_the_title_for_auto_captions(monkeypatch):
    # The model didn't list the title's "소베" itself.
    candidates = LlmPlaceExtractionResult(region="대구", places=[_heard("소배", [])])
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)
    tried = []

    async def fake_resolve_name(name, candidate, region, provider):
        tried.append(name)
        return {"name": name, "latitude": 35.86, "longitude": 128.59, "address": "대구 중구"} if name == "소베" else None

    monkeypatch.setattr(place_extraction_service, "_resolve_name", fake_resolve_name)
    request = make_request(
        video=VideoMeta(videoId="v1", youtubeUrl="https://youtu.be/x", title="대구 당일치기 소베,히오리", hashtags=[]),
        transcriptAutoGenerated=True,
    )

    result = asyncio.run(place_extraction_service.extract_places(request))

    assert tried == ["소배", "소베"]
    assert result.places[0].name == "소베"
    assert result.places[0].address == "대구 중구"


def test_sound_alikes_are_not_added_for_creator_provided_captions(monkeypatch):
    candidates = LlmPlaceExtractionResult(region="대구", places=[_heard("소배", [])])
    monkeypatch.setattr(place_extraction_service.llm_service, "extract_places", lambda prompt, provider: candidates)
    tried = []

    async def fake_resolve_name(name, candidate, region, provider):
        tried.append(name)
        return None

    monkeypatch.setattr(place_extraction_service, "_resolve_name", fake_resolve_name)
    request = make_request(video=VideoMeta(videoId="v1", youtubeUrl="https://youtu.be/x", title="소베", hashtags=[]))

    asyncio.run(place_extraction_service.extract_places(request))

    assert tried == ["소배"]


def test_bare_tag_codes_from_the_llm_are_kept_instead_of_failing_the_extraction():
    result = LlmPlaceExtractionResult(
        places=[{"name": "소베", "source": "transcript", "confidence": 0.9, "tags": ["베이커리 카페", {"code": "소금빵", "confidence": 0.8}]}]
    )

    assert [(t.code, t.confidence) for t in result.places[0].tags] == [("베이커리 카페", 0.6), ("소금빵", 0.8)]


# --- Collapsing one place the auto-captions spelled two ways -------------
# Real case from https://youtu.be/8tIGm8xndws: YouTube's speech recognition
# wrote "경포 해수역장" and "경포 해수욕장" one second apart, and the
# extractor returned both -- one located, one not.


def make_place(name, **overrides):
    defaults = dict(name=name, source="transcript", confidence=0.8)
    defaults.update(overrides)
    return GeocodedPlace(**defaults)


def test_merge_keeps_the_located_copy_of_a_misheard_name():
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("경포 해수역장", timestampSec=433, category="beach"),
            make_place("경포 해수욕장", timestampSec=434, latitude=37.8, longitude=128.9, category="other"),
        ],
        transcript_auto_generated=True,
    )

    assert [p.name for p in merged] == ["경포 해수욕장"]
    assert merged[0].latitude == 37.8


def test_merge_keeps_the_located_copy_even_when_it_came_first():
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("경포 해수욕장", timestampSec=433, latitude=37.8, longitude=128.9),
            make_place("경포 해수역장", timestampSec=434),
        ],
        transcript_auto_generated=True,
    )

    assert [p.name for p in merged] == ["경포 해수욕장"]
    assert merged[0].latitude == 37.8


def test_merge_ignores_category_disagreement():
    """The two copies of a misheard name usually land in different
    categories, which is exactly why the enrichment merge (which requires
    them to agree) left both in."""
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("경포 해수역장", timestampSec=433, category="beach"),
            make_place("경포 해수욕장", timestampSec=433, category="other"),
        ],
        transcript_auto_generated=True,
    )

    assert len(merged) == 1


def test_merge_fills_the_survivors_gaps_from_the_dropped_copy():
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("소배", timestampSec=100, category="restaurant", mentionNote="국물이 진했다"),
            make_place("소베", timestampSec=100, latitude=37.5, longitude=127.0, address="서울시 중구"),
        ],
        transcript_auto_generated=True,
    )

    assert len(merged) == 1
    survivor = merged[0]
    assert survivor.name == "소베"  # the located copy
    assert survivor.address == "서울시 중구"
    assert survivor.category == "restaurant"  # carried over from the dropped copy
    assert survivor.mentionNote == "국물이 진했다"


def test_merge_keeps_the_earlier_timestamp():
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("경포 해수욕장", timestampSec=433, latitude=37.8, longitude=128.9),
            make_place("경포 해수역장", timestampSec=440),
        ],
        transcript_auto_generated=True,
    )

    assert merged[0].timestampSec == 433


def test_merge_leaves_the_same_name_mentioned_much_later_alone():
    """Two visits to one place are two cards with two timestamps, and the
    user taps each to jump to that part of the video."""
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("경포 해수욕장", timestampSec=100, latitude=37.8, longitude=128.9),
            make_place("경포 해수욕장", timestampSec=600, latitude=37.8, longitude=128.9),
        ]
    )

    assert len(merged) == 2


def test_merge_leaves_different_places_at_the_same_moment_alone():
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("교동짬뽕", timestampSec=200, latitude=37.75, longitude=128.89),
            make_place("안목해변 커피거리", timestampSec=205, latitude=37.77, longitude=128.94),
        ]
    )

    assert len(merged) == 2


def test_merge_without_timestamps_needs_an_identical_name():
    """A metadata-only place has no position in the video to compare, so
    sound alone is not enough to call two names one place."""
    merged = place_extraction_service._merge_mishearings(
        [
            make_place("경포 해수역장", source="description"),
            make_place("경포 해수욕장", source="hashtags", latitude=37.8, longitude=128.9),
        ],
        transcript_auto_generated=True,
    )

    assert len(merged) == 2

    same = place_extraction_service._merge_mishearings(
        [
            make_place("경포 해수욕장", source="description"),
            make_place("경포해수욕장", source="hashtags", latitude=37.8, longitude=128.9),
        ],
        transcript_auto_generated=True,
    )

    assert len(same) == 1


def test_merge_leaves_similar_names_alone_when_a_human_wrote_the_captions():
    """Only speech recognition mishears. In a human-written caption two names
    a letter apart are two places -- a numbered branch, two shops in a row."""
    places = [
        make_place("장소1", timestampSec=0),
        make_place("장소2", timestampSec=0, latitude=37.5, longitude=127.0),
    ]

    assert len(place_extraction_service._merge_mishearings(places)) == 2


def test_merge_leaves_similar_names_alone_across_different_sources():
    """A name read off the screen was not misheard, so it is not a respelling
    of what the captions said."""
    places = [
        make_place("경포 해수역장", timestampSec=433),
        make_place("경포 해수욕장", timestampSec=433, source="on_screen_text", latitude=37.8, longitude=128.9),
    ]

    assert (
        len(place_extraction_service._merge_mishearings(places, transcript_auto_generated=True)) == 2
    )
