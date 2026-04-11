"""Health check endpoints for Kubernetes probes."""

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/healthz")
async def healthz():
    """Liveness probe — returns 200 if the server process is running."""
    return {"status": "ok"}


@router.get("/readyz")
async def readyz():
    """Readiness probe — returns 200 if the server is ready to serve traffic."""
    return {"status": "ready"}
