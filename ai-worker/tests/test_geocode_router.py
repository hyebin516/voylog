from fastapi.testclient import TestClient

from app.main import app
import app.routers.geocode_router as geocode_router_module

client = TestClient(app)


def test_geocode_returns_the_resolved_coordinates(monkeypatch):
    async def fake_geocode_place(query):
        assert query == "제주"
        return {"latitude": 33.4996, "longitude": 126.5312, "address": "제주특별자치도"}

    monkeypatch.setattr(geocode_router_module, "geocode_place", fake_geocode_place)

    res = client.post("/geocode", json={"query": "제주"})

    assert res.status_code == 200
    assert res.json() == {"latitude": 33.4996, "longitude": 126.5312, "address": "제주특별자치도"}


def test_geocode_returns_503_when_the_region_cannot_be_resolved(monkeypatch):
    async def fake_geocode_place(query):
        return None

    monkeypatch.setattr(geocode_router_module, "geocode_place", fake_geocode_place)

    res = client.post("/geocode", json={"query": "존재하지않는지역이름"})

    assert res.status_code == 503
    assert res.json()["error"]["code"] == "GEOCODING_FAILED"


def test_geocode_search_returns_matching_candidates(monkeypatch):
    async def fake_search_places(query, size):
        assert query == "제주 호텔"
        assert size == 8
        return [
            {"placeId": "kakao:1", "name": "제주 게스트하우스", "address": "제주 제주시 연동", "latitude": 33.4, "longitude": 126.5}
        ]

    monkeypatch.setattr(geocode_router_module, "search_places", fake_search_places)

    res = client.post("/geocode/search", json={"query": "제주 호텔"})

    assert res.status_code == 200
    assert res.json() == {
        "candidates": [
            {"placeId": "kakao:1", "name": "제주 게스트하우스", "address": "제주 제주시 연동", "latitude": 33.4, "longitude": 126.5}
        ]
    }


def test_geocode_search_returns_an_empty_list_when_nothing_matches(monkeypatch):
    async def fake_search_places(query, size):
        return []

    monkeypatch.setattr(geocode_router_module, "search_places", fake_search_places)

    res = client.post("/geocode/search", json={"query": "존재하지않는숙소이름"})

    assert res.status_code == 200
    assert res.json() == {"candidates": []}


def test_geocode_reverse_returns_the_resolved_address(monkeypatch):
    async def fake_reverse_geocode(latitude, longitude):
        assert latitude == 33.4996
        assert longitude == 126.5312
        return "제주특별자치도 제주시"

    monkeypatch.setattr(geocode_router_module, "reverse_geocode", fake_reverse_geocode)

    res = client.post("/geocode/reverse", json={"latitude": 33.4996, "longitude": 126.5312})

    assert res.status_code == 200
    assert res.json() == {"address": "제주특별자치도 제주시"}


def test_geocode_reverse_returns_null_address_when_unresolvable(monkeypatch):
    async def fake_reverse_geocode(latitude, longitude):
        return None

    monkeypatch.setattr(geocode_router_module, "reverse_geocode", fake_reverse_geocode)

    res = client.post("/geocode/reverse", json={"latitude": 0, "longitude": 0})

    assert res.status_code == 200
    assert res.json() == {"address": None}
