# Phase 1 — S3 Buckets

Two S3 buckets for the content ingestion pipeline:

- **Raw Media Bucket** — upload target for source MP4 files
- **Encrypted Media Bucket** — output for encrypted HLS chunks from MediaConvert

## Security
- All public access blocked on both buckets
- Server-side encryption (SSE-KMS) enforced
- Bucket policies deny unencrypted uploads and insecure transport
- Versioning enabled on both buckets

## Usage
```bash
cd infra/phase1-ingestion
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

## Outputs
- `raw_bucket_id` / `raw_bucket_arn`
- `encrypted_bucket_id` / `encrypted_bucket_arn`
