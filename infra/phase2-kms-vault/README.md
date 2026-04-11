# Phase 2 — KMS Key Setup

Two KMS keys for the DRM platform:

- **Content Encryption Key** — encrypts/decrypts per-content HLS keys stored in Vault/DynamoDB
- **S3 Encryption Key** — server-side encryption for media buckets

## Security
- Automatic key rotation enabled (configurable interval, default 365 days)
- Key deletion window of 30 days (configurable)
- Least-privilege key policies
- S3 key allows S3 service principal access

## Usage
```bash
cd infra/phase2-kms-vault
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

## Outputs
- `content_key_id` / `content_key_arn` / `content_key_alias`
- `s3_key_id` / `s3_key_arn`
