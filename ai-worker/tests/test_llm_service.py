import pytest

from app.services import llm_service
from app.schemas.response_schema import LlmPlaceExtractionResult, PlaceSummaryResult
from app.utils.exceptions import AiProviderError

SUCCESS_RESULT = LlmPlaceExtractionResult(places=[])
SUCCESS_SUMMARY_RESULT = PlaceSummaryResult(pros="좋아요", cons="아쉬워요")


def test_call_with_retry_succeeds_on_first_attempt():
    calls = []

    def call_fn(prompt):
        calls.append(prompt)
        return SUCCESS_RESULT

    result = llm_service._call_with_retry(call_fn, "prompt", "openai")

    assert result is SUCCESS_RESULT
    assert len(calls) == 1


def test_call_with_retry_retries_once_then_succeeds():
    attempts = {"n": 0}

    def call_fn(prompt):
        attempts["n"] += 1
        if attempts["n"] == 1:
            raise RuntimeError("transient failure")
        return SUCCESS_RESULT

    result = llm_service._call_with_retry(call_fn, "prompt", "openai")

    assert result is SUCCESS_RESULT
    assert attempts["n"] == 2


def test_call_with_retry_raises_ai_provider_error_after_two_failures():
    def call_fn(prompt):
        raise RuntimeError("still failing")

    with pytest.raises(AiProviderError):
        llm_service._call_with_retry(call_fn, "prompt", "openai")


def test_extract_places_explicit_openai_provider_never_falls_back_to_claude(monkeypatch):
    openai_calls = []
    claude_calls = []
    monkeypatch.setattr(llm_service, "_call_openai", lambda p: (openai_calls.append(p), SUCCESS_RESULT)[1])
    monkeypatch.setattr(llm_service, "_call_claude", lambda p: (claude_calls.append(p), SUCCESS_RESULT)[1])

    result = llm_service.extract_places("prompt", provider="openai")

    assert result is SUCCESS_RESULT
    assert len(openai_calls) == 1
    assert len(claude_calls) == 0


def test_extract_places_explicit_openai_provider_raises_without_trying_claude(monkeypatch):
    monkeypatch.setattr(llm_service, "_call_openai", lambda p: (_ for _ in ()).throw(RuntimeError("down")))
    claude_calls = []
    monkeypatch.setattr(llm_service, "_call_claude", lambda p: (claude_calls.append(p), SUCCESS_RESULT)[1])

    with pytest.raises(AiProviderError):
        llm_service.extract_places("prompt", provider="openai")

    assert len(claude_calls) == 0


def test_extract_places_auto_mode_uses_openai_when_it_succeeds(monkeypatch):
    claude_calls = []
    monkeypatch.setattr(llm_service, "_call_openai", lambda p: SUCCESS_RESULT)
    monkeypatch.setattr(llm_service, "_call_claude", lambda p: (claude_calls.append(p), SUCCESS_RESULT)[1])

    result = llm_service.extract_places("prompt", provider="auto")

    assert result is SUCCESS_RESULT
    assert len(claude_calls) == 0


def test_extract_places_auto_mode_falls_back_to_claude_after_openai_exhausts_retries(monkeypatch):
    monkeypatch.setattr(llm_service, "_call_openai", lambda p: (_ for _ in ()).throw(RuntimeError("down")))
    monkeypatch.setattr(llm_service, "_call_claude", lambda p: SUCCESS_RESULT)

    result = llm_service.extract_places("prompt", provider="auto")

    assert result is SUCCESS_RESULT


def test_extract_places_auto_mode_raises_when_both_providers_exhaust_retries(monkeypatch):
    monkeypatch.setattr(llm_service, "_call_openai", lambda p: (_ for _ in ()).throw(RuntimeError("down")))
    monkeypatch.setattr(llm_service, "_call_claude", lambda p: (_ for _ in ()).throw(RuntimeError("also down")))

    with pytest.raises(AiProviderError):
        llm_service.extract_places("prompt", provider="auto")


def test_summarize_place_explicit_openai_provider_never_falls_back_to_claude(monkeypatch):
    openai_calls = []
    claude_calls = []
    monkeypatch.setattr(llm_service, "_call_openai_summary", lambda p: (openai_calls.append(p), SUCCESS_SUMMARY_RESULT)[1])
    monkeypatch.setattr(llm_service, "_call_claude_summary", lambda p: (claude_calls.append(p), SUCCESS_SUMMARY_RESULT)[1])

    result = llm_service.summarize_place("prompt", provider="openai")

    assert result is SUCCESS_SUMMARY_RESULT
    assert len(openai_calls) == 1
    assert len(claude_calls) == 0


def test_summarize_place_auto_mode_falls_back_to_claude_after_openai_exhausts_retries(monkeypatch):
    monkeypatch.setattr(llm_service, "_call_openai_summary", lambda p: (_ for _ in ()).throw(RuntimeError("down")))
    monkeypatch.setattr(llm_service, "_call_claude_summary", lambda p: SUCCESS_SUMMARY_RESULT)

    result = llm_service.summarize_place("prompt", provider="auto")

    assert result is SUCCESS_SUMMARY_RESULT


def test_summarize_place_auto_mode_raises_when_both_providers_exhaust_retries(monkeypatch):
    monkeypatch.setattr(llm_service, "_call_openai_summary", lambda p: (_ for _ in ()).throw(RuntimeError("down")))
    monkeypatch.setattr(llm_service, "_call_claude_summary", lambda p: (_ for _ in ()).throw(RuntimeError("also down")))

    with pytest.raises(AiProviderError):
        llm_service.summarize_place("prompt", provider="auto")


