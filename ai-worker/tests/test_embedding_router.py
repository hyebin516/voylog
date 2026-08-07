from fastapi.testclient import TestClient

from app.main import app
from app.services import embedding_service

client = TestClient(app)


def test_generate_embedding_returns_vector_model_and_dimensions(monkeypatch):
    monkeypatch.setattr(embedding_service, "generate_embedding", lambda text: [0.1, 0.2])

    res = client.post("/embeddings/generate", json={"text": "소금빵 카페"})

    assert res.status_code == 200
    data = res.json()
    assert data["embedding"] == [0.1, 0.2]
    assert data["model"] == embedding_service.EMBEDDING_MODEL
    assert data["dimensions"] == embedding_service.EMBEDDING_DIMENSIONS


def test_generate_embedding_rejects_missing_text():
    res = client.post("/embeddings/generate", json={})

    assert res.status_code == 422
