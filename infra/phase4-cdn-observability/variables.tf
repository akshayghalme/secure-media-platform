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
