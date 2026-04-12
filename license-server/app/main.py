"""License server application entry point.

FastAPI app that validates subscriptions and returns
time-bound decryption keys for DRM-protected content.
"""

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import make_asgi_app

from app.routes.license import router as license_router
from app.routes.health import router as health_router

app = FastAPI(
    title="Secure Media Platform - License Server",
    description="DRM license server for content key delivery",
    version="1.0.0",
)

# WHY CORS: the browser test player (player/index.html) calls this API
# from a different origin (http://localhost:8080 for local dev, a real
# player domain in prod). Without this middleware the browser blocks
# the POST with "No 'Access-Control-Allow-Origin' header". Allowed
# origins come from CORS_ALLOW_ORIGINS as a comma-separated list — in
# production set it to the exact player domain, never "*".
_allowed_origins = [
    o.strip()
    for o in os.getenv("CORS_ALLOW_ORIGINS", "http://localhost:8080").split(",")
    if o.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

app.include_router(health_router)
app.include_router(license_router, prefix="/api/v1")
