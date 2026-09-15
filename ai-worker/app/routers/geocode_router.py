from fastapi import APIRouter

from app.schemas.request_schema import GeocodeRequest, PlaceSearchRequest, ReverseGeocodeRequest
from app.schemas.response_schema import GeocodeResponse, PlaceSearchResponse, ReverseGeocodeResponse
from app.services.geocoding_service import geocode_place, reverse_geocode, search_places
from app.utils.exceptions import GeocodingFailedError

router = APIRouter()


@router.post("/geocode", response_model=GeocodeResponse)
async def geocode(request: GeocodeRequest) -> GeocodeResponse:
    result = await geocode_place(request.query)
    if result is None:
        raise GeocodingFailedError(f"Could not geocode '{request.query}'")
    return GeocodeResponse(**result)


@router.post("/geocode/search", response_model=PlaceSearchResponse)
async def geocode_search(request: PlaceSearchRequest) -> PlaceSearchResponse:
    # No results is a normal outcome (e.g. an obscure guesthouse name), not
    # an error -- the client falls back to picking a point on the map.
    candidates = await search_places(request.query, request.size)
    return PlaceSearchResponse(candidates=candidates)


@router.post("/geocode/reverse", response_model=ReverseGeocodeResponse)
async def geocode_reverse(request: ReverseGeocodeRequest) -> ReverseGeocodeResponse:
    address = await reverse_geocode(request.latitude, request.longitude)
    return ReverseGeocodeResponse(address=address)
