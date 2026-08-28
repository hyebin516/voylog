import asyncio

import pytest

from app.schemas.request_schema import HotelInput, PlaceInput, RouteOptimizationRequest
from app.services import route_optimization_service as svc
from app.utils.distance import haversine_distance_m


@pytest.fixture(autouse=True)
def no_kakao_key(monkeypatch):
    # Forces every _travel_time() call onto the deterministic Haversine fallback,
    # so these tests never make a real network call.
    monkeypatch.setattr(svc, "KAKAO_REST_API_KEY", None)


HOTEL_A = HotelInput(hotelId="hotel-a", name="Hotel A", latitude=37.50, longitude=127.00, address="a")
HOTEL_B = HotelInput(hotelId="hotel-b", name="Hotel B", latitude=37.60, longitude=127.10, address="b")
PLACE_1 = PlaceInput(placeId="p1", name="Place 1", latitude=37.52, longitude=127.02)
PLACE_2 = PlaceInput(placeId="p2", name="Place 2", latitude=37.55, longitude=127.05)
PLACE_3 = PlaceInput(placeId="p3", name="Place 3", latitude=37.58, longitude=127.08)


def test_travel_time_uses_haversine_fallback_without_an_api_key():
    origin = {"latitude": 37.5, "longitude": 127.0}
    dest = {"latitude": 37.6, "longitude": 127.1}

    distance_m, duration_sec = asyncio.run(svc._travel_time(None, origin, dest))

    expected_distance = haversine_distance_m(37.5, 127.0, 37.6, 127.1)
    assert distance_m == pytest.approx(expected_distance)
    assert duration_sec == pytest.approx(expected_distance / svc.ASSUMED_CITY_SPEED_MPS)


def test_travel_time_falls_back_to_haversine_when_kakao_call_raises(monkeypatch):
    monkeypatch.setattr(svc, "KAKAO_REST_API_KEY", "fake-key")

    async def failing_kakao_call(client, origin, dest):
        raise RuntimeError("kakao mobility down")

    monkeypatch.setattr(svc, "_kakao_travel_time", failing_kakao_call)

    origin = {"latitude": 37.5, "longitude": 127.0}
    dest = {"latitude": 37.6, "longitude": 127.1}
    distance_m, _ = asyncio.run(svc._travel_time(None, origin, dest))

    assert distance_m == pytest.approx(haversine_distance_m(37.5, 127.0, 37.6, 127.1))


def test_optimize_route_round_trip_keeps_the_same_hotel_at_both_ends():
    request = RouteOptimizationRequest(
        startHotel=HOTEL_A,
        endHotel=HOTEL_A,
        places=[PLACE_1, PLACE_2, PLACE_3],
        routeType="roundTrip",
        optimizationPriority="duration",
    )

    result = asyncio.run(svc.optimize_route(request))

    assert result.optimizedRoute[0].type == "hotel"
    assert result.optimizedRoute[0].hotelId == "hotel-a"
    assert result.optimizedRoute[-1].type == "hotel"
    assert result.optimizedRoute[-1].hotelId == "hotel-a"
    assert result.startPlace.hotelId == "hotel-a"
    assert result.endPlace.hotelId == "hotel-a"

    middle_place_ids = {point.placeId for point in result.optimizedRoute[1:-1]}
    assert middle_place_ids == {"p1", "p2", "p3"}
    assert len(result.optimizedRoute) == 5  # start hotel + 3 places + end hotel


def test_optimize_route_hotel_to_hotel_keeps_distinct_start_and_end():
    request = RouteOptimizationRequest(
        startHotel=HOTEL_A,
        endHotel=HOTEL_B,
        places=[PLACE_1, PLACE_2],
        routeType="hotelToHotel",
        optimizationPriority="duration",
    )

    result = asyncio.run(svc.optimize_route(request))

    assert result.optimizedRoute[0].hotelId == "hotel-a"
    assert result.optimizedRoute[-1].hotelId == "hotel-b"
    middle_place_ids = {point.placeId for point in result.optimizedRoute[1:-1]}
    assert middle_place_ids == {"p1", "p2"}


def test_optimize_route_reports_positive_totals_matching_the_chosen_path():
    request = RouteOptimizationRequest(
        startHotel=HOTEL_A,
        endHotel=HOTEL_B,
        places=[PLACE_1, PLACE_2, PLACE_3],
        routeType="hotelToHotel",
        optimizationPriority="duration",
    )

    result = asyncio.run(svc.optimize_route(request))

    assert result.totalDistanceM > 0
    assert result.totalDurationSec > 0
    # duration is derived from distance via the fixed assumed city speed (Haversine fallback)
    assert result.totalDurationSec == pytest.approx(result.totalDistanceM / svc.ASSUMED_CITY_SPEED_MPS, rel=0.05)


def test_optimize_route_echoes_the_requested_route_type_and_priority():
    request = RouteOptimizationRequest(
        startHotel=HOTEL_A,
        endHotel=HOTEL_A,
        places=[PLACE_1, PLACE_2],
        routeType="roundTrip",
        optimizationPriority="duration",
    )

    result = asyncio.run(svc.optimize_route(request))

    assert result.routeType == "roundTrip"
    assert result.optimizationPriority == "duration"
    assert result.transportMode == "car"


def test_optimize_route_defaults_to_car_and_echoes_walk_when_requested():
    request = RouteOptimizationRequest(
        startHotel=HOTEL_A,
        endHotel=HOTEL_B,
        places=[PLACE_1, PLACE_2],
        routeType="hotelToHotel",
        optimizationPriority="duration",
        transportMode="walk",
    )

    result = asyncio.run(svc.optimize_route(request))

    assert result.transportMode == "walk"


def test_travel_time_falls_back_to_walking_speed_haversine_for_walk_mode():
    origin = {"latitude": 37.5, "longitude": 127.0}
    dest = {"latitude": 37.6, "longitude": 127.1}

    distance_m, duration_sec = asyncio.run(svc._travel_time(None, origin, dest, "walk"))

    expected_distance = haversine_distance_m(37.5, 127.0, 37.6, 127.1)
    assert distance_m == pytest.approx(expected_distance)
    assert duration_sec == pytest.approx(expected_distance / svc.ASSUMED_SPEED_MPS["walk"])
    # Walking is slower than the car assumption, so it should take longer for the same distance.
    assert svc.ASSUMED_SPEED_MPS["walk"] < svc.ASSUMED_SPEED_MPS["car"]


def test_kakao_travel_time_calls_the_walk_endpoint_and_parses_its_response_shape(monkeypatch):
    monkeypatch.setattr(svc, "KAKAO_REST_API_KEY", "fake-key")

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {"route": {"properties": {"totalDistance": 1195, "totalTime": 1250}}}

    class FakeClient:
        def __init__(self):
            self.called_url = None
            self.called_params = None

        async def get(self, url, headers=None, params=None):
            self.called_url = url
            self.called_params = params
            return FakeResponse()

    fake_client = FakeClient()
    origin = {"latitude": 37.4979, "longitude": 127.0276}
    dest = {"latitude": 37.5015, "longitude": 127.0396}

    distance_m, duration_sec = asyncio.run(svc._kakao_travel_time(fake_client, origin, dest, "walk"))

    assert fake_client.called_url == svc.KAKAO_DIRECTIONS_URL["walk"]
    assert fake_client.called_params == {
        "start_x": origin["longitude"],
        "start_y": origin["latitude"],
        "end_x": dest["longitude"],
        "end_y": dest["latitude"],
    }
    assert distance_m == 1195.0
    assert duration_sec == 1250.0
