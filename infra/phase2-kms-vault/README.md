# Phase 2 — KMS + Vault on EKS

KMS keys for encryption and an EKS cluster with HashiCorp Vault in HA mode.

## KMS Keys
- **Content Encryption Key** — encrypts per-content HLS decryption keys
- **S3 Encryption Key** — server-side encryption for media buckets
- Auto-rotation enabled, 30-day deletion window

## EKS + Vault
- **VPC** — 2 public + 2 private subnets across AZs, NAT gateway
- **EKS** — managed cluster with configurable node group
- **Vault** — HA mode (3 replicas), Raft storage, audit logging, UI enabled

## Usage
```bash
cd infra/phase2-kms-vault
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

## Post-Deploy
After apply, initialize and unseal Vault:
```bash
aws eks update-kubeconfig --name secure-media-platform-eks-dev
kubectl exec -n vault vault-0 -- vault operator init
kubectl exec -n vault vault-0 -- vault operator unseal <key>
```

## Outputs
- `content_key_id` / `content_key_arn` / `content_key_alias`
- `s3_key_id` / `s3_key_arn`
- `vpc_id`, `eks_cluster_name`, `eks_cluster_endpoint`
