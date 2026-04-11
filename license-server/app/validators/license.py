"""License request validation."""

from pydantic import BaseModel, Field


class LicenseRequest(BaseModel):
    """Request body for the /license endpoint."""

    content_id: str = Field(..., description="Unique content identifier", min_length=1, max_length=256)
    user_id: str = Field(..., description="Authenticated user identifier", min_length=1, max_length=256)
    subscription_tier: str = Field(
        ...,
        description="User subscription level",
        pattern="^(free|basic|premium)$",
    )


class LicenseResponse(BaseModel):
    """Response body for the /license endpoint."""

    content_id: str
    decryption_key: str
    expires_at: str
    license_id: str
