# Lambda — Trigger MediaConvert

Triggered on `.mp4` upload to raw S3 bucket. Submits a MediaConvert job to transcode into AES-128 encrypted HLS.

## Flow
1. MP4 uploaded to `smp-raw-media-{env}`
2. S3 event notification invokes this Lambda
3. Lambda submits MediaConvert job with HLS + AES-128 encryption
4. Encrypted `.ts` chunks written to `smp-encrypted-media-{env}`

## Environment Variables
- `OUTPUT_BUCKET` — encrypted media bucket name
- `MEDIACONVERT_ENDPOINT` — account-specific MediaConvert API endpoint
- `MEDIACONVERT_ROLE_ARN` — IAM role for MediaConvert
- `HLS_AES_KEY` — AES-128 encryption key (hex)
- `HLS_KEY_URI` — URI for key delivery to HLS player

## Local Testing
```bash
python -c "from handler import handler; print('Import OK')"
```
