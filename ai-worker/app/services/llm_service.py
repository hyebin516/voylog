import base64
import json
import time

from anthropic import Anthropic
from openai import OpenAI

from app.config import ANTHROPIC_API_KEY, LLM_TIMEOUT_SECONDS, OPENAI_API_KEY, VISION_BATCH_SIZE
from app.prompts.place_extraction_prompt import SYSTEM_PROMPT
from app.prompts.place_match_prompt import SYSTEM_PROMPT as MATCH_SYSTEM_PROMPT
from app.prompts.place_summary_prompt import SYSTEM_PROMPT as SUMMARY_SYSTEM_PROMPT
from app.schemas.response_schema import LlmPlaceExtractionResult, PlaceMatchResult, PlaceSummaryResult
from app.utils.exceptions import AiProviderError
from app.utils.logger import logger

_openai_client = OpenAI(api_key=OPENAI_API_KEY, timeout=LLM_TIMEOUT_SECONDS) if OPENAI_API_KEY else None
_anthropic_client = Anthropic(api_key=ANTHROPIC_API_KEY, timeout=LLM_TIMEOUT_SECONDS) if ANTHROPIC_API_KEY else None


def _parse_json(raw_text: str) -> LlmPlaceExtractionResult:
    data = json.loads(raw_text)
    return LlmPlaceExtractionResult(**data)


def _call_openai(user_prompt: str) -> LlmPlaceExtractionResult:
    if not _openai_client:
        raise RuntimeError("OpenAI client is not configured")

    response = _openai_client.chat.completions.create(
        model="gpt-4o-mini",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
    )
    return _parse_json(response.choices[0].message.content)


def _call_claude(user_prompt: str) -> LlmPlaceExtractionResult:
    if not _anthropic_client:
        raise RuntimeError("Claude client is not configured")

    response = _anthropic_client.messages.create(
        model="claude-3-5-sonnet-latest",
        max_tokens=2048,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}],
    )
    return _parse_json(response.content[0].text)


# A rate-limited call retried immediately just fails again inside the same
# minute window. Providers report these as 429 and ask for a short wait, so
# the retry backs off instead of burning its only second chance.
_RATE_LIMIT_BACKOFF_SECONDS = 3


def _is_rate_limit(exc: Exception) -> bool:
    return "rate_limit" in str(exc).lower() or "429" in str(exc)


def _call_with_retry(call_fn, user_prompt: str, provider_name: str) -> LlmPlaceExtractionResult:
    for attempt in range(2):
        try:
            return call_fn(user_prompt)
        except Exception as exc:
            logger.warning("%s attempt %d failed: %s", provider_name, attempt + 1, exc)
            if attempt == 0 and _is_rate_limit(exc):
                time.sleep(_RATE_LIMIT_BACKOFF_SECONDS)
    raise AiProviderError(f"{provider_name} failed after retry")


def extract_places(user_prompt: str, provider: str = "auto") -> LlmPlaceExtractionResult:
    if provider == "openai":
        return _call_with_retry(_call_openai, user_prompt, "openai")

    if provider == "claude":
        return _call_with_retry(_call_claude, user_prompt, "claude")

    try:
        return _call_with_retry(_call_openai, user_prompt, "openai")
    except AiProviderError:
        logger.info("Falling back to Claude after OpenAI failure")
        return _call_with_retry(_call_claude, user_prompt, "claude")


_SCREEN_TEXT_PROMPT = (
    "The attached images are frames sampled from a YouTube travel vlog. "
    "Transcribe any text visible on screen exactly as shown -- burned-in "
    "captions, place-name overlays, signage the vlogger points the camera "
    "at, etc. Ignore the video player UI itself (progress bar, timestamps, "
    "channel watermark). If a frame has no readable text, skip it. Return "
    "the transcribed text only, one line per distinct piece of text, no "
    "commentary or explanation. If nothing is readable in any frame, "
    "return an empty response."
)


def _image_content_block_openai(frame: bytes) -> dict:
    b64 = base64.b64encode(frame).decode("utf-8")
    # "low" detail bills a flat 85 tokens per image instead of scaling with
    # resolution. Without it a 60-frame batch consumed the whole 200k
    # tokens-per-minute budget, which then 429'd every small call that
    # followed -- including the place-matching ones, so places silently
    # ended up with no coordinates. Burned-in vlog place names are large
    # title overlays, which survive the downscale.
    return {
        "type": "image_url",
        "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "low"},
    }


def _call_openai_vision(frames: list[bytes]) -> str:
    if not _openai_client:
        raise RuntimeError("OpenAI client is not configured")

    content = [{"type": "text", "text": _SCREEN_TEXT_PROMPT}] + [_image_content_block_openai(f) for f in frames]
    response = _openai_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": content}],
    )
    return (response.choices[0].message.content or "").strip()


def _image_content_block_claude(frame: bytes) -> dict:
    b64 = base64.b64encode(frame).decode("utf-8")
    return {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64}}


def _call_claude_vision(frames: list[bytes]) -> str:
    if not _anthropic_client:
        raise RuntimeError("Claude client is not configured")

    content = [_image_content_block_claude(f) for f in frames] + [{"type": "text", "text": _SCREEN_TEXT_PROMPT}]
    response = _anthropic_client.messages.create(
        model="claude-3-5-sonnet-latest",
        max_tokens=1024,
        messages=[{"role": "user", "content": content}],
    )
    return response.content[0].text.strip()


