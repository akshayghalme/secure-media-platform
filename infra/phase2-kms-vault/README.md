# Phase 2 — Vault on EKS

Deploys an EKS cluster with HashiCorp Vault in HA mode using Raft storage.

## Architecture
- **VPC** — 2 public + 2 private subnets across AZs, NAT gateway for private egress
- **EKS** — managed Kubernetes cluster with configurable node group
- **Vault** — HA mode with 3 replicas, Raft integrated storage, audit logging, UI enabled

## Vault Features
- HA with Raft consensus (no external storage dependency)
- Sidecar injector enabled for automatic secret injection
- Audit storage for compliance
- ClusterIP service (not exposed externally)

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
- `vpc_id`, `eks_cluster_name`, `eks_cluster_endpoint`
