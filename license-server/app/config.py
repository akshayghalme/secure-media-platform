"""Application configuration loaded from environment variables."""

import os


class Settings:
    """Server configuration from environment variables."""

    AWS_REGION: str = os.getenv("AWS_REGION", "ap-south-1")
    DYNAMODB_TABLE: str = os.getenv("DYNAMODB_TABLE", "secure-media-platform-content-keys-dev")
    VAULT_ADDR: str = os.getenv("VAULT_ADDR", "http://vault.vault.svc.cluster.local:8200")
    VAULT_TOKEN: str = os.getenv("VAULT_TOKEN", "")
    VAULT_SECRET_PATH: str = os.getenv("VAULT_SECRET_PATH", "secret/data/content-keys")
    KMS_KEY_ALIAS: str = os.getenv("KMS_KEY_ALIAS", "alias/secure-media-platform-content-key-dev")
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://redis-service:6379")
    LICENSE_TTL_HOURS: int = int(os.getenv("LICENSE_TTL_HOURS", "48"))


settings = Settings()
