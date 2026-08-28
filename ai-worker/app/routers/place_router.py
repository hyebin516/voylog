from fastapi import APIRouter

from app.schemas.request_schema import PlaceExtractionRequest, PlaceSummaryRequest
from app.schemas.response_schema import PlaceExtractionResponse, PlaceSummaryResponse
from app.services import place_extraction_service, place_summary_service

router = APIRouter()


@router.post("/extract-places", response_model=PlaceExtractionResponse)
async def extract_places(request: PlaceExtractionRequest) -> PlaceExtractionResponse:
    return await place_extraction_service.extract_places(request)


@router.post("/places/summarize", response_model=PlaceSummaryResponse)
async def summarize_place(request: PlaceSummaryRequest) -> PlaceSummaryResponse:
    return await place_summary_service.summarize_place(request)
