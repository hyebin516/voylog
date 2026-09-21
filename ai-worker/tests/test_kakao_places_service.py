import asyncio

from app.services import kakao_places_service


class FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._payload


class FakeAsyncClient:
    def __init__(self, payloads_by_code=None, error_codes=None):
        self._payloads_by_code = payloads_by_code or {}
        self._error_codes = error_codes or set()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def get(self, url, headers=None, params=None):
        code = params["category_group_code"]
        if code in self._error_codes:
            raise RuntimeError(f"kakao down for {code}")
        return FakeResponse(self._payloads_by_code.get(code, {"documents": []}))


def _doc(doc_id, name, x, y):
    return {"id": doc_id, "place_name": name, "x": x, "y": y}


def test_returns_empty_list_without_an_api_key(monkeypatch):
    monkeypatch.setattr(kakao_places_service, "KAKAO_REST_API_KEY", None)

    result = asyncio.run(kakao_places_service.search_nearby_by_category(37.5, 127.0, 1500))

    assert result == []


def test_merges_results_from_all_category_codes_and_maps_to_our_category_labels(monkeypatch):
    monkeypatch.setattr(kakao_places_service, "KAKAO_REST_API_KEY", "fake-key")
    payloads = {
        "CE7": {"documents": [_doc("1", "카페 A", "127.02", "37.50")]},
        "FD6": {"documents": [_doc("2", "식당 B", "127.03", "37.51")]},
        "AT4": {"documents": [_doc("3", "관광지 C", "127.04", "37.52")]},
    }
    monkeypatch.setattr(
        kakao_places_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient(payloads_by_code=payloads)
    )

    result = asyncio.run(kakao_places_service.search_nearby_by_category(37.5, 127.0, 1500))

    by_id = {c.placeId: c for c in result}
    assert by_id["kakao:1"].name == "카페 A"
    assert by_id["kakao:1"].category == "cafe"
    assert by_id["kakao:1"].latitude == 37.50
    assert by_id["kakao:1"].longitude == 127.02
    assert by_id["kakao:2"].category == "restaurant"
    assert by_id["kakao:3"].category == "attraction"
    # Kakao candidates never have our LLM-extracted business hours/embedding/tags.
    assert by_id["kakao:1"].businessHours is None
    assert by_id["kakao:1"].embedding is None
    assert by_id["kakao:1"].tags == []


def test_a_failing_category_call_does_not_fail_the_others(monkeypatch):
    monkeypatch.setattr(kakao_places_service, "KAKAO_REST_API_KEY", "fake-key")
    payloads = {"CE7": {"documents": [_doc("1", "카페 A", "127.02", "37.50")]}}
    monkeypatch.setattr(
        kakao_places_service.httpx,
        "AsyncClient",
        lambda timeout=None: FakeAsyncClient(payloads_by_code=payloads, error_codes={"FD6", "AT4"}),
    )

    result = asyncio.run(kakao_places_service.search_nearby_by_category(37.5, 127.0, 1500))

    assert [c.placeId for c in result] == ["kakao:1"]


class FakeKeywordClient:
    def __init__(self, documents):
        self._documents = documents

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def get(self, url, headers=None, params=None):
        return FakeResponse({"documents": self._documents})


def test_mood_search_skips_parking_lots_and_other_non_destinations(monkeypatch):
    monkeypatch.setattr(kakao_places_service, "KAKAO_REST_API_KEY", "fake-key")
    documents = [
        {**_doc("1", "제주동문시장", "126.52", "33.51"), "category_group_code": ""},
        {**_doc("2", "제주동문시장 주차장", "126.52", "33.51"), "category_group_code": "PK6"},
        {**_doc("3", "동문시장 편의점", "126.52", "33.51"), "category_group_code": "CS2"},
    ]
    monkeypatch.setattr(kakao_places_service.httpx, "AsyncClient", lambda **kwargs: FakeKeywordClient(documents))

    result = asyncio.run(kakao_places_service.search_nearby_by_mood(33.51, 126.52, 1000, "활기찬"))

    assert {c.name for c in result} == {"제주동문시장"}
