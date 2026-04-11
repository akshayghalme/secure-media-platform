# Phase 3 — License Server on EKS

ECR repository and supporting infrastructure for the FastAPI license server.

## ECR Repository
- Immutable tags (prevents overwriting deployed versions)
- Scan on push (automatic CVE detection)
- Lifecycle policy: keep last 10 tagged images, expire untagged after 1 day

## Build & Push
```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com

# Build
cd license-server
docker build -t secure-media-platform/license-server:v1.0.0 .

# Tag and push
docker tag secure-media-platform/license-server:v1.0.0 <ecr-url>:v1.0.0
docker push <ecr-url>:v1.0.0
```
