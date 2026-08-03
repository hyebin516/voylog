from fastapi.testclient import TestClient

from app.main import app
from app.services import transcript_service
from app.utils.exceptions import TranscriptNotFoundError

client = TestClient(app)


def test_health_endpoint():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_ai_worker_error_is_mapped_to_its_own_status_code_and_error_envelope(monkeypatch):
    async def raise_not_found(youtube_url):
        raise TranscriptNotFoundError()

    monkeypatch.setattr(transcript_service, "get_transcript", raise_not_found)

    res = client.post("/extract-transcript", json={"youtubeUrl": "https://youtu.be/dQw4w9WgXcQ"})

    assert res.status_code == 422
    assert res.json() == {"error": {"code": "TRANSCRIPT_NOT_FOUND", "message": "Transcript is not available for this video"}}


def test_extract_transcript_validates_request_body():
    res = client.post("/extract-transcript", json={})
    assert res.status_code == 422  # FastAPI/pydantic request validation, not our AiWorkerError
