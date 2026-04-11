"""Health check endpoints for Kubernetes probes."""

from fastapi import APIRouter, Response

from app.cache import get_redis

router = APIRouter(tags=["health"])


@router.get("/healthz")
async def healthz():
    """Liveness probe — returns 200 if the server process is running."""
    return {"status": "ok"}


@router.get("/readyz")
async def readyz(response: Response):
    """Readiness probe — returns 200 if the server and Redis are reachable."""
    try:
        r = await get_redis()
        await r.ping()
        return {"status": "ready", "redis": "connected"}
    except Exception:
        response.status_code = 503
        return {"status": "not_ready", "redis": "disconnected"}
