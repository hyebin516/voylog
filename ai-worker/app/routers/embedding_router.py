from fastapi import APIRouter

from app.schemas.request_schema import (
    EmbeddingBatchRequest,
    EmbeddingRequest,
    EmbeddingSimilarityRequest,
    PreferenceUpdateRequest,
)
from app.schemas.response_schema import (
    EmbeddingBatchResponse,
    EmbeddingResponse,
    EmbeddingSimilarityResponse,
    EmbeddingSimilarityScore,
    PreferenceUpdateResponse,
)
from app.services import embedding_service, preference_vector_service
from app.utils.vector_math import cosine_similarity

router = APIRouter()


@router.post("/embeddings/generate", response_model=EmbeddingResponse)
async def generate_embedding(request: EmbeddingRequest) -> EmbeddingResponse:
    embedding = embedding_service.generate_embedding(request.text)
    return EmbeddingResponse(
        embedding=embedding,
        model=embedding_service.EMBEDDING_MODEL,
        dimensions=embedding_service.EMBEDDING_DIMENSIONS,
    )


@router.post("/embeddings/generate-batch", response_model=EmbeddingBatchResponse)
async def generate_embeddings(request: EmbeddingBatchRequest) -> EmbeddingBatchResponse:
    embeddings = embedding_service.generate_embeddings(request.texts)
    return EmbeddingBatchResponse(
        embeddings=embeddings,
        model=embedding_service.EMBEDDING_MODEL,
        dimensions=embedding_service.EMBEDDING_DIMENSIONS,
    )


@router.post("/embeddings/update-preference", response_model=PreferenceUpdateResponse)
async def update_preference(request: PreferenceUpdateRequest) -> PreferenceUpdateResponse:
    embedding = preference_vector_service.update_preference_embedding(
        request.currentEmbedding, request.placeEmbedding, request.weight
    )
    return PreferenceUpdateResponse(embedding=embedding)


@router.post("/embeddings/similarity", response_model=EmbeddingSimilarityResponse)
async def batch_similarity(request: EmbeddingSimilarityRequest) -> EmbeddingSimilarityResponse:
    """Generic cosine-similarity batch endpoint -- callers (backend) never
    compute embedding math themselves, they always hand it to AI Worker (see
    the FR-18 similar-taste pattern this reuses `cosine_similarity` from)."""
    similarities = [
        EmbeddingSimilarityScore(key=target.key, score=cosine_similarity(request.embeddingA, target.embedding))
        for target in request.embeddingsB
    ]
    return EmbeddingSimilarityResponse(similarities=similarities)
