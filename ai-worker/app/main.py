from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

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
