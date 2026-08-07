from fastapi import APIRouter

from app.schemas.request_schema import NearbyScoreRequest
from app.schemas.response_schema import NearbyScoreResponse
from app.services import nearby_recommendation_service

router = APIRouter()


@router.post("/recommendations/nearby-score", response_model=NearbyScoreResponse)
async def score_nearby(request: NearbyScoreRequest) -> NearbyScoreResponse:
    return nearby_recommendation_service.score_nearby(request)
