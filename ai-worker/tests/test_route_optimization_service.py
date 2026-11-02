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

    distance_m, duration_sec, _ = asyncio.run(svc._travel_time(None, origin, dest))

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
    distance_m, _, _ = asyncio.run(svc._travel_time(None, origin, dest))

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


def test_optimize_route_reports_per_leg_distance_and_duration_for_each_stop_after_the_first():
    request = RouteOptimizationRequest(
        startHotel=HOTEL_A,
        endHotel=HOTEL_B,
        places=[PLACE_1, PLACE_2, PLACE_3],
        routeType="hotelToHotel",
        optimizationPriority="duration",
    )

    result = asyncio.run(svc.optimize_route(request))
    route = result.optimizedRoute

    # The first stop has no preceding leg.
    assert route[0].legDistanceM is None
    assert route[0].legDurationSec is None

    # Every later stop's leg should be a real positive Haversine-derived
    # value, not fabricated by dividing the aggregate total evenly.
    for point in route[1:]:
        assert point.legDistanceM is not None and point.legDistanceM > 0
        assert point.legDurationSec is not None and point.legDurationSec > 0

    # The legs should sum back to (approximately) the reported totals.
    assert sum(p.legDistanceM for p in route[1:]) == pytest.approx(result.totalDistanceM, abs=len(route))
    assert sum(p.legDurationSec for p in route[1:]) == pytest.approx(result.totalDurationSec, abs=len(route))


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


def test_optimize_route_echoes_transit_when_requested():
    request = RouteOptimizationRequest(
        startHotel=HOTEL_A,
        endHotel=HOTEL_B,
        places=[PLACE_1, PLACE_2],
        routeType="hotelToHotel",
        optimizationPriority="duration",
        transportMode="transit",
    )

    result = asyncio.run(svc.optimize_route(request))

    assert result.transportMode == "transit"


def test_travel_time_falls_back_to_walking_speed_haversine_for_walk_mode():
    origin = {"latitude": 37.5, "longitude": 127.0}
    dest = {"latitude": 37.6, "longitude": 127.1}

    distance_m, duration_sec, _ = asyncio.run(svc._travel_time(None, origin, dest, "walk"))

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
            return {"status": "OK", "route": {"properties": {"totalDistance": 1195, "totalTime": 1250}}}

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

    distance_m, duration_sec, _ = asyncio.run(svc._kakao_travel_time(fake_client, origin, dest, "walk"))

    assert fake_client.called_url == svc.KAKAO_DIRECTIONS_URL["walk"]
    assert fake_client.called_params == {
        "start_x": origin["longitude"],
        "start_y": origin["latitude"],
        "end_x": dest["longitude"],
        "end_y": dest["latitude"],
    }
    assert distance_m == 1195.0
    assert duration_sec == 1250.0


def test_kakao_travel_time_rejects_a_too_far_away_walk_response_instead_of_treating_it_as_zero(monkeypatch):
    """Kakao's walk API returns HTTP 200 with status=TOO_FAR_AWAY and a zeroed-out
    route (not an HTTP error) when no walking route exists between two points
    (e.g. across water, or unreasonably far apart) — confirmed against the real
    API. If unhandled, this makes an unwalkable pair look like a free (0m, 0s)
    move to the optimizer, which would then happily route through it."""
    monkeypatch.setattr(svc, "KAKAO_REST_API_KEY", "fake-key")

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {"status": "TOO_FAR_AWAY", "route": {"legs": [], "properties": {"totalDistance": 0, "totalTime": 0}}}

    class FakeClient:
        async def get(self, url, headers=None, params=None):
            return FakeResponse()

    origin = {"latitude": 37.4979, "longitude": 127.0276}
    dest = {"latitude": 37.4602, "longitude": 126.4407}

    with pytest.raises(Exception):
        asyncio.run(svc._kakao_travel_time(FakeClient(), origin, dest, "walk"))


