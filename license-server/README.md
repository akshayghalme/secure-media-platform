# License Server

FastAPI application that validates subscriptions and returns time-bound decryption keys for DRM-protected content.

## Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/license` | Issue a decryption key license |
| GET | `/healthz` | Liveness probe |
| GET | `/readyz` | Readiness probe |
| GET | `/metrics` | Prometheus metrics |

## License Flow
1. Client sends `content_id`, `user_id`, `subscription_tier`
2. Server validates subscription (free tier is denied)
3. Retrieves encrypted content key from Vault
4. Decrypts via KMS
5. Returns plaintext key with 48-hour TTL

## Run Locally
```bash
cd license-server
pip install -r requirements.txt
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=dev-token
uvicorn app.main:app --reload
```

## Test
```bash
curl -X POST http://localhost:8000/api/v1/license \
  -H "Content-Type: application/json" \
  -d '{"content_id": "movie-001", "user_id": "user-123", "subscription_tier": "premium"}'
```

## Environment Variables
See `app/config.py` for all configuration options.
