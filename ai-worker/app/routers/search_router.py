from fastapi import APIRouter

from app.schemas.request_schema import HashtagSearchRequest, VideoSearchRequest
from app.schemas.response_schema import HashtagSearchResponse
from app.services import video_search_service

router = APIRouter()


@router.post("/search-hashtag", response_model=HashtagSearchResponse)
async def search_hashtag(request: HashtagSearchRequest) -> HashtagSearchResponse:
    return await video_search_service.search_by_hashtag(request)


@router.post("/search-videos", response_model=HashtagSearchResponse)
async def search_videos(request: VideoSearchRequest) -> HashtagSearchResponse:
    return await video_search_service.search_by_query(request)
