"""License endpoint — validates subscription and returns time-bound decryption key."""

import base64
import uuid
from datetime import datetime, timedelta, timezone

import boto3
from fastapi import APIRouter, HTTPException
from prometheus_client import Counter, Histogram

from app.cache import get_cached_license, set_cached_license
from app.config import settings
from app.validators.license import LicenseRequest, LicenseResponse
from app.vault_client import get_content_key

router = APIRouter(tags=["license"])

# Prometheus metrics
LICENSE_REQUESTS = Counter(
    "license_requests_total",
    "Total license requests",
    ["status"],
)
LICENSE_LATENCY = Histogram(
    "license_request_duration_seconds",
    "License request latency",
    buckets=[0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1.0],
)
CACHE_HITS = Counter(
    "license_cache_hits_total",
    "Total license cache hits",
)

kms_client = boto3.client("kms", region_name=settings.AWS_REGION)


def decrypt_key(encrypted_key: str) -> str:
    """Decrypt a KMS-encrypted data key and return the plaintext as hex.

    Args:
        encrypted_key: Base64-encoded ciphertext blob from KMS.

    Returns:
        Hex-encoded plaintext key.
    """
    response = kms_client.decrypt(
        CiphertextBlob=base64.b64decode(encrypted_key),
    )
    return response["Plaintext"].hex()


@router.post("/license", response_model=LicenseResponse)
@LICENSE_LATENCY.time()
async def issue_license(request: LicenseRequest):
    """Issue a time-bound decryption key for the requested content.

    Validates the user's subscription tier, retrieves the content's
    encrypted key from Vault, decrypts it via KMS, and returns a
    license with an expiration timestamp.

    Args:
        request: License request with content_id, user_id, subscription_tier.

    Returns:
        LicenseResponse with decryption key and expiration.

    Raises:
        HTTPException: 403 if subscription is insufficient,
                       404 if content key not found,
                       500 on internal errors.
    """
    cached = await get_cached_license(request.content_id, request.user_id)
    if cached:
        CACHE_HITS.inc()
        LICENSE_REQUESTS.labels(status="cached").inc()
        return LicenseResponse(**cached)

    if request.subscription_tier == "free":
        LICENSE_REQUESTS.labels(status="denied").inc()
        raise HTTPException(
            status_code=403,
            detail="Premium content requires a basic or premium subscription",
        )

    vault_data = await get_content_key(request.content_id)
    if not vault_data:
        LICENSE_REQUESTS.labels(status="not_found").inc()
        raise HTTPException(
            status_code=404,
            detail=f"No encryption key found for content: {request.content_id}",
        )

    try:
        plaintext_key = decrypt_key(vault_data["encrypted_key"])
    except Exception as e:
        LICENSE_REQUESTS.labels(status="error").inc()
        raise HTTPException(
            status_code=500,
            detail="Failed to decrypt content key",
        )

    expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.LICENSE_TTL_HOURS)
    license_id = str(uuid.uuid4())

    LICENSE_REQUESTS.labels(status="issued").inc()

    response = LicenseResponse(
        content_id=request.content_id,
        decryption_key=plaintext_key,
        expires_at=expires_at.isoformat(),
        license_id=license_id,
    )

    await set_cached_license(request.content_id, request.user_id, response.model_dump())

    return response
