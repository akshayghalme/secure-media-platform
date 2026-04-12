# Test Player — HLS.js harness

Simple browser-side test client that proves the whole pipeline works end-to-end: ingestion → encryption → license issuance → CloudFront delivery → decryption → playback.

## What it does

1. POSTs `{content_id, user_id, subscription_tier}` to the license server's `/api/v1/license`.
2. Receives the hex AES key and converts it to raw bytes.
3. Loads the signed CloudFront manifest URL via hls.js.
4. Intercepts hls.js's key loader so segments are decrypted with the license-server-issued key instead of whatever URI the manifest's `EXT-X-KEY` tag points at.

Step 4 is the important bit — it makes the **license server the source of truth** for decryption. Without the interception, an attacker with the manifest URL could just fetch the key from whatever CDN path is embedded in it.

## Run it

Serve the directory over HTTP (opening `index.html` as a `file://` URL will break CORS against the license server):

```bash
cd player
python3 -m http.server 8080
# then open http://localhost:8080
```

Fill in:
- **License server URL** — default points at a locally-running license server (`uvicorn app.main:app --port 8000`).
- **HLS manifest URL** — a signed CloudFront URL built with `cf-private.pem` and the `cloudfront_public_key_id` output from `infra/phase4-cdn-observability`.
- **Content ID / User ID / Tier** — must match a content key stored in DynamoDB/Vault (phase 2) and a tier the license server accepts (`basic` or `premium`).

Click **Play**. The status panel shows each step.

## CORS

The license server needs to allow this origin. For local testing, add `http://localhost:8080` to FastAPI's `CORSMiddleware` allow list. Production should lock this down to the real player domain.

## Browser support

- Chrome / Firefox / Edge — use hls.js path with the custom key loader. Decryption key never touches the network beyond the license call.
- Safari — falls back to native HLS, which fetches the key via the manifest URI. The harness warns in the status panel. Safari support requires the key to be reachable at the URI embedded in `EXT-X-KEY`, which defeats the point of the license server; treat this as a known limitation of the test harness, not of the platform.

## Files

- `index.html` — inputs + video element.
- `player.js` — license fetch, key loader override, hls.js wiring.