def _call_with_retry_text(call_fn, frames: list[bytes], provider_name: str) -> str:
    for attempt in range(2):
        try:
            return call_fn(frames)
        except Exception as exc:
            logger.warning("%s vision attempt %d failed: %s", provider_name, attempt + 1, exc)
    raise AiProviderError(f"{provider_name} vision failed after retry")


def extract_screen_text(frames: list[bytes], provider: str = "auto") -> str:
    """Best-effort OCR/vision read of on-screen text across the given video
    frames -- used only as a fallback when transcript+metadata place
    extraction found nothing. Returns "" (never raises) if no frames are
    given or every provider attempt fails, since the caller treats an empty
    result the same as "this fallback didn't help"."""
    if not frames:
        return ""

    # Sent in batches so a dense sample (the background enrichment pass
    # reads up to ENRICHMENT_MAX_FRAMES) never becomes one oversized
    # request. A failed batch is skipped rather than discarding the text the
    # other batches already found.
    texts = []
    for start in range(0, len(frames), VISION_BATCH_SIZE):
        text = _read_screen_text_batch(frames[start : start + VISION_BATCH_SIZE], provider)
        if text:
            texts.append(text)
    return "\n".join(texts)


def _read_screen_text_batch(frames: list[bytes], provider: str) -> str:
    try:
        if provider == "openai":
            return _call_with_retry_text(_call_openai_vision, frames, "openai")
        if provider == "claude":
            return _call_with_retry_text(_call_claude_vision, frames, "claude")

        try:
            return _call_with_retry_text(_call_openai_vision, frames, "openai")
        except AiProviderError:
            logger.info("Falling back to Claude after OpenAI vision failure")
            return _call_with_retry_text(_call_claude_vision, frames, "claude")
    except AiProviderError as exc:
        logger.warning("extract_screen_text: a batch failed on every provider, skipping it: %s", exc)
        return ""


def _parse_summary_json(raw_text: str) -> PlaceSummaryResult:
    data = json.loads(raw_text)
    return PlaceSummaryResult(**data)


def _call_openai_summary(user_prompt: str) -> PlaceSummaryResult:
    if not _openai_client:
        raise RuntimeError("OpenAI client is not configured")

    response = _openai_client.chat.completions.create(
        model="gpt-4o-mini",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": SUMMARY_SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
    )
    return _parse_summary_json(response.choices[0].message.content)


def _call_claude_summary(user_prompt: str) -> PlaceSummaryResult:
    if not _anthropic_client:
        raise RuntimeError("Claude client is not configured")

    response = _anthropic_client.messages.create(
        model="claude-3-5-sonnet-latest",
        max_tokens=512,
        system=SUMMARY_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}],
    )
    return _parse_summary_json(response.content[0].text)


def summarize_place(user_prompt: str, provider: str = "auto") -> PlaceSummaryResult:
    if provider == "openai":
        return _call_with_retry(_call_openai_summary, user_prompt, "openai")

    if provider == "claude":
        return _call_with_retry(_call_claude_summary, user_prompt, "claude")

    try:
        return _call_with_retry(_call_openai_summary, user_prompt, "openai")
    except AiProviderError:
        logger.info("Falling back to Claude after OpenAI failure")
        return _call_with_retry(_call_claude_summary, user_prompt, "claude")


def _parse_match_json(raw_text: str) -> PlaceMatchResult:
    data = json.loads(raw_text)
    return PlaceMatchResult(**data)


def _call_openai_match(user_prompt: str) -> PlaceMatchResult:
    if not _openai_client:
        raise RuntimeError("OpenAI client is not configured")

    response = _openai_client.chat.completions.create(
        model="gpt-4o-mini",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": MATCH_SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
    )
    return _parse_match_json(response.choices[0].message.content)


def _call_claude_match(user_prompt: str) -> PlaceMatchResult:
    if not _anthropic_client:
        raise RuntimeError("Claude client is not configured")

    response = _anthropic_client.messages.create(
        model="claude-3-5-sonnet-latest",
        max_tokens=256,
        system=MATCH_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}],
    )
    return _parse_match_json(response.content[0].text)


def match_place(user_prompt: str, provider: str = "auto") -> PlaceMatchResult:
    """Picks which map-search candidate an extracted place refers to.

    Never raises: geocoding is best-effort, so if every provider fails the
    caller just falls back to its own choice rather than failing the whole
    video analysis."""
    try:
        if provider == "openai":
            return _call_with_retry(_call_openai_match, user_prompt, "openai")
        if provider == "claude":
            return _call_with_retry(_call_claude_match, user_prompt, "claude")

        try:
            return _call_with_retry(_call_openai_match, user_prompt, "openai")
        except AiProviderError:
            logger.info("Falling back to Claude after OpenAI failure")
            return _call_with_retry(_call_claude_match, user_prompt, "claude")
    except Exception as exc:
        logger.warning("match_place failed, leaving the candidate choice to the caller: %s", exc)
        return PlaceMatchResult(index=None, reason=None)
