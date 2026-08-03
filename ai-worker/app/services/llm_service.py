import json

from anthropic import Anthropic
from openai import OpenAI

from app.config import ANTHROPIC_API_KEY, LLM_TIMEOUT_SECONDS, OPENAI_API_KEY
from app.prompts.place_extraction_prompt import SYSTEM_PROMPT
from app.schemas.response_schema import LlmPlaceExtractionResult
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
