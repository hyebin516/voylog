import asyncio

from app.config import ENRICHMENT_FRAME_INTERVAL_SECONDS, ENRICHMENT_MAX_FRAMES
from app.constants.tag_catalog import ALL_TAG_CODES
from app.prompts.place_extraction_prompt import build_user_prompt
from app.schemas.request_schema import PlaceExtractionRequest
from app.schemas.response_schema import GeocodedPlace, PlaceExtractionResponse, PlaceTag
from app.prompts import place_match_prompt
from app.services import frame_extraction_service, llm_service
from app.services.geocoding_service import search_places
from app.utils.korean_similarity import sound_similarity, names_plausibly_same, similar_written_words
from app.utils.place_similarity import normalized_name
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


async def _resolve_name(name: str, candidate, region: str | None, llm_provider: str) -> dict | None:
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
    queries = [f"{region} {name}", name] if region else [name]

    results = []
    for query in queries:
        results = await search_places(query, size=_MATCH_CANDIDATE_COUNT)
        if results:
            break

    if not results:
        return None

    user_prompt = place_match_prompt.build_user_prompt(
        place_name=name,
        candidates=results,
        region=region,
        category=candidate.category,
        mention_note=candidate.mentionNote,
    )
    match = await asyncio.to_thread(llm_service.match_place, user_prompt, llm_provider)

    if match.index is None or not (0 <= match.index < len(results)):
        logger.info("No confident map match for '%s' (region=%s)", name, region)
        return None

    chosen = results[match.index]
    if not names_plausibly_same(name, chosen["name"]):
        logger.info("Rejected map match '%s' for '%s': the names are different places", chosen["name"], name)
        return None
    return {
        "name": name,
        "latitude": chosen["latitude"],
        "longitude": chosen["longitude"],
        "address": chosen["address"],
    }


def _names_to_try(candidate) -> list[str]:
    names = []
    for name in [candidate.name, *candidate.alternativeNames]:
        name = (name or "").strip()
        if name and name not in names:
            names.append(name)
    return names


async def _resolve_location(candidate, region: str | None, llm_provider: str) -> dict | None:
    """Resolves the name as extracted first, then each written spelling of
    the same place from the title/description/on-screen text. Auto-generated
    captions heard "소베" as "소배", which no map search finds; the title's
    spelling does. The returned `name` is the spelling that matched, so the
    place is shown under its real name."""
    for name in _names_to_try(candidate):
        location = await _resolve_name(name, candidate, region, llm_provider)
        if location:
            return location
    return None


def _with_written_sound_alikes(candidate, written_text: str):
    """Adds words from the title/description/hashtags/on-screen text that
    sound like a name heard in auto-generated captions ("소배" -> the
    title's "소베") as spellings to try. The model is asked to list these
    itself but often doesn't, so this makes the fallback dependable; a wrong
    sound-alike is harmless, since it still has to be found on the map and
    confirmed there."""
    if candidate.source != "transcript":
        return candidate
    extra = [
        word
        for word in similar_written_words(candidate.name, written_text)
        if word not in candidate.alternativeNames
    ]
    if not extra:
        return candidate
    return candidate.model_copy(update={"alternativeNames": [*candidate.alternativeNames, *extra]})


def _display_name(candidate, geo: dict | None, transcript_auto_generated: bool) -> str:
    """The spelling that found the place on the map. When nothing matched,
    a name heard by speech recognition gives way to one the creator wrote
    ("바카" in the captions, "@vaca" on screen); otherwise the extracted
    name stays."""
    if geo and geo.get("name"):
        return geo["name"]
    if transcript_auto_generated and candidate.source == "transcript" and candidate.alternativeNames:
        return candidate.alternativeNames[0]
    return candidate.name


# Two mentions this far apart in the video are two visits, not one name heard
# twice. Captions re-spell a name within a sentence, not minutes later.
_SAME_MOMENT_SEC = 20

# Jamo-level agreement above this means the same name misheard: "경포
# 해수역장" vs "경포 해수욕장" differs by one letter out of eleven.
_SAME_NAME_SOUND = 0.75


def _merge_mishearings(
    places: list[GeocodedPlace], transcript_auto_generated: bool = False
) -> list[GeocodedPlace]:
    """Collapses entries that are one place the captions spelled two ways.

    Matched on *sound*, not on category: an auto-caption typo often lands the
    two copies in different categories ("경포 해수역장" came back as `beach`
    and "경포 해수욕장" as `other`), so requiring the categories to agree --
    which is what the enrichment merge does -- keeps both.

    The copy that was located wins, since a geocoded name is one Kakao
    recognised; between two located or two unlocated copies the first stays.
    Everything it knows that the winner does not is carried over, so merging
    never loses an address, a category or a comment.
    """
    kept: list[GeocodedPlace] = []
    for place in places:
        match_index = next(
            (
                i
                for i, other in enumerate(kept)
                if _same_mention(place, other, transcript_auto_generated)
            ),
            None,
        )
        if match_index is None:
            kept.append(place)
            continue
        kept[match_index] = _better_of(kept[match_index], place)
    return kept


