import pytest

from app.services import embedding_service
from app.utils.exceptions import AiProviderError


class FakeEmbeddingData:
    def __init__(self, embedding, index=0):
        self.embedding = embedding
        self.index = index


class FakeEmbeddingResponse:
    def __init__(self, embedding):
        self.data = [FakeEmbeddingData(embedding)]


class FakeEmbeddingsResource:
    def __init__(self, embedding=None, error=None):
        self.embedding = embedding
        self.error = error
        self.calls = []

    def create(self, model, input):
        self.calls.append((model, input))
        if self.error:
            raise self.error
        return FakeEmbeddingResponse(self.embedding)


class FakeOpenAiClient:
    def __init__(self, embeddings):
        self.embeddings = embeddings


def test_generate_embedding_returns_the_vector(monkeypatch):
    fake_embeddings = FakeEmbeddingsResource(embedding=[0.1, 0.2, 0.3])
    monkeypatch.setattr(embedding_service, "_openai_client", FakeOpenAiClient(fake_embeddings))

    result = embedding_service.generate_embedding("소금빵 카페")

    assert result == [0.1, 0.2, 0.3]
    assert fake_embeddings.calls[0] == (embedding_service.EMBEDDING_MODEL, "소금빵 카페")


def test_generate_embedding_raises_ai_provider_error_when_the_client_is_missing(monkeypatch):
    monkeypatch.setattr(embedding_service, "_openai_client", None)

    with pytest.raises(AiProviderError):
        embedding_service.generate_embedding("text")


def test_generate_embedding_wraps_provider_failures(monkeypatch):
    fake_embeddings = FakeEmbeddingsResource(error=RuntimeError("down"))
    monkeypatch.setattr(embedding_service, "_openai_client", FakeOpenAiClient(fake_embeddings))

    with pytest.raises(AiProviderError):
        embedding_service.generate_embedding("text")


class FakeBatchEmbeddingsResource:
    def __init__(self):
        self.calls = []

    def create(self, model, input):
        self.calls.append((model, input))

        class Response:
            # Deliberately reversed, to prove results are put back in input order.
            data = [FakeEmbeddingData([float(i)], index=i) for i in reversed(range(len(input)))]

        return Response()


def test_generate_embeddings_embeds_all_texts_in_one_call_in_input_order(monkeypatch):
    fake_embeddings = FakeBatchEmbeddingsResource()
    monkeypatch.setattr(embedding_service, "_openai_client", FakeOpenAiClient(fake_embeddings))

    result = embedding_service.generate_embeddings(["a", "b", "c"])

    assert result == [[0.0], [1.0], [2.0]]
    assert fake_embeddings.calls == [(embedding_service.EMBEDDING_MODEL, ["a", "b", "c"])]


def test_generate_embeddings_skips_the_provider_for_no_texts(monkeypatch):
    monkeypatch.setattr(embedding_service, "_openai_client", None)

    assert embedding_service.generate_embeddings([]) == []


def test_generate_embeddings_wraps_provider_failures(monkeypatch):
    fake_embeddings = FakeEmbeddingsResource(error=RuntimeError("down"))
    monkeypatch.setattr(embedding_service, "_openai_client", FakeOpenAiClient(fake_embeddings))

    with pytest.raises(AiProviderError):
        embedding_service.generate_embeddings(["text"])
