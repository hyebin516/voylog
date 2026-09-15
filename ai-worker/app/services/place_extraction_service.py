import asyncio

from app.config import ENRICHMENT_FRAME_INTERVAL_SECONDS, ENRICHMENT_MAX_FRAMES
from app.constants.tag_catalog import ALL_TAG_CODES
from app.prompts.place_extraction_prompt import build_user_prompt
from app.schemas.request_schema import PlaceExtractionRequest
from app.schemas.response_schema import GeocodedPlace, PlaceExtractionResponse, PlaceTag
from app.prompts import place_match_prompt
from app.services import frame_extraction_service, llm_service
from app.services.geocoding_service import search_places
from app.utils.logger import logger

# How many map-search candidates to put in front of the LLM. Enough to
# contain the right branch of a chain, small enough to keep the prompt
# cheap.
_MATCH_CANDIDATE_COUNT = 5

_ALLOWED_TAG_CODES = set(ALL_TAG_CODES)


def _valid_tags(tags: list[PlaceTag]) -> list[PlaceTag]:
    """Drops any tag the LLM hallucinated outside the fixed catalog, since a
    tag code is only useful for matching if both sides agree on the
    vocabulary."""
    return [tag for tag in tags if tag.code in _ALLOWED_TAG_CODES]


def _sanitize_source_and_timestamp(
    source: str,
    timestamp_sec,
    transcript_available: bool,
    screen_text_available: bool = False,
):
    """The LLM occasionally mislabels a metadata-only place as
    `source: "transcript"` (with a spurious timestampSec) even when no
    transcript text was in its prompt at all. Enforce the invariant the rest
    of the app relies on (CLAUDE.md: "transcript 유래는 타임스탬프 포함,
    메타데이터 유래는 timestampSec = null") rather than trusting the model's
    self-reported source when we can verify it's impossible. Same idea for
    `on_screen_text` when the OCR fallback never actually ran/found text."""
    if not transcript_available and source == "transcript":
        return "description", None
    if not screen_text_available and source == "on_screen_text":
        return "description", None
    return source, timestamp_sec


async def _extract_on_screen_text(youtube_url: str, llm_provider: str, thorough: bool = False) -> str:
    """Fallback for any video with no official transcript: download a
    low-res copy of the video, sample a few frames, and read any on-screen
    text via vision LLM. Never raises -- any failure here just means the
    caller proceeds with the (metadata-only) result it already had."""
    try:
        if thorough:
            frames = await frame_extraction_service.download_and_sample_frames(
                youtube_url,
                interval_seconds=ENRICHMENT_FRAME_INTERVAL_SECONDS,
                max_frames=ENRICHMENT_MAX_FRAMES,
            )
        else:
            frames = await frame_extraction_service.download_and_sample_frames(youtube_url)
        if not frames:
            return ""
        return await asyncio.to_thread(llm_service.extract_screen_text, frames, llm_provider)
    except Exception as exc:
        logger.warning("On-screen text fallback failed for %s: %s", youtube_url, exc)
        return ""


async def _resolve_location(candidate, region: str | None, llm_provider: str) -> dict | None:
    """Finds the real place an extracted name refers to.

    A bare keyword search on the name alone is what used to put a 대전 vlog's
    "정동" in 서울 -- the first Kakao hit for a common name is frequently in a
    different city entirely. So the search is scoped to the video's region
    when we know it, and the LLM then confirms which candidate (if any) is
    actually the place being talked about. No confident match means no
    coordinates, which is better than a pin in the wrong city.

    The LLM only *chooses among* real Kakao results -- coordinates still
    come solely from Kakao, never from the model.
    """
    queries = [f"{region} {candidate.name}", candidate.name] if region else [candidate.name]

    results = []
    for query in queries:
        results = await search_places(query, size=_MATCH_CANDIDATE_COUNT)
        if results:
            break

    if not results:
        return None

    user_prompt = place_match_prompt.build_user_prompt(
        place_name=candidate.name,
        candidates=results,
        region=region,
        category=candidate.category,
        mention_note=candidate.mentionNote,
    )
    match = await asyncio.to_thread(llm_service.match_place, user_prompt, llm_provider)

    if match.index is None or not (0 <= match.index < len(results)):
        logger.info("No confident map match for '%s' (region=%s)", candidate.name, region)
        return None

    chosen = results[match.index]
    return {
        "latitude": chosen["latitude"],
        "longitude": chosen["longitude"],
        "address": chosen["address"],
    }


async def extract_places(request: PlaceExtractionRequest) -> PlaceExtractionResponse:
    user_prompt = build_user_prompt(
        title=request.video.title,
        description=request.video.description,
        hashtags=request.video.hashtags,
        transcript=[segment.model_dump() for segment in request.transcript],
    )

    llm_result = await asyncio.to_thread(llm_service.extract_places, user_prompt, request.llmProvider)

    transcript_available = len(request.transcript) > 0
    screen_text_available = False

    # Any video with no official transcript may still have places only
    # visible as burned-in captions/overlays -- metadata alone finding a
    # place doesn't mean it found all of them, so this runs whenever there's
    # no transcript to fall back on, not just when metadata found nothing.
    #
    # It deliberately does NOT run on its own for videos whose transcript
    # merely produced few places, tempting as that is: the pass downloads
    # the whole video and takes minutes, while the backend's
    # /extract-places budget is 30s, so widening the trigger turned those
    # analyses into 503s instead of improving them. The caller asks for it
    # explicitly (`forceScreenText`) from a background job instead.
    if not transcript_available or request.forceScreenText:
        screen_text = await _extract_on_screen_text(
            request.video.youtubeUrl, request.llmProvider, thorough=request.forceScreenText
        )
        if screen_text:
            screen_text_available = True
            user_prompt = build_user_prompt(
                title=request.video.title,
                description=request.video.description,
                hashtags=request.video.hashtags,
                # Keep the transcript when we have one: it's poor at proper
                # nouns but still carries context and the timestamps that
                # on-screen text alone can't provide.
                transcript=[segment.model_dump() for segment in request.transcript],
                screen_text=screen_text,
            )
            llm_result = await asyncio.to_thread(llm_service.extract_places, user_prompt, request.llmProvider)

    region = llm_result.region
    geocode_results = await asyncio.gather(
        *(_resolve_location(candidate, region, request.llmProvider) for candidate in llm_result.places)
    )

    places = []
    for candidate, geo in zip(llm_result.places, geocode_results):
        source, timestamp_sec = _sanitize_source_and_timestamp(
            candidate.source, candidate.timestampSec, transcript_available, screen_text_available
        )
        places.append(
            GeocodedPlace(
                name=candidate.name,
                timestampSec=timestamp_sec,
                latitude=geo["latitude"] if geo else None,
                longitude=geo["longitude"] if geo else None,
                address=geo["address"] if geo else None,
                source=source,
                confidence=candidate.confidence,
                category=candidate.category,
                businessHours=candidate.businessHours,
                tags=_valid_tags(candidate.tags),
                mentionNote=candidate.mentionNote,
            )
        )

    return PlaceExtractionResponse(places=places)
