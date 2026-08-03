from fastapi import APIRouter

from app.schemas.request_schema import TranscriptRequest
from app.schemas.response_schema import TranscriptResponse
from app.services import transcript_service

router = APIRouter()


@router.post("/extract-transcript", response_model=TranscriptResponse)
async def extract_transcript(request: TranscriptRequest) -> TranscriptResponse:
    return await transcript_service.get_transcript(request.youtubeUrl)
