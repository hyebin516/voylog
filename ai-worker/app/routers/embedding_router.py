from fastapi import APIRouter

from app.schemas.request_schema import EmbeddingRequest
from app.schemas.response_schema import EmbeddingResponse
from app.services import embedding_service

router = APIRouter()


@router.post("/embeddings/generate", response_model=EmbeddingResponse)
async def generate_embedding(request: EmbeddingRequest) -> EmbeddingResponse:
    embedding = embedding_service.generate_embedding(request.text)
    return EmbeddingResponse(
        embedding=embedding,
        model=embedding_service.EMBEDDING_MODEL,
        dimensions=embedding_service.EMBEDDING_DIMENSIONS,
    )
