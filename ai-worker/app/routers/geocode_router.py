from fastapi import APIRouter

from app.schemas.request_schema import GeocodeRequest
from app.schemas.response_schema import GeocodeResponse
from app.services.geocoding_service import geocode_place
from app.utils.exceptions import GeocodingFailedError

router = APIRouter()


@router.post("/geocode", response_model=GeocodeResponse)
async def geocode(request: GeocodeRequest) -> GeocodeResponse:
    result = await geocode_place(request.query)
    if result is None:
        raise GeocodingFailedError(f"Could not geocode '{request.query}'")
    return GeocodeResponse(**result)
