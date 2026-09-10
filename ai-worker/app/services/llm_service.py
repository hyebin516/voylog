import base64
import json

from anthropic import Anthropic
from openai import OpenAI

from app.config import ANTHROPIC_API_KEY, LLM_TIMEOUT_SECONDS, OPENAI_API_KEY
from app.prompts.place_extraction_prompt import SYSTEM_PROMPT
from app.prompts.place_summary_prompt import SYSTEM_PROMPT as SUMMARY_SYSTEM_PROMPT
from app.schemas.response_schema import LlmPlaceExtractionResult, PlaceSummaryResult
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


def _call_with_retry(call_fn, user_prompt: str, provider_name: str) -> LlmPlaceExtractionResult:
    for attempt in range(2):
        try:
            return call_fn(user_prompt)
        except Exception as exc:
            logger.warning("%s attempt %d failed: %s", provider_name, attempt + 1, exc)
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
    return {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}


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
        logger.warning("extract_screen_text: all providers failed, treating as no text found: %s", exc)
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
