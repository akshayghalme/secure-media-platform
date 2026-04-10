# License Server

FastAPI application that validates subscriptions and returns time-bound decryption keys for DRM-protected content.

## Run locally
```bash
cd license-server
pip install -r requirements.txt
uvicorn app.main:app --reload
```
