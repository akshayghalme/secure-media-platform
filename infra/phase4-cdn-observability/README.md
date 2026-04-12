# Phase 4 — CDN + Observability

CloudFront distribution fronting the encrypted media bucket, with Origin Access Control (OAC) and trusted-key-group signed URLs. Observability (Prometheus/Grafana/alerts) lands in later tasks of this phase.

## What this module creates

- `aws_cloudfront_origin_access_control.encrypted_media` — OAC so CloudFront can SigV4-sign requests to the SSE-KMS bucket (legacy OAI can't).
- `aws_cloudfront_public_key.signer` + `aws_cloudfront_key_group.signers` — trust anchor for signed URLs. The license server holds the matching private key and signs every `.m3u8` URL before handing it to the player.
- `aws_cloudfront_distribution.media` — HTTPS-only, HLS-tuned caching policy, `trusted_key_groups` set so unsigned requests get a 403.
- `aws_s3_bucket_policy.encrypted_media` — replaces the phase1 bucket policy; allows only this specific distribution (`AWS:SourceArn` condition) to read objects.

## Prerequisites

1. Phase 1 (S3 buckets) already applied — this module looks up the encrypted bucket by name.
2. Generate a signing keypair locally (do NOT commit either file):
   ```bash
   openssl genrsa -out cf-private.pem 2048
   openssl rsa -pubout -in cf-private.pem -out cf-public.pem
   ```
3. Store `cf-private.pem` in AWS Secrets Manager or a Kubernetes Secret so the license server can sign URLs with it. Never let it touch git.

## One-time migration from phase1

Phase 1 created an `aws_s3_bucket_policy.encrypted_media` resource. This module replaces it. Before the first apply, remove it from phase1 state so the two modules don't fight:

```bash
cd infra/phase1-ingestion
terraform state rm aws_s3_bucket_policy.encrypted_media
```

Then delete that resource block from `phase1-ingestion/main.tf` in a follow-up PR so phase1's plan stays clean.

## Apply

```bash
cd infra/phase4-cdn-observability
export TF_VAR_cloudfront_public_key_pem="$(cat ../../cf-public.pem)"
terraform init
terraform plan
terraform apply
```

## Outputs

- `distribution_domain_name` — base URL for playback (e.g. `d1234.cloudfront.net`).
- `cloudfront_public_key_id` — the license server includes this as the `Key-Pair-Id` query param in every signed URL.

## How to test

```bash
# Unsigned request — should return 403 MissingKey
curl -I https://$(terraform output -raw distribution_domain_name)/test/master.m3u8

# Signed request — build the policy + signature with cf-private.pem
# (see AWS docs "Creating a signed URL using a custom policy"), then:
curl -I "https://.../test/master.m3u8?Policy=...&Signature=...&Key-Pair-Id=..."
# → 200 OK
```

## Notes

- CloudFront + ACM certs for custom domains MUST live in `us-east-1`. The aliased provider in `main.tf` is ready for when the `phase4-hls-player` task adds a custom domain + ACM cert.
- Logging is intentionally off for now; real-time logs via Kinesis come in a later task.
