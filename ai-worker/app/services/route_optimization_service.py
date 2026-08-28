import asyncio
from itertools import product
from typing import List, Tuple

import httpx

from app.config import KAKAO_REST_API_KEY, KAKAO_TIMEOUT_SECONDS
from app.schemas.request_schema import RouteOptimizationRequest
from app.schemas.response_schema import RouteOptimizationResponse, RoutePoint
from app.utils.distance import haversine_distance_m
from app.utils.logger import logger

KAKAO_DIRECTIONS_URL = {
    "car": "https://apis-navi.kakaomobility.com/v1/directions",
    "walk": "https://dapi.kakao.com/v2/routing/walk",
}
ASSUMED_CITY_SPEED_MPS = 8.3  # ~30 km/h fallback for car duration estimation
ASSUMED_SPEED_MPS = {
    "car": ASSUMED_CITY_SPEED_MPS,
    "walk": 1.1,  # ~4 km/h, average walking pace
}


async def _kakao_travel_time(client: httpx.AsyncClient, origin: dict, dest: dict, mode: str) -> Tuple[float, float]:
    headers = {"Authorization": f"KakaoAK {KAKAO_REST_API_KEY}"}

    if mode == "walk":
        params = {
            "start_x": origin["longitude"],
            "start_y": origin["latitude"],
            "end_x": dest["longitude"],
            "end_y": dest["latitude"],
        }
        response = await client.get(KAKAO_DIRECTIONS_URL["walk"], headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        props = data["route"]["properties"]
        return float(props["totalDistance"]), float(props["totalTime"])

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
        if index == start_idx:
            return RoutePoint(
                order=order,
                type="hotel",
                hotelId=start_hotel.hotelId,
                name=start_hotel.name,
                latitude=start_hotel.latitude,
                longitude=start_hotel.longitude,
            )
        if index == end_idx:
            return RoutePoint(
                order=order,
                type="hotel",
                hotelId=end_hotel.hotelId,
                name=end_hotel.name,
                latitude=end_hotel.latitude,
                longitude=end_hotel.longitude,
            )
        place = request.places[index - 1]
        return RoutePoint(
            order=order,
            type="place",
            placeId=place.placeId,
            name=place.name,
            latitude=place.latitude,
            longitude=place.longitude,
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
