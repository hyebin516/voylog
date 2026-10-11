"""The worker has no user accounts and spends money on every call, so when
it is reachable from the internet the shared secret is all that protects it.
A check that silently stops checking looks exactly like one that works."""

import importlib

import pytest
from fastapi.testclient import TestClient


def build_app(monkeypatch, token):
    monkeypatch.setenv("AI_WORKER_TOKEN", token) if token else monkeypatch.delenv(
        "AI_WORKER_TOKEN", raising=False
    )
    import app.config as config
    import app.main as main

    importlib.reload(config)
    importlib.reload(main)
    return main.app


@pytest.fixture(autouse=True)
def restore_modules():
    yield
    # Leave the modules as the rest of the suite expects to find them.
    import app.config as config
    import app.main as main

    importlib.reload(config)
    importlib.reload(main)


def test_no_token_configured_lets_every_call_through(monkeypatch):
    client = TestClient(build_app(monkeypatch, None))

    assert client.get("/health").status_code == 200
    # A real route: rejected by validation, not by the token check.
    assert client.post("/geocode", json={}).status_code != 401


def test_configured_token_rejects_a_caller_without_it(monkeypatch):
    client = TestClient(build_app(monkeypatch, "s3cret"))

    response = client.post("/geocode", json={})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "WORKER_UNAUTHORIZED"


def test_configured_token_rejects_a_wrong_one(monkeypatch):
    client = TestClient(build_app(monkeypatch, "s3cret"))

    response = client.post("/geocode", json={}, headers={"X-Worker-Token": "guess"})

    assert response.status_code == 401


def test_configured_token_accepts_the_right_one(monkeypatch):
    client = TestClient(build_app(monkeypatch, "s3cret"))

    response = client.post("/geocode", json={}, headers={"X-Worker-Token": "s3cret"})

    # Past the gate: whatever the route answers, it is not the token refusal.
    assert response.status_code != 401


def test_health_stays_open_so_the_host_probe_keeps_working(monkeypatch):
    client = TestClient(build_app(monkeypatch, "s3cret"))

    assert client.get("/health").status_code == 200