def test_travel_time_falls_back_to_haversine_for_a_too_far_away_walk_pair(monkeypatch):
    """End-to-end through _travel_time: a TOO_FAR_AWAY response must not be
    reported as a 0-second move — it should fall back to the (large) Haversine
    + walking-speed estimate instead."""
    monkeypatch.setattr(svc, "KAKAO_REST_API_KEY", "fake-key")

    async def too_far_away(client, origin, dest, mode):
        raise ValueError("Kakao walk routing returned status='TOO_FAR_AWAY'")

    monkeypatch.setattr(svc, "_kakao_travel_time", too_far_away)

    origin = {"latitude": 37.4979, "longitude": 127.0276}
    dest = {"latitude": 37.4602, "longitude": 126.4407}  # ~50km away

    distance_m, duration_sec, _ = asyncio.run(svc._travel_time(None, origin, dest, "walk"))

    expected_distance = haversine_distance_m(37.4979, 127.0276, 37.4602, 126.4407)
    assert distance_m == pytest.approx(expected_distance)
    assert distance_m > 10_000  # sanity check: this pair really is far apart
    assert duration_sec == pytest.approx(expected_distance / svc.ASSUMED_SPEED_MPS["walk"])


def test_travel_time_falls_back_to_transit_speed_haversine_for_transit_mode():
    origin = {"latitude": 37.5, "longitude": 127.0}
    dest = {"latitude": 37.6, "longitude": 127.1}

    distance_m, duration_sec, _ = asyncio.run(svc._travel_time(None, origin, dest, "transit"))

    expected_distance = haversine_distance_m(37.5, 127.0, 37.6, 127.1)
    assert distance_m == pytest.approx(expected_distance)
    assert duration_sec == pytest.approx(expected_distance / svc.ASSUMED_SPEED_MPS["transit"])
    # Transit (with waiting/transfers) is assumed slower than driving but
    # faster than walking.
    assert svc.ASSUMED_SPEED_MPS["walk"] < svc.ASSUMED_SPEED_MPS["transit"] < svc.ASSUMED_SPEED_MPS["car"]


def test_kakao_travel_time_picks_the_fastest_transit_route_among_several_options(monkeypatch):
    """Kakao's public-transit API returns several route options (bus-only,
    subway-only, combined transfers, ...) in one response -- confirmed
    against the real API. This app only ever optimizes on duration, so it
    should pick whichever option has the lowest totalTime, not just the
    first one in the list."""
    monkeypatch.setattr(svc, "KAKAO_REST_API_KEY", "fake-key")

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {
                "status": "OK",
                "routes": [
                    {"properties": {"type": "BUS", "totalDistance": 1198, "totalTime": 521}},
                    {"properties": {"type": "SUBWAY", "totalDistance": 1211, "totalTime": 606}},
                    {"properties": {"type": "BUS_AND_SUBWAY", "totalDistance": 2966, "totalTime": 1334}},
                ],
            }

    class FakeClient:
        async def get(self, url, headers=None, params=None):
            return FakeResponse()

    origin = {"latitude": 37.4979, "longitude": 127.0276}
    dest = {"latitude": 37.5015, "longitude": 127.0396}

    distance_m, duration_sec, _ = asyncio.run(svc._kakao_travel_time(FakeClient(), origin, dest, "transit"))

    assert distance_m == 1198.0
    assert duration_sec == 521.0


def test_kakao_travel_time_rejects_a_non_ok_transit_response_instead_of_treating_it_as_zero(monkeypatch):
    monkeypatch.setattr(svc, "KAKAO_REST_API_KEY", "fake-key")

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {"status": "NOT_FOUND", "routes": []}

    class FakeClient:
        async def get(self, url, headers=None, params=None):
            return FakeResponse()

    origin = {"latitude": 37.4979, "longitude": 127.0276}
    dest = {"latitude": 37.4602, "longitude": 126.4407}

    with pytest.raises(Exception):
        asyncio.run(svc._kakao_travel_time(FakeClient(), origin, dest, "transit"))


