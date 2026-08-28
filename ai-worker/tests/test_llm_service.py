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
