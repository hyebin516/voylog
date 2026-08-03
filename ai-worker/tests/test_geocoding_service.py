import asyncio

from app.services import geocoding_service


class FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._payload


class FakeAsyncClient:
    def __init__(self, payload=None, error=None):
        self._payload = payload
        self._error = error

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def get(self, url, headers, params):
        if self._error:
            raise self._error
        return FakeResponse(self._payload)


def test_geocode_place_returns_none_without_an_api_key(monkeypatch):
    monkeypatch.setattr(geocoding_service, "KAKAO_REST_API_KEY", None)

    result = asyncio.run(geocoding_service.geocode_place("해운대해수욕장"))

    assert result is None


def test_geocode_place_maps_the_first_document(monkeypatch):
    monkeypatch.setattr(geocoding_service, "KAKAO_REST_API_KEY", "fake-key")
    payload = {
        "documents": [
            {"y": "35.1587", "x": "129.1603", "road_address_name": "해운대해변로", "address_name": "구 주소"}
        ]
    }
    monkeypatch.setattr(geocoding_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient(payload=payload))

    result = asyncio.run(geocoding_service.geocode_place("해운대해수욕장"))

    assert result == {"latitude": 35.1587, "longitude": 129.1603, "address": "해운대해변로"}


def test_geocode_place_falls_back_to_address_name_when_no_road_address(monkeypatch):
    monkeypatch.setattr(geocoding_service, "KAKAO_REST_API_KEY", "fake-key")
    payload = {"documents": [{"y": "35.0", "x": "129.0", "road_address_name": None, "address_name": "지번 주소"}]}
    monkeypatch.setattr(geocoding_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient(payload=payload))

    result = asyncio.run(geocoding_service.geocode_place("어딘가"))

    assert result["address"] == "지번 주소"


def test_geocode_place_returns_none_when_no_documents_found(monkeypatch):
    monkeypatch.setattr(geocoding_service, "KAKAO_REST_API_KEY", "fake-key")
    monkeypatch.setattr(
        geocoding_service.httpx, "AsyncClient", lambda timeout=None: FakeAsyncClient(payload={"documents": []})
    )

    result = asyncio.run(geocoding_service.geocode_place("존재하지않는장소"))

    assert result is None


def test_geocode_place_returns_none_when_the_http_call_raises(monkeypatch):
    monkeypatch.setattr(geocoding_service, "KAKAO_REST_API_KEY", "fake-key")
    monkeypatch.setattr(
        geocoding_service.httpx,
        "AsyncClient",
        lambda timeout=None: FakeAsyncClient(error=RuntimeError("network down")),
    )

    result = asyncio.run(geocoding_service.geocode_place("장소"))

    assert result is None
