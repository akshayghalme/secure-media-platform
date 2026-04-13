# Secure Media Platform

Production-style DRM pipeline that protects video the way Netflix and Disney+ do: encrypted HLS chunks in S3, per-content AES keys in Vault, a license server that hands out time-bound decryption keys, and a signed-URL CloudFront distribution on the front.

Architecture diagram and flow walkthrough: [`docs/architecture.md`](docs/architecture.md) · [`docs/drm-flow.md`](docs/drm-flow.md)

## Tech stack

| Layer | Tool |
|---|---|
| IaC | Terraform (AWS provider ~> 5.0) |
| Cloud | AWS (S3, Lambda, MediaConvert, KMS, DynamoDB, CloudFront, SNS, EKS) |
| Orchestration | Kubernetes on EKS, Helm |
| Secrets / keys | HashiCorp Vault (on EKS), AWS KMS |
| License server | Python 3.11, FastAPI, Redis |
| Ops automation | Ansible (key rotation), Bash helpers |
| Observability | Prometheus, Grafana, Alertmanager → Slack + SNS |

## Prerequisites

- Terraform ≥ 1.5
- AWS CLI v2 configured with an account that can create the resources listed above
- `kubectl`, `helm` ≥ 3.12
- Python 3.11 (for license server + scripts)
- An EKS cluster you can deploy into (phase 3 onwards)
- `envsubst`, `jq`

## Quick start (Phase 1 only)

```bash
git clone https://github.com/akshayghalme/secure-media-platform.git
cd secure-media-platform

# Phase 1 — ingestion pipeline
cd infra/phase1-ingestion
terraform init
terraform apply

# Upload a test clip
aws s3 cp sample.mp4 s3://smp-raw-media-dev/
# ~2 min later, encrypted HLS chunks appear in smp-encrypted-media-dev/
```

Full end-to-end deploy (all 4 phases) is in [`docs/deploy.md`](docs/deploy.md).

## Phases

| # | Branch prefix | What it builds |
|---|---|---|
| 1 | `feature/phase1-*` | S3 buckets, IAM, Lambda trigger, MediaConvert HLS + AES-128, SNS completion |
| 2 | `feature/phase2-*` | KMS key, Vault on EKS, DynamoDB content→key mapping, Ansible 30-day rotation |
| 3 | `feature/phase3-*` | FastAPI license server, Redis cache, Docker/ECR, Helm chart, HPA, IRSA for KMS decrypt |
| 4 | `feature/phase4-*` | CloudFront + OAC + signed URLs, HLS.js test player, Prometheus scrape/rules, Grafana SLI dashboard, Slack + SNS alerts |

### Definition-of-done checks
- **Phase 1:** Upload `.mp4` → encrypted `.ts` chunks in output bucket
- **Phase 2:** `content_id` lookup returns a valid encrypted key from Vault
- **Phase 3:** `curl /license?content_id=...` returns a decryption key in < 200 ms
- **Phase 4:** Browser plays the encrypted stream; Grafana shows live SLIs; p99 > 200 ms pages Slack

## Project learnings

Real problems this solves (and how):

- **Per-content key isolation.** One compromised key exposes one video, not the whole catalog. Implemented via KMS + Vault, mapped by content ID in DynamoDB, rotated by Ansible.
- **Key rotation without breaking active sessions.** Rotation publishes a new key version; the license server issues keys with TTL-bound leases (Redis) so in-flight sessions drain naturally.
- **Origin protection.** S3 is locked to CloudFront via OAC; every segment request is a signed URL checked against an RSA key pair the license server controls.
- **Observability that matches alerts.** Grafana panels and Prometheus alerts both query the same recording rules — "what you see" always equals "what fires."
- **No static AWS credentials in the cluster.** The license server assumes a KMS-decrypt role via IRSA; Alertmanager assumes its SNS-publish role the same way.

## Repo layout

```
infra/
  phase1-ingestion/           S3, IAM, Lambda, MediaConvert
  phase2-kms-vault/           KMS, Vault, DynamoDB mapping
  phase3-eks-license/         EKS, ECR, IRSA, cluster wiring
  phase4-cdn-observability/   CloudFront, Prometheus, Grafana, Alertmanager, SNS
lambda/                       trigger_mediaconvert, job_complete_handler
license-server/               FastAPI app + Vault client
helm/license-server/          Chart with Redis subchart and HPA
ansible/key-rotation/         30-day rotation playbook
docs/                         architecture.md, drm-flow.md, deploy.md
scripts/                      bootstrap, signing, seeding, dashboard loader
```

## Contributing

Branch naming, commit style, and PR rules live in `CLAUDE.md`. TL;DR: one branch per task, PRs against `develop`, never merge to `main` yourself.
