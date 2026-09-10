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


def test_update_preference_returns_the_updated_embedding():
    res = client.post(
        "/embeddings/update-preference",
        json={"currentEmbedding": [1.0, 0.0], "placeEmbedding": [0.0, 1.0], "weight": 1.0},
    )

    assert res.status_code == 200
    data = res.json()
    assert round(data["embedding"][0], 4) == round(data["embedding"][1], 4)


def test_update_preference_works_without_a_current_embedding():
    res = client.post(
        "/embeddings/update-preference",
        json={"placeEmbedding": [1.0, 0.0], "weight": 1.0},
    )

    assert res.status_code == 200
    assert res.json()["embedding"] == [1.0, 0.0]


def test_update_preference_rejects_a_missing_place_embedding():
    res = client.post("/embeddings/update-preference", json={"weight": 1.0})

    assert res.status_code == 422


def test_similarity_returns_a_score_per_target_in_the_same_order():
    res = client.post(
        "/embeddings/similarity",
        json={
            "embeddingA": [1.0, 0.0],
            "embeddingsB": [
                {"key": "author-1", "embedding": [1.0, 0.0]},
                {"key": "author-2", "embedding": [0.0, 1.0]},
            ],
        },
    )

    assert res.status_code == 200
    similarities = res.json()["similarities"]
    assert similarities[0] == {"key": "author-1", "score": 1.0}
    assert similarities[1] == {"key": "author-2", "score": 0.0}


def test_similarity_returns_null_score_for_a_mismatched_dimension_target():
    res = client.post(
        "/embeddings/similarity",
        json={
            "embeddingA": [1.0, 0.0, 0.0],
            "embeddingsB": [{"key": "author-1", "embedding": [1.0, 0.0]}],
        },
    )

    assert res.status_code == 200
    assert res.json()["similarities"] == [{"key": "author-1", "score": None}]


def test_similarity_returns_empty_list_for_no_targets():
    res = client.post("/embeddings/similarity", json={"embeddingA": [1.0, 0.0], "embeddingsB": []})

    assert res.status_code == 200
    assert res.json()["similarities"] == []


def test_similarity_rejects_missing_embedding_a():
    res = client.post("/embeddings/similarity", json={"embeddingsB": []})

    assert res.status_code == 422
