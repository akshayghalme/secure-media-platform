# Deploy Walkthrough — Zero to Playing Video

End-to-end steps to stand the platform up on a real AWS account and play an encrypted video through the browser test player. Expect ~2 hours the first time, most of it waiting for EKS to come up.

**Cost warning:** leaving this running costs a few dollars a day (EKS control plane ~$0.10/hr, NAT gateway ~$0.045/hr, plus CloudFront egress per GB). `terraform destroy` in reverse order when you're done.

---

## 0. Prerequisites

Install these locally:

| Tool | Version | Check |
|---|---|---|
| `aws` CLI | v2+ | `aws --version` |
| `terraform` | 1.5+ | `terraform version` |
| `kubectl` | 1.28+ | `kubectl version --client` |
| `helm` | 3.12+ | `helm version` |
| `docker` | any | `docker version` |
| `python3` | 3.10+ | `python3 --version` |
| `openssl` | any | `openssl version` |

Configure AWS creds for an IAM user/role with admin on the target account:

```bash
aws configure
aws sts get-caller-identity   # confirm
export AWS_REGION=ap-south-1
```

---

## 1. Generate secrets (once, never commit)

```bash
# CloudFront signed-URL keypair
openssl genrsa -out cf-private.pem 2048
openssl rsa -pubout -in cf-private.pem -out cf-public.pem

# Double-check git ignores them
grep -E 'cf-(private|public)\.pem|\*\.pem' .gitignore
```

Keep both files outside the repo tree after the deploy, or at least confirm `.gitignore` catches them.

---

## 2. Apply Terraform in order

Each phase has its own state. Apply them in dependency order.

### 2a. Phase 1 — S3 + Lambda + MediaConvert

```bash
cd infra/phase1-ingestion
terraform init
terraform apply
cd ../..
```

Outputs to note: `raw_bucket_id`, `encrypted_bucket_id`.

### 2b. Phase 2 — KMS + VPC + EKS + Vault + DynamoDB

This is the slowest step. EKS control plane takes ~15 minutes to come up.

```bash
cd infra/phase2-kms-vault
terraform init
terraform apply
cd ../..
```

Wire `kubectl` to the new cluster:

```bash
aws eks update-kubeconfig --name secure-media-platform-eks-dev --region ap-south-1
kubectl get nodes   # should show 2 Ready
```

### 2c. Phase 3 — ECR + IRSA role for license server

Phase 3 now also provisions the IAM role the license-server pod assumes via IRSA. It looks up phase 2's EKS cluster + OIDC provider via data sources, so phase 2 must be fully applied first.

```bash
cd infra/phase3-eks-license
terraform init
terraform apply
export ECR_REPO=$(terraform output -raw ecr_repository_url)
export LICENSE_ROLE_ARN=$(terraform output -raw license_server_role_arn)
cd ../..
echo "$ECR_REPO"
echo "$LICENSE_ROLE_ARN"
```

Save both — they feed into the `helm install` in step 7.

### 2d. Phase 4 — CloudFront

First, remove the phase1-owned bucket policy so phase4 can replace it:

```bash
cd infra/phase1-ingestion
terraform state rm aws_s3_bucket_policy.encrypted_media
cd ../..
```

Then apply:

```bash
cd infra/phase4-cdn-observability
export TF_VAR_cloudfront_public_key_pem="$(cat ../../cf-public.pem)"
terraform init
terraform apply
export CF_DOMAIN=$(terraform output -raw distribution_domain_name)
export CF_KEY_ID=$(terraform output -raw cloudfront_public_key_id)
cd ../..
echo "$CF_DOMAIN / $CF_KEY_ID"
```

---

## 3. Build and push the license server image

```bash
# Log Docker in to ECR
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin "${ECR_REPO%/*}"

# Build and push
docker build -t "$ECR_REPO:v1.0.0" license-server/
docker push "$ECR_REPO:v1.0.0"
```

---

## 4. Install Vault and kube-prometheus-stack on the cluster

Phase 2 Terraform creates the EKS cluster and the Vault IAM plumbing but the actual Vault and Prometheus installs happen via Helm on the cluster:

```bash
# Namespaces
kubectl create namespace vault
kubectl create namespace monitoring

# Vault (dev mode — fine for the walkthrough; production needs HA + auto-unseal)
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault -n vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root"

# Prometheus stack (for the ServiceMonitor from phase4-prometheus)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring

# Wait for Vault
kubectl -n vault rollout status statefulset/vault
```

---

## 5. Seed a test content key

The license server reads content keys from Vault. Seed one:

```bash
# Port-forward Vault locally
kubectl -n vault port-forward svc/vault 8200:8200 &
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
export KMS_KEY_ALIAS=alias/secure-media-platform-content-key-dev

pip install boto3 httpx
python3 scripts/seed-content-key.py demo-movie-001
```

Save the hex key it prints — you'll need it if you want to encrypt HLS segments yourself in step 6.

---

## 6. Get some encrypted video into the bucket

Easiest path: upload a sample MP4 to the raw bucket and let Phase 1's MediaConvert pipeline do the work.

```bash
RAW_BUCKET=$(cd infra/phase1-ingestion && terraform output -raw raw_bucket_id)
# Grab a small test clip (or use any MP4 you have)
curl -L -o sample.mp4 \
  "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
aws s3 cp sample.mp4 "s3://$RAW_BUCKET/demo-movie-001/source.mp4"
```

Watch the job complete:

```bash
aws mediaconvert list-jobs --max-results 5 --region ap-south-1
# wait for Status=COMPLETE, then:
ENC_BUCKET=$(cd infra/phase1-ingestion && terraform output -raw encrypted_bucket_id)
aws s3 ls "s3://$ENC_BUCKET/demo-movie-001/" --recursive
# should show master.m3u8 + segments
```