# --- optimize_place_route (bookmark-folder routes, FR-11) -----------------
# Walking uses the Haversine fallback at 1.1 m/s: ~0.5 km apart is a 7-8
# minute walk (walked), ~5 km apart is a 75 minute walk (bus instead).
NEAR_A = PlaceInput(placeId="near-a", name="Near A", latitude=36.7800, longitude=127.0000)
NEAR_B = PlaceInput(placeId="near-b", name="Near B", latitude=36.7845, longitude=127.0000)
FAR = PlaceInput(placeId="far", name="Far", latitude=36.8250, longitude=127.0000)


@pytest.fixture
def buses(monkeypatch):
    """A 20-minute bus for any pair, recording which pairs were looked up."""
    looked_up = []

    async def fake_bus_leg(client, origin, dest):
        looked_up.append((origin["latitude"], dest["latitude"]))
        return 5100.0, 1200.0, "600번 · 온양온천역 → 신정호", [[36.78, 127.0], [36.77, 126.98]]

    monkeypatch.setattr(svc, "_bus_leg", fake_bus_leg)
    return looked_up


def _place_route(places):
    from app.schemas.request_schema import PlaceRouteRequest

    return asyncio.run(svc.optimize_place_route(PlaceRouteRequest(places=places)))


def test_place_route_walks_short_legs_and_takes_the_bus_for_long_ones(buses):
    result = _place_route([NEAR_A, FAR, NEAR_B])

    far_leg = next(p for p in result.optimizedRoute if p.name == "Far")
    if far_leg.order == 0:
        far_leg = result.optimizedRoute[1]
    assert far_leg.legTransportMode == "transit"
    assert far_leg.legDurationSec == 1200
    assert far_leg.legGuidance == "600번 · 온양온천역 → 신정호"
    walked = [p for p in result.optimizedRoute[1:] if p.legTransportMode == "walk"]
    assert walked and all(p.legGuidance is None for p in walked)
    assert result.transportMode == "mixed"


def test_place_route_only_looks_up_buses_for_legs_too_long_to_walk(buses):
    _place_route([NEAR_A, NEAR_B])

    assert buses == []


def test_place_route_is_an_open_path_between_the_places_only(buses):
    result = _place_route([NEAR_A, FAR, NEAR_B])

    assert result.routeType == "placeToPlace"
    assert [p.type for p in result.optimizedRoute] == ["place", "place", "place"]
    assert result.optimizedRoute[0].legDurationSec is None
    assert result.optimizedRoute[0].legTransportMode is None
    # The far place is at an end: visiting it in the middle would mean
    # riding out and back again.
    assert result.optimizedRoute[1].name != "Far"
    # The total is exactly the legs shown -- no hidden trip to a centre point.
    assert result.totalDurationSec == sum(p.legDurationSec for p in result.optimizedRoute[1:])


def test_place_route_walks_a_long_leg_when_there_is_no_bus(monkeypatch):
    async def no_bus(client, origin, dest):
        return None

    monkeypatch.setattr(svc, "_bus_leg", no_bus)

    result = _place_route([NEAR_A, FAR])

    # Never an invented bus: without a real route the leg stays on foot.
    assert result.optimizedRoute[1].legTransportMode == "walk"
    assert result.transportMode == "walk"


def test_place_route_that_is_all_walkable_is_a_walking_route(buses):
    result = _place_route([NEAR_A, NEAR_B])

    assert result.transportMode == "walk"
    assert result.optimizedRoute[1].legTransportMode == "walk"


def test_leg_choice_takes_the_bus_only_when_walking_is_long_and_the_bus_is_quicker():
    WALK_PATH = [[36.1, 127.1], [36.2, 127.2]]
    BUS_PATH = [[36.3, 127.3], [36.4, 127.4]]
    bus = (3500.0, 1200.0, "600번", BUS_PATH)

    assert svc._leg_choice((3000.0, 2000.0, WALK_PATH), bus) == (3500.0, 1200.0, "transit", "600번", BUS_PATH)
    assert svc._leg_choice((3000.0, 1100.0, WALK_PATH), (3500.0, 1500.0, "600번", BUS_PATH)) == (
        3000.0, 1100.0, "walk", None, WALK_PATH)
    assert svc._leg_choice((500.0, 400.0, WALK_PATH), bus) == (500.0, 400.0, "walk", None, WALK_PATH)
    assert svc._leg_choice((3000.0, 2000.0, WALK_PATH), None) == (3000.0, 2000.0, "walk", None, WALK_PATH)


