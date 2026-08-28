import asyncio

from app.prompts.place_summary_prompt import build_user_prompt
from app.schemas.request_schema import PlaceSummaryRequest
from app.schemas.response_schema import PlaceSummaryResponse
from app.services import llm_service


async def summarize_place(request: PlaceSummaryRequest) -> PlaceSummaryResponse:
    user_prompt = build_user_prompt(place_name=request.placeName, notes=request.notes)
    result = await asyncio.to_thread(llm_service.summarize_place, user_prompt, request.llmProvider)
    return PlaceSummaryResponse(pros=result.pros, cons=result.cons)
