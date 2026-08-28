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