> **Note:** Phase 1's Lambda currently lets MediaConvert generate its own AES key. For the license-server flow to decrypt those segments, the key Vault holds must match the key MediaConvert used. The cleanest fix is to drive MediaConvert from a key you generated (pass `StaticKeyProvider` pointing at a URL you control). That refactor is tracked as future work; for this walkthrough, either:
>
> - **Option A:** skip encryption on the test clip (set MediaConvert's HLS encryption to `DISABLED` for the demo job) — video plays without the license loop but still goes through CloudFront signed URLs. Simpler.
> - **Option B:** re-encrypt the generated segments locally with the seeded key and re-upload. More realistic but fiddly.

Option A is recommended for your first run.

---

## 7. Install the license server Helm chart

The chart bundles Bitnami Redis as a subchart (see `Chart.yaml` dependencies). Pull it once before the first install:

```bash
helm dependency update helm/license-server
```

Create the Secret first — the pod won't become Ready without `VAULT_TOKEN`:

```bash
kubectl create secret generic license-server-secrets \
  --from-literal=VAULT_TOKEN=root \
  --from-literal=VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
```

Then install, wiring in the IRSA role ARN from step 2c:

```bash
helm install license-server helm/license-server \
  --set image.repository="$ECR_REPO" \
  --set image.tag=v1.0.0 \
  --set env.CORS_ALLOW_ORIGINS=http://localhost:8080 \
  --set serviceAccount.roleArn="$LICENSE_ROLE_ARN"

kubectl rollout status deployment/license-server
kubectl get svc,hpa,servicemonitor,pods -l app=license-server
# you should see license-server-redis-master-0 as well (the subchart)

# Verify the SA picked up the IRSA annotation
kubectl get sa license-server -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# should print the role ARN
```

**Without `serviceAccount.roleArn` the pod runs with node-role credentials, which lack KMS decrypt. The first license request will fail with `AccessDenied` and the readiness probe stops passing.** If that happens, `helm upgrade --reuse-values --set serviceAccount.roleArn=$LICENSE_ROLE_ARN` fixes it without a full reinstall.

Using an external managed Redis (ElastiCache, Upstash) instead? Disable the subchart:

```bash
helm install license-server helm/license-server \
  --set image.repository="$ECR_REPO" \
  --set redis.enabled=false \
  --set env.REDIS_URL="redis://your-endpoint:6379" \
  --set serviceAccount.roleArn="$LICENSE_ROLE_ARN"
```

Smoke test:

```bash
kubectl port-forward svc/license-server 8000:80 &
curl -s http://localhost:8000/healthz
curl -s -X POST http://localhost:8000/api/v1/license \
  -H 'Content-Type: application/json' \
  -d '{"content_id":"demo-movie-001","user_id":"u1","subscription_tier":"premium"}' | jq
```

Expected: `decryption_key`, `expires_at`, `license_id`.

---

## 8. Play it in the browser

```bash
# Build a signed CloudFront URL for the manifest
pip install cryptography
python3 scripts/sign-cloudfront-url.py \
  --url "https://$CF_DOMAIN/demo-movie-001/master.m3u8" \
  --key-pair-id "$CF_KEY_ID" \
  --private-key cf-private.pem \
  --expires-in 3600
# copy the output

# Serve the test player
(cd player && python3 -m http.server 8080) &
open http://localhost:8080
```

In the browser:

1. **License server URL** → `http://localhost:8000/api/v1/license` (leave as-is).
2. **HLS manifest URL** → paste the signed URL from above.
3. **Content ID** → `demo-movie-001`.
4. Click **Play**.

You should see the video play and the status panel show `license_id` + `expires_at`. 🎬

---

## 9. See the metrics flowing

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090 &
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
```

- Prometheus → http://localhost:9090 → Status → Targets → `license-server` should be `UP`.
- Query `license_server:request_duration_seconds:p99` to see the recorded latency.
- Grafana → http://localhost:3000 (default admin password from the secret `kube-prometheus-stack-grafana`).

The Grafana dashboard from `feature/phase4-grafana` will consume these same series once that task lands.

---

## 10. Tear down

Reverse order, or you'll leak orphaned ENIs and security groups:

```bash
helm uninstall license-server
helm uninstall vault -n vault
helm uninstall kube-prometheus-stack -n monitoring

terraform -chdir=infra/phase4-cdn-observability destroy
terraform -chdir=infra/phase3-eks-license destroy
terraform -chdir=infra/phase2-kms-vault destroy   # slowest
terraform -chdir=infra/phase1-ingestion destroy
```

If `phase2` destroy hangs on VPC deletion, it's almost always a dangling ELB from the Helm installs — make sure `helm uninstall` ran cleanly first.

---

## Common gotchas

- **CloudFront 403 "Missing Key"** — manifest URL wasn't signed, or it expired. Re-run `sign-cloudfront-url.py`.
- **CloudFront 403 "SignatureDoesNotMatch"** — the `.pem` you passed to terraform doesn't match the one you're signing with. Re-run phase 4 apply with the correct public key.
- **hls.js "keyLoadError"** — the hex key from the license server didn't match what the segments were actually encrypted with. See the note in step 6.
- **Pods stuck `ImagePullBackOff`** — EKS node IAM role is missing the `AmazonEC2ContainerRegistryReadOnly` managed policy. Phase 2's node group should attach it; verify with `aws iam list-attached-role-policies`.
- **Prometheus target DOWN** — ServiceMonitor label `release:` doesn't match your kube-prometheus-stack release name. Either rename the install or override `serviceMonitor.labels.release` in values.yaml.
