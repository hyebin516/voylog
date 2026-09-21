import asyncio
from itertools import product
from typing import List, Tuple

import httpx

from app.config import KAKAO_REST_API_KEY, KAKAO_TIMEOUT_SECONDS
from app.schemas.request_schema import PlaceRouteRequest, RouteOptimizationRequest
from app.schemas.response_schema import RouteOptimizationResponse, RoutePoint
from app.utils.distance import haversine_distance_m
from app.utils.logger import logger

KAKAO_DIRECTIONS_URL = {
    "car": "https://apis-navi.kakaomobility.com/v1/directions",
    "walk": "https://dapi.kakao.com/v2/routing/walk",
    "transit": "https://dapi.kakao.com/v2/routing/publictraffic",
}
ASSUMED_CITY_SPEED_MPS = 8.3  # ~30 km/h fallback for car duration estimation
ASSUMED_SPEED_MPS = {
    "car": ASSUMED_CITY_SPEED_MPS,
    "walk": 1.1,  # ~4 km/h, average walking pace
    "transit": 4.2,  # ~15 km/h effective average incl. waiting/transfers
}


async def _kakao_travel_time(client: httpx.AsyncClient, origin: dict, dest: dict, mode: str) -> Tuple[float, float]:
    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}

    if mode in ("walk", "transit"):
        params = {
            "start_x": origin["longitude"],
            "start_y": origin["latitude"],
            "end_x": dest["longitude"],
            "end_y": dest["latitude"],
        }
        response = await client.get(KAKAO_DIRECTIONS_URL[mode], headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        # Both the walk and public-transit APIs return HTTP 200 with a
        # zeroed-out/empty result (not an HTTP error) when no route exists
        # (e.g. across water, or too far apart) — treat any non-"OK" status
        # as a failure so callers fall back to Haversine instead of
        # silently treating an unreachable pair as a free (0m, 0s) move.
        if data.get("status") != "OK":
            raise ValueError(f"Kakao {mode} routing returned status={data.get('status')!r}")

        if mode == "walk":
            props = data["route"]["properties"]
            return float(props["totalDistance"]), float(props["totalTime"])

        # transit: the API returns several route options (bus-only,
        # subway-only, combined transfers, ...) -- pick the fastest one,
        # consistent with this app only ever optimizing on duration.
        routes = data.get("routes", [])
        if not routes:
            raise ValueError("Kakao transit routing returned no routes")
        best = min(routes, key=lambda r: r["properties"]["totalTime"])
        return float(best["properties"]["totalDistance"]), float(best["properties"]["totalTime"])

    params = {
        "origin": f"{origin['longitude']},{origin['latitude']}",
        "destination": f"{dest['longitude']},{dest['latitude']}",
    }
    response = await client.get(KAKAO_DIRECTIONS_URL["car"], headers=headers, params=params)
    response.raise_for_status()
    data = response.json()
    summary = data["routes"][0]["summary"]
    return float(summary["distance"]), float(summary["duration"])


async def _travel_time(client: httpx.AsyncClient, origin: dict, dest: dict, mode: str = "car") -> Tuple[float, float]:
    if KAKAO_REST_API_KEY:
        try:
            return await _kakao_travel_time(client, origin, dest, mode)
        except Exception as exc:
            logger.warning("Kakao API failed for mode=%s, falling back to Haversine: %s", mode, exc)

    distance_m = haversine_distance_m(origin["latitude"], origin["longitude"], dest["latitude"], dest["longitude"])
    duration_sec = distance_m / ASSUMED_SPEED_MPS[mode]
    return distance_m, duration_sec


async def _build_matrices(nodes: List[dict], mode: str = "car") -> Tuple[List[List[float]], List[List[float]]]:
    n = len(nodes)
    distance_matrix = [[0.0] * n for _ in range(n)]
    duration_matrix = [[0.0] * n for _ in range(n)]

    async with httpx.AsyncClient(timeout=KAKAO_TIMEOUT_SECONDS) as client:
        pairs = [(i, j) for i, j in product(range(n), range(n)) if i != j]
        results = await asyncio.gather(*(_travel_time(client, nodes[i], nodes[j], mode) for i, j in pairs))

    for (i, j), (distance_m, duration_sec) in zip(pairs, results):
        distance_matrix[i][j] = distance_m
        duration_matrix[i][j] = duration_sec

    return distance_matrix, duration_matrix


def _route_cost(route: List[int], matrix: List[List[float]]) -> float:
    return sum(matrix[route[i]][route[i + 1]] for i in range(len(route) - 1))


def _nearest_neighbor_path(matrix: List[List[float]], start: int, end: int, middle: List[int]) -> List[int]:
    """Greedy path construction with a fixed start node and a fixed end node.

    When start == end (round trip), `middle` already excludes the shared
    index, so this naturally degenerates into the round-trip case.
    """
    unvisited = set(middle)
    route = [start]
    current = start

    while unvisited:
        nxt = min(unvisited, key=lambda j: matrix[current][j])
        route.append(nxt)
        unvisited.remove(nxt)
        current = nxt

    route.append(end)
    return route


def _two_opt(route: List[int], matrix: List[List[float]]) -> List[int]:
    """2-opt local search that keeps the first and last positions fixed,
    so the start and end endpoints are always preserved."""
    improved = True
    best = route

    while improved:
        improved = False
        for i in range(1, len(best) - 2):
            for j in range(i + 1, len(best) - 1):
                candidate = best[:i] + best[i:j + 1][::-1] + best[j + 1:]
                if _route_cost(candidate, matrix) < _route_cost(best, matrix):
                    best = candidate
                    improved = True

    return best


async def optimize_route(request: RouteOptimizationRequest) -> RouteOptimizationResponse:
    start_hotel = request.startHotel
    end_hotel = request.endHotel

    nodes = (
        [{"latitude": start_hotel.latitude, "longitude": start_hotel.longitude}]
        + [{"latitude": p.latitude, "longitude": p.longitude} for p in request.places]
        + [{"latitude": end_hotel.latitude, "longitude": end_hotel.longitude}]
    )

    start_idx = 0
    end_idx = len(nodes) - 1
    middle_indices = list(range(1, end_idx))

    distance_matrix, duration_matrix = await _build_matrices(nodes, request.transportMode)

    initial_route = _nearest_neighbor_path(duration_matrix, start_idx, end_idx, middle_indices)
    optimized_indices = _two_opt(initial_route, duration_matrix)

    total_distance_m = round(_route_cost(optimized_indices, distance_matrix))
    total_duration_sec = round(_route_cost(optimized_indices, duration_matrix))

    def to_route_point(order: int, index: int) -> RoutePoint:
        # The leg arriving here is from the previous stop in the optimized
        # order -- order 0 has no preceding leg, so it stays null rather
        # than fabricating a value.
        if order == 0:
            leg_distance_m = None
            leg_duration_sec = None
        else:
            prev_index = optimized_indices[order - 1]
            leg_distance_m = round(distance_matrix[prev_index][index])
            leg_duration_sec = round(duration_matrix[prev_index][index])

        if index == start_idx:
            return RoutePoint(
                order=order,
                type="hotel",
                hotelId=start_hotel.hotelId,
                name=start_hotel.name,
                latitude=start_hotel.latitude,
                longitude=start_hotel.longitude,
                legDistanceM=leg_distance_m,
                legDurationSec=leg_duration_sec,
            )
        if index == end_idx:
            return RoutePoint(
                order=order,
                type="hotel",
                hotelId=end_hotel.hotelId,
                name=end_hotel.name,
                latitude=end_hotel.latitude,
                longitude=end_hotel.longitude,
                legDistanceM=leg_distance_m,
                legDurationSec=leg_duration_sec,
            )
        place = request.places[index - 1]
        return RoutePoint(
            order=order,
            type="place",
            placeId=place.placeId,
            name=place.name,
            latitude=place.latitude,
            longitude=place.longitude,
            legDistanceM=leg_distance_m,
            legDurationSec=leg_duration_sec,
        )

    optimized_route = [to_route_point(order, index) for order, index in enumerate(optimized_indices)]

    return RouteOptimizationResponse(
        routeType=request.routeType,
        optimizationPriority=request.optimizationPriority,
        transportMode=request.transportMode,
        startPlace=optimized_route[0],
        endPlace=optimized_route[-1],
        optimizedRoute=optimized_route,
        totalDistanceM=total_distance_m,
        totalDurationSec=total_duration_sec,
    )


# A leg is walked when walking it takes at most this long; anything longer
# goes by bus (Kakao public-transit routing) when there is one and it is
# quicker. Walking a 61-minute leg because the whole route was "a walking
# course" is what this replaces -- and a car isn't something a traveller
# reaching for this feature can assume they have.
WALK_LEG_MAX_SEC = 15 * 60

PLACE_ROUTE_TYPE = "placeToPlace"
MIXED_TRANSPORT_MODE = "mixed"


def _vehicle_label(step: dict) -> str:
    vehicles = step.get("vehicles") or []
    if not vehicles:
        return ""
    name = str(vehicles[0].get("name", "")).strip()
    if step.get("type") == "BUS" and name and not name.endswith("번"):
        name = f"{name}번"
    return name


def _transit_guidance(route: dict) -> str | None:
    """ "600번 · 온양온천역 신한은행 → 신정호관광지 건너", or with a transfer
    "600번 → 12번 · A → B". Built from the route's riding steps."""
    rides = [s.get("properties", {}) for s in route.get("steps", [])]
    rides = [r for r in rides if r.get("type") in ("BUS", "SUBWAY")]
    if not rides:
        return None
    labels = " → ".join(label for label in (_vehicle_label(r) for r in rides) if label)
    first_stops = rides[0].get("stops") or []
    last_stops = rides[-1].get("stops") or []
    if first_stops and last_stops:
        stops = f"{first_stops[0].get('name')} → {last_stops[-1].get('name')}"
        return f"{labels} · {stops}" if labels else stops
    return labels or None


async def _bus_leg(client: httpx.AsyncClient, origin: dict, dest: dict):
    """(distance, duration, guidance) of the quickest public-transit route,
    or None when there isn't one. Deliberately no straight-line estimate on
    failure: an invented bus leg is worse than walking it.

    Kakao's totalTime covers the ride plus walking to and from the stops,
    not the wait at the stop."""
    if not KAKAO_REST_API_KEY:
        return None
    try:
        response = await client.get(
            KAKAO_DIRECTIONS_URL["transit"],
            headers={"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"},
            params={
                "start_x": origin["longitude"],
                "start_y": origin["latitude"],
                "end_x": dest["longitude"],
                "end_y": dest["latitude"],
            },
        )
        response.raise_for_status()
        data = response.json()
        if data.get("status") != "OK" or not data.get("routes"):
            return None
        best = min(data["routes"], key=lambda r: r["properties"]["totalTime"])
        props = best["properties"]
        return float(props["totalDistance"]), float(props["totalTime"]), _transit_guidance(best)
    except Exception as exc:
        logger.warning("Kakao transit lookup failed, leaving the leg on foot: %s", exc)
        return None


def _leg_choice(walk: Tuple[float, float], bus) -> Tuple[float, float, str, str | None]:
    """(distance, duration, mode, guidance) for one leg: walk it if that's
    short enough, otherwise take the bus when there is one and it's quicker."""
    walk_distance, walk_duration = walk
    if walk_duration <= WALK_LEG_MAX_SEC or bus is None:
        return walk_distance, walk_duration, "walk", None
    bus_distance, bus_duration, guidance = bus
    if bus_duration < walk_duration:
        return bus_distance, bus_duration, "transit", guidance
    return walk_distance, walk_duration, "walk", None


async def _build_mixed_matrices(nodes: List[dict]):
    """Walking times for every pair, bus routes only where walking is too
    long -- most legs between nearby bookmarks never need the transit
    lookup."""
    n = len(nodes)
    pairs = [(i, j) for i, j in product(range(n), range(n)) if i != j]

    async with httpx.AsyncClient(timeout=KAKAO_TIMEOUT_SECONDS) as client:
        walks = await asyncio.gather(*(_travel_time(client, nodes[i], nodes[j], "walk") for i, j in pairs))
        walk_by_pair = dict(zip(pairs, walks))
        long_pairs = [p for p in pairs if walk_by_pair[p][1] > WALK_LEG_MAX_SEC]
        buses = await asyncio.gather(*(_bus_leg(client, nodes[i], nodes[j]) for i, j in long_pairs))
        bus_by_pair = dict(zip(long_pairs, buses))

    distance = [[0.0] * n for _ in range(n)]
    duration = [[0.0] * n for _ in range(n)]
    mode = [[None] * n for _ in range(n)]
    guidance = [[None] * n for _ in range(n)]
    for i, j in pairs:
        distance[i][j], duration[i][j], mode[i][j], guidance[i][j] = _leg_choice(
            walk_by_pair[(i, j)], bus_by_pair.get((i, j))
        )
    return distance, duration, mode, guidance


async def optimize_place_route(request: PlaceRouteRequest) -> RouteOptimizationResponse:
    """The quickest order to visit the places, starting and ending at
    whichever of them makes the whole trip shortest (an open path, not a
    loop back to some centre point), each leg walked or taken by bus.

    The open path is solved as a loop through an extra node that costs
    nothing to reach from or leave for any place, so the existing
    fixed-endpoint optimizer picks the best first and last stops itself.
    """
    nodes = [{"latitude": p.latitude, "longitude": p.longitude} for p in request.places]
    distance, duration, mode, guidance = await _build_mixed_matrices(nodes)

    free = len(nodes)
    for row in (distance, duration):
        for r in row:
            r.append(0.0)
        row.append([0.0] * (free + 1))

    # Every place gets a turn as the first stop -- from the free node all
    # first moves cost nothing, so a single greedy start is arbitrary.
    candidates = []
    for first in range(free):
        rest = [i for i in range(free) if i != first]
        greedy = _nearest_neighbor_path(duration, first, free, rest)
        candidates.append(_two_opt([free] + greedy, duration))
    route = min(candidates, key=lambda r: _route_cost(r, duration))
    order = route[1:-1]

    points = []
    for position, index in enumerate(order):
        place = request.places[index]
        prev = order[position - 1] if position > 0 else None
        points.append(
            RoutePoint(
                order=position,
                type="place",
                placeId=place.placeId,
                name=place.name,
                latitude=place.latitude,
                longitude=place.longitude,
                legDistanceM=round(distance[prev][index]) if prev is not None else None,
                legDurationSec=round(duration[prev][index]) if prev is not None else None,
                legTransportMode=mode[prev][index] if prev is not None else None,
                legGuidance=guidance[prev][index] if prev is not None else None,
            )
        )

    legs = [(order[k], order[k + 1]) for k in range(len(order) - 1)]
    used_modes = {mode[a][b] for a, b in legs}
    return RouteOptimizationResponse(
        routeType=PLACE_ROUTE_TYPE,
        optimizationPriority="duration",
        # "walk" when every leg ended up walkable, so a compact folder
        # still reads as the walking route it is.
        transportMode="walk" if used_modes <= {"walk"} else MIXED_TRANSPORT_MODE,
        startPlace=points[0],
        endPlace=points[-1],
        optimizedRoute=points,
        # Sums of the legs as shown, so the header always adds up.
        totalDistanceM=sum(p.legDistanceM for p in points[1:]),
        totalDurationSec=sum(p.legDurationSec for p in points[1:]),
    )
