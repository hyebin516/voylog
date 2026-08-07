from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_nearby_score_returns_sorted_recommendations():
    body = {
        "latitude": 37.5,
        "longitude": 127.0,
        "localTime": "2026-08-10T12:00:00",
        "radiusMeters": 2000,
        "limit": 20,
        "candidates": [
            {"placeId": "p1", "name": "Place 1", "latitude": 37.5005, "longitude": 127.0},
            {"placeId": "p2", "name": "Place 2", "latitude": 37.501, "longitude": 127.0},
        ],
    }

    res = client.post("/recommendations/nearby-score", json=body)

    assert res.status_code == 200
    data = res.json()
    assert len(data["recommendations"]) == 2
    assert data["recommendations"][0]["placeId"] == "p1"


def test_nearby_score_with_no_candidates_returns_an_empty_list():
    body = {
        "latitude": 37.5,
        "longitude": 127.0,
        "localTime": "2026-08-10T12:00:00",
        "candidates": [],
    }

    res = client.post("/recommendations/nearby-score", json=body)

    assert res.status_code == 200
    assert res.json()["recommendations"] == []


def test_nearby_score_rejects_a_missing_latitude():
    res = client.post("/recommendations/nearby-score", json={"longitude": 127.0, "localTime": "2026-08-10T12:00:00"})

    assert res.status_code == 422
