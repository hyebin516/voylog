"""The last filter before a place becomes a card.

Guards the asymmetry that matters: a real place wrongly dropped is gone
with no way for anyone to notice, while junk left in is merely untidy. So
every case here is about *not* dropping too much.
"""

import asyncio

import pytest

from app.schemas.response_schema import GeocodedPlace, NotAPlace, PlaceVerificationResult
from app.services import place_extraction_service


def place(name, **overrides):
    defaults = dict(name=name, source="transcript", confidence=0.8)
    defaults.update(overrides)
    return GeocodedPlace(**defaults)


def run(places, verification, monkeypatch, provider="auto"):
    asked = {}

    def fake_verify(user_prompt, prov):
        asked["prompt"] = user_prompt
        asked["provider"] = prov
        return verification

    monkeypatch.setattr(place_extraction_service.llm_service, "verify_places", fake_verify)
    kept = asyncio.run(
        place_extraction_service._drop_non_places(places, "강릉 브이로그", "강릉", provider)
    )
    return kept, asked


def test_drops_a_name_the_model_says_is_not_a_place(monkeypatch):
    places = [
        place("경포 해수욕장", latitude=37.8, longitude=128.9),
        place("오리바이하"),
    ]

    kept, _ = run(
        places,
        PlaceVerificationResult(notPlaces=[NotAPlace(index=0, reason="오리배 타기를 잘못 들은 것")]),
        monkeypatch,
    )

    assert [p.name for p in kept] == ["경포 해수욕장"]


def test_keeps_everything_when_the_model_finds_nothing_to_drop(monkeypatch):
    places = [place("재민천"), place("두물거리 카페거리")]

    kept, _ = run(places, PlaceVerificationResult(notPlaces=[]), monkeypatch)

    assert [p.name for p in kept] == ["재민천", "두물거리 카페거리"]


def test_never_asks_about_a_place_the_map_already_found(monkeypatch):
    """A located name has been confirmed by Kakao. Putting it in front of
    the model again is a chance to lose it for nothing."""
    places = [
        place("경포 해수욕장", latitude=37.8, longitude=128.9),
        place("오리바이하"),
    ]

    _, asked = run(places, PlaceVerificationResult(notPlaces=[]), monkeypatch)

    assert "오리바이하" in asked["prompt"]
    assert "경포 해수욕장" not in asked["prompt"]


def test_makes_no_call_at_all_when_everything_was_located(monkeypatch):
    called = {"count": 0}

    def fake_verify(user_prompt, provider):
        called["count"] += 1
        return PlaceVerificationResult(notPlaces=[])

    monkeypatch.setattr(place_extraction_service.llm_service, "verify_places", fake_verify)
    places = [place("경포 해수욕장", latitude=37.8, longitude=128.9)]

    kept = asyncio.run(place_extraction_service._drop_non_places(places, "t", "강릉", "auto"))

    assert called["count"] == 0
    assert len(kept) == 1


def test_an_index_outside_the_list_drops_nothing(monkeypatch):
    """The index comes from the model. A bad one must not take out a place
    that was never asked about."""
    places = [
        place("경포 해수욕장", latitude=37.8, longitude=128.9),
        place("재민천"),
    ]

    kept, _ = run(
        places,
        PlaceVerificationResult(notPlaces=[NotAPlace(index=7), NotAPlace(index=-1)]),
        monkeypatch,
    )

    assert len(kept) == 2


def test_a_failed_check_keeps_every_place(monkeypatch):
    """verify_places swallows provider failures and answers with an empty
    list, so an outage leaves the results exactly as they were."""
    def exploding_verify(user_prompt, provider):
        raise RuntimeError("provider down")

    monkeypatch.setattr(place_extraction_service.llm_service, "verify_places", exploding_verify)
    places = [place("재민천")]

    with pytest.raises(RuntimeError):
        asyncio.run(place_extraction_service._drop_non_places(places, "t", "강릉", "auto"))


def test_verify_places_itself_never_raises(monkeypatch):
    """The real guard: llm_service.verify_places turns any failure into an
    empty answer, which is what keeps a provider outage from costing an
    analysis its places."""
    from app.services import llm_service

    monkeypatch.setattr(llm_service, "_openai_client", None)
    monkeypatch.setattr(llm_service, "_anthropic_client", None)

    result = llm_service.verify_places("anything", "auto")

    assert result.notPlaces == []
