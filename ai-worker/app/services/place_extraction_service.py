import asyncio

from app.prompts.place_extraction_prompt import build_user_prompt
from app.schemas.request_schema import PlaceExtractionRequest
from app.schemas.response_schema import GeocodedPlace, PlaceExtractionResponse
from app.services import llm_service
from app.services.geocoding_service import geocode_place


async def extract_places(request: PlaceExtractionRequest) -> PlaceExtractionResponse:
    user_prompt = build_user_prompt(
        title=request.video.title,
        description=request.video.description,
        hashtags=request.video.hashtags,
        transcript=[segment.model_dump() for segment in request.transcript],
    )

    llm_result = await asyncio.to_thread(llm_service.extract_places, user_prompt, request.llmProvider)

    geocode_results = await asyncio.gather(*(geocode_place(candidate.name) for candidate in llm_result.places))

    places = []
    for candidate, geo in zip(llm_result.places, geocode_results):
        places.append(
            GeocodedPlace(
                name=candidate.name,
                timestampSec=candidate.timestampSec,
                latitude=geo["latitude"] if geo else None,
                longitude=geo["longitude"] if geo else None,
                address=geo["address"] if geo else None,
                source=candidate.source,
                confidence=candidate.confidence,
                category=candidate.category,
                businessHours=candidate.businessHours,
            )
        )

    return PlaceExtractionResponse(places=places)