def test_extract_screen_text_returns_empty_string_immediately_when_no_frames_given():
    openai_calls = []
    result = llm_service.extract_screen_text([], provider="auto")

    assert result == ""
    assert openai_calls == []


def test_extract_screen_text_explicit_openai_provider_never_falls_back_to_claude(monkeypatch):
    openai_calls = []
    claude_calls = []
    monkeypatch.setattr(llm_service, "_call_openai_vision", lambda frames: (openai_calls.append(frames), "제주 감성카페")[1])
    monkeypatch.setattr(llm_service, "_call_claude_vision", lambda frames: (claude_calls.append(frames), "제주 감성카페")[1])

    result = llm_service.extract_screen_text([b"frame1"], provider="openai")

    assert result == "제주 감성카페"
    assert len(openai_calls) == 1
    assert len(claude_calls) == 0


def test_extract_screen_text_auto_mode_falls_back_to_claude_after_openai_exhausts_retries(monkeypatch):
    monkeypatch.setattr(llm_service, "_call_openai_vision", lambda frames: (_ for _ in ()).throw(RuntimeError("down")))
    monkeypatch.setattr(llm_service, "_call_claude_vision", lambda frames: "해운대 야경 맛집")

    result = llm_service.extract_screen_text([b"frame1"], provider="auto")

    assert result == "해운대 야경 맛집"


def test_extract_screen_text_returns_empty_string_instead_of_raising_when_both_providers_fail(monkeypatch):
    """Unlike extract_places (a hard requirement, raises AiProviderError on
    total failure), this is a best-effort fallback -- the caller treats an
    empty string the same as "OCR found nothing useful", so it must never
    raise and break the place-extraction request it's a fallback for."""
    monkeypatch.setattr(llm_service, "_call_openai_vision", lambda frames: (_ for _ in ()).throw(RuntimeError("down")))
    monkeypatch.setattr(llm_service, "_call_claude_vision", lambda frames: (_ for _ in ()).throw(RuntimeError("also down")))

    result = llm_service.extract_screen_text([b"frame1"], provider="auto")

    assert result == ""


def test_extract_screen_text_sends_frames_in_batches(monkeypatch):
    """The background pass reads up to 120 frames -- never in one request."""
    monkeypatch.setattr(llm_service, "VISION_BATCH_SIZE", 24)
    batch_sizes = []

    def fake_vision(frames):
        batch_sizes.append(len(frames))
        return f"text{len(batch_sizes)}"

    monkeypatch.setattr(llm_service, "_call_openai_vision", fake_vision)

    text = llm_service.extract_screen_text([b"f"] * 60, "openai")

    assert batch_sizes == [24, 24, 12]
    assert text == "text1\ntext2\ntext3"


def test_extract_screen_text_keeps_other_batches_when_one_fails(monkeypatch):
    monkeypatch.setattr(llm_service, "VISION_BATCH_SIZE", 2)
    calls = {"n": 0}

    def flaky_vision(frames):
        calls["n"] += 1
        # First batch fails on both of its attempts, the second succeeds.
        if calls["n"] <= 2:
            raise RuntimeError("boom")
        return "성심당"

    monkeypatch.setattr(llm_service, "_call_openai_vision", flaky_vision)

    assert llm_service.extract_screen_text([b"f"] * 4, "openai") == "성심당"


class _RateLimitError(Exception):
    pass


def test_a_rate_limited_call_waits_the_time_the_provider_asks_and_tries_again(monkeypatch):
    sleeps = []
    monkeypatch.setattr(llm_service.time, "sleep", sleeps.append)
    attempts = {"n": 0}

    def call_fn(prompt):
        attempts["n"] += 1
        if attempts["n"] <= 3:
            raise _RateLimitError("Error code: 429 - Rate limit reached ... Please try again in 1.5s.")
        return SUCCESS_RESULT

    assert llm_service._call_with_retry(call_fn, "prompt", "openai") is SUCCESS_RESULT
    assert sleeps == [1.5, 1.5, 1.5]


def test_rate_limit_waits_are_clamped_and_bounded_by_a_total_budget(monkeypatch):
    sleeps = []
    monkeypatch.setattr(llm_service.time, "sleep", sleeps.append)

    def call_fn(prompt):
        raise _RateLimitError("429 rate_limit_exceeded, try again in 132ms")

    with pytest.raises(AiProviderError):
        llm_service._call_with_retry(call_fn, "prompt", "openai")

    assert all(wait == llm_service._RATE_LIMIT_MIN_WAIT_SECONDS for wait in sleeps)
    assert sum(sleeps) <= llm_service._RATE_LIMIT_MAX_TOTAL_WAIT_SECONDS


def test_a_non_rate_limit_failure_still_gets_only_one_retry(monkeypatch):
    sleeps = []
    monkeypatch.setattr(llm_service.time, "sleep", sleeps.append)
    attempts = {"n": 0}

    def call_fn(prompt):
        attempts["n"] += 1
        raise RuntimeError("invalid json")

    with pytest.raises(AiProviderError):
        llm_service._call_with_retry(call_fn, "prompt", "openai")

    assert attempts["n"] == 2
    assert sleeps == []


def test_thorough_extraction_uses_the_stronger_openai_model(monkeypatch):
    models = []
    monkeypatch.setattr(
        llm_service, "_call_openai", lambda prompt, model=llm_service._OPENAI_EXTRACTION_MODEL: (models.append(model), SUCCESS_RESULT)[1]
    )

    llm_service.extract_places("prompt", "openai")
    llm_service.extract_places("prompt", "openai", thorough=True)

    assert models == [llm_service._OPENAI_EXTRACTION_MODEL, llm_service._OPENAI_THOROUGH_EXTRACTION_MODEL]
