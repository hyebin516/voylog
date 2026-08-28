from fastapi import APIRouter

from app.schemas.request_schema import NearbyScoreRequest, WalkingCourseRequest
from app.schemas.response_schema import NearbyScoreResponse, WalkingCourseResponse
from app.services import nearby_recommendation_service, walking_course_service

router = APIRouter()


@router.post("/recommendations/nearby-score", response_model=NearbyScoreResponse)
async def score_nearby(request: NearbyScoreRequest) -> NearbyScoreResponse:
    return nearby_recommendation_service.score_nearby(request)


@router.post("/recommendations/walking-course", response_model=WalkingCourseResponse)
async def walking_course(request: WalkingCourseRequest) -> WalkingCourseResponse:
    return await walking_course_service.generate_walking_course(request)
