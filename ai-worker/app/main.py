import secrets

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.config import AI_WORKER_TOKEN

from app.routers import (
    embedding_router,
    geocode_router,
    place_router,
    recommendation_router,
    route_router,
    search_router,
    transcript_router,
)
from app.utils.exceptions import AiWorkerError

app = FastAPI(title="Travel YouTube AI Worker")

# Paths that answer without the shared secret. /health has to stay open for
# the host's liveness probe, and the docs are harmless without the routes.
_OPEN_PATHS = frozenset({"/health", "/docs", "/openapi.json", "/redoc"})


@app.middleware("http")
async def require_worker_token(request: Request, call_next):
    """Rejects callers that do not know the shared secret.

    Only enforced when AI_WORKER_TOKEN is set, so local dev and the test
    suite run untouched. Deployments either set it or keep this service off
    the public internet -- see backend/.env.example.
    """
    if AI_WORKER_TOKEN and request.url.path not in _OPEN_PATHS:
        presented = request.headers.get("X-Worker-Token", "")
        # Compared in constant time: a plain == leaks the secret one
        # character at a time to anyone who can measure the response.
        if not secrets.compare_digest(presented, AI_WORKER_TOKEN):
            return JSONResponse(
                status_code=401,
                content={"error": {"code": "WORKER_UNAUTHORIZED", "message": "Invalid worker token"}},
            )
    return await call_next(request)

app.include_router(transcript_router.router)
app.include_router(place_router.router)
app.include_router(route_router.router)
app.include_router(search_router.router)
app.include_router(recommendation_router.router)
app.include_router(embedding_router.router)
app.include_router(geocode_router.router)


@app.exception_handler(AiWorkerError)
async def ai_worker_error_handler(request: Request, exc: AiWorkerError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.code, "message": exc.message}},
    )


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
