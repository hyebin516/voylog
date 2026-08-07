from openai import OpenAI

from app.config import LLM_TIMEOUT_SECONDS, OPENAI_API_KEY
from app.utils.exceptions import AiProviderError

# Swappable by replacing this module's client/constants (e.g. with a local
# sentence-transformers provider) -- callers only depend on generate_embedding,
# never on a specific vendor.
EMBEDDING_MODEL = "text-embedding-3-small"
EMBEDDING_DIMENSIONS = 1536

_openai_client = OpenAI(api_key=OPENAI_API_KEY, timeout=LLM_TIMEOUT_SECONDS) if OPENAI_API_KEY else None


def generate_embedding(text: str) -> list[float]:
    if not _openai_client:
        raise AiProviderError("Embedding provider is not configured")

    try:
        response = _openai_client.embeddings.create(model=EMBEDDING_MODEL, input=text)
    except Exception as exc:
        raise AiProviderError(f"Embedding generation failed: {exc}") from exc

    return response.data[0].embedding
