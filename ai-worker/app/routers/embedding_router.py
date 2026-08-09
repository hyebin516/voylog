from fastapi import APIRouter

from app.schemas.request_schema import EmbeddingRequest, PreferenceUpdateRequest
from app.schemas.response_schema import EmbeddingResponse, PreferenceUpdateResponse
from app.services import embedding_service, preference_vector_service

router = APIRouter()


@router.post("/embeddings/generate", response_model=EmbeddingResponse)
async def generate_embedding(request: EmbeddingRequest) -> EmbeddingResponse:
    embedding = embedding_service.generate_embedding(request.text)
    return EmbeddingResponse(
        embedding=embedding,
        model=embedding_service.EMBEDDING_MODEL,
        dimensions=embedding_service.EMBEDDING_DIMENSIONS,
    )


@router.post("/embeddings/update-preference", response_model=PreferenceUpdateResponse)
async def update_preference(request: PreferenceUpdateRequest) -> PreferenceUpdateResponse:
    embedding = preference_vector_service.update_preference_embedding(
        request.currentEmbedding, request.placeEmbedding, request.weight
    )
    return PreferenceUpdateResponse(embedding=embedding)
