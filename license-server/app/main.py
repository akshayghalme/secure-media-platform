"""License server application entry point.

FastAPI app that validates subscriptions and returns
time-bound decryption keys for DRM-protected content.
"""

import os

from fastapi import FastAPI
from prometheus_client import make_asgi_app

from app.routes.license import router as license_router
from app.routes.health import router as health_router

app = FastAPI(
    title="Secure Media Platform - License Server",
    description="DRM license server for content key delivery",
    version="1.0.0",
)

# Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

app.include_router(health_router)
app.include_router(license_router, prefix="/api/v1")
