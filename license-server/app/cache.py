"""Redis cache client for license responses."""

import json

import redis.asyncio as redis

from app.config import settings

_pool: redis.Redis | None = None


async def get_redis() -> redis.Redis:
    """Return a shared async Redis connection.

    Returns:
        Async Redis client instance.
    """
    global _pool
    if _pool is None:
        _pool = redis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
        )
    return _pool


async def get_cached_license(content_id: str, user_id: str) -> dict | None:
    """Retrieve a cached license response from Redis.

    Args:
        content_id: Content identifier.
        user_id: User identifier.

    Returns:
        Cached license dict or None if not found.
    """
    r = await get_redis()
    key = f"license:{content_id}:{user_id}"
    data = await r.get(key)
    if data:
        return json.loads(data)
    return None


async def set_cached_license(content_id: str, user_id: str, license_data: dict) -> None:
    """Cache a license response in Redis with TTL.

    Args:
        content_id: Content identifier.
        user_id: User identifier.
        license_data: License response to cache.
    """
    r = await get_redis()
    key = f"license:{content_id}:{user_id}"
    ttl_seconds = settings.LICENSE_TTL_HOURS * 3600
    await r.set(key, json.dumps(license_data), ex=ttl_seconds)