def _same_mention(
    a: GeocodedPlace, b: GeocodedPlace, transcript_auto_generated: bool
) -> bool:
    if normalized_name(a.name) == normalized_name(b.name):
        # The same name twice is one place only if it is also the same moment;
        # a second visit later in the video is its own card with its own
        # timestamp for the user to jump to.
        return _same_moment(a, b)
    if not _sound_alike_is_possible(a, b, transcript_auto_generated):
        return False
    return _same_moment(a, b) and sound_similarity(a.name, b.name) >= _SAME_NAME_SOUND


def _sound_alike_is_possible(
    a: GeocodedPlace, b: GeocodedPlace, transcript_auto_generated: bool
) -> bool:
    """Whether two *different* names can be one name heard wrong.

    Only speech recognition mishears, so this needs auto-generated captions
    and two transcript-derived places. Without the guard, names that differ
    by a single letter for an ordinary reason -- a numbered branch, two
    neighbouring shops -- would be merged into one place on sound alone.
    """
    if not transcript_auto_generated:
        return False
    return a.source == "transcript" and b.source == "transcript"


def _same_moment(a: GeocodedPlace, b: GeocodedPlace) -> bool:
    if a.timestampSec is None or b.timestampSec is None:
        # Metadata-derived places have no position in the video to compare,
        # so an identical name is all there is to go on.
        return normalized_name(a.name) == normalized_name(b.name)
    return abs(a.timestampSec - b.timestampSec) <= _SAME_MOMENT_SEC


def _better_of(first: GeocodedPlace, second: GeocodedPlace) -> GeocodedPlace:
    winner, loser = (first, second)
    if winner.latitude is None and loser.latitude is not None:
        winner, loser = (loser, winner)

    # Fill the winner's gaps from the one being dropped.
    return winner.model_copy(
        update={
            "latitude": winner.latitude if winner.latitude is not None else loser.latitude,
            "longitude": winner.longitude if winner.longitude is not None else loser.longitude,
            "address": winner.address or loser.address,
            "category": winner.category or loser.category,
            "businessHours": winner.businessHours or loser.businessHours,
            "tags": winner.tags or loser.tags,
            "mentionNote": winner.mentionNote or loser.mentionNote,
            # The earlier mention is where the place first appears.
            "timestampSec": min(
                [t for t in (winner.timestampSec, loser.timestampSec) if t is not None],
                default=None,
            ),
        }
    )


async def extract_places(request: PlaceExtractionRequest) -> PlaceExtractionResponse:
    user_prompt = build_user_prompt(
        title=request.video.title,
        description=request.video.description,
        hashtags=request.video.hashtags,
        transcript=[segment.model_dump() for segment in request.transcript],
        transcript_auto_generated=request.transcriptAutoGenerated,
    )

    llm_result = await asyncio.to_thread(llm_service.extract_places, user_prompt, request.llmProvider)

    transcript_available = len(request.transcript) > 0
    screen_text_available = False
    screen_text = ""

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
                transcript_auto_generated=request.transcriptAutoGenerated,
            )
            llm_result = await asyncio.to_thread(
                llm_service.extract_places, user_prompt, request.llmProvider, request.forceScreenText
            )

    candidates = llm_result.places
    if request.transcriptAutoGenerated:
        written_text = " ".join(
            [request.video.title or "", request.video.description or "", " ".join(request.video.hashtags), screen_text]
        )
        candidates = [_with_written_sound_alikes(candidate, written_text) for candidate in candidates]

    region = llm_result.region
    geocode_results = await asyncio.gather(
        *(_resolve_location(candidate, region, request.llmProvider) for candidate in candidates)
    )

    places = []
    for candidate, geo in zip(candidates, geocode_results):
        source, timestamp_sec = _sanitize_source_and_timestamp(
            candidate.source, candidate.timestampSec, transcript_available, screen_text_available
        )
        places.append(
            GeocodedPlace(
                name=_display_name(candidate, geo, request.transcriptAutoGenerated),
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

    return PlaceExtractionResponse(
        places=_merge_mishearings(places, request.transcriptAutoGenerated)
    )