def test_leg_choice_drives_when_it_is_too_far_to_walk_and_no_bus_goes_there():
    """A 224km bookmark pair came out as "도보 3393분" (56 hours): the bus
    lookup found nothing, so the leg fell back to walking and the Haversine
    estimate divided the straight line by walking speed."""
    WALK = (224000.0, 203000.0, [])  # ~56 hours on foot
    CAR = (240000.0, 9600.0, [[36.1, 127.1]])  # ~2h40m

    distance, duration, mode, guidance, path = svc._leg_choice(WALK, None, CAR)

    assert mode == "car"
    assert duration == 9600.0
    assert guidance is None
    assert path == [[36.1, 127.1]]


def test_leg_choice_prefers_the_bus_over_the_car_when_there_is_one():
    WALK = (3000.0, 2000.0, [])
    BUS = (3500.0, 1200.0, "600번", [[36.2, 127.2]])
    CAR = (3400.0, 600.0, [[36.3, 127.3]])

    _, _, mode, _, _ = svc._leg_choice(WALK, BUS, CAR)

    assert mode == "transit"


def test_leg_choice_still_walks_a_short_leg_even_when_a_car_is_available():
    WALK = (500.0, 400.0, [[36.1, 127.1]])
    CAR = (600.0, 120.0, [[36.2, 127.2]])

    _, _, mode, _, _ = svc._leg_choice(WALK, None, CAR)

    assert mode == "walk"


def test_leg_choice_keeps_walking_when_nothing_else_routes():
    """No bus, no car -- the straight-line walk is all there is. Better a
    visibly odd number than a fabricated drive."""
    WALK = (224000.0, 203000.0, [])

    _, duration, mode, _, _ = svc._leg_choice(WALK, None, None)

    assert mode == "walk"
    assert duration == 203000.0


def test_leg_choice_returns_the_path_of_the_mode_it_actually_picked():
    """A leg labelled "버스 22분" drawn along the walking line would be a lie."""
    WALK_PATH = [[36.1, 127.1]]
    BUS_PATH = [[36.3, 127.3]]

    _, _, mode, _, path = svc._leg_choice((3000.0, 2000.0, WALK_PATH), (3500.0, 1200.0, "600번", BUS_PATH))

    assert mode == "transit"
    assert path is BUS_PATH


def test_transit_guidance_names_the_buses_and_the_stops():
    route = {
        "steps": [
            {"properties": {"type": "WALK"}},
            {"properties": {"type": "BUS", "vehicles": [{"name": "600"}, {"name": "610"}],
                            "stops": [{"name": "온양온천역 신한은행"}, {"name": "백련암"}]}},
            {"properties": {"type": "BUS", "vehicles": [{"name": "12"}],
                            "stops": [{"name": "백련암"}, {"name": "신정호관광지 건너"}]}},
        ]
    }

    assert svc._transit_guidance(route) == "600번 → 12번 · 온양온천역 신한은행 → 신정호관광지 건너"


def test_bus_leg_is_none_without_an_api_key():
    # The autouse fixture removes the key: no straight-line "bus" is invented.
    assert asyncio.run(svc._bus_leg(None, {"latitude": 1, "longitude": 1}, {"latitude": 2, "longitude": 2})) is None


def test_same_point_legs_never_call_kakao():
    """왕복 코스는 출발 노드와 도착 노드가 같은 좌표다. 그 조합까지 카카오에
    물으면 SAME_POINT로 거절당하고 경고만 쌓인다."""
    import asyncio
    from app.services import route_optimization_service as svc

    called = []

    async def fail_if_called(*args, **kwargs):
        called.append(args)
        raise AssertionError("동일 좌표인데 카카오를 호출했다")

    same = {"latitude": 37.5, "longitude": 127.0}
    distance, duration, path = asyncio.run(
        svc._travel_time(None, same, dict(same), "walk")
    )

    assert (distance, duration, path) == (0.0, 0.0, [])
    assert called == []
