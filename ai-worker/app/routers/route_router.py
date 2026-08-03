from fastapi import APIRouter

from app.schemas.request_schema import RouteOptimizationRequest
from app.schemas.response_schema import RouteOptimizationResponse
from app.services import route_optimization_service
from app.utils.exceptions import InvalidRequestError

router = APIRouter()

MIN_PLACES = 2
MAX_PLACES = 10


@router.post("/optimize-route", response_model=RouteOptimizationResponse)
async def optimize_route(request: RouteOptimizationRequest) -> RouteOptimizationResponse:
    if not (MIN_PLACES <= len(request.places) <= MAX_PLACES):
        raise InvalidRequestError(f"places must contain between {MIN_PLACES} and {MAX_PLACES} items")

    return await route_optimization_service.optimize_route(request)
