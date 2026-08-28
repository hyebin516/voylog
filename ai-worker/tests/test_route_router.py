from fastapi.testclient import TestClient

from app.main import app
from app.services import route_optimization_service

client = TestClient(app)

HOTEL = {"hotelId": "h1", "name": "Hotel", "latitude": 37.5, "longitude": 127.0, "address": "addr"}


def place(i):
    return {"placeId": f"p{i}", "name": f"Place {i}", "latitude": 37.5 + i * 0.01, "longitude": 127.0 + i * 0.01}


def test_optimize_route_rejects_fewer_than_two_places():
    body = {"startHotel": HOTEL, "endHotel": HOTEL, "places": [place(1)], "routeType": "roundTrip"}
    res = client.post("/optimize-route", json=body)
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "INVALID_REQUEST"


def test_optimize_route_rejects_more_than_ten_places():
    body = {
        "startHotel": HOTEL,
        "endHotel": HOTEL,
        "places": [place(i) for i in range(11)],
        "routeType": "roundTrip",
    }
    res = client.post("/optimize-route", json=body)
    assert res.status_code == 400
    assert res.json()["error"]["code"] == "INVALID_REQUEST"


def test_optimize_route_accepts_two_places_and_delegates_to_the_service(monkeypatch):
    async def fake_optimize(request):
        from app.schemas.response_schema import RouteOptimizationResponse, RoutePoint

        return RouteOptimizationResponse(
            routeType=request.routeType,
            optimizationPriority=request.optimizationPriority,
            transportMode=request.transportMode,
            startPlace=RoutePoint(order=0, type="hotel", hotelId="h1", name="Hotel", latitude=37.5, longitude=127.0),
            endPlace=RoutePoint(order=2, type="hotel", hotelId="h1", name="Hotel", latitude=37.5, longitude=127.0),
            optimizedRoute=[],
            totalDistanceM=100,
            totalDurationSec=60,
        )

    monkeypatch.setattr(route_optimization_service, "optimize_route", fake_optimize)

    body = {"startHotel": HOTEL, "endHotel": HOTEL, "places": [place(1), place(2)], "routeType": "roundTrip"}
    res = client.post("/optimize-route", json=body)

    assert res.status_code == 200
    assert res.json()["totalDistanceM"] == 100
