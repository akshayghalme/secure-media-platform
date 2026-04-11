"""Vault client for retrieving content encryption keys."""

import httpx

from app.config import settings


async def get_content_key(content_id: str) -> dict | None:
    """Retrieve the encrypted content key from Vault.

    Args:
        content_id: Unique identifier for the content.

    Returns:
        Dictionary with encrypted_key, key_id, and rotated_at,
        or None if the key is not found.
    """
    url = f"{settings.VAULT_ADDR}/v1/{settings.VAULT_SECRET_PATH}/{content_id}"
    headers = {"X-Vault-Token": settings.VAULT_TOKEN}

    async with httpx.AsyncClient() as client:
        response = await client.get(url, headers=headers)

    if response.status_code != 200:
        return None

    data = response.json().get("data", {}).get("data", {})
    return data if data else None
