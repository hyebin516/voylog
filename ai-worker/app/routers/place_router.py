from fastapi import APIRouter

from app.schemas.request_schema import PlaceExtractionRequest
from app.schemas.response_schema import PlaceExtractionResponse
from app.services import place_extraction_service

router = APIRouter()


@router.post("/extract-places", response_model=PlaceExtractionResponse)
async def extract_places(request: PlaceExtractionRequest) -> PlaceExtractionResponse:
    return await place_extraction_service.extract_places(request)
