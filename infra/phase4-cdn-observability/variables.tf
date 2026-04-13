variable "aws_region" {
  description = "AWS region for non-CloudFront resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "secure-media-platform"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "encrypted_bucket_name" {
  description = "Base name of the encrypted media bucket from phase1 (without environment suffix)"
  type        = string
  default     = "smp-encrypted-media"
}

# WHY the PEM comes in as a variable, not a file path: keeps secrets/keys
# out of git. The operator generates the keypair locally
# (openssl genrsa -out cf-private.pem 2048 && openssl rsa -pubout ...)
# and exports the public PEM via TF_VAR_cloudfront_public_key_pem.
variable "cloudfront_public_key_pem" {
  description = "PEM-encoded RSA public key used to verify signed URLs"
  type        = string
  sensitive   = true
}

variable "price_class" {
  description = "CloudFront price class — PriceClass_100 covers US/EU/Canada only (cheapest)"
  type        = string
  default     = "PriceClass_200"
}

variable "default_ttl_seconds" {
  description = "Default cache TTL for HLS segments"
  type        = number
  default     = 86400
}

# ── Alerting (phase4-alerts) ──────────────────────────────────────────
# WHY these are variables instead of data sources into phase3 state:
# same loose-coupling rationale as `encrypted_media` above — phase4
# does not want to read phase3's remote state. The operator supplies
# these at apply time (or via a tfvars file kept out of git).
variable "eks_oidc_provider_url" {
  description = "OIDC issuer URL of the EKS cluster (from phase3). Used to build the IRSA trust policy for Alertmanager."
  type        = string
}

variable "alertmanager_namespace" {
  description = "Kubernetes namespace where Alertmanager runs"
  type        = string
  default     = "monitoring"
}

variable "alertmanager_service_account" {
  description = "ServiceAccount name Alertmanager uses (kube-prometheus-stack default)"
  type        = string
  default     = "kube-prometheus-stack-alertmanager"
}
