import base64
import json
import re
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


# Place extraction model, for both the first pass (while the user waits)
# and the background on-screen-text pass. gpt-4.1-mini found places
# gpt-4o-mini missed in 3 of 3 runs on the same vlog (a shop only named on
# screen as "@vaca"), so the first pass now uses it too instead of leaving
# those places for the background pass to fill in minutes later.
_OPENAI_EXTRACTION_MODEL = "gpt-4.1-mini"
_OPENAI_THOROUGH_EXTRACTION_MODEL = _OPENAI_EXTRACTION_MODEL


def _call_openai(user_prompt: str, model: str = _OPENAI_EXTRACTION_MODEL) -> LlmPlaceExtractionResult:
    if not _openai_client:
        raise RuntimeError("OpenAI client is not configured")

    response = _openai_client.chat.completions.create(
        model=model,
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


# Rate limits are per minute. The on-screen-text pass alone can use a whole
# minute's token budget (each sampled frame is thousands of tokens), and the
# place-matching calls right after it used to fail both of their tries within
# a few seconds -- every place of a video lost its location, silently, since
# there is often no second provider to fall back to. So a rate-limited call
# waits the time the provider asks for (or backs off) and tries again, up to
# a total wait budget; ordinary failures still get just one retry.
_RATE_LIMIT_MAX_TOTAL_WAIT_SECONDS = 60
_RATE_LIMIT_MIN_WAIT_SECONDS = 1
_RATE_LIMIT_MAX_WAIT_SECONDS = 20
_RETRY_AFTER_PATTERN = re.compile(r"try again in ([\d.]+)\s*(ms|s)", re.IGNORECASE)


def _is_rate_limit(exc: Exception) -> bool:
    return "rate_limit" in str(exc).lower() or "429" in str(exc)


def _rate_limit_wait_seconds(exc: Exception, rate_limited_so_far: int) -> float:
    match = _RETRY_AFTER_PATTERN.search(str(exc))
    if match:
        wait = float(match.group(1)) / (1000 if match.group(2).lower() == "ms" else 1)
    else:
        wait = 2 ** rate_limited_so_far
    return min(max(wait, _RATE_LIMIT_MIN_WAIT_SECONDS), _RATE_LIMIT_MAX_WAIT_SECONDS)


def _retry(call_fn, argument, provider_name: str, label: str = ""):
    failures = 0
    rate_limited = 0
    waited = 0.0
    while True:
        try:
            return call_fn(argument)
        except Exception as exc:
            logger.warning("%s%s attempt failed: %s", provider_name, label, exc)
            if _is_rate_limit(exc):
                wait = _rate_limit_wait_seconds(exc, rate_limited)
                if waited + wait <= _RATE_LIMIT_MAX_TOTAL_WAIT_SECONDS:
                    rate_limited += 1
                    waited += wait
                    time.sleep(wait)
                    continue
            failures += 1
            if failures >= 2:
                break
    raise AiProviderError(f"{provider_name}{label} failed after retry")


def _call_with_retry(call_fn, user_prompt: str, provider_name: str) -> LlmPlaceExtractionResult:
    return _retry(call_fn, user_prompt, provider_name)


def extract_places(user_prompt: str, provider: str = "auto", thorough: bool = False) -> LlmPlaceExtractionResult:
    def call_openai(prompt):
        if thorough:
            return _call_openai(prompt, model=_OPENAI_THOROUGH_EXTRACTION_MODEL)
        return _call_openai(prompt)

    if provider == "openai":
        return _call_with_retry(call_openai, user_prompt, "openai")

    if provider == "claude":
        return _call_with_retry(_call_claude, user_prompt, "claude")

    try:
        return _call_with_retry(call_openai, user_prompt, "openai")
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


# Reading on-screen text. gpt-4o-mini bills a low-detail frame as ~2,800
# tokens, so one video's 120 frames (~340k tokens) exceeded the 200k
# tokens-per-minute limit on their own and starved the calls after them.
# Measured on the same 24 frames of a Korean vlog: gpt-4o-mini 68k tokens
# ($0.010), gpt-4.1-mini 13k tokens ($0.006) and it read the shop handles
# correctly ("@보흔바", "@데코와") where gpt-4o-mini wrote "테코와".
_OPENAI_VISION_MODEL = "gpt-4.1-mini"


def _call_openai_vision(frames: list[bytes]) -> str:
    if not _openai_client:
        raise RuntimeError("OpenAI client is not configured")

    content = [{"type": "text", "text": _SCREEN_TEXT_PROMPT}] + [_image_content_block_openai(f) for f in frames]
    response = _openai_client.chat.completions.create(
        model=_OPENAI_VISION_MODEL,
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
    return _retry(call_fn, frames, provider_name, label=" vision")


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
