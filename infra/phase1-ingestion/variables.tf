variable "aws_region" {
  description = "AWS region for all resources"
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

variable "raw_bucket_name" {
  description = "Name of the S3 bucket for raw uploaded media"
  type        = string
  default     = "smp-raw-media"
}

variable "encrypted_bucket_name" {
  description = "Name of the S3 bucket for encrypted HLS output"
  type        = string
  default     = "smp-encrypted-media"
}

# WHY the MediaConvert endpoint is a variable, not a data source: it's
# per-account and only exists after you open the MediaConvert console
# once to activate the service. terraform data sources can't provision
# it; the operator has to pass it in. `aws mediaconvert describe-endpoints`
# returns it once activated.
variable "mediaconvert_endpoint" {
  description = "Per-account MediaConvert endpoint URL (get via `aws mediaconvert describe-endpoints`)"
  type        = string
}

# WHY hls_aes_key is a variable (not generated inside terraform):
# for the demo flow this SAME key must also be seeded into Vault at
# `content-keys/<content_id>` so the license server hands back a key
# that actually decrypts MediaConvert's output. Generating it inside
# terraform would trap the plaintext in tfstate; passing it in lets the
# operator keep it ephemeral. Use `scripts/deploy-demo-key.sh` to
# generate + seed + set this variable in one shot.
#
# Production path: Lambda should fetch a per-content key from Vault at
# invocation time (keyed on the S3 object prefix) instead of reading
# one env var. That refactor is tracked as future work.
variable "hls_aes_key" {
  description = "32-char hex AES-128 key for HLS segment encryption (demo-mode: same key for all content)"
  type        = string
  sensitive   = true
}

variable "hls_key_uri" {
  description = "URI embedded in EXT-X-KEY so players know where to fetch the key. Not actually used for decryption because the test player overrides it via a custom hls.js keyLoader."
  type        = string
  default     = "https://license.example.com/key"
}
